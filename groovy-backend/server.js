const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
require('dotenv').config();

const { initDatabase } = require('./database');
const authRoutes = require('./routes/auth');
const libraryRoutes = require('./routes/library');
const adminRoutes = require('./routes/admin');
const telemetryRoutes = require('./routes/telemetry');
const musicRoutes = require('./routes/music');

const app = express();
const PORT = process.env.PORT || 4000;
const allowedOrigins = (process.env.CORS_ALLOWED_ORIGINS || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

// Middleware
app.use(cors({
  origin: allowedOrigins.length === 0
    ? '*'
    : (origin, callback) => {
      if (!origin || allowedOrigins.includes(origin)) {
        return callback(null, true);
      }
      return callback(new Error('CORS origin not allowed'));
    },
}));
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

const path = require('path');
const fs = require('fs');

// Serve compiled React frontend if present
const distPath = path.join(__dirname, '../react-website/dist');
const localDistPath = path.join(__dirname, 'public');
const staticDir = fs.existsSync(distPath) ? distPath : (fs.existsSync(localDistPath) ? localDistPath : null);

if (staticDir) {
  console.log(`📁 Serving React frontend from: ${staticDir}`);
  app.use(express.static(staticDir));
}

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/library', libraryRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/telemetry', telemetryRoutes);
app.use('/api/music', musicRoutes);

// SPA fallback: Return index.html for all frontend routes (excluding /api)
app.get('*', (req, res) => {
  if (req.path.startsWith('/api')) {
    return res.status(404).json({ error: 'API endpoint not found' });
  }
  if (staticDir && fs.existsSync(path.join(staticDir, 'index.html'))) {
    return res.sendFile(path.join(staticDir, 'index.html'));
  }
  res.send('🎵 Groovy Cloud Music API is running! (Frontend build not found)');
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
