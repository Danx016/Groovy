const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
require('dotenv').config();

const { initDatabase } = require('./database');
const authRoutes = require('./routes/auth');
const libraryRoutes = require('./routes/library');

const app = express();
const PORT = process.env.PORT || 4000;

// Middleware
app.use(cors({ origin: '*' }));
app.use(express.json({ limit: '10mb' }));
app.use(morgan('combined'));

// Health check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'Groovy Music Cloud API',
    database: 'MySQL',
    timestamp: new Date().toISOString(),
  });
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/library', libraryRoutes);

// Root greeting
app.get('/', (req, res) => {
  res.send('🎵 Groovy Cloud Music API is running!');
});

// Start server after DB is ready
async function startServer() {
  try {
    await initDatabase();
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`🚀 Groovy Cloud API listening on http://0.0.0.0:${PORT}`);
    });
  } catch (err) {
    console.error('❌ Failed to start Groovy server:', err);
    process.exit(1);
  }
}

startServer();
