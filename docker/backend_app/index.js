const express = require('express');
const bodyParser = require('body-parser');

const app = express();
const PORT = 3000;
const users = [];
app.use(bodyParser.json());

// Routes
app.get('/', (req, res) => {
    res.send('Hello World');
});

// Get registered users
app.get('/users', (req, res) => {
    return res.json(users);
});

// registere new user
app.post('/users', (req, res) => {
    const newUserId = req.body.userId;
    if (!newUserId) {
        return res.status(400).json({ message: 'User ID is required' });
    }
    if (users.includes(newUserId)) {
        return res.status(400).json({ message: 'User already registered' });
    }
    users.push(newUserId);
    res.status(201).json({ message: 'User registered successfully', userId: newUserId });
});

// Start server
const server = app.listen(PORT, () => {
    console.log(`🚀 Server is running on port ${PORT}`);
});

// Graceful shutdown to free the port
const shutdown = () => {
    console.log('\n🛑 Shutting down server...');
    server.close(() => {
        console.log('✅ Server closed. Port freed.');
        process.exit(0);
    });
};

// Handle process signals
process.on('SIGINT', shutdown);   // For Ctrl + C
process.on('SIGTERM', shutdown);  // For kill or system stop