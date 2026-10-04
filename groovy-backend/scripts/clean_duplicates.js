const { initDatabase, getPool } = require('../database');

async function cleanDuplicates() {
  await initDatabase();
  const pool = getPool();
  console.log('[Deduplication] Starting playback_history cleanup...');

  const [rows] = await pool.query(
    'SELECT id, user_id, song_id, title, duration, listen_seconds, played_at FROM playback_history ORDER BY user_id ASC, played_at ASC, id ASC'
  );
  console.log(`[Deduplication] Total rows in playback_history: ${rows.length}`);

  const toDelete = [];
  let prev = null;

  for (const row of rows) {
    if (prev && prev.user_id === row.user_id && String(prev.song_id) === String(row.song_id)) {
      const diffSec = Math.abs((new Date(row.played_at).getTime() - new Date(prev.played_at).getTime()) / 1000);
      const threshold = Math.max(prev.duration || 240, 240);
      if (diffSec <= threshold) {
        toDelete.push(row.id);
        continue;
      }
    }
    prev = row;
  }

  console.log(`[Deduplication] Found ${toDelete.length} heartbeat duplicate entries.`);

  if (toDelete.length > 0) {
    // Delete in batches of 500 to avoid query size limits
    const batchSize = 500;
    for (let i = 0; i < toDelete.length; i += batchSize) {
      const batch = toDelete.slice(i, i + batchSize);
      await pool.query('DELETE FROM playback_history WHERE id IN (?)', [batch]);
      console.log(`[Deduplication] Deleted batch ${i + 1} to ${Math.min(i + batchSize, toDelete.length)}...`);
    }
    console.log(`[Deduplication] Successfully purged ${toDelete.length} duplicate rows.`);
  }

  const [remaining] = await pool.query('SELECT COUNT(*) as count FROM playback_history');
  console.log(`[Deduplication] Clean playback_history total count: ${remaining[0].count}`);
  process.exit(0);
}

cleanDuplicates().catch(err => {
  console.error('[Deduplication Error]:', err);
  process.exit(1);
});
