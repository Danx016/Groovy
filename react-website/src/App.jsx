import React, { useState } from 'react';
import { AuthProvider } from './context/AuthContext';
import { LibraryProvider } from './context/LibraryContext';
import { PlayerProvider } from './context/PlayerContext';
import { Header } from './components/layout/Header';
import { Sidebar } from './components/layout/Sidebar';
import { BottomNav } from './components/layout/BottomNav';
import { BottomMiniPlayer } from './components/player/BottomMiniPlayer';
import { FullPlayerModal } from './components/player/FullPlayerModal';
import { AuthModal } from './components/auth/AuthModal';
import { CreatePlaylistModal } from './components/ui/CreatePlaylistModal';
import { HomeView } from './components/views/HomeView';
import { LibraryView } from './components/views/LibraryView';
import { SearchView } from './components/views/SearchView';
import { RadioView } from './components/views/RadioView';
import { HistoryView } from './components/views/HistoryView';
import { PlaylistDetailView } from './components/views/PlaylistDetailView';
import { ArtistDetailView } from './components/views/ArtistDetailView';
import { AlbumDetailView } from './components/views/AlbumDetailView';
import { AccountView } from './components/views/AccountView';
import { SettingsView } from './components/views/SettingsView';
import { AdminPortal } from './components/admin/AdminPortal';
import { LandingDownloadPage } from './components/views/LandingDownloadPage';
import { usePlayer } from './context/PlayerContext';

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
  const [activeTab, setActiveTab] = useState('home');
  const [selectedPlaylist, setSelectedPlaylist] = useState(null);
  const [isCreatePlaylistOpen, setIsCreatePlaylistOpen] = useState(false);

  const {
    selectedArtist, setSelectedArtist,
    selectedAlbum, setSelectedAlbum,
  } = usePlayer();

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
    if (isDownloadRoute(h, p, s)) return 'download';
    return 'player';
  });

  React.useEffect(() => {
    const handleLocationChange = () => {
      const p = window.location.pathname;
      const h = window.location.hash;
      const s = window.location.search;
      if (p.startsWith('/admin') || h === '#admin' || s.includes('admin=true')) {
        setCurrentRoute('admin');
      } else if (isDownloadRoute(h, p, s)) {
        setCurrentRoute('download');
      } else {
        setCurrentRoute('player');
      }
    };

    window.addEventListener('popstate', handleLocationChange);
    window.addEventListener('hashchange', handleLocationChange);
    return () => {
      window.removeEventListener('popstate', handleLocationChange);
      window.removeEventListener('hashchange', handleLocationChange);
    };
  }, []);

  const switchTab = (tab) => {
    if (tab === 'admin') {
      window.location.hash = 'admin';
      setCurrentRoute('admin');
      return;
    }
    if (tab === 'download') {
      window.location.hash = 'download';
      setCurrentRoute('download');
      return;
    }
    setSelectedPlaylist(null);
    setSelectedArtist(null);
    setSelectedAlbum(null);
    setActiveTab(tab);
    if (currentRoute !== 'player') {
      window.location.hash = '';
      setCurrentRoute('player');
    }
  };

  // 1. If visiting Admin Portal:
  if (currentRoute === 'admin') {
    return (
      <AdminPortal
        onBackToPlayer={() => {
          window.location.hash = '';
          window.history.pushState({}, '', '/');
          setCurrentRoute('player');
          setActiveTab('home');
        }}
      />
    );
  }

  // 2. If visiting Landing & Download Page:
  if (currentRoute === 'download') {
    return (
      <LandingDownloadPage
        onOpenPlayer={() => {
          window.location.hash = '';
          window.history.pushState({}, '', '/');
          setCurrentRoute('player');
          setActiveTab('home');
        }}
        onOpenAdmin={() => {
          window.location.hash = 'admin';
          setCurrentRoute('admin');
        }}
      />
    );
  }

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: '#000', color: '#fff' }}>
      {/* Desktop Sidebar */}
      <Sidebar
        activeTab={activeTab}
        setActiveTab={switchTab}
        onOpenCreatePlaylist={() => setIsCreatePlaylistOpen(true)}
      />

      {/* Main content column */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0, overflow: 'hidden' }}>
        <Header activeTab={activeTab} setActiveTab={switchTab} />

        <main style={{ flex: 1, overflowY: 'auto', padding: '20px 20px 0' }}>
          {selectedArtist ? (
            <ArtistDetailView
              artistName={selectedArtist}
              onBack={() => setSelectedArtist(null)}
              onSelectAlbum={(alb) => {
                setSelectedAlbum(alb);
                setSelectedArtist(null);
              }}
            />
          ) : selectedAlbum ? (
            <AlbumDetailView
              album={selectedAlbum}
              onBack={() => setSelectedAlbum(null)}
              onSelectArtist={(art) => {
                setSelectedArtist(art);
                setSelectedAlbum(null);
              }}
            />
          ) : selectedPlaylist ? (
            <PlaylistDetailView playlist={selectedPlaylist} onBack={() => setSelectedPlaylist(null)} />
          ) : (
            <>
              {activeTab === 'home'    && <HomeView setActiveTab={switchTab} onSelectArtist={setSelectedArtist} onSelectAlbum={setSelectedAlbum} />}
              {activeTab === 'search'  && <SearchView onSelectArtist={setSelectedArtist} onSelectAlbum={setSelectedAlbum} />}
              {activeTab === 'library' && <LibraryView onSelectPlaylist={setSelectedPlaylist} onSelectArtist={setSelectedArtist} onSelectAlbum={setSelectedAlbum} onOpenCreatePlaylist={() => setIsCreatePlaylistOpen(true)} />}
              {activeTab === 'history' && <HistoryView onBack={() => switchTab('home')} onSelectArtist={setSelectedArtist} onSelectAlbum={setSelectedAlbum} />}
              {activeTab === 'radio'   && <RadioView />}
              {activeTab === 'account' && <AccountView setActiveTab={switchTab} />}
              {activeTab === 'settings' && <SettingsView />}
            </>
          )}
        </main>
      </div>

      {/* Mini Player (above bottom nav) */}
      <BottomMiniPlayer />

      {/* Mobile bottom navigation */}
      <BottomNav activeTab={activeTab} setActiveTab={switchTab} />

      {/* Fullscreen Player */}
      <FullPlayerModal />

      {/* Auth Modal */}
      <AuthModal />

      {/* Create Playlist Modal */}
      <CreatePlaylistModal isOpen={isCreatePlaylistOpen} onClose={() => setIsCreatePlaylistOpen(false)} />
    </div>
  );
}

export default function App() {
  return (
    <>
      <style>{layoutStyles}</style>
      <AuthProvider>
        <LibraryProvider>
          <PlayerProvider>
            <MainApp />
          </PlayerProvider>
        </LibraryProvider>
      </AuthProvider>
    </>
  );
}
