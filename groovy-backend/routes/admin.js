const express = require('express');
const bcrypt = require('bcryptjs');
const { getPool } = require('../database');
const { authenticateAdmin } = require('../middleware/auth');

const router = express.Router();

// Apply admin authentication middleware to all admin endpoints
router.use(authenticateAdmin);

/**
 * GET /api/admin/live-playback
 * Real-time list of all users currently listening to music right now
 */
router.get('/live-playback', async (req, res) => {
  try {
    const pool = getPool();
    // 1. Live playback stream presence (within last 5 minutes)
    const [rows] = await pool.query(`
      SELECT 
        lp.user_id,
        u.name as user_name,
        u.email as user_email,
        u.avatar_url as user_avatar,
        u.role as user_role,
        lp.song_id,
        lp.title,
        lp.artist,
        lp.album,
        lp.cover_art,
        lp.duration,
        lp.position,
        lp.is_playing,
        lp.platform,
        lp.device_name,
        lp.ip_address,
        lp.device_model,
        lp.os_version,
        lp.country,
        lp.city,
        lp.started_at,
        lp.last_ping_at,
        TIMESTAMPDIFF(SECOND, lp.last_ping_at, NOW()) as seconds_since_ping
      FROM user_live_playback lp
      JOIN users u ON lp.user_id = u.id
      WHERE lp.last_ping_at >= NOW() - INTERVAL 300 SECOND
      ORDER BY lp.last_ping_at DESC
    `);

    // 2. Users active/connected in the app right now (within last 5 minutes)
    const [connectedRows] = await pool.query(`
      SELECT 
        s.id as session_id,
        s.user_id,
        u.name as user_name,
        u.email as user_email,
        u.avatar_url as user_avatar,
        u.role as user_role,
        s.client_platform,
        s.device_model,
        s.device_os,
        s.os_version,
        s.ip_address,
        s.country,
        s.country_code,
        s.city,
        s.region,
        s.isp,
        s.session_duration_seconds,
        COALESCE(s.last_active_at, s.created_at) as last_active_at,
        TIMESTAMPDIFF(SECOND, COALESCE(s.last_active_at, s.created_at), NOW()) as seconds_since_active
      FROM user_sessions s
      JOIN users u ON s.user_id = u.id
      WHERE s.last_active_at >= NOW() - INTERVAL 300 SECOND OR s.created_at >= NOW() - INTERVAL 300 SECOND
      ORDER BY s.last_active_at DESC
    `);

    return res.json({
      success: true,
      count: rows.length,
      listeners: rows.map(r => ({
        userId: r.user_id,
        userName: r.user_name,
        userEmail: r.user_email,
        userAvatar: r.user_avatar,
        userRole: r.user_role,
        songId: r.song_id,
        title: r.title,
        artist: r.artist,
        album: r.album,
        coverArt: r.cover_art,
        duration: r.duration,
        position: r.position,
        isPlaying: r.is_playing === 1 && (r.seconds_since_ping < 90),
        platform: r.platform || 'Desconocido',
        deviceName: r.device_name,
        ipAddress: r.ip_address,
        deviceModel: r.device_model,
        osVersion: r.os_version,
        country: r.country,
        city: r.city,
        startedAt: r.started_at,
        lastPingAt: r.last_ping_at,
        secondsSincePing: r.seconds_since_ping,
      })),
      connectedUsers: connectedRows.map(s => ({
        sessionId: s.session_id,
        userId: s.user_id,
        userName: s.user_name,
        userEmail: s.user_email,
        userAvatar: s.user_avatar,
        userRole: s.user_role,
        platform: s.client_platform || s.device_os,
        deviceModel: s.device_model || s.device_os,
        osVersion: s.os_version,
        ipAddress: s.ip_address,
        country: s.country,
        countryCode: s.country_code,
        city: s.city,
        region: s.region,
        isp: s.isp,
        durationSeconds: s.session_duration_seconds,
        lastActiveAt: s.last_active_at,
        secondsSinceActive: s.seconds_since_active,
      })),
    });
  } catch (err) {
    console.error('[Admin Live Playback Error]:', err);
    return res.status(500).json({ success: false, error: 'Error al consultar reproducción en vivo.' });
  }
});

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
      WHERE created_at >= NOW() - INTERVAL 1 DAY OR last_active_at >= NOW() - INTERVAL 1 DAY
    `);
    const activeToday = activeTodayRows[0].count;

    // Currently active listeners (playing right now within 180s)
    const [activeListenersRows] = await pool.query(`
      SELECT COUNT(*) as count 
      FROM user_live_playback 
      WHERE is_playing = 1 AND last_ping_at >= NOW() - INTERVAL 180 SECOND
    `);
    const activeListeners = activeListenersRows[0].count;

    // Total listen time in seconds across all users (sum of users table or playback_history)
    const [listenTimeRows] = await pool.query(`
      SELECT COALESCE(
        NULLIF(SUM(u.total_listen_seconds), 0),
        (SELECT SUM(COALESCE(h.listen_seconds, h.duration, 180)) FROM playback_history h),
        0
      ) as total_seconds FROM users u
    `);
    const totalListenSeconds = parseInt(listenTimeRows[0]?.total_seconds || 0, 10);

    // Total Favorites & Playlists & Plays & Sessions
    const [favRows] = await pool.query('SELECT COUNT(*) as count FROM favorites');
    const [playlistRows] = await pool.query('SELECT COUNT(*) as count FROM playlists');
    const [historyRows] = await pool.query('SELECT COUNT(*) as count FROM playback_history');
    const [sessionRows] = await pool.query('SELECT COUNT(*) as count FROM user_sessions');

    // Recent sessions
    const [recentSessions] = await pool.query(`
      SELECT 
        s.id, 
        s.user_id, 
        u.name as user_name, 
        u.email as user_email, 
        s.ip_address, 
        s.device_os, 
        s.browser, 
        s.client_platform, 
        s.device_model,
        s.os_version,
        s.country,
        s.city,
        s.isp,
        s.created_at, 
        s.last_active_at, 
        s.session_duration_seconds
      FROM user_sessions s
      JOIN users u ON s.user_id = u.id
      ORDER BY s.created_at DESC
      LIMIT 8
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
        activeListeners,
        totalListenSeconds,
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
 * List all users with aggregated telemetry, live playback, listening time, and last active dates
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
        COALESCE(u.last_login_at, (SELECT s.created_at FROM user_sessions s WHERE s.user_id = u.id ORDER BY s.id DESC LIMIT 1), u.created_at) as last_login_at, 
        COALESCE(u.last_active_at, u.last_login_at, (SELECT s.last_active_at FROM user_sessions s WHERE s.user_id = u.id ORDER BY s.id DESC LIMIT 1), u.created_at) as last_active_at,
        COALESCE(NULLIF(u.last_login_ip, ''), (SELECT s.ip_address FROM user_sessions s WHERE s.user_id = u.id ORDER BY s.id DESC LIMIT 1), '127.0.0.1') as last_login_ip, 
        COALESCE(NULLIF(u.last_device, ''), (SELECT CONCAT(COALESCE(s.device_model, s.device_os), ' · ', COALESCE(s.os_version, s.device_os)) FROM user_sessions s WHERE s.user_id = u.id ORDER BY s.id DESC LIMIT 1), 'Sin dispositivo') as last_device, 
        COALESCE(NULLIF(u.last_country, ''), (SELECT s.country FROM user_sessions s WHERE s.user_id = u.id ORDER BY s.id DESC LIMIT 1), 'Colombia') as last_country,
        COALESCE(NULLIF(u.last_country_code, ''), (SELECT s.country_code FROM user_sessions s WHERE s.user_id = u.id ORDER BY s.id DESC LIMIT 1), 'CO') as last_country_code,
        COALESCE(NULLIF(u.last_city, ''), (SELECT s.city FROM user_sessions s WHERE s.user_id = u.id ORDER BY s.id DESC LIMIT 1), 'Local') as last_city,
        COALESCE(NULLIF(u.last_region, ''), (SELECT s.region FROM user_sessions s WHERE s.user_id = u.id ORDER BY s.id DESC LIMIT 1), '') as last_region,
        COALESCE(NULLIF(u.last_isp, ''), (SELECT s.isp FROM user_sessions s WHERE s.user_id = u.id ORDER BY s.id DESC LIMIT 1), 'Proveedor Local') as last_isp,
        COALESCE(NULLIF(u.last_os_version, ''), (SELECT s.os_version FROM user_sessions s WHERE s.user_id = u.id ORDER BY s.id DESC LIMIT 1), '') as last_os_version,
        COALESCE(NULLIF(u.last_device_model, ''), (SELECT s.device_model FROM user_sessions s WHERE s.user_id = u.id ORDER BY s.id DESC LIMIT 1), '') as last_device_model,
        COALESCE(
          NULLIF(u.total_listen_seconds, 0),
          (SELECT SUM(COALESCE(h.listen_seconds, h.duration, 180)) FROM playback_history h WHERE h.user_id = u.id),
          0
        ) as total_listen_seconds,
        u.created_at,
        (SELECT COUNT(*) FROM favorites f WHERE f.user_id = u.id) as favorites_count,
        (SELECT COUNT(*) FROM playlists p WHERE p.user_id = u.id) as playlists_count,
        (SELECT COUNT(*) FROM playback_history h WHERE h.user_id = u.id) as history_count,
        (SELECT COUNT(*) FROM user_sessions s WHERE s.user_id = u.id) as sessions_count,
        lp.song_id as live_song_id,
        lp.title as live_title,
        lp.artist as live_artist,
        lp.cover_art as live_cover_art,
        lp.platform as live_platform,
        lp.device_name as live_device,
        lp.device_model as live_device_model,
        lp.os_version as live_os_version,
        lp.country as live_country,
        lp.city as live_city,
        lp.is_playing as live_is_playing,
        lp.position as live_position,
        lp.duration as live_duration,
        lp.last_ping_at as live_last_ping,
        TIMESTAMPDIFF(SECOND, lp.last_ping_at, NOW()) as live_seconds_ago
      FROM users u
      LEFT JOIN user_live_playback lp ON lp.user_id = u.id AND lp.last_ping_at >= NOW() - INTERVAL 180 SECOND
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
        lastActiveAt: u.last_active_at,
        lastLoginIp: u.last_login_ip,
        lastDevice: u.last_device,
        lastCountry: u.last_country,
        lastCountryCode: u.last_country_code,
        lastCity: u.last_city,
        lastRegion: u.last_region,
        lastIsp: u.last_isp,
        lastOsVersion: u.last_os_version,
        lastDeviceModel: u.last_device_model,
        totalListenSeconds: u.total_listen_seconds || 0,
        createdAt: u.created_at,
        livePlayback: u.live_song_id ? {
          songId: u.live_song_id,
          title: u.live_title,
          artist: u.live_artist,
          coverArt: u.live_cover_art,
          platform: u.live_platform,
          device: u.live_device,
          deviceModel: u.live_device_model,
          osVersion: u.live_os_version,
          country: u.live_country,
          city: u.live_city,
          isPlaying: u.live_is_playing === 1 && (u.live_seconds_ago < 45),
          position: u.live_position,
          duration: u.live_duration,
          lastPingAt: u.live_last_ping,
        } : null,
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
      `SELECT id, name, email, avatar_url, role, is_banned, last_login_at, last_active_at, 
              last_login_ip, last_device, last_country, last_country_code, last_city, last_region, 
              last_isp, last_os_version, last_device_model, total_listen_seconds, created_at, updated_at 
       FROM users WHERE id = ? LIMIT 1`,
      [id]
    );

    if (userRows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Usuario no encontrado.',
      });
    }

    const user = userRows[0];

    // Live playback presence (all active devices for this user)
    const [liveRows] = await pool.query(`
      SELECT song_id, title, artist, album, cover_art, duration, position, is_playing, 
             platform, device_name, device_model, os_version, country, city, ip_address, started_at, last_ping_at,
             TIMESTAMPDIFF(SECOND, last_ping_at, NOW()) as seconds_since_ping
      FROM user_live_playback 
      WHERE user_id = ? AND last_ping_at >= NOW() - INTERVAL 120 SECOND
      ORDER BY last_ping_at DESC
    `, [id]);

    const livePlaybacks = liveRows.map(r => ({
      songId: r.song_id,
      title: r.title,
      artist: r.artist,
      album: r.album,
      coverArt: r.cover_art,
      duration: r.duration,
      position: r.position,
      isPlaying: r.is_playing === 1 && r.seconds_since_ping < 45,
      platform: r.platform,
      deviceName: r.device_name,
      deviceModel: r.device_model,
      osVersion: r.os_version,
      country: r.country,
      city: r.city,
      ipAddress: r.ip_address,
      startedAt: r.started_at,
      lastPingAt: r.last_ping_at,
    }));

    const livePlayback = livePlaybacks.length > 0 ? livePlaybacks[0] : null;

    // Real aggregate counts directly from tables
    const [countRows] = await pool.query(`
      SELECT 
        (SELECT COUNT(*) FROM playback_history WHERE user_id = ?) as total_plays,
        (SELECT COUNT(*) FROM favorites WHERE user_id = ?) as total_favorites,
        (SELECT COUNT(*) FROM playlists WHERE user_id = ?) as total_playlists,
        (SELECT COUNT(*) FROM user_sessions WHERE user_id = ?) as total_sessions
    `, [id, id, id, id]);

    const totalPlays = countRows[0]?.total_plays || 0;
    const totalFavorites = countRows[0]?.total_favorites || 0;
    const totalPlaylists = countRows[0]?.total_playlists || 0;
    const totalSessions = countRows[0]?.total_sessions || 0;

    // Login sessions / devices / IPs (last 100)
    const [sessions] = await pool.query(
      `SELECT id, ip_address, device_os, browser, device_type, client_platform, 
              device_model, os_version, browser_version, country, country_code, city, region, isp,
              user_agent, created_at, last_active_at, session_duration_seconds 
       FROM user_sessions 
       WHERE user_id = ? 
       ORDER BY created_at DESC 
       LIMIT 100`,
      [id]
    );

    // User's playlists
    const [playlists] = await pool.query(
      'SELECT id, name, description, cover_art, created_at FROM playlists WHERE user_id = ? ORDER BY created_at DESC',
      [id]
    );

    // User's favorites (last 100)
    const [favorites] = await pool.query(
      'SELECT id, song_id, title, artist, album, cover_art, duration, created_at FROM favorites WHERE user_id = ? ORDER BY created_at DESC LIMIT 100',
      [id]
    );

    // User's playback history (last 100)
    const [history] = await pool.query(
      `SELECT id, song_id, title, artist, album, cover_art, duration, platform, device_name, ip_address, played_at 
       FROM playback_history 
       WHERE user_id = ? 
       ORDER BY played_at DESC 
       LIMIT 100`,
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
        lastActiveAt: user.last_active_at,
        lastLoginIp: user.last_login_ip,
        lastDevice: user.last_device,
        lastCountry: user.last_country,
        lastCountryCode: user.last_country_code,
        lastCity: user.last_city,
        lastRegion: user.last_region,
        lastIsp: user.last_isp,
        lastOsVersion: user.last_os_version,
        lastDeviceModel: user.last_device_model,
        totalListenSeconds: user.total_listen_seconds || 0,
        createdAt: user.created_at,
        updatedAt: user.updated_at,
        totalPlays,
      },
      stats: {
        plays: totalPlays,
        favorites: totalFavorites,
        playlists: totalPlaylists,
        sessions: totalSessions,
      },
      livePlayback,
      livePlaybacks,
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

    const updates = [];
    const params = [];

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

    params.push(id);
    await pool.query(`UPDATE users SET ${updates.join(', ')} WHERE id = ?`, params);

    return res.json({
      success: true,
      message: 'Usuario actualizado exitosamente.',
    });
  } catch (err) {
    console.error('[Admin Update User Error]:', err);
    return res.status(500).json({
      success: false,
      error: 'Error al actualizar usuario: ' + err.message,
    });
  }
});

