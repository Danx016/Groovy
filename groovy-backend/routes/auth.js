const express = require('express');
const bcrypt = require('bcryptjs');
const { getPool } = require('../database');
const { generateToken, authenticateToken } = require('../middleware/auth');

const router = express.Router();

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

    // Hash password
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    // Insert user
    const [result] = await pool.query(
      'INSERT INTO users (name, email, password_hash, avatar_url) VALUES (?, ?, ?, ?)',
      [cleanName, cleanEmail, passwordHash, avatarUrl || null]
    );

    const user = {
      id: result.insertId,
      name: cleanName,
      email: cleanEmail,
      avatarUrl: avatarUrl || null,
      createdAt: new Date().toISOString(),
    };

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
      'SELECT id, name, email, password_hash, avatar_url, created_at FROM users WHERE email = ? LIMIT 1',
      [cleanEmail]
    );

    if (rows.length === 0) {
      return res.status(401).json({
        success: false,
        error: 'Correo o contraseña incorrectos.',
      });
    }

    const dbUser = rows[0];
    const isMatch = await bcrypt.compare(password, dbUser.password_hash);

    if (!isMatch) {
      return res.status(401).json({
        success: false,
        error: 'Correo o contraseña incorrectos.',
      });
    }

    const user = {
      id: dbUser.id,
      name: dbUser.name,
      email: dbUser.email,
      avatarUrl: dbUser.avatar_url,
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
      'SELECT id, name, email, avatar_url, created_at FROM users WHERE id = ? LIMIT 1',
      [req.user.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Usuario no encontrado.',
      });
    }

    const dbUser = rows[0];
    return res.json({
      success: true,
      user: {
        id: dbUser.id,
        name: dbUser.name,
        email: dbUser.email,
        avatarUrl: dbUser.avatar_url,
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
      'SELECT id, name, email, avatar_url, created_at FROM users WHERE id = ? LIMIT 1',
      [req.user.id]
    );

    return res.json({
      success: true,
      message: 'Perfil actualizado exitosamente',
      user: rows[0],
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
