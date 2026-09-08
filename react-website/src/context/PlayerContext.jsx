import React, { createContext, useContext, useState, useEffect, useRef, useCallback } from 'react';
import { musicService } from '../services/musicService';
import { telemetryApi } from '../services/api';
import { useLibrary } from './LibraryContext';

const PlayerContext = createContext(null);

export const PlayerProvider = ({ children }) => {
  const { recordPlayHistory } = useLibrary();
  
  const audioRef = useRef(null);
  const [currentSong, setCurrentSong] = useState(() => {
    try {
      const saved = localStorage.getItem('groovy_last_song');
      return saved ? JSON.parse(saved) : null;
    } catch {
      return null;
    }
  });
  const [isPlaying, setIsPlaying] = useState(false);
  const [queue, setQueue] = useState(() => {
    try {
      const saved = localStorage.getItem('groovy_last_queue');
      return saved ? JSON.parse(saved) : [];
    } catch {
      return [];
    }
  });
  const [queueIndex, setQueueIndex] = useState(0);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [volume, setVolume] = useState(() => {
    const v = localStorage.getItem('groovy_volume');
    return v !== null ? parseFloat(v) : 0.85;
  });
  const [isMuted, setIsMuted] = useState(false);
  const [isShuffle, setIsShuffle] = useState(false);
  const [repeatMode, setRepeatMode] = useState('off'); // 'off', 'all', 'one'
  const [isFullPlayerOpen, setIsFullPlayerOpen] = useState(false);
  const [activePlayerTab, setActivePlayerTab] = useState('art'); // 'art' | 'lyrics' | 'queue'
  
  const [lyrics, setLyrics] = useState({ syncedLyrics: null, plainLyrics: null, parsedLyrics: [] });
  const [isLyricsLoading, setIsLyricsLoading] = useState(false);
  
  // Up Next / "A continuación" / Radio
  const [upNext, setUpNext] = useState([]);

  // Active navigation targets for Artist and Album screens
  const [selectedArtist, setSelectedArtist] = useState(null);
  const [selectedAlbum, setSelectedAlbum] = useState(null);

  // Live Playback Telemetry Heartbeat (Web Player)
  useEffect(() => {
    if (!currentSong || !isPlaying) return;

    telemetryApi.reportPlayback({
      songId: currentSong.id,
      title: currentSong.title,
      artist: currentSong.artist || '',
      album: currentSong.album || '',
      coverArt: currentSong.coverArt || '',
      duration: Math.round(duration || currentSong.duration || 0),
      position: Math.round(currentTime || 0),
      isPlaying: true,
      platform: 'Web',
      deviceName: 'Web Player',
      listenDeltaSeconds: 0,
    }).catch(() => {});

    const interval = setInterval(() => {
      telemetryApi.reportPlayback({
        songId: currentSong.id,
        title: currentSong.title,
        artist: currentSong.artist || '',
        album: currentSong.album || '',
        coverArt: currentSong.coverArt || '',
        duration: Math.round(duration || currentSong.duration || 0),
        position: Math.round(audioRef.current?.currentTime || 0),
        isPlaying: true,
        platform: 'Web',
        deviceName: 'Web Player',
        listenDeltaSeconds: 8,
      }).catch(() => {});
    }, 8000);

    return () => {
      clearInterval(interval);
      telemetryApi.reportPlayback({
        songId: currentSong.id,
        title: currentSong.title,
        artist: currentSong.artist || '',
        album: currentSong.album || '',
        coverArt: currentSong.coverArt || '',
        duration: Math.round(duration || currentSong.duration || 0),
        position: Math.round(audioRef.current?.currentTime || 0),
        isPlaying: false,
        platform: 'Web',
        deviceName: 'Web Player',
        listenDeltaSeconds: 0,
      }).catch(() => {});
    };
  }, [currentSong, isPlaying, duration, currentTime]);

  const loadLyrics = useCallback(async (song) => {
    if (!song) return;
    setIsLyricsLoading(true);
    try {
      const lrc = await musicService.getLyrics(song.artist, song.title);
      setLyrics(lrc);
    } catch {
      setLyrics({ syncedLyrics: null, plainLyrics: null, parsedLyrics: [] });
    } finally {
      setIsLyricsLoading(false);
    }
  }, []);

  // Initialize Audio element handlers
  useEffect(() => {
    const audio = audioRef.current;
    if (!audio) return;

    const handleTimeUpdate = () => setCurrentTime(audio.currentTime);
    const handleLoadedMetadata = () => {
      if (audio.duration && !isNaN(audio.duration) && audio.duration > 0) {
        setDuration(audio.duration);
      }
    };
    const handleEnded = () => handleTrackEnded();
    const handlePlay = () => setIsPlaying(true);
    const handlePause = () => setIsPlaying(false);
    const handleError = (e) => {
      console.warn('Audio playback error:', e);
      setIsPlaying(false);
    };

    audio.addEventListener('timeupdate', handleTimeUpdate);
    audio.addEventListener('loadedmetadata', handleLoadedMetadata);
    audio.addEventListener('ended', handleEnded);
    audio.addEventListener('play', handlePlay);
    audio.addEventListener('pause', handlePause);
    audio.addEventListener('error', handleError);

    return () => {
      audio.removeEventListener('timeupdate', handleTimeUpdate);
      audio.removeEventListener('loadedmetadata', handleLoadedMetadata);
      audio.removeEventListener('ended', handleEnded);
      audio.removeEventListener('play', handlePlay);
      audio.removeEventListener('pause', handlePause);
      audio.removeEventListener('error', handleError);
    };
  }, [queue, queueIndex, repeatMode, isShuffle]);

  // Handle track ending logic
  const handleTrackEnded = () => {
    if (repeatMode === 'one') {
      if (audioRef.current) {
        audioRef.current.currentTime = 0;
        audioRef.current.play().catch(() => {});
      }
    } else {
      nextTrack();
    }
  };

  // Play a specific song or set queue
  const playSong = async (song, newQueue = null, startIndex = 0) => {
    if (!song) return;
    
    if (newQueue && Array.isArray(newQueue) && newQueue.length > 0) {
      setQueue(newQueue);
      localStorage.setItem('groovy_last_queue', JSON.stringify(newQueue.slice(0, 50)));
      const idx = newQueue.findIndex((s) => s.id === song.id);
      setQueueIndex(idx >= 0 ? idx : startIndex);
    } else if (!queue.some((s) => s.id === song.id)) {
      setQueue((prev) => {
        const updated = [song, ...prev];
        localStorage.setItem('groovy_last_queue', JSON.stringify(updated.slice(0, 50)));
        return updated;
      });
      setQueueIndex(0);
    } else {
      const idx = queue.findIndex((s) => s.id === song.id);
      setQueueIndex(idx >= 0 ? idx : 0);
    }

    setCurrentSong(song);
    localStorage.setItem('groovy_last_song', JSON.stringify(song));
    recordPlayHistory(song);

    // Audio stream loading with fallback
    if (audioRef.current) {
      const streamSrc = song.audioUrl || `https://cdn.freesound.org/previews/682/682245_14625902-lq.mp3`;
      audioRef.current.src = streamSrc;
      audioRef.current.volume = isMuted ? 0 : volume;
      audioRef.current.play().then(() => {
        setIsPlaying(true);
      }).catch((e) => {
        console.warn('Autoplay prevented or audio source issue:', e);
      });
    }

    loadLyrics(song);

    // Fetch related tracks for "A continuación" / Radio
    musicService.getRelatedTracks(song).then((tracks) => {
      setUpNext(tracks || []);
    }).catch(() => {});
  };

  const togglePlay = () => {
    if (!audioRef.current) return;
    if (isPlaying) {
      audioRef.current.pause();
    } else {
      if (!currentSong && queue.length > 0) {
        playSong(queue[0]);
      } else if (audioRef.current.src) {
        audioRef.current.play().catch((e) => console.warn('Play error:', e));
      } else if (currentSong) {
        playSong(currentSong);
      }
    }
  };

  const nextTrack = () => {
    if (queue.length === 0) return;
    let nextIdx;
    if (isShuffle) {
      nextIdx = Math.floor(Math.random() * queue.length);
    } else {
      nextIdx = queueIndex + 1;
      if (nextIdx >= queue.length) {
        if (repeatMode === 'all') {
          nextIdx = 0;
        } else if (upNext.length > 0) {
          // Auto-DJ: Take from "A continuación"
          const autoSong = upNext[0];
          setUpNext((prev) => prev.slice(1));
          setQueue((prev) => [...prev, autoSong]);
          setQueueIndex(queue.length);
          playSong(autoSong);
          return;
        } else {
          setIsPlaying(false);
          return;
        }
      }
    }
    setQueueIndex(nextIdx);
    playSong(queue[nextIdx]);
  };

  const prevTrack = () => {
    if (queue.length === 0) return;
    if (currentTime > 3 && audioRef.current) {
      audioRef.current.currentTime = 0;
      return;
    }
    let prevIdx = queueIndex - 1;
    if (prevIdx < 0) {
      prevIdx = repeatMode === 'all' ? queue.length - 1 : 0;
    }
    setQueueIndex(prevIdx);
    playSong(queue[prevIdx]);
  };

  const seekTo = (time) => {
    if (audioRef.current) {
      const clamped = Math.max(0, Math.min(time, duration || 9999));
      audioRef.current.currentTime = clamped;
      setCurrentTime(clamped);
    }
  };

  const changeVolume = (val) => {
    const clamped = Math.max(0, Math.min(1, val));
    setVolume(clamped);
    localStorage.setItem('groovy_volume', String(clamped));
    if (audioRef.current) {
      audioRef.current.volume = clamped;
    }
    if (clamped > 0 && isMuted) setIsMuted(false);
  };

  const toggleMute = () => {
    if (audioRef.current) {
      if (isMuted) {
        audioRef.current.volume = volume;
        setIsMuted(false);
      } else {
        audioRef.current.volume = 0;
        setIsMuted(true);
      }
    }
  };

  const toggleShuffle = () => setIsShuffle(!isShuffle);

  const toggleRepeat = () => {
    if (repeatMode === 'off') setRepeatMode('all');
    else if (repeatMode === 'all') setRepeatMode('one');
    else setRepeatMode('off');
  };

  const addToQueue = (song) => {
    setQueue((prev) => {
      const next = [...prev, song];
      localStorage.setItem('groovy_last_queue', JSON.stringify(next.slice(0, 50)));
      return next;
    });
  };

  const playNextInQueue = (song) => {
    setQueue((prev) => {
      const next = [...prev];
      next.splice(queueIndex + 1, 0, song);
      localStorage.setItem('groovy_last_queue', JSON.stringify(next.slice(0, 50)));
      return next;
    });
  };

  const removeFromQueue = (index) => {
    setQueue((prev) => {
      const next = prev.filter((_, idx) => idx !== index);
      localStorage.setItem('groovy_last_queue', JSON.stringify(next.slice(0, 50)));
      return next;
    });
    if (index < queueIndex) {
      setQueueIndex((prev) => Math.max(0, prev - 1));
    }
  };

  const clearQueue = () => {
    if (currentSong) {
      setQueue([currentSong]);
      setQueueIndex(0);
      localStorage.setItem('groovy_last_queue', JSON.stringify([currentSong]));
    } else {
      setQueue([]);
      setQueueIndex(0);
      localStorage.removeItem('groovy_last_queue');
    }
  };

  // Global Keyboard Shortcuts (Space, Arrows, M, L, F)
  useEffect(() => {
    const handleKeyDown = (e) => {
      const activeTag = document.activeElement?.tagName?.toLowerCase();
      if (activeTag === 'input' || activeTag === 'textarea' || document.activeElement?.isContentEditable) {
        return;
      }

      if (e.code === 'Space') {
        e.preventDefault();
        togglePlay();
      } else if (e.code === 'ArrowRight' && (e.ctrlKey || e.metaKey)) {
        e.preventDefault();
        nextTrack();
      } else if (e.code === 'ArrowLeft' && (e.ctrlKey || e.metaKey)) {
        e.preventDefault();
        prevTrack();
      } else if (e.code === 'ArrowRight') {
        e.preventDefault();
        if (audioRef.current) {
          seekTo(audioRef.current.currentTime + 5);
        }
      } else if (e.code === 'ArrowLeft') {
        e.preventDefault();
        if (audioRef.current) {
          seekTo(audioRef.current.currentTime - 5);
        }
      } else if (e.code === 'KeyM') {
        e.preventDefault();
        toggleMute();
      } else if (e.code === 'KeyL') {
        e.preventDefault();
        if (isFullPlayerOpen && activePlayerTab === 'lyrics') {
          setIsFullPlayerOpen(false);
        } else {
          setActivePlayerTab('lyrics');
          setIsFullPlayerOpen(true);
        }
      } else if (e.code === 'KeyF') {
        e.preventDefault();
        setIsFullPlayerOpen(prev => !prev);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [togglePlay, nextTrack, prevTrack, isFullPlayerOpen, activePlayerTab]);

  const downloadSong = (song = currentSong) => {
    if (!song || !song.audioUrl) return;
    const a = document.createElement('a');
    a.href = song.audioUrl;
    a.download = `${song.artist || 'Groovy'} - ${song.title || 'Song'}.mp3`;
    a.target = '_blank';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
  };

  const copyShareLink = (song = currentSong) => {
    if (!song) return;
    const url = `${window.location.origin}/#song=${song.id || encodeURIComponent(song.title)}`;
    navigator.clipboard?.writeText(url);
  };

  return (
    <PlayerContext.Provider
      value={{
        currentSong,
        isPlaying,
        queue,
        queueIndex,
        currentTime,
        duration,
        volume,
        isMuted,
        isShuffle,
        repeatMode,
        lyrics,
        isLyricsLoading,
        isFullPlayerOpen,
        activePlayerTab,
        setActivePlayerTab,
        playSong,
        togglePlay,
        nextTrack,
        prevTrack,
        seekTo,
        changeVolume,
        toggleMute,
        toggleShuffle,
        toggleRepeat,
        addToQueue,
        playNextInQueue,
        removeFromQueue,
        clearQueue,
        downloadSong,
        copyShareLink,
        upNext,
        selectedArtist,
        setSelectedArtist,
        selectedAlbum,
        setSelectedAlbum,
        openArtist: (artistName) => {
          setSelectedArtist(artistName);
          setIsFullPlayerOpen(false);
        },
        openAlbum: (album) => {
          setSelectedAlbum(album);
          setIsFullPlayerOpen(false);
        },
        openFullPlayer: (tab = 'art') => {
          setActivePlayerTab(tab);
          setIsFullPlayerOpen(true);
        },
        closeFullPlayer: () => setIsFullPlayerOpen(false),
      }}
    >
      <audio ref={audioRef} preload="auto" />
      {children}
    </PlayerContext.Provider>
  );
};

export const usePlayer = () => {
  const context = useContext(PlayerContext);
  if (!context) {
    throw new Error('usePlayer must be used within a PlayerProvider');
  }
  return context;
};
