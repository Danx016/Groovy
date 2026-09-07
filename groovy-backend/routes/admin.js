const express = require('express');
const bcrypt = require('bcryptjs');
const { getPool } = require('../database');
const { authenticateAdmin } = require('../middleware/auth');

const router = express.Router();

// Apply admin authentication middleware to all admin endpoints
router.use(authenticateAdmin);

/**
 * GET /api/admin/metrics
 * System-wide metrics & telemetry overview
 */
router.get('/metrics', async (req, res) => {
  try {
    const pool = getPool();

    // Total users
    const [totalUsersRows] = await pool.query('SELECT COUNT(*) as count FROM users');
    const totalUsers = totalUsersRows[0].count;

    // Active users in last 24h
    const [activeTodayRows] = await pool.query(`
      SELECT COUNT(DISTINCT user_id) as count 
      FROM user_sessions 
      WHERE created_at >= NOW() - INTERVAL 1 DAY
    `);
    const activeToday = activeTodayRows[0].count;

    // Total Favorites & Playlists
    const [favRows] = await pool.query('SELECT COUNT(*) as count FROM favorites');
    const [playlistRows] = await pool.query('SELECT COUNT(*) as count FROM playlists');
    const [historyRows] = await pool.query('SELECT COUNT(*) as count FROM playback_history');
    const [sessionRows] = await pool.query('SELECT COUNT(*) as count FROM user_sessions');

    // Recent 6 logins
    const [recentSessions] = await pool.query(`
      SELECT s.id, s.user_id, u.name as user_name, u.email as user_email, s.ip_address, s.device_os, s.browser, s.client_platform, s.created_at
      FROM user_sessions s
      JOIN users u ON s.user_id = u.id
      ORDER BY s.created_at DESC
      LIMIT 6
    `);

    // Top played songs
    const [topSongs] = await pool.query(`
      SELECT song_id, title, artist, cover_art, COUNT(*) as play_count
      FROM playback_history
      GROUP BY song_id, title, artist, cover_art
      ORDER BY play_count DESC
      LIMIT 5
    `);

    return res.json({
      success: true,
      metrics: {
        totalUsers,
        activeToday,
        totalFavorites: favRows[0].count,
        totalPlaylists: playlistRows[0].count,
        totalPlays: historyRows[0].count,
        totalSessions: sessionRows[0].count,
        recentSessions,
        topSongs,
      },
    });
  } catch (err) {
    console.error('[Admin Metrics Error]:', err);
    return res.status(500).json({
      success: false,
      error: 'Error al consultar métricas del sistema.',
    });
  }
});

/**
 * GET /api/admin/users
 * List all users with aggregated telemetry (favorites, playlists, history, last IP, last device)
 */
router.get('/users', async (req, res) => {
  try {
    const { q, role, status } = req.query;
    const pool = getPool();

    let query = `
      SELECT 
        u.id, 
        u.name, 
        u.email, 
        u.avatar_url, 
        u.role, 
        u.is_banned, 
        u.last_login_at, 
        u.last_login_ip, 
        u.last_device, 
        u.created_at,
        (SELECT COUNT(*) FROM favorites f WHERE f.user_id = u.id) as favorites_count,
        (SELECT COUNT(*) FROM playlists p WHERE p.user_id = u.id) as playlists_count,
        (SELECT COUNT(*) FROM playback_history h WHERE h.user_id = u.id) as history_count,
        (SELECT COUNT(*) FROM user_sessions s WHERE s.user_id = u.id) as sessions_count
      FROM users u
      WHERE 1=1
    `;
    const params = [];

    if (q) {
      query += ` AND (u.name LIKE ? OR u.email LIKE ? OR u.last_login_ip LIKE ? OR u.last_device LIKE ?)`;
      const searchPattern = `%${q.trim()}%`;
      params.push(searchPattern, searchPattern, searchPattern, searchPattern);
    }

    if (role && role !== 'all') {
      query += ` AND u.role = ?`;
      params.push(role);
    }

    if (status === 'banned') {
      query += ` AND u.is_banned = 1`;
    } else if (status === 'active') {
      query += ` AND (u.is_banned = 0 OR u.is_banned IS NULL)`;
    }

    query += ` ORDER BY u.created_at DESC`;

    const [rows] = await pool.query(query, params);

    return res.json({
      success: true,
      users: rows.map(u => ({
        id: u.id,
        name: u.name,
        email: u.email,
        avatarUrl: u.avatar_url,
        role: u.role || 'user',
        isBanned: u.is_banned === 1,
        lastLoginAt: u.last_login_at,
        lastLoginIp: u.last_login_ip,
        lastDevice: u.last_device,
        createdAt: u.created_at,
        stats: {
          favorites: u.favorites_count || 0,
          playlists: u.playlists_count || 0,
          plays: u.history_count || 0,
          sessions: u.sessions_count || 0,
        },
      })),
    });
  } catch (err) {
    console.error('[Admin Get Users Error]:', err);
    return res.status(500).json({
      success: false,
      error: 'Error al obtener la lista de usuarios.',
    });
  }
});

