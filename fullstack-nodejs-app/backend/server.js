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
