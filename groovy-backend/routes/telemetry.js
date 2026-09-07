const express = require('express');
const { getPool } = require('../database');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

// Apply auth middleware
router.use(authenticateToken);

/**
 * Helper to parse client details
 */
function parseClient(req) {
  const forwarded = req.headers['x-forwarded-for'];
  let ip = forwarded ? forwarded.split(',')[0].trim() : (req.headers['x-real-ip'] || req.socket?.remoteAddress || '127.0.0.1');
  if (ip.startsWith('::ffff:')) {
    ip = ip.replace('::ffff:', '');
  }

  const ua = req.headers['user-agent'] || '';
  const customPlatform = req.headers['x-client-platform'] || req.body?.platform;

  let os = customPlatform || 'Unknown';
  if (!customPlatform || customPlatform === 'Unknown') {
    if (/windows/i.test(ua)) os = 'Windows';
    else if (/android/i.test(ua)) os = 'Android';
    else if (/iphone|ipad|ipod/i.test(ua)) os = 'iOS';
    else if (/macintosh|mac os x/i.test(ua)) os = 'macOS';
    else if (/linux/i.test(ua)) os = 'Linux';
  }

  let browser = 'Web Client';
  if (/edg/i.test(ua)) browser = 'Edge';
  else if (/chrome|crios/i.test(ua)) browser = 'Chrome';
  else if (/firefox/i.test(ua)) browser = 'Firefox';
  else if (/safari/i.test(ua) && !/chrome/i.test(ua)) browser = 'Safari';
  else if (/dart|flutter/i.test(ua)) browser = 'Groovy Native App';

  return { ip, os, browser, ua };
}

/**
 * POST /api/telemetry/playback
 * Real-time heartbeat of what the user is listening to right now (Android, Windows, Web)
 */
router.post('/playback', async (req, res) => {
  try {
    const {
      songId,
      title,
      artist,
      album,
      coverArt,
      duration = 0,
      position = 0,
      isPlaying = true,
      platform,
      deviceName,
      listenDeltaSeconds = 15, // seconds listened since last ping
    } = req.body;

    if (!songId || !title) {
      return res.status(400).json({ success: false, error: 'songId y title son obligatorios' });
    }

    const client = parseClient(req);
    const resolvedPlatform = platform || client.os;
    const resolvedDevice = deviceName || `${resolvedPlatform} (${client.browser})`;
    const pool = getPool();
    const userId = req.user.id;

    // 1. Upsert into user_live_playback
    await pool.query(`
      INSERT INTO user_live_playback (
        user_id, song_id, title, artist, album, cover_art, duration, position, 
        is_playing, platform, device_name, ip_address, last_ping_at
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
      ON DUPLICATE KEY UPDATE
        song_id = VALUES(song_id),
        title = VALUES(title),
        artist = VALUES(artist),
        album = VALUES(album),
        cover_art = VALUES(cover_art),
        duration = VALUES(duration),
        position = VALUES(position),
        is_playing = VALUES(is_playing),
        platform = VALUES(platform),
        device_name = VALUES(device_name),
        ip_address = VALUES(ip_address),
        last_ping_at = CURRENT_TIMESTAMP
    `, [
      userId,
      String(songId),
      title,
      artist || '',
      album || '',
      coverArt || '',
      parseInt(duration, 10) || 0,
      parseInt(position, 10) || 0,
      isPlaying ? 1 : 0,
      resolvedPlatform,
      resolvedDevice,
      client.ip,
    ]);

    // 2. Accumulate listening seconds in users and active session if music is playing
    const delta = Math.min(Math.max(parseInt(listenDeltaSeconds, 10) || 0, 0), 60);
    if (isPlaying && delta > 0) {
      await pool.query(`
        UPDATE users 
        SET total_listen_seconds = total_listen_seconds + ?, 
            last_active_at = CURRENT_TIMESTAMP,
            last_login_ip = ?,
            last_device = ?
        WHERE id = ?
      `, [delta, client.ip, resolvedDevice, userId]);

      await pool.query(`
        UPDATE user_sessions 
        SET session_duration_seconds = session_duration_seconds + ?,
            last_active_at = CURRENT_TIMESTAMP
        WHERE user_id = ? 
        ORDER BY id DESC LIMIT 1
      `, [delta, userId]);
    } else {
      await pool.query(`
        UPDATE users 
        SET last_active_at = CURRENT_TIMESTAMP 
        WHERE id = ?
      `, [userId]);
    }

    return res.json({
      success: true,
      status: isPlaying ? 'playing' : 'paused',
      platform: resolvedPlatform,
      device: resolvedDevice,
    });
  } catch (err) {
    console.error('[Telemetry Playback Error]:', err);
    return res.status(500).json({ success: false, error: 'Error al procesar telemetría de reproducción.' });
  }
});

/**
 * POST /api/telemetry/ping
 * Heartbeat sent when user opens app or is browsing (Android, Windows, Web)
 */
router.post('/ping', async (req, res) => {
  try {
    const client = parseClient(req);
    const pool = getPool();
    const userId = req.user.id;
    const platform = req.body?.platform || client.os;
    const deviceSummary = `${platform} (${client.browser})`;

    // Check if there is a session logged in the last 2 hours
    const [recentSession] = await pool.query(`
      SELECT id, created_at, last_active_at 
      FROM user_sessions 
      WHERE user_id = ? AND created_at >= NOW() - INTERVAL 2 HOUR 
      ORDER BY id DESC LIMIT 1
    `, [userId]);

    if (recentSession.length > 0) {
      // Update session last active time
      await pool.query(`
        UPDATE user_sessions 
        SET last_active_at = CURRENT_TIMESTAMP,
            session_duration_seconds = TIMESTAMPDIFF(SECOND, created_at, CURRENT_TIMESTAMP)
        WHERE id = ?
      `, [recentSession[0].id]);
    } else {
      // Record new session
      await pool.query(`
        INSERT INTO user_sessions (user_id, ip_address, user_agent, device_os, browser, device_type, client_platform)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `, [
        userId,
        client.ip,
        client.ua,
        platform,
        client.browser,
        platform === 'Android' || platform === 'iOS' ? 'Mobile' : 'Desktop',
        `Groovy (${platform})`,
      ]);
    }

    // Update user metadata
    await pool.query(`
      UPDATE users 
      SET last_active_at = CURRENT_TIMESTAMP,
          last_login_at = COALESCE(last_login_at, CURRENT_TIMESTAMP),
          last_login_ip = ?,
          last_device = ?
      WHERE id = ?
    `, [client.ip, deviceSummary, userId]);

    return res.json({ success: true, timestamp: new Date().toISOString() });
  } catch (err) {
    console.error('[Telemetry Ping Error]:', err);
    return res.status(500).json({ success: false, error: 'Error al procesar ping.' });
  }
});

module.exports = router;