/**
 * GET /api/admin/users/:id
 * Full deep dive into a user's account, devices, IPs, playlists, favorites, playback history
 */
router.get('/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const pool = getPool();

    const [userRows] = await pool.query(
      'SELECT id, name, email, avatar_url, role, is_banned, last_login_at, last_login_ip, last_device, created_at, updated_at FROM users WHERE id = ? LIMIT 1',
      [id]
    );

    if (userRows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Usuario no encontrado.',
      });
    }

    const user = userRows[0];

    // Login sessions / devices / IPs (last 50)
    const [sessions] = await pool.query(
      'SELECT id, ip_address, device_os, browser, device_type, client_platform, user_agent, created_at, last_active_at FROM user_sessions WHERE user_id = ? ORDER BY created_at DESC LIMIT 50',
      [id]
    );

    // User's playlists
    const [playlists] = await pool.query(
      'SELECT id, name, description, cover_art, created_at FROM playlists WHERE user_id = ? ORDER BY created_at DESC',
      [id]
    );

    // User's favorites (last 50)
    const [favorites] = await pool.query(
      'SELECT id, song_id, title, artist, album, cover_art, duration, created_at FROM favorites WHERE user_id = ? ORDER BY created_at DESC LIMIT 50',
      [id]
    );

    // User's playback history (last 50)
    const [history] = await pool.query(
      'SELECT id, song_id, title, artist, album, cover_art, duration, played_at FROM playback_history WHERE user_id = ? ORDER BY played_at DESC LIMIT 50',
      [id]
    );

    return res.json({
      success: true,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        avatarUrl: user.avatar_url,
        role: user.role || 'user',
        isBanned: user.is_banned === 1,
        lastLoginAt: user.last_login_at,
        lastLoginIp: user.last_login_ip,
        lastDevice: user.last_device,
        createdAt: user.created_at,
        updatedAt: user.updated_at,
      },
      sessions,
      playlists,
      favorites,
      history,
    });
  } catch (err) {
    console.error('[Admin Get User Detail Error]:', err);
    return res.status(500).json({
      success: false,
      error: 'Error al obtener los detalles del usuario.',
    });
  }
});

/**
 * PUT /api/admin/users/:id
 * Edit user information (name, email, role, password)
 */
