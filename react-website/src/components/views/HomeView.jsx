import React, { useState, useEffect } from 'react';
import { Play, Pause, ChevronRight, MoreVertical, Sparkles, Flame, Zap, Stars, Disc3, CheckCircle2, User } from 'lucide-react';
import { usePlayer } from '../../context/PlayerContext';
import { useLibrary } from '../../context/LibraryContext';
import { musicService, GENRES_LIST } from '../../services/musicService';

const DEFAULT_TOP_ARTISTS = [
  { id: 10583405, name: 'Bad Bunny', image: 'https://cdn-images.dzcdn.net/images/artist/044a3f315b041864887a8dd8709e6926/1000x1000-000000-80-0-0.jpg', genre: 'Urbano Latino' },
  { id: 4050205, name: 'The Weeknd', image: 'https://cdn-images.dzcdn.net/images/artist/581693b4724a7fcfa754455101e13a44/1000x1000-000000-80-0-0.jpg', genre: 'R&B / Pop' },
  { id: 1166311, name: 'Feid', image: 'https://cdn-images.dzcdn.net/images/artist/e629c93e03b3c225d8d52a42bae71537/1000x1000-000000-80-0-0.jpg', genre: 'Reggaetón' },
  { id: 1429862, name: 'Karol G', image: 'https://cdn-images.dzcdn.net/images/artist/a1f81d11ff92b23ae1b1a7d6eec7716f/1000x1000-000000-80-0-0.jpg', genre: 'Urbano' },
  { id: 12246, name: 'Taylor Swift', image: 'https://cdn-images.dzcdn.net/images/artist/33e0a16b94dd6d19488e09f5926c4832/1000x1000-000000-80-0-0.jpg', genre: 'Pop' },
  { id: 892, name: 'Coldplay', image: 'https://cdn-images.dzcdn.net/images/artist/4ab1be22b51ecb6ec1f1f50f757279f6/1000x1000-000000-80-0-0.jpg', genre: 'Rock Alternativo' },
  { id: 130835, name: 'Drake', image: 'https://cdn-images.dzcdn.net/images/artist/5d2fa5169a8c79c882103f56d9539352/1000x1000-000000-80-0-0.jpg', genre: 'Hip-Hop' },
  { id: 8645063, name: 'Dua Lipa', image: 'https://cdn-images.dzcdn.net/images/artist/f104d44439c2889e47fdb6e05391c4d9/1000x1000-000000-80-0-0.jpg', genre: 'Dance Pop' },
  { id: 9892994, name: 'Billie Eilish', image: 'https://cdn-images.dzcdn.net/images/artist/e795a947ce733a46d0a79ec0bc401b2f/1000x1000-000000-80-0-0.jpg', genre: 'Alt Pop' },
  { id: 122177302, name: 'Peso Pluma', image: 'https://cdn-images.dzcdn.net/images/artist/495fe20a9a1d48c89429188e404bc03d/1000x1000-000000-80-0-0.jpg', genre: 'Regional Urbano' }
];

