require('dotenv').config();
const jwt = require('jsonwebtoken');

const token = jwt.sign(
  { id: 1, email: 'danilorodelo355@gmail.com', role: 'admin' },
  process.env.JWT_SECRET || 'groovy_jwt_secret_key_2026'
);

fetch('http://127.0.0.1:4000/api/admin/sessions', {
  headers: { Authorization: `Bearer ${token}` }
})
  .then(res => res.json())
  .then(data => {
    console.log('--- TEST /api/admin/sessions ---');
    console.log('Success:', data.success);
    console.log('Total Devices:', data.devices?.length);
    console.log('Total Sessions in Audit Log:', data.sessions?.length);
    console.log('Stats:', data.stats);
    console.log('\n--- DISPOSITIVOS DETECTADOS ---');
    console.table(data.devices?.map(d => ({
      Usuario: d.userName,
      Dispositivo: d.deviceModel,
      Plataforma: d.clientPlatform,
      IP: d.ipAddress,
      Ubicación: `${d.city || ''}, ${d.country || ''}`,
      Sesiones: d.totalSessions,
      'Última Actividad': d.lastActiveAt,
      'En Línea': d.isOnline ? '🟢 SI' : '⚪ NO'
    })));
  })
  .catch(console.error);
