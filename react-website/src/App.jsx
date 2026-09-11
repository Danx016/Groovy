import React, { useEffect, useState } from 'react';
import { AuthProvider } from './context/AuthContext';
import { AdminPortal } from './components/admin/AdminPortal';
import { LandingDownloadPage } from './components/views/LandingDownloadPage';
import { PublicSite } from './components/views/PublicSite';

function AppRouter() {
  const [route, setRoute] = useState(() => window.location.hash.toLowerCase());

  useEffect(() => {
    const onChange = () => setRoute(window.location.hash.toLowerCase());
    window.addEventListener('hashchange', onChange);
    return () => window.removeEventListener('hashchange', onChange);
  }, []);

  const openRoute = (hash) => {
    window.location.hash = hash;
    setRoute(hash);
  };

  if (route === '#download' || route === '#descargas' || route.startsWith('#interfaz') || route.startsWith('#funciones') || route.startsWith('#faq') || route.startsWith('#caracteristicas-download') || route.startsWith('#capturas')) {
    return <LandingDownloadPage onOpenPlayer={() => openRoute('#inicio')} />;
  }
  if (route === '#admin') {
    return <AdminPortal onBackToPlayer={() => openRoute('#inicio')} />;
  }
  return <PublicSite onOpenDownloads={() => openRoute('#download')} onOpenAdmin={() => openRoute('#admin')} />;
}

export default function App() {
  return <AuthProvider><AppRouter /></AuthProvider>;
}
