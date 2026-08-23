const express = require('express');
const { getPool } = require('../database');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

// Apply auth middleware to all library routes
router.use(authenticateToken);

// ==========================================
// FAVORITES / STARRED SONGS
// ==========================================

// GET /api/library/favorites
router.get('/favorites', async (req, res) => {
  try {
    const pool = getPool();
    const [rows] = await pool.query(
      'SELECT song_id as id, title, artist, album, cover_art as coverArt, duration, created_at FROM favorites WHERE user_id = ? ORDER BY created_at DESC',
      [req.user.id]
    );

    return res.json({
      success: true,
      favorites: rows,
    });
  } catch (err) {
    console.error('[Favorites GET Error]:', err);
    return res.status(500).json({ success: false, error: 'Error al obtener favoritos.' });
  }
});

// POST /api/library/favorites
router.post('/favorites', async (req, res) => {
  try {
    const { songId, title, artist, album, coverArt, duration } = req.body;

    if (!songId || !title) {
      return res.status(400).json({
        success: false,
        error: 'songId y title son obligatorios.',
      });
    }

    const pool = getPool();
    await pool.query(
      `INSERT INTO favorites (user_id, song_id, title, artist, album, cover_art, duration)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE title = VALUES(title), artist = VALUES(artist), album = VALUES(album), cover_art = VALUES(cover_art), duration = VALUES(duration)`,
      [req.user.id, songId, title, artist || '', album || '', coverArt || '', duration || 0]
    );

    return res.status(201).json({
      success: true,
      message: 'Canción añadida a favoritos.',
    });
  } catch (err) {
    console.error('[Favorites POST Error]:', err);
    return res.status(500).json({ success: false, error: 'Error al guardar favorito.' });
  }
});

// DELETE /api/library/favorites/:songId
router.delete('/favorites/:songId', async (req, res) => {
  try {
    const pool = getPool();
    await pool.query(
      'DELETE FROM favorites WHERE user_id = ? AND song_id = ?',
      [req.user.id, req.params.songId]
    );

    return res.json({
      success: true,
      message: 'Canción eliminada de favoritos.',
    });
  } catch (err) {
    console.error('[Favorites DELETE Error]:', err);
    return res.status(500).json({ success: false, error: 'Error al eliminar de favoritos.' });
  }
});

// ==========================================
// PLAYLISTS
// ==========================================

// GET /api/library/playlists
router.get('/playlists', async (req, res) => {
  try {
    const pool = getPool();
    const [playlists] = await pool.query(
      `SELECT p.id, p.name, p.description, p.cover_art as coverArt, p.created_at, p.updated_at,
              COUNT(ps.id) as song_count
       FROM playlists p
       LEFT JOIN playlist_songs ps ON p.id = ps.playlist_id
       WHERE p.user_id = ?
       GROUP BY p.id
       ORDER BY p.updated_at DESC`,
      [req.user.id]
    );

    return res.json({
      success: true,
      playlists,
    });
  } catch (err) {
    console.error('[Playlists GET Error]:', err);
    return res.status(500).json({ success: false, error: 'Error al obtener playlists.' });
  }
});

// POST /api/library/playlists
router.post('/playlists', async (req, res) => {
  try {
    const { name, description, coverArt } = req.body;

    if (!name || name.trim().length === 0) {
      return res.status(400).json({
        success: false,
        error: 'El nombre de la playlist es obligatorio.',
      });
    }

    const pool = getPool();
    const [result] = await pool.query(
      'INSERT INTO playlists (user_id, name, description, cover_art) VALUES (?, ?, ?, ?)',
      [req.user.id, name.trim(), description || '', coverArt || '']
    );

    return res.status(201).json({
      success: true,
      message: 'Playlist creada exitosamente.',
      playlist: {
        id: result.insertId,
        name: name.trim(),
        description: description || '',
        coverArt: coverArt || '',
        songCount: 0,
      },
    });
  } catch (err) {
    console.error('[Playlists POST Error]:', err);
    return res.status(500).json({ success: false, error: 'Error al crear playlist.' });
  }
});

