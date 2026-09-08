import React, { useState } from 'react';
import { Radio, Play, Pause, Volume2, Globe, Sparkles, Heart, Activity } from 'lucide-react';
import { usePlayer } from '../../context/PlayerContext';

const RADIO_STATIONS = [
  {
    id: 'rad_1',
    name: 'Los 40 Principales',
    tagline: 'Todos los éxitos del momento en español e inglés',
    country: 'España / Internacional',
    genre: 'Pop / Top 40',
    frequency: '93.9 FM',
    coverArt: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&auto=format&fit=crop&q=80',
    audioUrl: 'https://stream.zeno.fm/f3wvbbqmdg8uv',
    gradient: 'linear-gradient(135deg, #FF416C 0%, #FF4B2B 100%)',
  },
  {
    id: 'rad_2',
    name: 'La Mega 97.9 FM',
    tagline: 'El poder del Reggaetón, Salsa y Urbano Latino',
    country: 'Latinoamérica / USA',
    genre: 'Urbano & Reggaetón',
    frequency: '97.9 FM',
    coverArt: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&auto=format&fit=crop&q=80',
    audioUrl: 'https://stream.zeno.fm/fvrx45277k8uv',
    gradient: 'linear-gradient(135deg, #8A2387 0%, #E94057 50%, #F27121 100%)',
  },
  {
    id: 'rad_3',
    name: 'Ibiza Global Radio',
    tagline: 'La mejor música electrónica y deep house directo desde Ibiza',
    country: 'España',
    genre: 'House / Deep Electronic',
    frequency: '100.8 FM',
    coverArt: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=800&auto=format&fit=crop&q=80',
    audioUrl: 'https://stream.zeno.fm/swd66k3b7k8uv',
    gradient: 'linear-gradient(135deg, #4E65FF 0%, #92EFFD 100%)',
  },
  {
    id: 'rad_4',
    name: 'Rock FM Clásicos',
    tagline: '500 clásicos del rock sin interrupciones',
    country: 'Internacional',
    genre: 'Classic Rock',
    frequency: '101.7 FM',
    coverArt: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=800&auto=format&fit=crop&q=80',
    audioUrl: 'https://stream.zeno.fm/f3wvbbqmdg8uv',
    gradient: 'linear-gradient(135deg, #232526 0%, #414345 100%)',
  },
  {
    id: 'rad_5',
    name: 'Chill & Lo-Fi Beats Radio',
    tagline: 'Música instrumental relajante para estudiar y concentrarte',
    country: 'Global',
    genre: 'Lo-Fi / Ambient',
    frequency: '24/7 Stream',
    coverArt: 'https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?w=800&auto=format&fit=crop&q=80',
    audioUrl: 'https://cdn.freesound.org/previews/530/530415_11861866-lq.mp3',
    gradient: 'linear-gradient(135deg, #654ea3 0%, #eaafc8 100%)',
  },
  {
    id: 'rad_6',
    name: 'Radio Disney Hits',
    tagline: 'Tus canciones favoritas de hoy y de siempre',
    country: 'Latinoamérica',
    genre: 'Pop / Teen',
    frequency: '94.3 FM',
    coverArt: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=800&auto=format&fit=crop&q=80',
    audioUrl: 'https://stream.zeno.fm/fvrx45277k8uv',
    gradient: 'linear-gradient(135deg, #f857a6 0%, #ff5858 100%)',
  },
];

