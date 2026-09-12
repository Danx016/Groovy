const jwt = require('jsonwebtoken');

const PRIMARY_SECRET = process.env.JWT_SECRET;

if (!PRIMARY_SECRET) {
  throw new Error('JWT_SECRET must be configured before starting the backend');
}

function verifyTokenWithFallback(token) {
  if (!token) return null;
  try {
    const decoded = jwt.verify(token, PRIMARY_SECRET, {
      algorithms: ['HS256'],
    });
    if (decoded && decoded.id) return decoded;
  } catch (err) {
    return null;
  }
  return null;
}

function generateToken(user) {
  return jwt.sign(
    {
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role || 'user',
    },
    PRIMARY_SECRET,
    { expiresIn: '90d', algorithm: 'HS256' }
  );
}

function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = (authHeader && authHeader.split(' ')[1]) || req.body?.token || req.query?.token;

  if (!token) {
    return res.status(401).json({
      success: false,
      error: 'No se proporcionó token de autenticación',
    });
  }

  const user = verifyTokenWithFallback(token);
  if (!user) {
    return res.status(403).json({
      success: false,
      error: 'Token inválido o expirado. Por favor inicia sesión nuevamente.',
    });
  }
  req.user = user;
  next();
}

function optionalAuth(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = (authHeader && authHeader.split(' ')[1]) || req.body?.token || req.query?.token;
  if (token) {
    const user = verifyTokenWithFallback(token);
    if (user) req.user = user;
  }
  next();
}

const ADMIN_EMAILS = (process.env.ADMIN_EMAILS || 'danilorodelo355@gmail.com')
  .split(',')
  .map((e) => e.trim().toLowerCase())
  .filter(Boolean);

function authenticateAdmin(req, res, next) {
  authenticateToken(req, res, () => {
    const userEmail = req.user?.email ? req.user.email.toLowerCase() : '';
    if (req.user && (req.user.role === 'admin' || ADMIN_EMAILS.includes(userEmail))) {
      return next();
    }
    return res.status(403).json({
      success: false,
      error: 'Acceso denegado. Se requieren permisos de administrador.',
    });
  });
}

module.exports = {
  generateToken,
  authenticateToken,
  optionalAuth,
  authenticateAdmin,
  verifyTokenWithFallback,
  JWT_SECRET: PRIMARY_SECRET,
};
