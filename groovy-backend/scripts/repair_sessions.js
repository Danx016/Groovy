require('dotenv').config();
const { initDatabase, getPool } = require('../database');

async function repair() {
  await initDatabase();
  const pool = getPool();
  try {
    console.log('--- REPARANDO SESIONES DE USUARIO CORRUPTAS ---');
    
    // 1. Contar sesiones afectadas
    const [before] = await pool.query(`
      SELECT COUNT(*) as count 
      FROM user_sessions 
      WHERE created_at < '2026-10-04 00:00:00' 
        AND last_active_at >= '2026-10-04 00:00:00'
    `);
    console.log(`Sesiones históricas con timestamp falso de hoy: ${before[0].count}`);

    // 2. Restaurar last_active_at real basado en created_at + session_duration_seconds
    const [result] = await pool.query(`
      UPDATE user_sessions 
      SET last_active_at = IF(session_duration_seconds > 0, DATE_ADD(created_at, INTERVAL session_duration_seconds SECOND), created_at)
      WHERE created_at < '2026-10-04 00:00:00' 
        AND last_active_at >= '2026-10-04 00:00:00'
    `);
    console.log(`Filas reparadas exitosamente: ${result.affectedRows}`);

    // 3. Resumen de dispositivos por usuario
    const [devices] = await pool.query(`
      SELECT 
        s.user_id,
        u.name,
        COALESCE(s.device_model, 'Desconocido') as device,
        s.client_platform,
        COUNT(*) as total_sesiones,
        MIN(s.created_at) as primera_vez,
        MAX(s.last_active_at) as ultima_actividad
      FROM user_sessions s
      LEFT JOIN users u ON s.user_id = u.id
      GROUP BY s.user_id, u.name, s.device_model, s.client_platform
      ORDER BY ultima_actividad DESC
    `);
    console.log('\n--- RESUMEN DE DISPOSITIVOS TRAS REPARACIÓN ---');
    console.table(devices);

    process.exit(0);
  } catch (err) {
    console.error('Error durante la reparación:', err);
    process.exit(1);
  }
}

repair();
