#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Setting up Full Stack Node.js Application...${NC}\n"

# Create project root directory
PROJECT_NAME="fullstack-nodejs-app"
echo -e "${YELLOW}📁 Creating project directory: ${PROJECT_NAME}${NC}"
mkdir -p $PROJECT_NAME
cd $PROJECT_NAME

# Create directory structure
echo -e "${YELLOW}📁 Creating directory structure...${NC}"
mkdir -p frontend/src frontend/public
mkdir -p backend

# Create docker-compose.yml
echo -e "${GREEN}✅ Creating docker-compose.yml${NC}"
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  frontend:
    build: ./frontend
    ports:
      - "3000:80"
    depends_on:
      - backend
    environment:
      - REACT_APP_API_URL=http://localhost:4000/api
    networks:
      - app-network

  backend:
    build: ./backend
    ports:
      - "4000:4000"
    depends_on:
      - mongodb
      - redis
    environment:
      - PORT=4000
      - MONGODB_URI=mongodb://mongodb:27017/myapp
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - NODE_ENV=production
    networks:
      - app-network
    restart: unless-stopped

  mongodb:
    image: mongo:7
    ports:
      - "27017:27017"
    volumes:
      - mongodb_data:/data/db
    networks:
      - app-network
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    networks:
      - app-network
    restart: unless-stopped

volumes:
  mongodb_data:
  redis_data:

networks:
  app-network:
    driver: bridge
EOF

# Create Backend Files
echo -e "${GREEN}✅ Creating backend/Dockerfile${NC}"
cat > backend/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./

RUN npm install --omit=dev

COPY . .

EXPOSE 4000

CMD ["node", "server.js"]
EOF

