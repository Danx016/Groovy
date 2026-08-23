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
import { PlaylistDetailView } from './components/views/PlaylistDetailView';
import { AccountView } from './components/views/AccountView';
import { SettingsView } from './components/views/SettingsView';

/* Global layout + responsive styles */
const layoutStyles = `
  /* Desktop: show sidebar, hide mobile elements */
  @media (min-width: 768px) {
    .sidebar { display: flex !important; }
    .bottom-nav { display: none !important; }
    .mobile-brand { display: none !important; }
    .desktop-search { display: flex !important; }
    .desktop-ctrl { display: flex !important; }
    .mini-player-wrapper { left: 240px; bottom: 0; }
  }
  @media (max-width: 767px) {
    .desktop-search { display: none !important; }
  }

  /* Song card hover overlay */
  .song-play-overlay { opacity: 0 !important; }
  [style*="background: #181818"]:hover .song-play-overlay,
  [style*="background:#181818"]:hover .song-play-overlay { opacity: 1 !important; }

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

  const switchTab = (tab) => {
    setSelectedPlaylist(null);
    setActiveTab(tab);
  };

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
          {selectedPlaylist ? (
            <PlaylistDetailView playlist={selectedPlaylist} onBack={() => setSelectedPlaylist(null)} />
          ) : (
            <>
              {activeTab === 'home'    && <HomeView setActiveTab={switchTab} />}
              {activeTab === 'library' && <LibraryView onSelectPlaylist={setSelectedPlaylist} onOpenCreatePlaylist={() => setIsCreatePlaylistOpen(true)} />}
              {activeTab === 'search'  && <SearchView />}
              {activeTab === 'account' && <AccountView />}
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