export const RadioView = () => {
  const { currentSong, isPlaying, playSong, togglePlay } = usePlayer();
  const [activeFilter, setActiveFilter] = useState('all');

  const handlePlayStation = (station) => {
    const isCurrent = currentSong?.id === station.id;
    if (isCurrent) {
      togglePlay();
    } else {
      playSong({
        id: station.id,
        title: station.name,
        artist: `${station.frequency} • ${station.genre}`,
        album: 'Radio en Vivo',
        coverArt: station.coverArt,
        duration: 0,
        audioUrl: station.audioUrl,
        isRadio: true,
      }, [station]);
    }
  };

  const featured = RADIO_STATIONS[0];
  const isFeaturedPlaying = currentSong?.id === featured.id && isPlaying;

  return (
    <div style={{ paddingBottom: '140px' }}>
      {/* Header */}
      <div style={{ marginBottom: '22px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 800, letterSpacing: '-0.6px', color: '#fff', marginBottom: '4px' }}>
          Radio en Vivo
        </h1>
        <p style={{ fontSize: '13px', color: '#A1A1A6' }}>
          Emisoras internacionales y transmisiones en directo en alta calidad
        </p>
      </div>

      {/* Featured Station Banner */}
      <div
        onClick={() => handlePlayStation(featured)}
        style={{
          background: featured.gradient,
          borderRadius: '16px', padding: '24px 28px',
          marginBottom: '32px', cursor: 'pointer',
          position: 'relative', overflow: 'hidden',
          boxShadow: '0 12px 32px rgba(255,65,108,0.3)',
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          transition: 'transform 0.2s',
        }}
        onMouseEnter={e => e.currentTarget.style.transform = 'scale(1.01)'}
        onMouseLeave={e => e.currentTarget.style.transform = 'scale(1)'}
      >
        <div style={{ zIndex: 2, maxWidth: '60%' }}>
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: '6px',
            background: 'rgba(0,0,0,0.35)', backdropFilter: 'blur(10px)',
            padding: '4px 10px', borderRadius: '20px', marginBottom: '10px',
          }}>
            <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#34C759', animation: 'pulse 1.5s infinite' }} />
            <span style={{ fontSize: '11px', fontWeight: 800, color: '#fff', letterSpacing: '0.04em' }}>EN VIVO AHORA</span>
          </div>

          <h2 style={{ fontSize: '28px', fontWeight: 900, color: '#fff', letterSpacing: '-0.5px', marginBottom: '6px' }}>
            {featured.name}
          </h2>
          <p style={{ fontSize: '14px', color: 'rgba(255,255,255,0.85)', marginBottom: '4px' }}>
            {featured.tagline}
          </p>
          <p style={{ fontSize: '12px', color: 'rgba(255,255,255,0.7)', fontWeight: 600 }}>
            {featured.frequency} • {featured.country}
          </p>
        </div>

        <div style={{ zIndex: 2, display: 'flex', alignItems: 'center', gap: '16px' }}>
          <div style={{
            width: '64px', height: '64px', borderRadius: '50%',
            background: '#fff', color: '#000',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 8px 24px rgba(0,0,0,0.4)',
          }}>
            {isFeaturedPlaying
              ? <Pause size={28} style={{ fill: '#000' }} />
              : <Play size={28} style={{ fill: '#000', marginLeft: '3px' }} />}
          </div>
        </div>
      </div>

      {/* Grid of Stations */}
      <h3 style={{ fontSize: '20px', fontWeight: 800, color: '#fff', marginBottom: '16px' }}>
        Todas las Emisoras
      </h3>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: '16px' }}>
        {RADIO_STATIONS.map((st) => {
          const isCurrent = currentSong?.id === st.id;
          const isStPlaying = isCurrent && isPlaying;

          return (
            <div
              key={st.id}
              onClick={() => handlePlayStation(st)}
              style={{
                display: 'flex', alignItems: 'center', gap: '16px',
                background: isCurrent ? 'rgba(250,36,60,0.14)' : '#181818',
                borderRadius: '14px', padding: '14px 16px',
                border: `0.5px solid ${isCurrent ? 'rgba(250,36,60,0.4)' : '#282828'}`,
                cursor: 'pointer', transition: 'all 0.2s',
                boxShadow: '0 4px 16px rgba(0,0,0,0.3)',
              }}
              onMouseEnter={e => {
                if (!isCurrent) {
                  e.currentTarget.style.background = '#222';
                  e.currentTarget.style.transform = 'translateY(-2px)';
                }
              }}
              onMouseLeave={e => {
                if (!isCurrent) {
                  e.currentTarget.style.background = '#181818';
                  e.currentTarget.style.transform = 'translateY(0)';
                }
              }}
            >
              {/* Artwork / Radio Icon */}
              <div style={{
                position: 'relative', width: '56px', height: '56px',
                borderRadius: '10px', overflow: 'hidden', flexShrink: 0,
                background: '#282828',
              }}>
                <img
                  src={st.coverArt}
                  alt={st.name}
                  style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                />
                <div style={{
                  position: 'absolute', inset: 0,
                  background: 'rgba(0,0,0,0.4)',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  opacity: isCurrent ? 1 : 0, transition: 'opacity 0.2s',
                }}>
                  {isStPlaying
                    ? <Pause size={20} style={{ fill: '#fff', color: '#fff' }} />
                    : <Play size={20} style={{ fill: '#fff', color: '#fff', marginLeft: '2px' }} />}
                </div>
              </div>

              {/* Text */}
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '2px' }}>
                  <p style={{
                    fontSize: '15px', fontWeight: 700,
                    color: isCurrent ? '#FA243C' : '#fff',
                    overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
                  }}>
                    {st.name}
                  </p>
                </div>
                <p style={{ fontSize: '12px', color: '#A1A1A6', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {st.genre}
                </p>
                <p style={{ fontSize: '11px', color: '#6B6B6B', marginTop: '2px' }}>
                  {st.frequency} • {st.country}
                </p>
              </div>

              {/* Status Badge */}
              <div style={{
                padding: '4px 8px', borderRadius: '6px',
                background: isStPlaying ? 'rgba(52,199,89,0.15)' : '#222',
                color: isStPlaying ? '#34C759' : '#6B6B6B',
                fontSize: '10px', fontWeight: 800, letterSpacing: '0.04em',
              }}>
                {isStPlaying ? 'EN VIVO' : 'STREAM'}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};
