const express = require('express');
const { getPool } = require('../database');
const { authenticateToken, optionalAuth } = require('../middleware/auth');
const { resolveIpLocation, parseFullClientInfo } = require('../utils/geoip');

const router = express.Router();

const normalizeCoverArt = (coverArt, songId) => {
  if (coverArt && typeof coverArt === 'string') {
    const trimmed = coverArt.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (!trimmed.includes('/') && !trimmed.includes('\\') && !trimmed.includes(' ') && trimmed.length >= 8 && trimmed.length <= 25) {
      return `https://i.ytimg.com/vi/${trimmed}/hqdefault.jpg`;
    }
  }
  if (songId && typeof songId === 'string') {
    const trimmedId = String(songId).trim();
    if (!trimmedId.startsWith('local_') && !trimmedId.includes('/') && !trimmedId.includes('\\') && trimmedId.length >= 8 && trimmedId.length <= 25) {
      return `https://i.ytimg.com/vi/${trimmedId}/hqdefault.jpg`;
    }
  }
  return (coverArt && typeof coverArt === 'string') ? coverArt : '';
};

router.use(optionalAuth);

/**
 * GET /api/telemetry/playback
 * Returns active live sessions and devices for Groovy Connect synchronization
 */
router.get('/playback', async (req, res) => {
  try {
    const client = parseFullClientInfo(req);
    const userId = req.user?.id || 0;
    const pool = getPool();

    const [rows] = await pool.query(`
      SELECT 
        user_id, platform, device_name, device_model, os_version, ip_address,
        song_id, title, artist, album, cover_art, duration, position, is_playing, last_ping_at,
        device_key, COALESCE(device_key, CONCAT(platform, '_', device_name)) as device_id
      FROM user_live_playback
      WHERE ((? > 0 AND user_id = ?) OR ip_address = ?)
        AND last_ping_at >= NOW() - INTERVAL 120 SECOND
      ORDER BY last_ping_at DESC
    `, [userId, userId, client.ip]);

    // Deduplicate by physical device (same platform and device name/model)
    const seen = new Set();
    const uniqueDevices = [];
    for (const row of rows) {
      const p = (row.platform || '').trim().toLowerCase();
      const d = (row.device_name || row.device_model || '').trim().toLowerCase();
      const key = `${p}_${d}`;
      if (!seen.has(key)) {
        seen.add(key);
        uniqueDevices.push(row);
      }
    }

    return res.json({ success: true, devices: uniqueDevices });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * POST /api/telemetry/command
 * Send playback command to a target remote device via Groovy Cloud Relay
 */
router.post('/command', async (req, res) => {
  try {
    const { targetDeviceId, senderDeviceId, action, payload } = req.body;
    const userId = req.user?.id || null;

    if (!targetDeviceId || !action) {
      return res.status(400).json({ success: false, error: 'targetDeviceId y action son requeridos' });
    }

    const pool = getPool();
    const payloadStr = payload ? (typeof payload === 'string' ? payload : JSON.stringify(payload)) : null;

    const [result] = await pool.query(`
      INSERT INTO device_commands (user_id, sender_device_id, target_device_id, action, payload, status)
      VALUES (?, ?, ?, ?, ?, 'pending')
    `, [userId, senderDeviceId || 'unknown', targetDeviceId, action, payloadStr]);

    return res.json({
      success: true,
      commandId: result.insertId,
      message: 'Comando enviado a la nube exitosamente',
    });
  } catch (err) {
    console.error('[Telemetry Command Error]:', err);
    return res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/telemetry/command
 * Polls pending commands for the calling device and marks them delivered
 */
router.get('/command', async (req, res) => {
  try {
    const deviceId = req.query.deviceId;
    const platform = req.query.platform || '';
    const model = req.query.model || '';
    const userId = req.user?.id || 0;
    if (!deviceId) {
      return res.status(400).json({ success: false, error: 'deviceId es requerido' });
    }

    const pool = getPool();

    // Expire old unconsumed commands older than 45 seconds
    pool.query(`
      UPDATE device_commands 
      SET status = 'expired' 
      WHERE status = 'pending' AND created_at < NOW() - INTERVAL 45 SECOND
    `).catch(() => {});

    // Construct alias patterns for target device matching
    const platformModel = (platform && model) ? `${platform}_${model}` : '';
    const platformDevice = platform ? `${platform}_%` : '';

    // Fetch pending commands for this target device (exact ID, platform composite, or user device)
    const [commands] = await pool.query(`
      SELECT id, user_id, sender_device_id, target_device_id, action, payload, created_at
      FROM device_commands
      WHERE status = 'pending'
        AND sender_device_id != ?
        AND (
          target_device_id = ?
          OR (? != '' AND target_device_id = ?)
          OR (? > 0 AND user_id = ? AND (target_device_id LIKE ? OR target_device_id = ?))
        )
      ORDER BY id ASC
      LIMIT 10
    `, [deviceId, deviceId, platformModel, platformModel, userId, userId, platformDevice, deviceId]);

    if (commands.length > 0) {
      const ids = commands.map(c => c.id);
      await pool.query(`
        UPDATE device_commands
        SET status = 'delivered', delivered_at = CURRENT_TIMESTAMP
        WHERE id IN (?)
      `, [ids]);
    }

    const parsedCommands = commands.map(c => {
      let parsedPayload = null;
      if (c.payload) {
        try {
          parsedPayload = JSON.parse(c.payload);
        } catch (_) {
          parsedPayload = c.payload;
        }
      }
      return {
        id: c.id,
        senderDeviceId: c.sender_device_id,
        action: c.action,
        payload: parsedPayload,
        createdAt: c.created_at,
      };
    });

    return res.json({
      success: true,
      commands: parsedCommands,
    });
  } catch (err) {
    console.error('[Telemetry Poll Command Error]:', err);
    return res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * POST /api/telemetry/playback
 * Real-time heartbeat of what the user is listening to right now (Android, Windows, Web)
 */
router.post('/playback', async (req, res) => {
  try {
    const {
      deviceId,
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

    const hasSong = Boolean(songId && title);
    const client = parseFullClientInfo(req);
    const geo = await resolveIpLocation(client.ip);

    const resolvedPlatform = platform || client.os;
    const resolvedDevice = deviceName || client.deviceSummary;
    const resolvedCoverArt = hasSong ? normalizeCoverArt(coverArt, songId) : '';
    const pool = getPool();
    const userId = req.user?.id || 0;
    const dbUserId = userId > 0 ? userId : null;

    if (userId > 0) {
      const [banCheck] = await pool.query('SELECT is_banned FROM users WHERE id = ? LIMIT 1', [userId]);
      if (banCheck.length > 0 && banCheck[0].is_banned === 1) {
        return res.status(403).json({ success: false, error: 'Tu cuenta ha sido suspendida.' });
      }
    }

    // 1. Log playback/presence to user_live_playback with atomic upsert
    const deviceKey = deviceId || `${userId > 0 ? userId : client.ip}_${(resolvedPlatform || 'app').toLowerCase()}_${(client.deviceModel || resolvedDevice || 'device').toLowerCase()}`;

    await pool.query(`
      INSERT INTO user_live_playback (
        user_id, song_id, title, artist, album, cover_art, duration, position, 
        is_playing, platform, device_name, ip_address, device_model, os_version, country, city, last_ping_at, device_key
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, ?)
      ON DUPLICATE KEY UPDATE
        user_id = COALESCE(VALUES(user_id), user_id),
        song_id = CASE WHEN VALUES(song_id) != '' THEN VALUES(song_id) ELSE song_id END,
        title = CASE WHEN VALUES(title) != '' THEN VALUES(title) ELSE title END,
        artist = CASE WHEN VALUES(title) != '' THEN VALUES(artist) ELSE artist END,
        album = CASE WHEN VALUES(title) != '' THEN VALUES(album) ELSE album END,
        cover_art = CASE WHEN VALUES(title) != '' THEN VALUES(cover_art) ELSE cover_art END,
        duration = CASE WHEN VALUES(title) != '' THEN VALUES(duration) ELSE duration END,
        position = CASE WHEN VALUES(title) != '' THEN VALUES(position) ELSE position END,
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
      dbUserId,
      hasSong ? String(songId) : '',
      hasSong ? title : '',
      hasSong ? (artist || '') : '',
      hasSong ? (album || '') : '',
      resolvedCoverArt,
      hasSong ? (parseInt(duration, 10) || 0) : 0,
      hasSong ? (parseInt(position, 10) || 0) : 0,
      (isPlaying && hasSong) ? 1 : 0,
      resolvedPlatform,
      resolvedDevice,
      client.ip,
      client.deviceModel,
      client.osVersion,
      geo.country,
      geo.city,
      deviceKey,
    ]);

    // Cleanup stale live sessions older than 75 seconds
    pool.query('DELETE FROM user_live_playback WHERE last_ping_at < NOW() - INTERVAL 75 SECOND').catch(() => {});

    // Purge any ghost/fallback rows for the same user and platform/model that have a different device_key
    if (deviceId && dbUserId) {
      pool.query(`
        DELETE FROM user_live_playback
        WHERE user_id = ?
          AND device_key != ?
          AND LOWER(platform) = LOWER(?)
          AND (LOWER(device_name) = LOWER(?) OR LOWER(device_model) = LOWER(?))
      `, [dbUserId, deviceKey, resolvedPlatform, resolvedDevice, client.deviceModel || '']).catch(() => {});
    }

    // 2. Automatically log to playback_history if new song started
    const delta = Math.min(Math.max(parseInt(listenDeltaSeconds, 10) || 0, 0), 60);
    if (isPlaying && dbUserId) {
      try {
        const [recentHistory] = await pool.query(
          'SELECT id FROM playback_history WHERE user_id = ? AND song_id = ? AND played_at >= NOW() - INTERVAL 45 SECOND LIMIT 1',
          [dbUserId, String(songId)]
        );
        if (recentHistory.length === 0) {
          await pool.query(
            'INSERT INTO playback_history (user_id, song_id, title, artist, album, cover_art, duration, platform, device_name, ip_address, listen_seconds) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [dbUserId, String(songId), title, artist || '', album || '', resolvedCoverArt, parseInt(duration, 10) || 0, resolvedPlatform, resolvedDevice, client.ip, delta || 15]
          );
        }
      } catch (histErr) {
        console.warn('[Telemetry History Log Warning]:', histErr.message);
      }
    }

    // 3. Accumulate listening seconds in users and active session if music is playing
    if (isPlaying && delta > 0) {
      if (userId > 0) {
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
      }

      await pool.query(`
        UPDATE user_sessions 
        SET session_duration_seconds = session_duration_seconds + ?,
            last_active_at = CURRENT_TIMESTAMP,
            device_model = COALESCE(device_model, ?),
            os_version = COALESCE(os_version, ?),
            country = COALESCE(country, ?),
            city = COALESCE(city, ?),
            isp = COALESCE(isp, ?)
        WHERE (user_id = ? OR ip_address = ?) AND client_platform = ?
        ORDER BY id DESC LIMIT 1
      `, [delta, client.deviceModel, client.osVersion, geo.country, geo.city, geo.isp, userId, client.ip, client.clientPlatform]);
    } else if (userId > 0) {
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
    const userId = req.user?.id || 0;
    const dbUserId = userId > 0 ? userId : null;

    if (userId > 0) {
      const [banCheck] = await pool.query('SELECT is_banned FROM users WHERE id = ? LIMIT 1', [userId]);
      if (banCheck.length > 0 && banCheck[0].is_banned === 1) {
        return res.status(403).json({ success: false, error: 'Tu cuenta ha sido suspendida.' });
      }
    }

    const platform = req.body?.platform || client.os;
    const deviceSummary = client.deviceSummary;

    // Check if there is an active session in the last 10 minutes for THIS SPECIFIC DEVICE / PLATFORM
    const [recentSession] = await pool.query(`
      SELECT id, created_at, last_active_at 
      FROM user_sessions 
      WHERE ((? IS NOT NULL AND user_id = ?) OR ip_address = ?) 
        AND client_platform = ? 
        AND (device_model = ? OR device_os = ?) 
        AND COALESCE(last_active_at, created_at) >= NOW() - INTERVAL 10 MINUTE 
      ORDER BY id DESC LIMIT 1
    `, [dbUserId, dbUserId, client.ip, client.clientPlatform, client.deviceModel, client.os]);

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
            isp = COALESCE(?, isp),
            user_id = COALESCE(?, user_id)
        WHERE id = ?
      `, [client.ip, client.deviceModel, client.osVersion, geo.country, geo.city, geo.isp, dbUserId, recentSession[0].id]);
    } else {
      // Record new session with full device & geolocation for this device
      await pool.query(`
        INSERT INTO user_sessions (
          user_id, ip_address, user_agent, device_os, browser, device_type, client_platform,
          device_model, os_version, browser_version, country, country_code, city, region, isp
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `, [
        dbUserId,
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

    // Update user metadata if authenticated
    if (dbUserId) {
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
    }

    // Clean up stale playback rows older than 25 seconds
    pool.query('DELETE FROM user_live_playback WHERE last_ping_at < NOW() - INTERVAL 25 SECOND').catch(() => {});

    return res.json({
      success: true,
      status: 'ping_received',
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    console.error('[Telemetry Ping Error]:', err);
    return res.status(500).json({ success: false, error: 'Error al procesar ping.' });
  }
});

/**
 * POST /api/telemetry/leave
 * Notifies that the user disconnected / closed the application
 */
router.post('/leave', async (req, res) => {
  try {
    const client = parseFullClientInfo(req);
    const pool = getPool();
    const userId = req.user?.id || 0;
    const platform = req.body?.platform || client.os;
    const deviceModel = req.body?.deviceModel || client.deviceModel;

    // 1. Remove live playback presence only for this device
    if (userId > 0) {
      await pool.query(
        'DELETE FROM user_live_playback WHERE user_id = ? AND (platform = ? OR device_model = ? OR ip_address = ?)',
        [userId, platform, deviceModel, client.ip]
      );
    } else {
      await pool.query('DELETE FROM user_live_playback WHERE ip_address = ?', [client.ip]);
    }

    // 2. Expire active sessions only for this client platform / device
    if (userId > 0) {
      await pool.query(`
        UPDATE user_sessions 
        SET last_active_at = NOW() - INTERVAL 1 HOUR 
        WHERE user_id = ? AND (client_platform = ? OR device_model = ? OR device_os = ?)
      `, [userId, client.clientPlatform, deviceModel, client.os]);
    } else {
      await pool.query(`
        UPDATE user_sessions 
        SET last_active_at = NOW() - INTERVAL 1 HOUR 
        WHERE ip_address = ? AND (client_platform = ? OR device_model = ?)
      `, [client.ip, client.clientPlatform, deviceModel]);
    }

    return res.json({ success: true, message: 'Presencia cerrada exitosamente' });
  } catch (err) {
    console.warn('[Telemetry Leave Warning]:', err.message);
    return res.json({ success: true });
  }
});

module.exports = router;
