const express = require('express');
const { getPool } = require('../database');
const { authenticateToken } = require('../middleware/auth');
const { resolveIpLocation, parseFullClientInfo } = require('../utils/geoip');

const router = express.Router();

// Apply auth middleware
router.use(authenticateToken);

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

    const client = parseFullClientInfo(req);
    const geo = await resolveIpLocation(client.ip);

    const resolvedPlatform = platform || client.os;
    const resolvedDevice = deviceName || client.deviceSummary;
    const pool = getPool();
    const userId = req.user.id;

    // 1. Log playback to user_live_playback with atomic upsert
    const deviceKey = `${userId}_${(resolvedPlatform || 'app').toLowerCase()}_${(client.deviceModel || resolvedDevice || 'device').toLowerCase()}`;

    await pool.query(`
      INSERT INTO user_live_playback (
        user_id, song_id, title, artist, album, cover_art, duration, position, 
        is_playing, platform, device_name, ip_address, device_model, os_version, country, city, last_ping_at, device_key
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, ?)
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
        device_model = VALUES(device_model),
        os_version = VALUES(os_version),
        country = VALUES(country),
        city = VALUES(city),
        last_ping_at = CURRENT_TIMESTAMP,
        device_key = VALUES(device_key)
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
      client.deviceModel,
      client.osVersion,
      geo.country,
      geo.city,
      deviceKey,
    ]);

    // Cleanup stale live sessions older than 3 minutes
    pool.query('DELETE FROM user_live_playback WHERE last_ping_at < NOW() - INTERVAL 180 SECOND').catch(() => {});

    // 2. Automatically log to playback_history if new song started
    const delta = Math.min(Math.max(parseInt(listenDeltaSeconds, 10) || 0, 0), 60);
    if (isPlaying) {
      try {
        const [recentHistory] = await pool.query(
          'SELECT id FROM playback_history WHERE user_id = ? AND song_id = ? AND played_at >= NOW() - INTERVAL 45 SECOND LIMIT 1',
          [userId, String(songId)]
        );
        if (recentHistory.length === 0) {
          await pool.query(
            'INSERT INTO playback_history (user_id, song_id, title, artist, album, cover_art, duration, platform, device_name, ip_address, listen_seconds) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [userId, String(songId), title, artist || '', album || '', coverArt || '', parseInt(duration, 10) || 0, resolvedPlatform, resolvedDevice, client.ip, delta || 15]
          );
        }
      } catch (histErr) {
        console.warn('[Telemetry History Log Warning]:', histErr.message);
      }
    }

    // 3. Accumulate listening seconds in users and active session if music is playing
    if (isPlaying && delta > 0) {
      await pool.query(`
        UPDATE users 
        SET total_listen_seconds = total_listen_seconds + ?, 
            last_active_at = CURRENT_TIMESTAMP,
            last_login_ip = ?,
            last_device = ?,
            last_country = COALESCE(?, last_country),
            last_country_code = COALESCE(?, last_country_code),
            last_city = COALESCE(?, last_city),
            last_region = COALESCE(?, last_region),
            last_isp = COALESCE(?, last_isp),
            last_os_version = COALESCE(?, last_os_version),
            last_device_model = COALESCE(?, last_device_model)
        WHERE id = ?
      `, [
        delta,
        client.ip,
        resolvedDevice,
        geo.country,
        geo.countryCode,
        geo.city,
        geo.region,
        geo.isp,
        client.osVersion,
        client.deviceModel,
        userId,
      ]);

      await pool.query(`
        UPDATE user_sessions 
        SET session_duration_seconds = session_duration_seconds + ?,
            last_active_at = CURRENT_TIMESTAMP,
            device_model = COALESCE(device_model, ?),
            os_version = COALESCE(os_version, ?),
            country = COALESCE(country, ?),
            city = COALESCE(city, ?),
            isp = COALESCE(isp, ?)
        WHERE user_id = ? AND client_platform = ?
        ORDER BY id DESC LIMIT 1
      `, [delta, client.deviceModel, client.osVersion, geo.country, geo.city, geo.isp, userId, client.clientPlatform]);
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
      deviceModel: client.deviceModel,
      osVersion: client.osVersion,
      location: {
        city: geo.city,
        country: geo.country,
        isp: geo.isp,
      },
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
    const client = parseFullClientInfo(req);
    const geo = await resolveIpLocation(client.ip);
    const pool = getPool();
    const userId = req.user.id;
    const platform = req.body?.platform || client.os;
    const deviceSummary = client.deviceSummary;

    // Check if there is an active session in the last 10 minutes for THIS SPECIFIC DEVICE / PLATFORM
    const [recentSession] = await pool.query(`
      SELECT id, created_at, last_active_at 
      FROM user_sessions 
      WHERE user_id = ? AND client_platform = ? AND (device_model = ? OR device_os = ?) AND COALESCE(last_active_at, created_at) >= NOW() - INTERVAL 10 MINUTE 
      ORDER BY id DESC LIMIT 1
    `, [userId, client.clientPlatform, client.deviceModel, client.os]);

    if (recentSession.length > 0) {
      // Update ongoing session last active time & duration for this device
      await pool.query(`
        UPDATE user_sessions 
        SET last_active_at = CURRENT_TIMESTAMP,
            session_duration_seconds = TIMESTAMPDIFF(SECOND, created_at, CURRENT_TIMESTAMP),
            ip_address = ?,
            device_model = COALESCE(?, device_model),
            os_version = COALESCE(?, os_version),
            country = COALESCE(?, country),
            city = COALESCE(?, city),
            isp = COALESCE(?, isp)
        WHERE id = ?
      `, [client.ip, client.deviceModel, client.osVersion, geo.country, geo.city, geo.isp, recentSession[0].id]);
    } else {
      // Record new session with full device & geolocation for this device
      await pool.query(`
        INSERT INTO user_sessions (
          user_id, ip_address, user_agent, device_os, browser, device_type, client_platform,
          device_model, os_version, browser_version, country, country_code, city, region, isp
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `, [
        userId,
        client.ip,
        client.userAgent,
        client.os,
        client.browser,
        client.deviceType,
        client.clientPlatform,
        client.deviceModel,
        client.osVersion,
        client.browserVersion,
        geo.country,
        geo.countryCode,
        geo.city,
        geo.region,
        geo.isp,
      ]);
    }

    // Update user metadata
    await pool.query(`
      UPDATE users 
      SET last_active_at = CURRENT_TIMESTAMP,
          last_login_at = COALESCE(last_login_at, CURRENT_TIMESTAMP),
          last_login_ip = ?,
          last_device = ?,
          last_country = COALESCE(?, last_country),
          last_country_code = COALESCE(?, last_country_code),
          last_city = COALESCE(?, last_city),
          last_region = COALESCE(?, last_region),
          last_isp = COALESCE(?, last_isp),
          last_os_version = COALESCE(?, last_os_version),
          last_device_model = COALESCE(?, last_device_model)
      WHERE id = ?
    `, [
      client.ip,
      deviceSummary,
      geo.country,
      geo.countryCode,
      geo.city,
      geo.region,
      geo.isp,
      client.osVersion,
      client.deviceModel,
      userId,
    ]);

    return res.json({
      success: true,
      timestamp: new Date().toISOString(),
      location: {
        city: geo.city,
        country: geo.country,
        isp: geo.isp,
      },
    });
  } catch (err) {
    console.error('[Telemetry Ping Error]:', err);
    return res.status(500).json({ success: false, error: 'Error al procesar ping.' });
  }
});

module.exports = router;
