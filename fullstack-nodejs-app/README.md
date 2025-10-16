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
