/**
 * useRecommendations — Replicates Android's RecommendationService
 * Builds Para Ti, Quick Picks and genre Mixes from history + favorites.
 */
import { useMemo } from 'react';
import { usePlayer } from '../context/PlayerContext';
import { useLibrary } from '../context/LibraryContext';

/* Shuffle helper */
const shuffle = (arr) => {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
};

const cleanSong = (song) =>
  song &&
  song.title?.trim() &&
  !/^\d{8,}$/.test(song.title.trim()) &&
  !song.title.startsWith('AUD-') &&
  !song.title.startsWith('PTT-') &&
  (!song.duration || song.duration >= 15);

export function useRecommendations() {
  const { history, queue } = usePlayer();
  const { favorites } = useLibrary();

  return useMemo(() => {
    /* Source pool: history + favorites, deduplicated */
    const seen = new Set();
    const pool = [...history, ...favorites].filter((s) => {
      if (!s || !s.id || seen.has(s.id)) return false;
      if (!cleanSong(s)) return false;
      // Filter out "[Unknown Album]" songs that have no real metadata
      if (s.title === '[Unknown Album]') return false;
      seen.add(s.id);
      return true;
    });

    if (pool.length === 0) {
      return { forYou: [], quickPicks: [], mixes: [] };
    }

    /* ---- Artist affinity from history ---- */
    const artistCount = {};
    const genreCount = {};
    history.forEach((s) => {
      if (s?.artist) artistCount[s.artist] = (artistCount[s.artist] || 0) + 1;
      if (s?.genre) genreCount[s.genre] = (genreCount[s.genre] || 0) + 1;
    });
    favorites.forEach((s) => {
      if (s?.artist) artistCount[s.artist] = (artistCount[s.artist] || 0) + 2; // favorites weigh more
      if (s?.genre) genreCount[s.genre] = (genreCount[s.genre] || 0) + 2;
    });

    const topArtists = Object.entries(artistCount)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map((e) => e[0]);

    const topGenres = Object.entries(genreCount)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 4)
      .map((e) => e[0]);

    /* ---- Para Ti: sorted by affinity score ---- */
    const scored = pool.map((s) => {
      let score = 0;
      const artistIdx = topArtists.indexOf(s.artist);
      const genreIdx = topGenres.indexOf(s.genre);
      if (artistIdx >= 0) score += (5 - artistIdx) * 3;
      if (genreIdx >= 0) score += (4 - genreIdx) * 2;
      if (favorites.find((f) => f.id === s.id)) score += 5;
      score += Math.random() * 2; // slight jitter
      return { s, score };
    });
    scored.sort((a, b) => b.score - a.score);
    const forYou = scored.slice(0, 15).map((x) => x.s);

    /* ---- Quick Picks: top-artist / top-genre songs NOT recently heard ---- */
    const recentIds = new Set(history.slice(0, 10).map((s) => s?.id));
    const quickCandidates = pool.filter(
      (s) =>
        !recentIds.has(s.id) &&
        (topArtists.includes(s.artist) || topGenres.includes(s.genre))
    );
    const quickPicks = shuffle(quickCandidates).slice(0, 15);

    /* ---- Mixes: per top artist and per top genre ---- */
    const mixes = [];

    topArtists.slice(0, 3).forEach((artist) => {
      const songs = pool.filter((s) => s.artist === artist);
      if (songs.length >= 3) {
        mixes.push({ name: `${artist} Mix`, songs: shuffle(songs).slice(0, 20) });
      }
    });

    topGenres.slice(0, 2).forEach((genre) => {
      const songs = pool.filter((s) => s.genre === genre);
      if (songs.length >= 3) {
        mixes.push({ name: `Mix de ${genre}`, songs: shuffle(songs).slice(0, 20) });
      }
    });

    /* ---- Time-based Vibes ---- */
    const hour = new Date().getHours();
    const timeLabel =
      hour >= 5 && hour < 12 ? 'Mañana' :
      hour >= 12 && hour < 17 ? 'Tarde' :
      hour >= 17 && hour < 21 ? 'Noche' : 'Nocturno';
    const vibesSongs = shuffle(pool).slice(0, 15);
    if (vibesSongs.length >= 3) {
      mixes.push({ name: `Vibras de ${timeLabel}`, songs: vibesSongs });
    }

    return { forYou, quickPicks, mixes };
  }, [history, favorites]);
}