// GET /api/library/playlists/:id
router.get('/playlists/:id', async (req, res) => {
  try {
    const pool = getPool();
    const [playlists] = await pool.query(
      'SELECT id, name, description, cover_art as coverArt, created_at, updated_at FROM playlists WHERE id = ? AND user_id = ? LIMIT 1',
      [req.params.id, req.user.id]
    );

    if (playlists.length === 0) {
      return res.status(404).json({ success: false, error: 'Playlist no encontrada.' });
    }

    const [songs] = await pool.query(
      'SELECT id, song_id as songId, title, artist, album, cover_art as coverArt, duration, position, added_at FROM playlist_songs WHERE playlist_id = ? ORDER BY position ASC, id ASC',
      [req.params.id]
    );

    return res.json({
      success: true,
      playlist: {
        ...playlists[0],
        songs,
      },
    });
  } catch (err) {
    console.error('[Playlist Detail GET Error]:', err);
    return res.status(500).json({ success: false, error: 'Error al consultar playlist.' });
  }
});

// POST /api/library/playlists/:id/songs
router.post('/playlists/:id/songs', async (req, res) => {
  try {
    const { songId, title, artist, album, coverArt, duration } = req.body;
    const pool = getPool();

    // Verify ownership
    const [playlists] = await pool.query(
      'SELECT id FROM playlists WHERE id = ? AND user_id = ? LIMIT 1',
      [req.params.id, req.user.id]
    );

    if (playlists.length === 0) {
      return res.status(404).json({ success: false, error: 'Playlist no encontrada.' });
    }

    // Get current max position
    const [posRow] = await pool.query(
      'SELECT COALESCE(MAX(position), 0) + 1 as nextPos FROM playlist_songs WHERE playlist_id = ?',
      [req.params.id]
    );
    const nextPos = posRow[0]?.nextPos || 0;

    await pool.query(
      `INSERT INTO playlist_songs (playlist_id, song_id, title, artist, album, cover_art, duration, position)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [req.params.id, songId, title, artist || '', album || '', coverArt || '', duration || 0, nextPos]
    );

    await pool.query(
      'UPDATE playlists SET updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      [req.params.id]
    );

    return res.status(201).json({
      success: true,
      message: 'Canción añadida a la playlist.',
    });
  } catch (err) {
    console.error('[Playlist Song POST Error]:', err);
    return res.status(500).json({ success: false, error: 'Error al añadir canción a la playlist.' });
  }
});

// DELETE /api/library/playlists/:id/songs/:songId
router.delete('/playlists/:id/songs/:songId', async (req, res) => {
  try {
    const pool = getPool();
    await pool.query(
      'DELETE FROM playlist_songs WHERE playlist_id = ? AND song_id = ?',
      [req.params.id, req.params.songId]
    );

    await pool.query(
      'UPDATE playlists SET updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      [req.params.id]
    );

    return res.json({
      success: true,
      message: 'Canción eliminada de la playlist.',
    });
  } catch (err) {
    console.error('[Playlist Song DELETE Error]:', err);
    return res.status(500).json({ success: false, error: 'Error al eliminar canción.' });
  }
});

// ==========================================
// PLAYBACK HISTORY
// ==========================================

// GET /api/library/history
router.get('/history', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit || '50', 10);
    const pool = getPool();
    const [rows] = await pool.query(
      'SELECT song_id as id, title, artist, album, cover_art as coverArt, duration, played_at FROM playback_history WHERE user_id = ? ORDER BY played_at DESC LIMIT ?',
      [req.user.id, limit]
    );

    return res.json({
      success: true,
      history: rows,
    });
  } catch (err) {
    console.error('[History GET Error]:', err);
    return res.status(500).json({ success: false, error: 'Error al obtener historial.' });
  }
});

// POST /api/library/history
router.post('/history', async (req, res) => {
  try {
    const { songId, title, artist, album, coverArt, duration } = req.body;
    if (!songId || !title) {
      return res.status(400).json({ success: false, error: 'songId y title requeridos' });
    }

    const pool = getPool();
    await pool.query(
      'INSERT INTO playback_history (user_id, song_id, title, artist, album, cover_art, duration) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [req.user.id, songId, title, artist || '', album || '', coverArt || '', duration || 0]
    );

    return res.status(201).json({
      success: true,
      message: 'Historial registrado.',
    });
  } catch (err) {
    console.error('[History POST Error]:', err);
    return res.status(500).json({ success: false, error: 'Error al registrar historial.' });
  }
});

module.exports = router;
