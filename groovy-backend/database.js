const mysql = require('mysql2/promise');
require('dotenv').config();

const dbConfig = {
  host: process.env.DB_HOST || 'mysql',
  port: parseInt(process.env.DB_PORT || '3306', 10),
  user: process.env.DB_USER || 'groovy_user',
  password: process.env.DB_PASSWORD || 'groovy_pass_2026',
  database: process.env.DB_NAME || 'groovy_db',
  waitForConnections: true,
  connectionLimit: parseInt(process.env.DB_CONNECTION_LIMIT || '40', 10),
  queueLimit: 0,
  enableKeepAlive: true,
  keepAliveInitialDelay: 10000,
};

let pool;

async function initDatabase(retries = 10, delay = 3000) {
  for (let i = 0; i < retries; i++) {
    try {
      console.log(`[Database] Connecting to MySQL at ${dbConfig.host}:${dbConfig.port} (attempt ${i + 1}/${retries})...`);
      
      // Test initial connection
      pool = mysql.createPool(dbConfig);
      const connection = await pool.getConnection();
      console.log('[Database] ✅ Connected to MySQL database successfully!');

      // Run automatic table migrations
      await runMigrations(connection);
      connection.release();
      return pool;
    } catch (err) {
      console.error(`[Database] Connection attempt ${i + 1} failed: ${err.message}`);
      if (i < retries - 1) {
        console.log(`[Database] Retrying in ${delay / 1000}s...`);
        await new Promise((res) => setTimeout(res, delay));
      } else {
        throw new Error(`[Database] Failed to connect to MySQL after ${retries} attempts: ${err.message}`);
      }
    }
  }
}

