const express = require('express');
const bcrypt = require('bcryptjs');
const { getPool } = require('../database');
const { generateToken, authenticateToken } = require('../middleware/auth');

const router = express.Router();

const { resolveIpLocation, parseFullClientInfo } = require('../utils/geoip');

/**
 * Record a user session log and update users table last login metadata with full device & geolocation
 */
async function recordSession(pool, userId, clientInfo) {
  try {
    const geo = await resolveIpLocation(clientInfo.ip);

    await pool.query(`
      INSERT INTO user_sessions (
        user_id, ip_address, user_agent, device_os, browser, device_type, client_platform,
        device_model, os_version, browser_version, country, country_code, city, region, isp
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `, [
      userId,
      clientInfo.ip,
      clientInfo.userAgent,
      clientInfo.os,
      clientInfo.browser,
      clientInfo.deviceType,
      clientInfo.clientPlatform,
      clientInfo.deviceModel,
      clientInfo.osVersion,
      clientInfo.browserVersion,
      geo.country,
      geo.countryCode,
      geo.city,
      geo.region,
      geo.isp,
    ]);

    await pool.query(`
      UPDATE users 
      SET last_login_at = CURRENT_TIMESTAMP, 
          last_login_ip = ?, 
          last_device = ?,
          last_country = ?,
          last_country_code = ?,
          last_city = ?,
          last_region = ?,
          last_isp = ?,
          last_os_version = ?,
          last_device_model = ?
      WHERE id = ?
    `, [
      clientInfo.ip,
      clientInfo.deviceSummary,
      geo.country,
      geo.countryCode,
      geo.city,
      geo.region,
      geo.isp,
      clientInfo.osVersion,
      clientInfo.deviceModel,
      userId,
    ]);
  } catch (err) {
    console.error('[Session Record Error]:', err.message);
  }
}

// POST /api/auth/register
router.post('/register', async (req, res) => {
  try {
    const { name, email, password, avatarUrl } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({
        success: false,
        error: 'Nombre, correo electrónico y contraseña son requeridos.',
      });
    }

    const cleanEmail = email.trim().toLowerCase();
    const cleanName = name.trim();

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        error: 'La contraseña debe tener al menos 6 caracteres.',
      });
    }

    const pool = getPool();

    // Check if email already exists
    const [existing] = await pool.query(
      'SELECT id FROM users WHERE email = ? LIMIT 1',
      [cleanEmail]
    );

    if (existing.length > 0) {
      return res.status(409).json({
        success: false,
        error: 'Este correo electrónico ya está registrado. Por favor inicia sesión.',
      });
    }

    // Check if this is the first user registered (auto-promote to admin)
    const [userCountRows] = await pool.query('SELECT COUNT(*) as count FROM users');
    const isFirstUser = userCountRows[0].count === 0;
    const initialRole = isFirstUser ? 'admin' : 'user';

    // Hash password
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    const clientInfo = parseFullClientInfo(req);

    // Insert user
    const [result] = await pool.query(`
      INSERT INTO users (name, email, password_hash, avatar_url, role, is_banned, last_login_at, last_login_ip, last_device) 
      VALUES (?, ?, ?, ?, ?, 0, CURRENT_TIMESTAMP, ?, ?)
    `, [
      cleanName,
      cleanEmail,
      passwordHash,
      avatarUrl || null,
      initialRole,
      clientInfo.ip,
      clientInfo.deviceSummary,
    ]);

    const user = {
      id: result.insertId,
      name: cleanName,
      email: cleanEmail,
      avatarUrl: avatarUrl || null,
      role: initialRole,
      isBanned: false,
      lastLoginIp: clientInfo.ip,
      lastDevice: clientInfo.deviceSummary,
      createdAt: new Date().toISOString(),
    };

    await recordSession(pool, user.id, clientInfo);

    const token = generateToken(user);

    return res.status(201).json({
      success: true,
      message: 'Usuario registrado exitosamente',
      token,
      user,
    });
  } catch (err) {
    console.error('[Auth Register Error]:', err);
    return res.status(500).json({
      success: false,
      error: 'Error interno del servidor al registrar usuario.',
    });
  }
});

