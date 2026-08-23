const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'groovy_jwt_secret_key_super_secure_2026';

function generateToken(user) {
  return jwt.sign(
    {
      id: user.id,
      email: user.email,
      name: user.name,
    },
    JWT_SECRET,
    { expiresIn: '90d' } // 90 days token validity for mobile apps
  );
}

function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Bearer <token>

  if (!token) {
    return res.status(401).json({
      success: false,
      error: 'No se proporcionó token de autenticación',
    });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({
        success: false,
        error: 'Token inválido o expirado. Por favor inicia sesión nuevamente.',
      });
    }
    req.user = user;
    next();
  });
}

module.exports = {
  generateToken,
  authenticateToken,
  JWT_SECRET,
};