echo -e "${GREEN}✅ Creating backend/package.json${NC}"
cat > backend/package.json << 'EOF'
{
  "name": "backend",
  "version": "1.0.0",
  "description": "Backend API with MongoDB and Redis",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "mongoose": "^8.0.0",
    "redis": "^4.6.0",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

echo -e "${GREEN}✅ Creating backend/server.js${NC}"
cat > backend/server.js << 'EOF'
const express = require('express');
const mongoose = require('mongoose');
const redis = require('redis');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 4000;

// Middleware
app.use(cors());
app.use(express.json());

// Redis Client
const redisClient = redis.createClient({
  socket: {
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379
  }
});

redisClient.on('error', (err) => console.error('Redis Client Error', err));
redisClient.connect();

// MongoDB Connection
mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/myapp')
  .then(() => console.log('MongoDB connected'))
  .catch(err => console.error('MongoDB connection error:', err));

// MongoDB Schema
const ItemSchema = new mongoose.Schema({
  name: { type: String, required: true },
  description: String,
  createdAt: { type: Date, default: Date.now }
});

const Item = mongoose.model('Item', ItemSchema);

// Health check
app.get('/api/health', async (req, res) => {
  try {
    const mongoStatus = mongoose.connection.readyState === 1 ? 'connected' : 'disconnected';
    const redisStatus = redisClient.isOpen ? 'connected' : 'disconnected';
    
    res.json({
      status: 'ok',
      mongodb: mongoStatus,
      redis: redisStatus,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get all items (with Redis caching)
app.get('/api/items', async (req, res) => {
  try {
    // Check Redis cache first
    const cachedItems = await redisClient.get('items');
    
    if (cachedItems) {
      return res.json({
        data: JSON.parse(cachedItems),
        source: 'cache'
      });
    }

    // If not in cache, get from MongoDB
    const items = await Item.find().sort({ createdAt: -1 });
    
    // Store in Redis cache for 60 seconds
    await redisClient.setEx('items', 60, JSON.stringify(items));
    
    res.json({
      data: items,
      source: 'database'
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Create item
app.post('/api/items', async (req, res) => {
  try {
    const { name, description } = req.body;
    
    const newItem = new Item({ name, description });
    await newItem.save();
    
    // Invalidate cache
    await redisClient.del('items');
    
    res.status(201).json(newItem);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Delete item
app.delete('/api/items/:id', async (req, res) => {
  try {
    await Item.findByIdAndDelete(req.params.id);
    
    // Invalidate cache
    await redisClient.del('items');
    
    res.json({ message: 'Item deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Visit counter using Redis
app.post('/api/visit', async (req, res) => {
  try {
    const count = await redisClient.incr('visit_count');
    res.json({ visits: count });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/visits', async (req, res) => {
  try {
    const count = await redisClient.get('visit_count') || 0;
    res.json({ visits: parseInt(count) });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`Backend server running on port ${PORT}`);
});
EOF

# Create Frontend Files
echo -e "${GREEN}✅ Creating frontend/Dockerfile${NC}"
cat > frontend/Dockerfile << 'EOF'
# Build stage
FROM node:18-alpine as build

WORKDIR /app

COPY package*.json ./

RUN npm ci

COPY . .

RUN npm run build

# Production stage
FROM nginx:alpine

COPY --from=build /app/build /usr/share/nginx/html

COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOF

echo -e "${GREEN}✅ Creating frontend/nginx.conf${NC}"
cat > frontend/nginx.conf << 'EOF'
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api {
        proxy_pass http://backend:4000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

echo -e "${GREEN}✅ Creating frontend/package.json${NC}"
cat > frontend/package.json << 'EOF'
{
  "name": "frontend",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "eslintConfig": {
    "extends": [
      "react-app"
    ]
  },
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  }
}
EOF

echo -e "${GREEN}✅ Creating frontend/public/index.html${NC}"
cat > frontend/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta name="description" content="Full Stack Node.js App with MongoDB and Redis" />
    <title>Full Stack App</title>
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
  </body>
</html>
EOF

echo -e "${GREEN}✅ Creating frontend/src/index.js${NC}"
cat > frontend/src/index.js << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import './App.css';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

echo -e "${GREEN}✅ Creating frontend/src/App.js${NC}"
cat > frontend/src/App.js << 'EOF'
import React, { useState, useEffect } from 'react';
import './App.css';

const API_URL = process.env.REACT_APP_API_URL || '/api';

function App() {
  const [items, setItems] = useState([]);
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [visits, setVisits] = useState(0);
  const [health, setHealth] = useState(null);
  const [loading, setLoading] = useState(false);
  const [source, setSource] = useState('');

  useEffect(() => {
    fetchHealth();
    fetchItems();
    fetchVisits();
    recordVisit();
  }, []);

  const fetchHealth = async () => {
    try {
      const res = await fetch(`${API_URL}/health`);
      const data = await res.json();
      setHealth(data);
    } catch (error) {
      console.error('Error fetching health:', error);
    }
  };

  const fetchItems = async () => {
    setLoading(true);
    try {
      const res = await fetch(`${API_URL}/items`);
      const data = await res.json();
      setItems(data.data);
      setSource(data.source);
    } catch (error) {
      console.error('Error fetching items:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchVisits = async () => {
    try {
      const res = await fetch(`${API_URL}/visits`);
      const data = await res.json();
      setVisits(data.visits);
    } catch (error) {
      console.error('Error fetching visits:', error);
    }
  };

  const recordVisit = async () => {
    try {
      const res = await fetch(`${API_URL}/visit`, { method: 'POST' });
      const data = await res.json();
      setVisits(data.visits);
    } catch (error) {
      console.error('Error recording visit:', error);
    }
  };

  const addItem = async (e) => {
    e.preventDefault();
    if (!name.trim()) return;

    try {
      const res = await fetch(`${API_URL}/items`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, description })
      });

      if (res.ok) {
        setName('');
        setDescription('');
        fetchItems();
      }
    } catch (error) {
      console.error('Error adding item:', error);
    }
  };

  const deleteItem = async (id) => {
    try {
      await fetch(`${API_URL}/items/${id}`, { method: 'DELETE' });
      fetchItems();
    } catch (error) {
      console.error('Error deleting item:', error);
    }
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>📦 Full Stack Node.js App</h1>
        <p>MongoDB + Redis + Express + React</p>
      </header>

      <div className="container">
        {/* Health Status */}
        <div className="card health-card">
          <h2>🏥 System Health</h2>
          {health ? (
            <div className="health-status">
              <div className={`status-item ${health.mongodb === 'connected' ? 'connected' : 'disconnected'}`}>
                MongoDB: {health.mongodb}
              </div>
              <div className={`status-item ${health.redis === 'connected' ? 'connected' : 'disconnected'}`}>
                Redis: {health.redis}
              </div>
              <div className="status-item">
                👥 Total Visits: {visits}
              </div>
            </div>
          ) : (
            <p>Loading...</p>
          )}
        </div>

        {/* Add Item Form */}
        <div className="card">
          <h2>➕ Add New Item</h2>
          <form onSubmit={addItem}>
            <input
              type="text"
              placeholder="Item name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
            />
            <input
              type="text"
              placeholder="Description (optional)"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
            />
            <button type="submit">Add Item</button>
          </form>
        </div>

        {/* Items List */}
        <div className="card">
          <div className="items-header">
            <h2>📋 Items List</h2>
            <button onClick={fetchItems} className="refresh-btn">
              🔄 Refresh
            </button>
          </div>
          {source && (
            <p className="cache-info">
              Data source: <strong>{source === 'cache' ? '⚡ Redis Cache' : '💾 MongoDB'}</strong>
            </p>
          )}
          {loading ? (
            <p>Loading items...</p>
          ) : items.length === 0 ? (
            <p className="no-items">No items yet. Add one above!</p>
          ) : (
            <div className="items-list">
              {items.map((item) => (
                <div key={item._id} className="item">
                  <div className="item-content">
                    <h3>{item.name}</h3>
                    {item.description && <p>{item.description}</p>}
                    <small>{new Date(item.createdAt).toLocaleString()}</small>
                  </div>
                  <button
                    onClick={() => deleteItem(item._id)}
                    className="delete-btn"
                  >
                    🗑️
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default App;
EOF

echo -e "${GREEN}✅ Creating frontend/src/App.css${NC}"
cat > frontend/src/App.css << 'EOF'
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  min-height: 100vh;
}

.App {
  min-height: 100vh;
  padding-bottom: 2rem;
}

.App-header {
  background: rgba(255, 255, 255, 0.95);
  padding: 2rem;
  text-align: center;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  margin-bottom: 2rem;
}

.App-header h1 {
  color: #667eea;
  margin-bottom: 0.5rem;
  font-size: 2.5rem;
}

.App-header p {
  color: #666;
  font-size: 1.1rem;
}

.container {
  max-width: 800px;
  margin: 0 auto;
  padding: 0 1rem;
}

.card {
  background: white;
  border-radius: 12px;
  padding: 2rem;
  margin-bottom: 1.5rem;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

.card h2 {
  color: #333;
  margin-bottom: 1.5rem;
  font-size: 1.5rem;
}

/* Health Card */
.health-card {
  background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%);
  color: white;
}

.health-card h2 {
  color: white;
}

.health-status {
  display: flex;
  gap: 1rem;
  flex-wrap: wrap;
}

.status-item {
  background: rgba(255, 255, 255, 0.2);
  padding: 0.75rem 1rem;
  border-radius: 8px;
  font-weight: 500;
  flex: 1;
  min-width: 150px;
  text-align: center;
}

.status-item.connected {
  background: rgba(255, 255, 255, 0.3);
}

/* Form */
form {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

input {
  padding: 0.75rem;
  border: 2px solid #e0e0e0;
  border-radius: 8px;
  font-size: 1rem;
  transition: border-color 0.3s;
}

input:focus {
  outline: none;
  border-color: #667eea;
}

button {
  padding: 0.75rem 1.5rem;
  background: #667eea;
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.3s;
}

button:hover {
  background: #5568d3;
}

.refresh-btn {
  padding: 0.5rem 1rem;
  font-size: 0.9rem;
}

/* Items */
.items-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.items-header h2 {
  margin-bottom: 0;
}

.cache-info {
  color: #666;
  margin-bottom: 1rem;
  font-size: 0.9rem;
}

.no-items {
  text-align: center;
  color: #999;
  padding: 2rem;
}

.items-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.item {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  padding: 1rem;
  background: #f8f9fa;
  border-radius: 8px;
  border: 2px solid #e0e0e0;
  transition: border-color 0.3s;
}

.item:hover {
  border-color: #667eea;
}

.item-content {
  flex: 1;
}

.item-content h3 {
  color: #333;
  margin-bottom: 0.5rem;
}

.item-content p {
  color: #666;
  margin-bottom: 0.5rem;
}

.item-content small {
  color: #999;
  font-size: 0.85rem;
}

.delete-btn {
  padding: 0.5rem 0.75rem;
  background: #ff4757;
  font-size: 1rem;
  min-width: auto;
}

.delete-btn:hover {
  background: #ee5a6f;
}

@media (max-width: 768px) {
  .App-header h1 {
    font-size: 1.8rem;
  }

  .card {
    padding: 1.5rem;
  }

  .health-status {
    flex-direction: column;
  }

  .status-item {
    width: 100%;
  }
}
EOF

# Create README
echo -e "${GREEN}✅ Creating README.md${NC}"
cat > README.md << 'EOF'
# Full Stack Node.js Application

A complete full-stack application with React frontend, Express backend, MongoDB, and Redis - all Dockerized.

## 🚀 Quick Start

### Prerequisites
- Docker
- Docker Compose

### Running the Application

1. **Start all services:**
   ```bash
   docker-compose up --build
   ```

2. **Access the application:**
   - Frontend: http://localhost:3000
   - Backend API: http://localhost:4000/api
   - MongoDB: localhost:27017
   - Redis: localhost:6379

3. **Stop all services:**
   ```bash
   docker-compose down
   ```

## 🔌 API Endpoints

- `GET /api/health` - System health status
- `GET /api/items` - Get all items (with Redis caching)
- `POST /api/items` - Create new item
- `DELETE /api/items/:id` - Delete item
- `GET /api/visits` - Get visit count
- `POST /api/visit` - Increment visit count

## ✨ Features

- React Frontend with modern UI
- Express Backend with RESTful API
- MongoDB for persistent storage
- Redis for caching and counters
- Full Docker containerization
- Health monitoring

## 🧪 Testing

```bash
# Test health endpoint
curl http://localhost:4000/api/health

# Create an item
curl -X POST http://localhost:4000/api/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Item","description":"This is a test"}'

# Get all items
curl http://localhost:4000/api/items
```

## 📦 Project Structure

```
.
├── docker-compose.yml
├── frontend/
│   ├── Dockerfile
│   ├── nginx.conf
│   ├── package.json
│   ├── public/
│   │   └── index.html
│   └── src/
│       ├── App.js
│       ├── App.css
│       └── index.js
└── backend/
    ├── Dockerfile
    ├── package.json
    └── server.js
```
EOF

# Create .gitignore
echo -e "${GREEN}✅ Creating .gitignore${NC}"
cat > .gitignore << 'EOF'
# Dependencies
node_modules/
*/node_modules/

# Production
build/
dist/

# Environment
.env
.env.local

# Logs
*.log
npm-debug.log*

# OS
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
*.swp
*.swo

# Docker
.dockerignore
EOF

echo -e "\n${BLUE}════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✨ Setup complete! ✨${NC}"
echo -e "${BLUE}════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}📂 Project created in: ${NC}$(pwd)"
echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "  1. cd $PROJECT_NAME"
echo -e "  2. docker-compose up --build"
echo -e "  3. Open http://localhost:3000 in your browser\n"

echo -e "${BLUE}💡 Useful commands:${NC}"
echo -e "  - Stop: ${GREEN}docker-compose down${NC}"
echo -e "  - Logs: ${GREEN}docker-compose logs -f${NC}"
echo -e "  - Rebuild: ${GREEN}docker-compose up --build${NC}\n"

echo -e "${GREEN}Happy coding! 🚀${NC}\n"