// POST /api/auth/login
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        error: 'Correo electrónico y contraseña son requeridos.',
      });
    }

    const cleanEmail = email.trim().toLowerCase();
    const pool = getPool();

    const [rows] = await pool.query(
      'SELECT id, name, email, password_hash, avatar_url, role, is_banned, created_at, last_login_ip, last_device FROM users WHERE email = ? LIMIT 1',
      [cleanEmail]
    );

    if (rows.length === 0) {
      return res.status(401).json({
        success: false,
        error: 'Correo o contraseña incorrectos.',
      });
    }

    const dbUser = rows[0];

    // Check if account is suspended/banned
    if (dbUser.is_banned === 1) {
      return res.status(403).json({
        success: false,
        error: 'Tu cuenta ha sido suspendida por el administrador.',
      });
    }

    const isMatch = await bcrypt.compare(password, dbUser.password_hash);

    if (!isMatch) {
      return res.status(401).json({
        success: false,
        error: 'Correo o contraseña incorrectos.',
      });
    }

    const clientInfo = parseFullClientInfo(req);
    await recordSession(pool, dbUser.id, clientInfo);

    const isPrimaryAdmin = cleanEmail === 'danilorodelo355@gmail.com';
    const userRole = isPrimaryAdmin ? 'admin' : (dbUser.role || 'user');

    const user = {
      id: dbUser.id,
      name: dbUser.name,
      email: dbUser.email,
      avatarUrl: dbUser.avatar_url,
      role: userRole,
      isBanned: dbUser.is_banned === 1,
      lastLoginIp: clientInfo.ip,
      lastDevice: clientInfo.deviceSummary,
      createdAt: dbUser.created_at,
    };

    const token = generateToken(user);

    return res.json({
      success: true,
      message: 'Inicio de sesión exitoso',
      token,
      user,
    });
  } catch (err) {
    console.error('[Auth Login Error]:', err);
    return res.status(500).json({
      success: false,
      error: 'Error interno del servidor al iniciar sesión.',
    });
  }
});

// POST /api/auth/google
router.post('/google', async (req, res) => {
  try {
    const { email, name, googleId, avatarUrl } = req.body;

    if (!email || !googleId) {
      return res.status(400).json({
        success: false,
        error: 'Email y Google ID son requeridos.',
      });
    }

    const cleanEmail = email.trim().toLowerCase();
    const cleanName = (name || cleanEmail.split('@')[0]).trim();
    const clientInfo = parseFullClientInfo(req);
    const pool = getPool();

    // Check if user exists by email
    const [rows] = await pool.query(
      'SELECT id, name, email, avatar_url, role, is_banned, created_at, last_login_ip, last_device FROM users WHERE email = ? LIMIT 1',
      [cleanEmail]
    );

    let user;
    if (rows.length > 0) {
      const existing = rows[0];
      if (existing.is_banned) {
        return res.status(403).json({
          success: false,
          error: 'Esta cuenta ha sido suspendida. Contacta a soporte.',
        });
      }

      // Update avatar or name if missing, and associate google_id
      if (avatarUrl && !existing.avatar_url) {
        await pool.query('UPDATE users SET avatar_url = ?, google_id = COALESCE(google_id, ?) WHERE id = ?', [avatarUrl, googleId, existing.id]);
        existing.avatar_url = avatarUrl;
      } else {
        await pool.query('UPDATE users SET google_id = COALESCE(google_id, ?) WHERE id = ?', [googleId, existing.id]);
      }

      user = {
        id: existing.id,
        name: existing.name || cleanName,
        email: existing.email,
        avatarUrl: existing.avatar_url,
        role: existing.role || 'user',
        isBanned: false,
        lastLoginIp: clientInfo.ip,
        lastDevice: clientInfo.deviceSummary,
        createdAt: existing.created_at,
      };
    } else {
      // First registered user gets 'admin'
      const [countResult] = await pool.query('SELECT COUNT(*) as total FROM users');
      const totalUsers = countResult[0]?.total || 0;
      const initialRole = totalUsers === 0 ? 'admin' : 'user';

      const dummyHash = await bcrypt.hash(`gauth_${googleId}_${Date.now()}`, 10);
      const [result] = await pool.query(`
        INSERT INTO users (name, email, password_hash, avatar_url, role, google_id, last_login_ip, last_device)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      `, [
        cleanName,
        cleanEmail,
        dummyHash,
        avatarUrl || null,
        initialRole,
        googleId,
        clientInfo.ip,
        clientInfo.deviceSummary,
      ]);

      user = {
        id: result.insertId,
        name: cleanName,
        email: cleanEmail,
        avatarUrl: avatarUrl || null,
        role: initialRole,
        isBanned: false,
        lastLoginIp: clientInfo.ip,
        lastDevice: clientInfo.deviceSummary,
        createdAt: new Date().toISOString(),
      };
    }

    await recordSession(pool, user.id, clientInfo);
    const token = generateToken(user);

    return res.status(200).json({
      success: true,
      message: 'Inicio de sesión con Google exitoso',
      token,
      user,
    });
  } catch (err) {
    console.error('[Auth Google Error]:', err);
    return res.status(500).json({
      success: false,
      error: 'Error interno al autenticar con Google.',
    });
  }
});

