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