/**
 * PATCH /api/admin/users/:id/ban
 * Toggle account ban / suspension status
 */
router.patch('/users/:id/ban', async (req, res) => {
  try {
    const { id } = req.params;
    const { isBanned } = req.body;
    const pool = getPool();

    if (parseInt(id, 10) === req.user.id) {
      return res.status(400).json({
        success: false,
        error: 'No puedes suspender tu propia cuenta de administrador.',
      });
    }

    await pool.query('UPDATE users SET is_banned = ? WHERE id = ?', [isBanned ? 1 : 0, id]);

    return res.json({
      success: true,
      message: isBanned ? 'Cuenta suspendida correctamente.' : 'Cuenta reactivada correctamente.',
      isBanned: !!isBanned,
    });
  } catch (err) {
    console.error('[Admin Ban User Error]:', err);
    return res.status(500).json({
      success: false,
      error: 'Error al cambiar estado de la cuenta.',
    });
  }
});

/**
 * DELETE /api/admin/users/:id
 * Permanently delete a user account and cascade data
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

    await pool.query('DELETE FROM users WHERE id = ?', [id]);

    return res.json({
      success: true,
      message: 'Usuario eliminado permanentemente de la base de datos.',
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
 * List all login sessions and device logs across all users
 */
router.get('/sessions', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit || '100', 10);
    const pool = getPool();

    const [rows] = await pool.query(`
      SELECT 
        s.id, 
        s.user_id, 
        u.name as user_name, 
        u.email as user_email, 
        s.ip_address, 
        s.device_os, 
        s.browser, 
        s.device_type, 
        s.client_platform, 
        s.device_model,
        s.os_version,
        s.browser_version,
        s.country,
        s.country_code,
        s.city,
        s.region,
        s.isp,
        s.created_at, 
        s.last_active_at,
        s.session_duration_seconds
      FROM user_sessions s
      JOIN users u ON s.user_id = u.id
      ORDER BY s.created_at DESC
      LIMIT ?
    `, [limit]);

    return res.json({
      success: true,
      count: rows.length,
      sessions: rows,
    });
  } catch (err) {
    console.error('[Admin Get Sessions Error]:', err);
    return res.status(500).json({
      success: false,
      error: 'Error al consultar sesiones.',
    });
  }
});

module.exports = router;