async function runMigrations(conn) {
  console.log('[Database] Running table migrations...');

  // 1. Users table
  await conn.query(`
    CREATE TABLE IF NOT EXISTS users (
      id INT AUTO_INCREMENT PRIMARY KEY,
      name VARCHAR(255) NOT NULL,
      email VARCHAR(255) NOT NULL UNIQUE,
      password_hash VARCHAR(255) NOT NULL,
      avatar_url TEXT,
      role VARCHAR(50) DEFAULT 'user',
      is_banned TINYINT(1) DEFAULT 0,
      last_login_at TIMESTAMP NULL,
      last_login_ip VARCHAR(100) NULL,
      last_device VARCHAR(255) NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      INDEX idx_email (email)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
  `);

  // Safe check to add missing columns to users if the table already existed
  const addColIfNotExists = async (columnName, columnDef) => {
    try {
      const [rows] = await conn.query(`
        SELECT COUNT(*) as count 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_SCHEMA = DATABASE() 
          AND TABLE_NAME = 'users' 
          AND COLUMN_NAME = ?
      `, [columnName]);
      if (rows[0].count === 0) {
        await conn.query(`ALTER TABLE users ADD COLUMN ${columnName} ${columnDef}`);
        console.log(`[Database] Added column users.${columnName}`);
      }
    } catch (e) {
      console.warn(`[Database] Warning adding column ${columnName}:`, e.message);
    }
  };

  await addColIfNotExists('role', "VARCHAR(50) DEFAULT 'user'");
  await addColIfNotExists('is_banned', 'TINYINT(1) DEFAULT 0');
  await addColIfNotExists('last_login_at', 'TIMESTAMP NULL');
  await addColIfNotExists('last_login_ip', 'VARCHAR(100) NULL');
  await addColIfNotExists('last_device', 'VARCHAR(255) NULL');
  await addColIfNotExists('google_id', 'VARCHAR(255) NULL');

  // 1b. User Sessions / Activity Logs table
  await conn.query(`
    CREATE TABLE IF NOT EXISTS user_sessions (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL,
      ip_address VARCHAR(100),
      user_agent TEXT,
      device_os VARCHAR(100),
      browser VARCHAR(100),
      device_type VARCHAR(50),
      client_platform VARCHAR(100),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      last_active_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      is_active TINYINT(1) DEFAULT 1,
      INDEX idx_session_user (user_id),
      INDEX idx_session_created (created_at DESC),
      CONSTRAINT fk_session_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
  `);

  // 2. Favorites table
  await conn.query(`
    CREATE TABLE IF NOT EXISTS favorites (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL,
      song_id VARCHAR(255) NOT NULL,
      title VARCHAR(255) NOT NULL,
      artist VARCHAR(255),
      album VARCHAR(255),
      cover_art TEXT,
      duration INT DEFAULT 0,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      UNIQUE KEY unique_user_song (user_id, song_id),
      INDEX idx_user_fav (user_id),
      CONSTRAINT fk_fav_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
  `);

  // 3. Playlists table
  await conn.query(`
    CREATE TABLE IF NOT EXISTS playlists (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL,
      name VARCHAR(255) NOT NULL,
      description TEXT,
      cover_art TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      INDEX idx_user_playlist (user_id),
      CONSTRAINT fk_playlist_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
  `);

  // 4. Playlist Songs table
  await conn.query(`
    CREATE TABLE IF NOT EXISTS playlist_songs (
      id INT AUTO_INCREMENT PRIMARY KEY,
      playlist_id INT NOT NULL,
      song_id VARCHAR(255) NOT NULL,
      title VARCHAR(255) NOT NULL,
      artist VARCHAR(255),
      album VARCHAR(255),
      cover_art TEXT,
      duration INT DEFAULT 0,
      position INT DEFAULT 0,
      added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_playlist (playlist_id),
      CONSTRAINT fk_pl_song FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
  `);

  // 5. Playback History table
  await conn.query(`
    CREATE TABLE IF NOT EXISTS playback_history (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL,
      song_id VARCHAR(255) NOT NULL,
      title VARCHAR(255) NOT NULL,
      artist VARCHAR(255),
      album VARCHAR(255),
      cover_art TEXT,
      duration INT DEFAULT 0,
      listen_seconds INT DEFAULT 0,
      platform VARCHAR(100) NULL,
      device_name VARCHAR(255) NULL,
      ip_address VARCHAR(100) NULL,
      played_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_user_hist (user_id, played_at DESC),
      CONSTRAINT fk_hist_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
  `);

  // 6. User Live Playback Presence table (Who is currently playing music in real time)
  await conn.query(`
    CREATE TABLE IF NOT EXISTS user_live_playback (
      device_key VARCHAR(255) PRIMARY KEY,
      user_id INT NULL,
      song_id VARCHAR(255) NOT NULL,
      title VARCHAR(255) NOT NULL,
      artist VARCHAR(255),
      album VARCHAR(255),
      cover_art TEXT,
      duration INT DEFAULT 0,
      position INT DEFAULT 0,
      is_playing TINYINT(1) DEFAULT 1,
      volume FLOAT DEFAULT 1.0,
      platform VARCHAR(100) DEFAULT 'Desconocido',
      device_name VARCHAR(255) DEFAULT 'Groovy App',
      device_model VARCHAR(255) NULL,
      os_version VARCHAR(255) NULL,
      ip_address VARCHAR(100),
      country VARCHAR(100) NULL,
      city VARCHAR(100) NULL,
      started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      last_ping_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      INDEX idx_live_ping (last_ping_at DESC),
      INDEX idx_live_user (user_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
  `);

  // 7. Device Commands table (Groovy Connect Cloud Relay)
  await conn.query(`
    CREATE TABLE IF NOT EXISTS device_commands (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NULL,
      sender_device_id VARCHAR(255) NOT NULL,
      target_device_id VARCHAR(255) NOT NULL,
      action VARCHAR(50) NOT NULL,
      payload LONGTEXT NULL,
      status ENUM('pending', 'delivered', 'expired') DEFAULT 'pending',
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      delivered_at TIMESTAMP NULL,
      INDEX idx_target_status (target_device_id, status, created_at),
      INDEX idx_user_commands (user_id, created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
  `);

  // Extra column migrations
  await addColIfNotExists('total_listen_seconds', 'INT DEFAULT 0');
  await addColIfNotExists('last_active_at', 'TIMESTAMP NULL');

  const addColToTable = async (tableName, columnName, columnDef) => {
    try {
      const [rows] = await conn.query(`
        SELECT COUNT(*) as count 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_SCHEMA = DATABASE() 
          AND TABLE_NAME = ? 
          AND COLUMN_NAME = ?
      `, [tableName, columnName]);
      if (rows[0].count === 0) {
        await conn.query(`ALTER TABLE ${tableName} ADD COLUMN ${columnName} ${columnDef}`);
        console.log(`[Database] Added column ${tableName}.${columnName}`);
      }
    } catch (e) {
      console.warn(`[Database] Warning adding column ${tableName}.${columnName}:`, e.message);
    }
  };

  await addColToTable('user_sessions', 'session_duration_seconds', 'INT DEFAULT 0');
  await addColToTable('user_sessions', 'last_ping_at', 'TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');
  await addColToTable('user_sessions', 'device_model', 'VARCHAR(255) NULL');
  await addColToTable('user_sessions', 'os_version', 'VARCHAR(255) NULL');
  await addColToTable('user_sessions', 'browser_version', 'VARCHAR(100) NULL');
  await addColToTable('user_sessions', 'country', 'VARCHAR(100) NULL');
  await addColToTable('user_sessions', 'country_code', 'VARCHAR(10) NULL');
  await addColToTable('user_sessions', 'city', 'VARCHAR(100) NULL');
  await addColToTable('user_sessions', 'region', 'VARCHAR(100) NULL');
  await addColToTable('user_sessions', 'isp', 'VARCHAR(255) NULL');

  await addColToTable('playback_history', 'platform', 'VARCHAR(100) NULL');
  await addColToTable('playback_history', 'device_name', 'VARCHAR(255) NULL');
  await addColToTable('playback_history', 'ip_address', 'VARCHAR(100) NULL');
  await addColToTable('playback_history', 'listen_seconds', 'INT DEFAULT 0');

  await addColToTable('users', 'last_country', 'VARCHAR(100) NULL');
  await addColToTable('users', 'last_country_code', 'VARCHAR(10) NULL');
  await addColToTable('users', 'last_city', 'VARCHAR(100) NULL');
  await addColToTable('users', 'last_region', 'VARCHAR(100) NULL');
  await addColToTable('users', 'last_isp', 'VARCHAR(255) NULL');
  await addColToTable('users', 'last_os_version', 'VARCHAR(255) NULL');
  await addColToTable('users', 'last_device_model', 'VARCHAR(255) NULL');

  await addColToTable('user_live_playback', 'device_model', 'VARCHAR(255) NULL');
  await addColToTable('user_live_playback', 'os_version', 'VARCHAR(255) NULL');
  await addColToTable('user_live_playback', 'country', 'VARCHAR(100) NULL');
  await addColToTable('user_live_playback', 'city', 'VARCHAR(100) NULL');
  await addColToTable('user_live_playback', 'device_key', 'VARCHAR(255) NULL');
  await addColToTable('user_live_playback', 'local_ip', 'VARCHAR(100) NULL');
  await addColToTable('user_live_playback', 'local_port', 'INT DEFAULT 42425');

  // Allow guest sessions (user_id NULL) without foreign key constraints
  try {
    await conn.query('ALTER TABLE user_sessions MODIFY COLUMN user_id INT NULL');
  } catch (_) {}
  try {
    await conn.query('ALTER TABLE playback_history MODIFY COLUMN user_id INT NULL');
  } catch (_) {}
  try {
    await conn.query('ALTER TABLE user_live_playback MODIFY COLUMN user_id INT NULL');
  } catch (_) {}
  try {
    await conn.query('ALTER TABLE user_live_playback DROP FOREIGN KEY fk_live_user');
  } catch (_) {}
  try {
    // Ensure all existing rows have a non-null device_key before converting to PRIMARY KEY
    await conn.query(`
      UPDATE user_live_playback 
      SET device_key = CONCAT(COALESCE(user_id, 'guest'), '_', LOWER(COALESCE(platform, 'app')), '_', LOWER(COALESCE(device_name, 'device'))) 
      WHERE device_key IS NULL OR device_key = ''
    `);
    await conn.query('ALTER TABLE user_live_playback MODIFY COLUMN device_key VARCHAR(255) NOT NULL');
    await conn.query('ALTER TABLE user_live_playback DROP PRIMARY KEY');
    await conn.query('ALTER TABLE user_live_playback ADD PRIMARY KEY (device_key)');
    console.log('[Database] Migrated user_live_playback to device_key primary key');
  } catch (_) {}
  try {
    await conn.query('ALTER TABLE user_live_playback ADD COLUMN volume FLOAT DEFAULT 1.0');
    console.log('[Database] Migrated user_live_playback to include volume column');
  } catch (_) {}

  // Promote danilorodelo355@gmail.com and initial admin to admin role
  try {
    await conn.query("UPDATE users SET role = 'admin' WHERE email = 'danilorodelo355@gmail.com'");
    const [adminCheck] = await conn.query("SELECT id FROM users WHERE role = 'admin' LIMIT 1");
    if (adminCheck.length === 0) {
      await conn.query("UPDATE users SET role = 'admin' ORDER BY id ASC LIMIT 1");
    }
    console.log('[Database] 👑 Admin roles verified.');
  } catch (e) {
    console.warn('[Database] Admin role setup:', e.message);
  }

  console.log('[Database] ✅ All MySQL tables verified and ready.');

  // Background backfill for past sessions without location
  setTimeout(async () => {
    try {
      const { resolveIpLocation } = require('./utils/geoip');
      const [sessionsToEnrich] = await pool.query(`
        SELECT id, ip_address FROM user_sessions 
        WHERE (country IS NULL OR country = '' OR country = 'Desconocido') AND ip_address IS NOT NULL
        LIMIT 50
      `);
      for (const s of sessionsToEnrich) {
        const geo = await resolveIpLocation(s.ip_address);
        await pool.query(`
          UPDATE user_sessions 
          SET country = ?, country_code = ?, city = ?, region = ?, isp = ?
          WHERE id = ?
        `, [geo.country, geo.countryCode, geo.city, geo.region, geo.isp, s.id]);
      }
      
      const [usersToEnrich] = await pool.query(`
        SELECT id, last_login_ip FROM users 
        WHERE (last_country IS NULL OR last_country = '' OR last_country = 'Desconocido') AND last_login_ip IS NOT NULL
        LIMIT 20
      `);
      for (const u of usersToEnrich) {
        const geo = await resolveIpLocation(u.last_login_ip);
        await pool.query(`
          UPDATE users 
          SET last_country = ?, last_country_code = ?, last_city = ?, last_region = ?, last_isp = ?
          WHERE id = ?
        `, [geo.country, geo.countryCode, geo.city, geo.region, geo.isp, u.id]);
      }
    } catch (err) {
      console.warn('[Database] Geo backfill notice:', err.message);
    }
  }, 1000);
}

function getPool() {
  if (!pool) {
    throw new Error('[Database] Pool not initialized. Call initDatabase() first.');
  }
  return pool;
}

module.exports = {
  initDatabase,
  getPool,
};
