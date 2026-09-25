import React, { useState, useEffect } from 'react';
import { AuthProvider } from './context/AuthContext';
import { AdminPortal } from './components/admin/AdminPortal';
import { LandingDownloadPage } from './components/views/LandingDownloadPage';
import { PublicSite } from './components/views/PublicSite';

import { DownloaderView } from './components/views/DownloaderView';

/* Global layout + responsive styles */
const layoutStyles = `
  /* Desktop: show sidebar, hide mobile elements */
  @media (min-width: 768px) {
    .sidebar { display: flex !important; }
    .bottom-nav { display: none !important; }
    .mobile-brand { display: none !important; }
    .desktop-search { display: flex !important; }
    .desktop-ctrl { display: flex !important; }
  }
  @media (max-width: 767px) {
    .desktop-search { display: none !important; }
    .desktop-nav { display: none !important; }
    .hide-mobile { display: none !important; }
    .desktop-player-bar { bottom: 64px !important; height: 68px !important; padding: 0 12px !important; }
  }

  /* Song card hover overlay */
  .song-play-overlay { opacity: 0 !important; }
  div:hover > .song-play-overlay,
  div:hover .song-play-overlay { opacity: 1 !important; }

  /* Input placeholder */
  input::placeholder { color: #6B6B6B; }
  input:focus { outline: none; }

  /* Sidebar scrollbar */
  .sidebar { scrollbar-width: thin; scrollbar-color: #282828 transparent; }

  /* Hide horizontal scrollbars in strips */
  div[style*="overflow-x: auto"]::-webkit-scrollbar { display: none; }
`;

function MainApp() {
  const isDownloaderRoute = (h, p, s) => {
    const host = window.location.hostname.toLowerCase();
    if (host.includes('groovydescarga') || host.includes('descarga')) return true;
    if (p.startsWith('/downloader') || p.startsWith('/convert') || p.startsWith('/descargar-musica') || s.includes('downloader=true')) return true;
    const downloaderHashes = ['#downloader', '#convertir', '#descargar-musica', '#musica', '#mp3', '#mp4'];
    return downloaderHashes.some(dh => h.toLowerCase().startsWith(dh));
  };

  const isDownloadRoute = (h, p, s) => {
    if (p.startsWith('/download') || s.includes('download=true')) return true;
    const downloadHashes = ['#download', '#descargas', '#interfaz', '#funciones', '#preguntas', '#faq', '#caracteristicas', '#capturas'];
    return downloadHashes.some(dh => h.toLowerCase().startsWith(dh));
  };

  const [currentRoute, setCurrentRoute] = useState(() => {
    const p = window.location.pathname;
    const h = window.location.hash;
    const s = window.location.search;
    if (p.startsWith('/admin') || h === '#admin' || s.includes('admin=true')) return 'admin';
    if (isDownloaderRoute(h, p, s)) return 'downloader';
    if (isDownloadRoute(h, p, s)) return 'download';
    return 'public';
  });

  useEffect(() => {
    const handleLocationChange = () => {
      const p = window.location.pathname;
      const h = window.location.hash;
      const s = window.location.search;
      if (p.startsWith('/admin') || h === '#admin' || s.includes('admin=true')) {
        setCurrentRoute('admin');
      } else if (isDownloaderRoute(h, p, s)) {
        setCurrentRoute('downloader');
      } else if (isDownloadRoute(h, p, s)) {
        setCurrentRoute('download');
      } else {
        setCurrentRoute('public');
      }
    };

    window.addEventListener('popstate', handleLocationChange);
    window.addEventListener('hashchange', handleLocationChange);
    return () => {
      window.removeEventListener('popstate', handleLocationChange);
      window.removeEventListener('hashchange', handleLocationChange);
    };
  }, []);

  // 1. If visiting Admin Portal:
  if (currentRoute === 'admin') {
    return (
      <AdminPortal
        onBackToPlayer={() => {
          window.location.hash = '';
          window.history.pushState({}, '', '/');
          setCurrentRoute('public');
        }}
      />
    );
  }

  // 2. If visiting Media Downloader (MP3 & MP4 in multiple qualities):
  if (currentRoute === 'downloader') {
    return (
      <DownloaderView
        onBack={() => {
          window.location.hash = '';
          window.history.pushState({}, '', '/');
          setCurrentRoute('public');
        }}
      />
    );
  }

  // 3. If visiting Landing & App Download Page:
  if (currentRoute === 'download') {
    return (
      <LandingDownloadPage
        onOpenPlayer={() => {
          window.location.hash = '';
          window.history.pushState({}, '', '/');
          setCurrentRoute('public');
        }}
        onOpenDownloader={() => {
          window.location.hash = 'downloader';
          setCurrentRoute('downloader');
        }}
        onOpenAdmin={() => {
          window.location.hash = 'admin';
          setCurrentRoute('admin');
        }}
      />
    );
  }

  return (
    <PublicSite
      onOpenDownloads={() => {
        window.location.hash = 'download';
        setCurrentRoute('download');
      }}
      onOpenDownloader={() => {
        window.location.hash = 'downloader';
        setCurrentRoute('downloader');
      }}
      onOpenAdmin={() => {
        window.location.hash = 'admin';
        setCurrentRoute('admin');
      }}
    />
  );
}

export default function App() {
  return (
    <>
      <style>{layoutStyles}</style>
      <AuthProvider>
        <MainApp />
      </AuthProvider>
    </>
  );
}
