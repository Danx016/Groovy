import React, { useEffect, useState } from 'react';

export function TrackLandingView({ onBack }) {
  const [mediaInfo, setMediaInfo] = useState({
    type: 'track',
    id: '',
    title: 'Canción',
    subtitle: 'Groovy',
    coverUrl: '/logo.png',
    badge: 'Groovy Music',
    actionText: 'Reproducir en Groovy',
    isRound: false
  });

  useEffect(() => {
    const p = window.location.pathname;
    const h = window.location.hash;
    const s = window.location.search;
    const params = new URLSearchParams(s || (h.includes('?') ? h.substring(h.indexOf('?')) : ''));

    let type = 'track';
    let id = '';

    if (p.includes('/album/') || h.includes('#album/')) {
      type = 'album';
      id = (p.includes('/album/') ? p.split('/album/')[1] : h.split('#album/')[1])?.split('/')[0]?.split('?')[0];
    } else if (p.includes('/artist/') || h.includes('#artist/')) {
      type = 'artist';
      id = (p.includes('/artist/') ? p.split('/artist/')[1] : h.split('#artist/')[1])?.split('/')[0]?.split('?')[0];
    } else if (p.includes('/track/') || p.includes('/song/')) {
      type = 'track';
      id = (p.includes('/track/') ? p.split('/track/')[1] : p.split('/song/')[1])?.split('/')[0]?.split('?')[0];
    } else if (h.includes('#track/') || h.includes('#song/')) {
      type = 'track';
      id = (h.includes('#track/') ? h.split('#track/')[1] : h.split('#song/')[1])?.split('/')[0]?.split('?')[0];
    }

    let title = 'Música';
    let subtitle = 'Groovy';
    let coverUrl = '/logo.png';
    let badge = 'Groovy';
    let actionText = 'Abrir en Groovy';
    let isRound = false;

    if (type === 'track') {
      title = params.get('title') || 'Canción';
      subtitle = params.get('artist') || 'Groovy';
      coverUrl = params.get('cover') || (id ? `https://i.ytimg.com/vi/${id}/hqdefault.jpg` : '/logo.png');
      badge = 'Groovy Music';
      actionText = 'Reproducir en Groovy';
    } else if (type === 'album') {
      title = params.get('title') || params.get('name') || 'Álbum';
      subtitle = params.get('artist') || 'Groovy';
      coverUrl = params.get('cover') || params.get('image') || '/logo.png';
      badge = 'Álbum';
      actionText = 'Abrir Álbum en Groovy';
    } else if (type === 'artist') {
      title = params.get('name') || params.get('title') || 'Artista';
      subtitle = 'Artista';
      coverUrl = params.get('image') || params.get('cover') || '/logo.png';
      badge = 'Artista';
      actionText = 'Ver Artista en Groovy';
      isRound = true;
    }

    setMediaInfo({
      type,
      id: id || '',
      title,
      subtitle,
      coverUrl,
      badge,
      actionText,
      isRound
    });

    if (id) {
      const isAndroid = /Android/i.test(navigator.userAgent);
      const deepLink = `groovy://${type}/${id}`;
      const androidIntent = `intent://${type}/${id}#Intent;scheme=groovy;package=com.groovy.music;S.browser_fallback_url=${encodeURIComponent(window.location.href)};end`;

      // Auto-launch app
      const timer = setTimeout(() => {
        if (isAndroid) {
          window.location.href = androidIntent;
        } else {
          window.location.href = deepLink;
        }
      }, 350);

      return () => clearTimeout(timer);
    }
  }, []);

  const { type, id, title, subtitle, coverUrl, badge, actionText, isRound } = mediaInfo;

  const handleOpenApp = () => {
    if (!id) return;
    const isAndroid = /Android/i.test(navigator.userAgent);
    const deepLink = `groovy://${type}/${id}`;
    const androidIntent = `intent://${type}/${id}#Intent;scheme=groovy;package=com.groovy.music;S.browser_fallback_url=${encodeURIComponent(window.location.href)};end`;

    if (isAndroid) {
      window.location.href = androidIntent;
    } else {
      window.location.href = deepLink;
    }
  };

  return (
    <div style={{
      minHeight: '100vh',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      backgroundColor: '#0a0a0a',
      color: '#fff',
      padding: '24px 16px',
      position: 'relative',
      overflow: 'hidden',
      fontFamily: '-apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Helvetica, Arial, sans-serif'
    }}>
      {/* Background ambient glow */}
      <div style={{
        position: 'fixed',
        top: '-40%',
        left: '-40%',
        width: '180%',
        height: '180%',
        backgroundImage: `url('${coverUrl}')`,
        backgroundSize: 'cover',
        backgroundPosition: 'center',
        filter: 'blur(90px) brightness(0.2)',
        pointerEvents: 'none',
        zIndex: 0
      }} />

      <div style={{
        position: 'relative',
        zIndex: 1,
        width: '100%',
        maxWidth: 380,
        background: 'rgba(24, 24, 27, 0.88)',
        border: '1px solid rgba(255, 255, 255, 0.1)',
        backdropFilter: 'blur(24px)',
        borderRadius: 24,
        padding: '32px 24px',
        textAlign: 'center',
        boxShadow: '0 20px 50px rgba(0, 0, 0, 0.65)'
      }}>
        <div style={{
          display: 'inline-flex',
          alignItems: 'center',
          gap: 6,
          background: 'rgba(29, 185, 84, 0.15)',
          color: '#1DB954',
          fontWeight: 700,
          fontSize: 11,
          letterSpacing: 1,
          textTransform: 'uppercase',
          padding: '6px 14px',
          borderRadius: 999,
          marginBottom: 20,
          border: '1px solid rgba(29, 185, 84, 0.3)'
        }}>
          {badge}
        </div>

        <div style={{
          width: 220,
          height: 220,
          margin: '0 auto 20px auto',
          borderRadius: isRound ? '50%' : 18,
          overflow: 'hidden',
          boxShadow: '0 12px 36px rgba(0,0,0,0.7), 0 0 24px rgba(29, 185, 84, 0.25)',
          backgroundColor: '#18181b'
        }}>
          <img
            src={coverUrl}
            alt={title}
            style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
            onError={(e) => { e.currentTarget.src = '/logo.png'; }}
          />
        </div>

        <h1 style={{
          fontSize: 21,
          fontWeight: 700,
          marginBottom: 6,
          color: '#fff',
          lineHeight: 1.3
        }}>{title}</h1>

        <div style={{
          fontSize: 15,
          color: '#a1a1aa',
          marginBottom: 24
        }}>{subtitle}</div>

        <button
          onClick={handleOpenApp}
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 10,
            width: '100%',
            background: '#1DB954',
            color: '#000',
            fontSize: 15,
            fontWeight: 800,
            letterSpacing: 0.5,
            textTransform: 'uppercase',
            padding: '16px 20px',
            borderRadius: 999,
            border: 'none',
            cursor: 'pointer',
            boxShadow: '0 8px 24px rgba(29, 185, 84, 0.4)'
          }}
        >
          {actionText}
        </button>

        <div style={{ marginTop: 18, fontSize: 12, color: '#71717a' }}>
          ¿No tienes la app instalada?
        </div>
        <a
          href="/#download"
          onClick={(e) => {
            if (onBack) {
              e.preventDefault();
              onBack();
            }
          }}
          style={{
            display: 'inline-block',
            marginTop: 8,
            fontSize: 13,
            color: '#1DB954',
            textDecoration: 'none'
          }}
        >
          Descargar Groovy gratis
        </a>
      </div>
    </div>
  );
}