router.put('/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { name, email, role, password, avatarUrl } = req.body;
    const pool = getPool();

    const [existing] = await pool.query('SELECT id, email FROM users WHERE id = ? LIMIT 1', [id]);
    if (existing.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Usuario no encontrado.',
      });
    }

    if (email && email.trim().toLowerCase() !== existing[0].email) {
      const [duplicate] = await pool.query('SELECT id FROM users WHERE email = ? AND id != ? LIMIT 1', [
        email.trim().toLowerCase(),
        id,
      ]);
      if (duplicate.length > 0) {
        return res.status(409).json({
          success: false,
          error: 'Ese correo electrónico ya está registrado por otra cuenta.',
        });
      }
    }

    let passwordHash = null;
    if (password && password.trim().length >= 6) {
      const salt = await bcrypt.genSalt(10);
      passwordHash = await bcrypt.hash(password.trim(), salt);
    }

    let query = 'UPDATE users SET ';
    const params = [];
    const updates = [];

    if (name) {
      updates.push('name = ?');
      params.push(name.trim());
    }
    if (email) {
      updates.push('email = ?');
      params.push(email.trim().toLowerCase());
    }
    if (role && (role === 'admin' || role === 'user')) {
      updates.push('role = ?');
      params.push(role);
    }
    if (avatarUrl !== undefined) {
      updates.push('avatar_url = ?');
      params.push(avatarUrl);
    }
    if (passwordHash) {
      updates.push('password_hash = ?');
      params.push(passwordHash);
    }

    if (updates.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'No se enviaron campos válidos para actualizar.',
      });
    }

    query += updates.join(', ') + ' WHERE id = ?';
    params.push(id);

    await pool.query(query, params);

    const [updatedRows] = await pool.query(
      'SELECT id, name, email, avatar_url, role, is_banned, last_login_ip, last_device, created_at FROM users WHERE id = ?',
      [id]
    );

    return res.json({
      success: true,
      message: 'Usuario actualizado exitosamente',
      user: updatedRows[0],
    });
  } catch (err) {
    console.error('[Admin Update User Error]:', err);
    return res.status(500).json({
      success: false,
      error: 'Error al actualizar el usuario.',
    });
  }
});

/**
 * PUT /api/admin/users/:id/ban
 * Ban or unban a user
 */
router.put('/users/:id/ban', async (req, res) => {
  try {
    const { id } = req.params;
    const { isBanned } = req.body;
    const pool = getPool();

    // Prevent banning oneself
    if (parseInt(id, 10) === req.user.id && isBanned) {
      return res.status(400).json({
        success: false,
        error: 'No puedes suspender tu propia cuenta de administrador.',
      });
    }

    await pool.query('UPDATE users SET is_banned = ? WHERE id = ?', [isBanned ? 1 : 0, id]);

    return res.json({
      success: true,
      message: isBanned ? 'Usuario suspendido correctamente' : 'Usuario reactivado correctamente',
      isBanned: !!isBanned,
    });
  } catch (err) {
    console.error('[Admin Ban User Error]:', err);
    return res.status(500).json({
      success: false,
      error: 'Error al cambiar estado de suspensión.',
    });
  }
});

/**
 * DELETE /api/admin/users/:id
 * Permanently delete a user and cascade all their data
 */
router.delete('/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const pool = getPool();

    if (parseInt(id, 10) === req.user.id) {
      return res.status(400).json({
        success: false,
        error: 'No puedes eliminar tu propia cuenta de administrador.',
      });
    }

    const [existing] = await pool.query('SELECT name FROM users WHERE id = ?', [id]);
    if (existing.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Usuario no encontrado.',
      });
    }

    await pool.query('DELETE FROM users WHERE id = ?', [id]);

    return res.json({
      success: true,
      message: `Usuario ${existing[0].name} eliminado permanentemente.`,
    });
  } catch (err) {
    console.error('[Admin Delete User Error]:', err);
    return res.status(500).json({
      success: false,
      error: 'Error al eliminar usuario.',
    });
  }
});

/**
 * GET /api/admin/sessions
 * Global recent sessions / IP audit trail
 */
router.get('/sessions', async (req, res) => {
  try {
    const { limit = 100 } = req.query;
    const pool = getPool();

    const [sessions] = await pool.query(`
      SELECT 
        s.id,
        s.user_id,
        u.name as user_name,
        u.email as user_email,
        u.avatar_url as user_avatar,
        s.ip_address,
        s.user_agent,
        s.device_os,
        s.browser,
        s.device_type,
        s.client_platform,
        s.created_at,
        s.last_active_at
      FROM user_sessions s
      JOIN users u ON s.user_id = u.id
      ORDER BY s.created_at DESC
      LIMIT ?
    `, [parseInt(limit, 10) || 100]);

    return res.json({
      success: true,
      sessions,
    });
  } catch (err) {
    console.error('[Admin Get Sessions Error]:', err);
    return res.status(500).json({
      success: false,
      error: 'Error al obtener auditoría de sesiones e IPs.',
    });
  }
});

module.exports = router;