// GET /api/auth/me
router.get('/me', authenticateToken, async (req, res) => {
  try {
    const pool = getPool();
    const clientInfo = parseFullClientInfo(req);
    const geo = await resolveIpLocation(clientInfo.ip);

    // Update last_active_at and check session
    await pool.query(`
      UPDATE users 
      SET last_active_at = CURRENT_TIMESTAMP,
          last_login_ip = COALESCE(?, last_login_ip),
          last_device = COALESCE(?, last_device),
          last_country = COALESCE(?, last_country),
          last_country_code = COALESCE(?, last_country_code),
          last_city = COALESCE(?, last_city),
          last_region = COALESCE(?, last_region),
          last_isp = COALESCE(?, last_isp),
          last_os_version = COALESCE(?, last_os_version),
          last_device_model = COALESCE(?, last_device_model)
      WHERE id = ?
    `, [
      clientInfo.ip,
      clientInfo.deviceSummary,
      geo.country,
      geo.countryCode,
      geo.city,
      geo.region,
      geo.isp,
      clientInfo.osVersion,
      clientInfo.deviceModel,
      req.user.id,
    ]);

    // Check if session exists in last 10 minutes, else record a new session
    const [recentSession] = await pool.query(`
      SELECT id FROM user_sessions 
      WHERE user_id = ? AND COALESCE(last_active_at, created_at) >= NOW() - INTERVAL 10 MINUTE 
      ORDER BY id DESC LIMIT 1
    `, [req.user.id]);

    if (recentSession.length === 0) {
      await recordSession(pool, req.user.id, clientInfo);
    } else {
      await pool.query(`
        UPDATE user_sessions 
        SET last_active_at = CURRENT_TIMESTAMP,
            session_duration_seconds = TIMESTAMPDIFF(SECOND, created_at, CURRENT_TIMESTAMP)
        WHERE id = ?
      `, [recentSession[0].id]);
    }

    const [rows] = await pool.query(
      'SELECT id, name, email, avatar_url, role, is_banned, created_at, last_login_at, last_active_at, last_login_ip, last_device, total_listen_seconds FROM users WHERE id = ? LIMIT 1',
      [req.user.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Usuario no encontrado.',
      });
    }

    const dbUser = rows[0];

    if (dbUser.is_banned === 1) {
      return res.status(403).json({
        success: false,
        error: 'Tu cuenta ha sido suspendida por el administrador.',
      });
    }

    return res.json({
      success: true,
      user: {
        id: dbUser.id,
        name: dbUser.name,
        email: dbUser.email,
        avatarUrl: dbUser.avatar_url,
        role: dbUser.role || 'user',
        isBanned: dbUser.is_banned === 1,
        lastLoginAt: dbUser.last_login_at,
        lastActiveAt: dbUser.last_active_at,
        lastLoginIp: dbUser.last_login_ip,
        lastDevice: dbUser.last_device,
        totalListenSeconds: dbUser.total_listen_seconds || 0,
        createdAt: dbUser.created_at,
      },
    });
  } catch (err) {
    console.error('[Auth Me Error]:', err);
    return res.status(500).json({
      success: false,
      error: 'Error al consultar perfil de usuario.',
    });
  }
});

// PUT /api/auth/profile
router.put('/profile', authenticateToken, async (req, res) => {
  try {
    const { name, avatarUrl } = req.body;
    const pool = getPool();

    await pool.query(
      'UPDATE users SET name = COALESCE(?, name), avatar_url = COALESCE(?, avatar_url) WHERE id = ?',
      [name ? name.trim() : null, avatarUrl || null, req.user.id]
    );

    const [rows] = await pool.query(
      'SELECT id, name, email, avatar_url, role, is_banned, created_at, last_login_ip, last_device FROM users WHERE id = ? LIMIT 1',
      [req.user.id]
    );

    const updatedUser = rows[0];

    return res.json({
      success: true,
      message: 'Perfil actualizado exitosamente',
      user: {
        id: updatedUser.id,
        name: updatedUser.name,
        email: updatedUser.email,
        avatarUrl: updatedUser.avatar_url,
        role: updatedUser.role || 'user',
        isBanned: updatedUser.is_banned === 1,
        lastLoginIp: updatedUser.last_login_ip,
        lastDevice: updatedUser.last_device,
        createdAt: updatedUser.created_at,
      },
    });
  } catch (err) {
    console.error('[Auth Profile Error]:', err);
    return res.status(500).json({
      success: false,
      error: 'Error al actualizar perfil.',
    });
  }
});

module.exports = router;
