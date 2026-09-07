const mysql = require('mysql2/promise');
require('dotenv').config();

const dbConfig = {
  host: process.env.DB_HOST || 'mysql',
  port: parseInt(process.env.DB_PORT || '3306', 10),
  user: process.env.DB_USER || 'groovy_user',
  password: process.env.DB_PASSWORD || 'groovy_pass_2026',
  database: process.env.DB_NAME || 'groovy_db',
  waitForConnections: true,
  connectionLimit: 15,
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
      played_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_user_hist (user_id, played_at DESC),
      CONSTRAINT fk_hist_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
  `);

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
