const express = require('express');
const bcrypt = require('bcryptjs');
const { getPool } = require('../database');
const { generateToken, authenticateToken } = require('../middleware/auth');

const router = express.Router();

/**
 * Extract IP, User Agent, OS, Browser, Device Type from request
 */
function parseClientInfo(req) {
  const forwarded = req.headers['x-forwarded-for'];
  let ip = forwarded ? forwarded.split(',')[0].trim() : (req.headers['x-real-ip'] || req.socket?.remoteAddress || '127.0.0.1');
  if (ip.startsWith('::ffff:')) {
    ip = ip.replace('::ffff:', '');
  }

  const ua = req.headers['user-agent'] || '';
  const clientPlatformHeader = req.headers['x-client-platform'];

  let os = 'Unknown OS';
  if (/windows/i.test(ua)) os = 'Windows';
  else if (/android/i.test(ua)) os = 'Android';
  else if (/iphone|ipad|ipod/i.test(ua)) os = 'iOS';
  else if (/macintosh|mac os x/i.test(ua)) os = 'macOS';
  else if (/linux/i.test(ua)) os = 'Linux';
  else if (/cros/i.test(ua)) os = 'ChromeOS';

  let browser = 'Unknown Browser';
  if (/edg/i.test(ua)) browser = 'Edge';
  else if (/chrome|crios/i.test(ua)) browser = 'Chrome';
  else if (/firefox|fxios/i.test(ua)) browser = 'Firefox';
  else if (/safari/i.test(ua) && !/chrome/i.test(ua)) browser = 'Safari';
  else if (/opera|opr/i.test(ua)) browser = 'Opera';
  else if (/dart|flutter/i.test(ua)) browser = 'Groovy App Client';

  let deviceType = 'Desktop';
  if (/mobile/i.test(ua) || /android/i.test(ua) || /iphone/i.test(ua)) {
    deviceType = 'Mobile';
  } else if (/ipad|tablet/i.test(ua)) {
    deviceType = 'Tablet';
  }

  let clientPlatform = clientPlatformHeader || (deviceType === 'Mobile' ? `${os} Mobile` : `${os} Web`);
  if (/dart|flutter/i.test(ua)) {
    clientPlatform = `Groovy App (${os})`;
  }

  return {
    ip,
    userAgent: ua,
    os,
    browser,
    deviceType,
    clientPlatform,
    deviceSummary: `${os} (${browser})`,
  };
}

/**
 * Record a user session log and update users table last login metadata
 */
async function recordSession(pool, userId, clientInfo) {
  try {
    await pool.query(`
      INSERT INTO user_sessions (user_id, ip_address, user_agent, device_os, browser, device_type, client_platform)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `, [
      userId,
      clientInfo.ip,
      clientInfo.userAgent,
      clientInfo.os,
      clientInfo.browser,
      clientInfo.deviceType,
      clientInfo.clientPlatform,
    ]);

    await pool.query(`
      UPDATE users 
      SET last_login_at = CURRENT_TIMESTAMP, 
          last_login_ip = ?, 
          last_device = ? 
      WHERE id = ?
    `, [clientInfo.ip, clientInfo.deviceSummary, userId]);
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

    const clientInfo = parseClientInfo(req);

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

    const clientInfo = parseClientInfo(req);
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

// GET /api/auth/me
router.get('/me', authenticateToken, async (req, res) => {
  try {
    const pool = getPool();
    const [rows] = await pool.query(
      'SELECT id, name, email, avatar_url, role, is_banned, created_at, last_login_at, last_login_ip, last_device FROM users WHERE id = ? LIMIT 1',
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
        lastLoginIp: dbUser.last_login_ip,
        lastDevice: dbUser.last_device,
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