const TOP_ALBUMS = [
  { id: 'nadie_sabe', name: 'Nadie Sabe Lo Que Va a Pasar Mañana', artist: 'Bad Bunny', year: '2023', coverArt: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/bf/6d/46/bf6d4605-728b-6f8e-49b8-3e4b370165b4/197189196383.jpg/800x800bb.jpg' },
  { id: 'after_hours', name: 'After Hours', artist: 'The Weeknd', year: '2020', coverArt: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/4b/97/81/4b97813e-d90c-0335-ee17-c03531b7ca1e/20UMGIM08611.rgb.jpg/800x800bb.jpg' },
  { id: 'mor_no_te_olvides', name: 'MOR, No Le Temas a la Oscuridad', artist: 'Feid', year: '2023', coverArt: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/10/58/e7/1058e7ce-3f74-323e-6a56-ee0fc7e97f06/23UM1IM05230.rgb.jpg/800x800bb.jpg' },
  { id: 'manana_sera_bonito', name: 'MAÑANA SERÁ BONITO', artist: 'Karol G', year: '2023', coverArt: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/cf/e9/87/cfe98762-df08-25f0-5aa5-dbfc7a3ae051/23UMGIM13994.rgb.jpg/800x800bb.jpg' },
  { id: 'un_verano_sin_ti', name: 'Un Verano Sin Ti', artist: 'Bad Bunny', year: '2022', coverArt: 'https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/39/38/c1/3938c105-0210-916c-e547-0e6d628eb586/196626945068.jpg/800x800bb.jpg' },
  { id: 'future_nostalgia', name: 'Future Nostalgia', artist: 'Dua Lipa', year: '2020', coverArt: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/2b/97/65/2b97654a-5f04-890e-b7d1-9252c42d6229/190295286109.jpg/800x800bb.jpg' }
];

/* Song card matching Windows App screenshot */
const SongCard = ({ song, allSongs = [], index = 0 }) => {
  const { currentSong, isPlaying, playSong, togglePlay, openArtist, openAlbum } = usePlayer();
  const isCurrent = currentSong?.id === song.id;

  return (
    <div
      onClick={() => isCurrent ? togglePlay() : playSong(song, allSongs, index)}
      style={{
        flexShrink: 0,
        width: '185px',
        cursor: 'pointer',
        display: 'flex',
        flexDirection: 'column',
        userSelect: 'none',
        transition: 'transform 0.15s ease',
      }}
      onMouseEnter={e => e.currentTarget.style.transform = 'translateY(-3px)'}
      onMouseLeave={e => e.currentTarget.style.transform = 'translateY(0)'}
    >
      {/* Square Artwork */}
      <div style={{
        position: 'relative',
        width: '100%',
        aspectRatio: '1/1',
        borderRadius: '10px',
        overflow: 'hidden',
        background: '#1a1b1e',
        marginBottom: '10px',
        boxShadow: '0 8px 20px rgba(0,0,0,0.5)',
        border: isCurrent ? '1.5px solid #FA243C' : '1px solid rgba(255,255,255,0.06)',
      }}>
        <img
          src={song.coverArt || ''}
          alt={song.title}
          style={{ width: '100%', height: '100%', objectFit: 'cover' }}
          loading="lazy"
          onError={e => { e.target.src = 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600'; }}
        />

        {/* Hover / Active Play Button Overlay */}
        <div
          className="song-play-overlay"
          style={{
            position: 'absolute',
            inset: 0,
            background: 'rgba(0,0,0,0.4)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            opacity: isCurrent ? 1 : 0,
            transition: 'opacity 0.2s',
          }}
        >
          <div style={{
            width: '44px', height: '44px', borderRadius: '50%',
            background: '#fff', display: 'flex', alignItems: 'center',
            justifyContent: 'center', boxShadow: '0 4px 14px rgba(0,0,0,0.6)',
          }}>
            {isCurrent && isPlaying ? (
              <Pause size={20} style={{ fill: '#000', color: '#000' }} />
            ) : (
              <Play size={20} style={{ fill: '#000', color: '#000', marginLeft: '3px' }} />
            )}
          </div>
        </div>
      </div>

      {/* Song Title */}
      <h3 style={{
        fontSize: '14px',
        fontWeight: 700,
        color: isCurrent ? '#FA243C' : '#fff',
        letterSpacing: '-0.2px',
        margin: '0 0 3px 0',
        overflow: 'hidden',
        textOverflow: 'ellipsis',
        whiteSpace: 'nowrap',
      }}>
        {song.title}
      </h3>

      {/* Artist Name & Album */}
      <p style={{
        fontSize: '12.5px',
        color: '#8E8E93',
        margin: 0,
        overflow: 'hidden',
        textOverflow: 'ellipsis',
        whiteSpace: 'nowrap',
      }}>
        <span
          onClick={(e) => {
            e.stopPropagation();
            if (openArtist && song.artist) openArtist(song.artist);
          }}
          style={{ cursor: 'pointer' }}
          onMouseEnter={e => e.currentTarget.style.color = '#fff'}
          onMouseLeave={e => e.currentTarget.style.color = '#8E8E93'}
        >
          {song.artist}
        </span>
        {song.album && (
          <>
            {' • '}
            <span
              onClick={(e) => {
                e.stopPropagation();
                if (openAlbum) openAlbum({ id: song.albumId || song.id, name: song.album, artist: song.artist, coverArt: song.coverArt });
              }}
              style={{ cursor: 'pointer' }}
              onMouseEnter={e => e.currentTarget.style.color = '#fff'}
              onMouseLeave={e => e.currentTarget.style.color = '#8E8E93'}
            >
              {song.album}
            </span>
          </>
        )}
      </p>
    </div>
  );
};

/* Artist Avatar Card */
const ArtistCard = ({ artist, onClick }) => (
  <div
    onClick={onClick}
    style={{
      flexShrink: 0,
      width: '140px',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      cursor: 'pointer',
      textAlign: 'center',
      userSelect: 'none',
      transition: 'transform 0.15s ease',
    }}
    onMouseEnter={e => e.currentTarget.style.transform = 'translateY(-4px)'}
    onMouseLeave={e => e.currentTarget.style.transform = 'translateY(0)'}
  >
    <div style={{
      position: 'relative',
      width: '120px',
      height: '120px',
      borderRadius: '50%',
      overflow: 'hidden',
      marginBottom: '10px',
      boxShadow: '0 8px 24px rgba(0,0,0,0.6)',
      border: '2px solid rgba(255,255,255,0.08)',
    }}>
      <img
        src={artist.image}
        alt={artist.name}
        style={{ width: '100%', height: '100%', objectFit: 'cover' }}
        loading="lazy"
        onError={e => { e.target.src = 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500'; }}
      />
    </div>
    <div style={{ display: 'flex', alignItems: 'center', gap: '4px', maxWidth: '100%' }}>
      <p style={{
        fontSize: '14px', fontWeight: 700, color: '#fff', margin: 0,
        overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
      }}>
        {artist.name}
      </p>
      <CheckCircle2 size={13} style={{ color: '#FA243C', fill: 'rgba(250,36,60,0.2)', flexShrink: 0 }} />
    </div>
    <p style={{ fontSize: '11.5px', color: '#8E8E93', margin: '2px 0 0 0' }}>{artist.genre || 'Artista'}</p>
  </div>
);

/* Album Card */
const AlbumCard = ({ album, onClick }) => (
  <div
    onClick={onClick}
    style={{
      flexShrink: 0,
      width: '165px',
      display: 'flex',
      flexDirection: 'column',
      cursor: 'pointer',
      userSelect: 'none',
      transition: 'transform 0.15s ease',
    }}
    onMouseEnter={e => e.currentTarget.style.transform = 'translateY(-3px)'}
    onMouseLeave={e => e.currentTarget.style.transform = 'translateY(0)'}
  >
    <div style={{
      position: 'relative',
      width: '100%',
      aspectRatio: '1/1',
      borderRadius: '10px',
      overflow: 'hidden',
      marginBottom: '8px',
      boxShadow: '0 8px 20px rgba(0,0,0,0.5)',
      border: '1px solid rgba(255,255,255,0.06)',
    }}>
      <img
        src={album.coverArt}
        alt={album.name}
        style={{ width: '100%', height: '100%', objectFit: 'cover' }}
        loading="lazy"
      />
    </div>
    <h4 style={{
      fontSize: '13.5px', fontWeight: 700, color: '#fff', margin: '0 0 2px',
      overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
    }}>
      {album.name}
    </h4>
    <p style={{
      fontSize: '12px', color: '#8E8E93', margin: 0,
      overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
    }}>
      {album.artist} • {album.year}
    </p>
  </div>
);

/* Section with title and horizontal scroll */
const SectionRow = ({ title, songs = [], onSeeAll }) => {
  if (!songs || songs.length === 0) return null;

  return (
    <div style={{ marginBottom: '36px' }}>
      {/* Section Header */}
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        marginBottom: '16px',
      }}>
        <h2 style={{ fontSize: '20px', fontWeight: 800, letterSpacing: '-0.4px', color: '#fff' }}>
          {title}
        </h2>
        {onSeeAll && (
          <button
            onClick={onSeeAll}
            style={{
              background: 'transparent', border: 'none', color: '#888',
              cursor: 'pointer', display: 'flex', alignItems: 'center',
              padding: '4px', transition: 'color 0.15s',
            }}
            onMouseEnter={e => e.currentTarget.style.color = '#fff'}
            onMouseLeave={e => e.currentTarget.style.color = '#888'}
          >
            <ChevronRight size={20} />
          </button>
        )}
      </div>

      {/* Cards Strip */}
      <div style={{
        display: 'flex', gap: '16px', overflowX: 'auto',
        paddingBottom: '8px', scrollbarWidth: 'none',
      }}>
        {songs.map((song, idx) => (
          <SongCard key={`${song.id}-${idx}`} song={song} allSongs={songs} index={idx} />
        ))}
      </div>
    </div>
  );
};

export const HomeView = ({ setActiveTab, onSelectArtist, onSelectAlbum }) => {
  const { history = [] } = useLibrary();
  const { openArtist, openAlbum } = usePlayer();
  const [feeds, setFeeds] = useState(null);
  const [featuredArtists, setFeaturedArtists] = useState(DEFAULT_TOP_ARTISTS);

  const handleOpenArtist = (name) => {
    if (onSelectArtist) onSelectArtist(name);
    else if (openArtist) openArtist(name);
  };

  const handleOpenAlbum = (albumObj) => {
    if (onSelectAlbum) onSelectAlbum(albumObj);
    else if (openAlbum) openAlbum(albumObj);
  };

  useEffect(() => {
    let isMounted = true;
    const loadFeeds = async () => {
      try {
        const [feedData, artistsData] = await Promise.allSettled([
          musicService.getHomeFeeds(),
          musicService.getTopArtists(),
        ]);
        if (isMounted) {
          if (feedData.status === 'fulfilled' && feedData.value) setFeeds(feedData.value);
          if (artistsData.status === 'fulfilled' && artistsData.value?.length > 0) {
            setFeaturedArtists(artistsData.value);
          }
        }
      } catch (err) {
        console.warn('Feeds load failed:', err);
      } finally {
      }
    };
    loadFeeds();
    return () => { isMounted = false; };
  }, []);

  const recentSongs = (history && history.length > 0)
    ? history.slice(0, 10)
    : feeds?.trending?.slice(0, 8) || [];

  const recommendedMixes = feeds?.trending ? feeds.trending.slice(2, 12) : [];

  return (
    <div style={{ padding: '8px 24px 140px', minHeight: '100%' }}>
      {/* 1. Main View Header */}
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        marginBottom: '28px', paddingTop: '8px',
      }}>
        <h1 style={{
          fontSize: '32px', fontWeight: 900, letterSpacing: '-0.8px',
          color: '#fff', margin: 0,
        }}>
          Inicio
        </h1>

        {/* 3-dots Menu in red (Apple Music red) */}
        <button
          onClick={() => setActiveTab('settings')}
          style={{
            background: 'transparent', border: 'none', cursor: 'pointer',
            color: '#FA243C', padding: '6px', borderRadius: '50%',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}
          title="Opciones"
        >
          <MoreVertical size={24} />
        </button>
      </div>

      {/* 2. Artistas Destacados (Windows / Mobile circular avatars) */}
      <div style={{ marginBottom: '36px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px' }}>
          <h2 style={{ fontSize: '20px', fontWeight: 800, letterSpacing: '-0.4px', color: '#fff', display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Sparkles size={20} style={{ color: '#FA243C' }} /> Artistas Destacados
          </h2>
        </div>
        <div style={{
          display: 'flex', gap: '18px', overflowX: 'auto',
          paddingBottom: '8px', scrollbarWidth: 'none',
        }}>
          {featuredArtists.map((artist, idx) => (
            <ArtistCard
              key={artist.id || idx}
              artist={artist}
              onClick={() => handleOpenArtist(artist.name)}
            />
          ))}
        </div>
      </div>

      {/* 3. Section: Reproducciones recientes */}
      <SectionRow
        title="Reproducciones recientes"
        songs={recentSongs}
        onSeeAll={() => setActiveTab('history')}
      />

      {/* 4. Álbumes Populares */}
      <div style={{ marginBottom: '36px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px' }}>
          <h2 style={{ fontSize: '20px', fontWeight: 800, letterSpacing: '-0.4px', color: '#fff', display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Disc3 size={20} style={{ color: '#FA243C' }} /> Álbumes Populares
          </h2>
        </div>
        <div style={{
          display: 'flex', gap: '16px', overflowX: 'auto',
          paddingBottom: '8px', scrollbarWidth: 'none',
        }}>
          {TOP_ALBUMS.map((alb, idx) => (
            <AlbumCard
              key={idx}
              album={alb}
              onClick={() => handleOpenAlbum(alb)}
            />
          ))}
        </div>
      </div>

      {/* 5. Section: Mixes recomendados para ti */}
      <SectionRow
        title="Mixes recomendados para ti"
        songs={recommendedMixes}
        onSeeAll={() => setActiveTab('search')}
      />

      {/* 6. Section: Tendencias Globales */}
      {feeds?.trending && feeds.trending.length > 0 && (
        <SectionRow
          title="Tendencias del Momento"
          songs={feeds.trending}
          onSeeAll={() => setActiveTab('search')}
        />
      )}

      {/* 7. Section: Urbano & Reggaetón */}
      {feeds?.urbano && feeds.urbano.length > 0 && (
        <SectionRow
          title="Urbano Latino & Reggaetón"
          songs={feeds.urbano}
          onSeeAll={() => setActiveTab('search')}
        />
      )}

      {/* 8. Section: Pop Internacional */}
      {feeds?.pop && feeds.pop.length > 0 && (
        <SectionRow
          title="Pop Internacional"
          songs={feeds.pop}
          onSeeAll={() => setActiveTab('search')}
        />
      )}

      {/* 9. Section: Rock Clásico */}
      {feeds?.rock && feeds.rock.length > 0 && (
        <SectionRow
          title="Rock Clásico & Alternativo"
          songs={feeds.rock}
          onSeeAll={() => setActiveTab('search')}
        />
      )}
    </div>
  );
};
