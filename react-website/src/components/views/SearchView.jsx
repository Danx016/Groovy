import React, { useState, useEffect } from 'react';
import { Search, TrendingUp, Music2, Flame, Disc } from 'lucide-react';
import { musicService } from '../../services/musicService';
import { SongCard } from '../ui/SongCard';

const GENRES = [
  { name: 'Reggaetón', query: 'reggaeton bad bunny', color: '#E8001C' },
  { name: 'Pop Hits', query: 'pop hits 2024', color: '#A12AC4' },
  { name: 'Rock', query: 'rock classic alternative', color: '#E87502' },
  { name: 'Electrónica', query: 'electronic dance edm', color: '#148A08' },
  { name: 'Trap Latino', query: 'latin trap anuel', color: '#0D35A5' },
  { name: 'Lo-Fi', query: 'lofi hip hop chill', color: '#1E3264' },
  { name: 'Salsa', query: 'salsa clasica cumbia', color: '#C62828' },
  { name: 'R&B / Soul', query: 'r&b soul neo', color: '#6A1B9A' },
  { name: 'K-Pop', query: 'kpop bts blackpink', color: '#AD1457' },
  { name: 'Metal', query: 'metal rock heavy', color: '#37474F' },
];

export const SearchView = () => {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState([]);
  const [trending, setTrending] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    musicService.getTrendingSongs().then(setTrending).catch(console.error);
  }, []);

  const doSearch = async (q) => {
    if (!q?.trim()) { setResults([]); return; }
    setLoading(true);
    try { setResults(await musicService.searchSongs(q)); }
    catch (e) { console.error(e); }
    finally { setLoading(false); }
  };

  return (
    <div style={{ paddingBottom: '148px' }}>
      {/* Search bar */}
      <h1 style={{ fontSize: '28px', fontWeight: 700, letterSpacing: '-0.5px', marginBottom: '16px' }}>Explorar</h1>
      <div style={{
        display: 'flex', alignItems: 'center', gap: '12px',
        background: '#282828', borderRadius: '8px', padding: '12px 16px',
        border: '0.5px solid #404040', marginBottom: '28px',
      }}>
        <Search size={18} style={{ color: '#B3B3B3', flexShrink: 0 }} />
        <input
          type="text"
          value={query}
          onChange={e => { setQuery(e.target.value); if (e.target.value.trim().length > 2) doSearch(e.target.value); else if (!e.target.value.trim()) setResults([]); }}
          onKeyDown={e => e.key === 'Enter' && doSearch(query)}
          placeholder="¿Qué quieres escuchar?"
          style={{ flex: 1, background: 'transparent', border: 'none', fontSize: '16px', color: '#fff', outline: 'none' }}
        />
        {query && (
          <button onClick={() => { setQuery(''); setResults([]); }} style={{ color: '#B3B3B3', fontSize: '13px' }}>Limpiar</button>
        )}
      </div>

      {/* Loading */}
      {loading && (
        <div style={{ display: 'flex', justifyContent: 'center', padding: '32px' }}>
          <div className="animate-spin" style={{ width: '28px', height: '28px', border: '2.5px solid #FA243C', borderTopColor: 'transparent', borderRadius: '50%' }} />
        </div>
      )}

      {/* Results */}
      {!loading && results.length > 0 && (
        <div>
          <p style={{ fontSize: '13px', color: '#B3B3B3', marginBottom: '12px' }}>
            {results.length} resultados para "<strong style={{ color: '#fff' }}>{query}</strong>"
          </p>
          {results.map(s => <SongCard key={s.id} song={s} queue={results} />)}
        </div>
      )}

      {/* Genres + Trending (when not searching) */}
      {!loading && results.length === 0 && (
        <>
          {/* Genres Grid */}
          <div style={{ marginBottom: '32px' }}>
            <h2 style={{ fontSize: '20px', fontWeight: 700, letterSpacing: '-0.3px', marginBottom: '14px' }}>Géneros y Estilos</h2>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '8px' }}>
              {GENRES.map(g => (
                <div
                  key={g.name}
                  onClick={() => { setQuery(g.name); doSearch(g.query); }}
                  style={{
                    height: '60px', borderRadius: '8px', padding: '12px 16px',
                    background: g.color, cursor: 'pointer', overflow: 'hidden', position: 'relative',
                    transition: 'filter 0.15s',
                  }}
                  onMouseEnter={e => e.currentTarget.style.filter = 'brightness(1.15)'}
                  onMouseLeave={e => e.currentTarget.style.filter = 'brightness(1)'}
                >
                  <span style={{ fontWeight: 700, fontSize: '15px', color: '#fff', letterSpacing: '-0.2px' }}>{g.name}</span>
                </div>
              ))}
            </div>
          </div>

          {/* Trending */}
          {trending.length > 0 && (
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '14px' }}>
                <TrendingUp size={20} style={{ color: '#FA243C' }} />
                <h2 style={{ fontSize: '20px', fontWeight: 700, letterSpacing: '-0.3px' }}>Éxitos del Momento</h2>
              </div>
              {trending.map(s => <SongCard key={s.id} song={s} queue={trending} />)}
            </div>
          )}
        </>
      )}
    </div>
  );
};
