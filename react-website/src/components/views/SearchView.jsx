import React, { useState, useEffect, useRef } from 'react';
import { Search, X, Play, Pause, Heart, Plus, ListPlus, Music2, Disc, User, Sparkles, Clock, TrendingUp } from 'lucide-react';
import { usePlayer } from '../../context/PlayerContext';
import { useLibrary } from '../../context/LibraryContext';
import { useAuth } from '../../context/AuthContext';
import { musicService, GENRES_LIST } from '../../services/musicService';

const fmtDuration = (secs) => {
  if (!secs || isNaN(secs)) return '3:00';
  const m = Math.floor(secs / 60);
  const s = Math.floor(secs % 60);
  return `${m}:${s < 10 ? '0' : ''}${s}`;
};

export const SearchView = ({ onSelectArtist, onSelectAlbum }) => {
  const { currentSong, isPlaying, playSong, togglePlay, addToQueue, openArtist, openAlbum } = usePlayer();
  const { isFavorite, toggleFavorite } = useLibrary();
  const { isAuthenticated, openAuthModal } = useAuth();

  const handleOpenArtist = (name) => {
    if (onSelectArtist) onSelectArtist(name);
    else if (openArtist) openArtist(name);
  };

  const handleOpenAlbum = (albumObj) => {
    if (onSelectAlbum) onSelectAlbum(albumObj);
    else if (openAlbum) openAlbum(albumObj);
  };

  const [query, setQuery] = useState('');
  const [activeCategory, setActiveCategory] = useState('all'); // 'all' | 'songs' | 'artists' | 'albums'
  const [results, setResults] = useState([]);
  const [isLoading, setIsLoading] = useState(false);
  const [recentSearches, setRecentSearches] = useState(() => {
    try {
      const saved = localStorage.getItem('groovy_recent_searches');
      return saved ? JSON.parse(saved) : ['Bad Bunny', 'The Weeknd', 'Feid', 'Coldplay', 'Karol G'];
    } catch {
      return ['Bad Bunny', 'The Weeknd', 'Feid'];
    }
  });
  const searchInputRef = useRef(null);

  // Debounced search
  useEffect(() => {
    if (!query.trim()) {
      setResults([]);
      setIsLoading(false);
      return;
    }

    setIsLoading(true);
    const timeout = setTimeout(async () => {
      try {
        const res = await musicService.searchSongs(query, activeCategory);
        setResults(res);
      } catch (err) {
        console.error('Search error:', err);
      } finally {
        setIsLoading(false);
      }
    }, 280);

    return () => clearTimeout(timeout);
  }, [query, activeCategory]);

  const handleSelectRecent = (term) => {
    setQuery(term);
    if (searchInputRef.current) searchInputRef.current.focus();
  };

  const handleSaveRecent = (term) => {
    if (!term.trim()) return;
    const clean = term.trim();
    setRecentSearches(prev => {
      const next = [clean, ...prev.filter(s => s.toLowerCase() !== clean.toLowerCase())].slice(0, 10);
      localStorage.setItem('groovy_recent_searches', JSON.stringify(next));
      return next;
    });
  };

  const handleClearRecent = () => {
    setRecentSearches([]);
    localStorage.removeItem('groovy_recent_searches');
  };

  const CATEGORIES = [
    { id: 'all', label: 'Todo' },
    { id: 'songs', label: 'Canciones' },
    { id: 'artists', label: 'Artistas' },
    { id: 'albums', label: 'Álbumes' },
  ];

  return (
    <div style={{ paddingBottom: '140px' }}>
      {/* Header & Search Bar */}
      <div style={{ marginBottom: '20px' }}>
        <h1 style={{ fontSize: '32px', fontWeight: 900, letterSpacing: '-0.8px', color: '#fff', marginBottom: '16px' }}>
          Búsqueda
        </h1>

        <div style={{
          position: 'relative', width: '100%',
          display: 'flex', alignItems: 'center',
          background: '#1F1F1F', borderRadius: '12px',
          border: '1px solid #333', padding: '10px 16px',
          boxShadow: '0 4px 20px rgba(0,0,0,0.4)',
        }}>
          <Search size={18} style={{ color: '#A1A1A6', marginRight: '12px' }} />
          <input
            ref={searchInputRef}
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter') handleSaveRecent(query);
            }}
            placeholder="¿Qué deseas escuchar hoy? Canciones, artistas o álbumes..."
            style={{
              flex: 1, background: 'transparent', border: 'none',
              color: '#fff', fontSize: '15px', fontWeight: 500, outline: 'none',
            }}
          />
          {isLoading && (
            <div className="animate-spin" style={{ width: '16px', height: '16px', border: '2px solid #FA243C', borderTopColor: 'transparent', borderRadius: '50%', marginRight: '8px' }} />
          )}
          {query && (
            <button
              onClick={() => { setQuery(''); setResults([]); }}
              style={{ color: '#A1A1A6', background: 'transparent', border: 'none', cursor: 'pointer', padding: '4px' }}
            >
              <X size={16} />
            </button>
          )}
        </div>
      </div>

      {/* Category Pills */}
      {query.trim().length > 0 && (
        <div style={{ display: 'flex', gap: '8px', marginBottom: '20px', overflowX: 'auto', paddingBottom: '4px' }}>
          {CATEGORIES.map(c => (
            <button
              key={c.id}
              onClick={() => setActiveCategory(c.id)}
              style={{
                padding: '6px 16px', borderRadius: '20px',
                background: activeCategory === c.id ? '#FA243C' : '#222',
                color: activeCategory === c.id ? '#fff' : '#B3B3B3',
                fontSize: '13px', fontWeight: 600, border: 'none', cursor: 'pointer',
                transition: 'all 0.15s', flexShrink: 0,
              }}
            >
              {c.label}
            </button>
          ))}
        </div>
      )}

      {/* Search Results */}
      {query.trim().length > 0 ? (
        <div>
          {results.length === 0 && !isLoading ? (
            <div style={{ textAlign: 'center', padding: '60px 20px', color: '#6B6B6B' }}>
              <Music2 size={48} style={{ margin: '0 auto 12px', opacity: 0.3 }} />
              <p style={{ fontSize: '16px', fontWeight: 600, color: '#fff', marginBottom: '6px' }}>No encontramos resultados para "{query}"</p>
              <p style={{ fontSize: '13px' }}>Prueba buscando con otro término, artista o nombre de canción.</p>
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
              {results.map((song, i) => {
                const isCurrent = currentSong?.id === song.id;
                const isFav = isFavorite(song.id);

                return (
                  <div
                    key={`${song.id}-${i}`}
                    style={{
                      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                      padding: '10px 12px', borderRadius: '10px',
                      background: isCurrent ? 'rgba(250,36,60,0.12)' : 'transparent',
                      border: `0.5px solid ${isCurrent ? 'rgba(250,36,60,0.3)' : 'transparent'}`,
                      transition: 'background 0.15s',
                    }}
                    onMouseEnter={e => { if (!isCurrent) e.currentTarget.style.background = '#1A1A1A'; }}
                    onMouseLeave={e => { if (!isCurrent) e.currentTarget.style.background = 'transparent'; }}
                  >
                    {/* Left: Play button + Cover + Info */}
                    <div
                      onClick={() => {
                        handleSaveRecent(query);
                        isCurrent ? togglePlay() : playSong(song, results, i);
                      }}
                      style={{ display: 'flex', alignItems: 'center', gap: '14px', flex: 1, minWidth: 0, cursor: 'pointer' }}
                    >
                      <div style={{
                        position: 'relative', width: '48px', height: '48px',
                        borderRadius: '8px', overflow: 'hidden', flexShrink: 0, background: '#282828',
                      }}>
                        <img
                          src={song.coverArt}
                          alt={song.title}
                          style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                          onError={e => { e.target.src = 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600'; }}
                        />
                        <div style={{
                          position: 'absolute', inset: 0,
                          background: 'rgba(0,0,0,0.4)',
                          display: 'flex', alignItems: 'center', justifyContent: 'center',
                          opacity: isCurrent ? 1 : 0, transition: 'opacity 0.15s',
                        }}>
                          {isCurrent && isPlaying
                            ? <Pause size={18} style={{ fill: '#fff', color: '#fff' }} />
                            : <Play size={18} style={{ fill: '#fff', color: '#fff', marginLeft: '2px' }} />}
                        </div>
                      </div>

                      <div style={{ minWidth: 0, flex: 1 }}>
                        <p style={{
                          fontSize: '14px', fontWeight: 600,
                          color: isCurrent ? '#FA243C' : '#fff',
                          overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', marginBottom: '3px',
                        }}>
                          {song.title}
                        </p>
                        <p style={{
                          fontSize: '12px', color: '#A1A1A6',
                          overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
                        }}>
                          <span
                            onClick={(e) => {
                              e.stopPropagation();
                              handleOpenArtist(song.artist);
                            }}
                            style={{ cursor: 'pointer' }}
                            onMouseEnter={e => e.currentTarget.style.color = '#fff'}
                            onMouseLeave={e => e.currentTarget.style.color = '#A1A1A6'}
                          >
                            {song.artist}
                          </span>
                          {song.album && (
                            <>
                              {' • '}
                              <span
                                onClick={(e) => {
                                  e.stopPropagation();
                                  handleOpenAlbum({ id: song.albumId || song.id, name: song.album, artist: song.artist, coverArt: song.coverArt });
                                }}
                                style={{ cursor: 'pointer' }}
                                onMouseEnter={e => e.currentTarget.style.color = '#fff'}
                                onMouseLeave={e => e.currentTarget.style.color = '#A1A1A6'}
                              >
                                {song.album}
                              </span>
                            </>
                          )}
                        </p>
                      </div>
                    </div>

                    {/* Right: Actions */}
                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginLeft: '12px' }}>
                      <span style={{ fontSize: '12px', color: '#6B6B6B', minWidth: '36px', textAlign: 'right' }}>
                        {fmtDuration(song.duration)}
                      </span>

                      <button
                        onClick={() => isAuthenticated ? toggleFavorite(song) : openAuthModal()}
                        style={{
                          background: 'transparent', border: 'none', cursor: 'pointer',
                          color: isFav ? '#FA243C' : '#6B6B6B', padding: '6px', borderRadius: '6px',
                        }}
                        title={isFav ? 'Quitar de favoritos' : 'Guardar en favoritos'}
                        onMouseEnter={e => { if (!isFav) e.currentTarget.style.color = '#fff'; }}
                        onMouseLeave={e => { if (!isFav) e.currentTarget.style.color = '#6B6B6B'; }}
                      >
                        <Heart size={16} style={{ fill: isFav ? '#FA243C' : 'none' }} />
                      </button>

                      <button
                        onClick={() => addToQueue(song)}
                        style={{
                          background: 'transparent', border: 'none', cursor: 'pointer',
                          color: '#6B6B6B', padding: '6px', borderRadius: '6px',
                        }}
                        title="Agregar a la cola"
                        onMouseEnter={e => e.currentTarget.style.color = '#fff'}
                        onMouseLeave={e => e.currentTarget.style.color = '#6B6B6B'}
                      >
                        <ListPlus size={16} />
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      ) : (
        /* Default Explore View (when no search query) */
        <div>
          {/* Recent Searches */}
          {recentSearches.length > 0 && (
            <div style={{ marginBottom: '32px' }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '12px' }}>
                <h3 style={{ fontSize: '15px', fontWeight: 700, color: '#fff', display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <Clock size={16} style={{ color: '#A1A1A6' }} />
                  Búsquedas recientes
                </h3>
                <button
                  onClick={handleClearRecent}
                  style={{ fontSize: '12px', color: '#A1A1A6', background: 'transparent', border: 'none', cursor: 'pointer' }}
                  onMouseEnter={e => e.currentTarget.style.color = '#FA243C'}
                  onMouseLeave={e => e.currentTarget.style.color = '#A1A1A6'}
                >
                  Borrar historial
                </button>
              </div>

              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px' }}>
                {recentSearches.map((term, i) => (
                  <div
                    key={i}
                    onClick={() => handleSelectRecent(term)}
                    style={{
                      display: 'flex', alignItems: 'center', gap: '6px',
                      padding: '7px 14px', borderRadius: '20px',
                      background: '#1F1F1F', border: '1px solid #2D2D2D',
                      color: '#E5E5EA', fontSize: '13px', fontWeight: 500,
                      cursor: 'pointer', transition: 'all 0.15s',
                    }}
                    onMouseEnter={e => { e.currentTarget.style.background = '#282828'; e.currentTarget.style.borderColor = '#444'; }}
                    onMouseLeave={e => { e.currentTarget.style.background = '#1F1F1F'; e.currentTarget.style.borderColor = '#2D2D2D'; }}
                  >
                    <Search size={12} style={{ color: '#A1A1A6' }} />
                    <span>{term}</span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Genre & Mood Grid */}
          <div>
            <h3 style={{ fontSize: '18px', fontWeight: 700, color: '#fff', marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <TrendingUp size={18} style={{ color: '#FA243C' }} />
              Explorar todo
            </h3>

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(160px, 1fr))', gap: '14px' }}>
              {GENRES_LIST.map((g) => (
                <div
                  key={g.id}
                  onClick={() => setQuery(g.query)}
                  style={{
                    background: g.color,
                    borderRadius: '14px', padding: '18px 16px',
                    cursor: 'pointer', position: 'relative', overflow: 'hidden',
                    boxShadow: '0 8px 24px rgba(0,0,0,0.5)',
                    transition: 'all 0.2s cubic-bezier(0.4, 0, 0.2, 1)',
                    minHeight: '94px', display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
                  }}
                  onMouseEnter={e => {
                    e.currentTarget.style.transform = 'translateY(-4px) scale(1.02)';
                    e.currentTarget.style.boxShadow = '0 12px 28px rgba(0,0,0,0.7)';
                  }}
                  onMouseLeave={e => {
                    e.currentTarget.style.transform = 'translateY(0) scale(1)';
                    e.currentTarget.style.boxShadow = '0 8px 24px rgba(0,0,0,0.5)';
                  }}
                >
                  <span style={{ fontSize: '26px' }}>{g.icon}</span>
                  <span style={{ fontSize: '14px', fontWeight: 800, color: '#fff', textShadow: '0 2px 4px rgba(0,0,0,0.6)' }}>
                    {g.name}
                  </span>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
