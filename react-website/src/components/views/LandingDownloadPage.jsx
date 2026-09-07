import React, { useState, useEffect } from 'react';
import {
  Download,
  Laptop,
  Smartphone,
  Globe,
  Radio,
  Music,
  ShieldCheck,
  Zap,
  Sliders,
  Cloud,
  CheckCircle,
  ExternalLink,
  Github,
  Sparkles,
  ChevronRight,
  ArrowRight,
  Layers,
  Volume2,
  RefreshCw,
  Heart,
  FileCode,
  HardDrive,
  Check,
  Info,
  Play
} from 'lucide-react';

const GITHUB_REPO = 'Danx016/Groovy';
const GITHUB_API_RELEASE = `https://api.github.com/repos/${GITHUB_REPO}/releases/latest`;
const GITHUB_RELEASES_PAGE = `https://github.com/${GITHUB_REPO}/releases`;

export const LandingDownloadPage = ({ onOpenPlayer, onOpenAdmin }) => {
  const [releaseInfo, setReleaseInfo] = useState(null);
  const [isLoadingRelease, setIsLoadingRelease] = useState(true);
  const [userOS, setUserOS] = useState('windows'); // 'windows' | 'android' | 'mac' | 'linux' | 'other'
  const [selectedTab, setSelectedTab] = useState('all'); // 'all' | 'windows' | 'android' | 'linux'
  const [copiedLink, setCopiedLink] = useState(false);

  // Detect user operating system
  useEffect(() => {
    const ua = navigator.userAgent || navigator.vendor || window.opera || '';
    if (/android/i.test(ua)) {
      setUserOS('android');
      setSelectedTab('android');
    } else if (/windows|win32|win64/i.test(ua)) {
      setUserOS('windows');
      setSelectedTab('windows');
    } else if (/macintosh|mac os x/i.test(ua)) {
      setUserOS('mac');
      setSelectedTab('all');
    } else if (/linux/i.test(ua)) {
      setUserOS('linux');
      setSelectedTab('linux');
    } else {
      setUserOS('other');
    }
  }, []);

  // Fetch real-time release from GitHub
  useEffect(() => {
    let isMounted = true;
    async function fetchGitHubRelease() {
      setIsLoadingRelease(true);
      try {
        const res = await fetch(GITHUB_API_RELEASE, {
          headers: { Accept: 'application/vnd.github.v3+json' },
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        if (isMounted) {
          setReleaseInfo(data);
        }
      } catch (err) {
        console.warn('Could not fetch live GitHub release:', err);
        // Fallback default info if GitHub API rate-limited
        if (isMounted) {
          setReleaseInfo({
            tag_name: 'v1.0.65',
            name: 'Groovy v1.0.65',
            published_at: new Date().toISOString(),
            html_url: GITHUB_RELEASES_PAGE,
            body: 'Versión oficial con sincronización multidispositivo Groovy Connect, motor de audio Hi-Fi y optimizaciones para Windows y Android.',
            assets: [
              {
                name: 'Groovy-Setup.exe',
                browser_download_url: `https://github.com/${GITHUB_REPO}/releases/latest/download/Groovy-Setup.exe`,
                size: 38702255,
              },
              {
                name: 'Groovy-Windows-Portable.zip',
                browser_download_url: `https://github.com/${GITHUB_REPO}/releases/latest/download/Groovy-Windows-Portable.zip`,
                size: 45068261,
              },
              {
                name: 'app-release.apk',
                browser_download_url: `https://github.com/${GITHUB_REPO}/releases/latest/download/app-release.apk`,
                size: 32400000,
              },
            ],
          });
        }
      } finally {
        if (isMounted) setIsLoadingRelease(false);
      }
    }

    fetchGitHubRelease();
    return () => {
      isMounted = false;
    };
  }, []);

  const formatFileSize = (bytes) => {
    if (!bytes) return '';
    const mb = bytes / (1024 * 1024);
    return `${mb.toFixed(1)} MB`;
  };

  const formatDate = (dateStr) => {
    if (!dateStr) return 'Reciente';
    try {
      const d = new Date(dateStr);
      return d.toLocaleDateString('es-ES', { year: 'numeric', month: 'short', day: 'numeric' });
    } catch {
      return dateStr;
    }
  };

  // Find download assets
  const getAsset = (pattern) => {
    if (!releaseInfo?.assets) return null;
    return releaseInfo.assets.find((a) =>
      a.name.toLowerCase().includes(pattern.toLowerCase())
    );
  };

  const windowsSetupAsset = getAsset('setup') || getAsset('.exe') || {
    name: 'Groovy-Setup.exe',
    browser_download_url: `https://github.com/${GITHUB_REPO}/releases/latest/download/Groovy-Setup.exe`,
    size: 38702255,
  };

  const windowsZipAsset = getAsset('portable') || getAsset('windows.zip') || {
    name: 'Groovy-Windows-Portable.zip',
    browser_download_url: `https://github.com/${GITHUB_REPO}/releases/latest/download/Groovy-Windows-Portable.zip`,
    size: 45068261,
  };

  const androidApkAsset = getAsset('app-release.apk') || getAsset('.apk') || {
    name: 'Groovy-Android.apk',
    browser_download_url: `https://github.com/${GITHUB_REPO}/releases/latest/download/app-release.apk`,
    size: 32400000,
  };

  const linuxAsset = getAsset('linux') || getAsset('.tar.gz') || {
    name: 'groovy-linux-x64.tar.gz',
    browser_download_url: `https://github.com/${GITHUB_REPO}/releases/latest/download/groovy-linux-x64.tar.gz`,
    size: 42000000,
  };

  const versionTag = releaseInfo?.tag_name || 'v1.0.65';
  const publishDate = formatDate(releaseInfo?.published_at);

  const copyShareLink = () => {
    navigator.clipboard?.writeText(window.location.href);
    setCopiedLink(true);
    setTimeout(() => setCopiedLink(false), 2200);
  };

  return (
    <div style={{ minHeight: '100vh', background: '#000000', color: '#ffffff', fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif' }}>
      {/* 1. TOP NAVBAR */}
      <header
        style={{
          position: 'sticky',
          top: 0,
          zIndex: 100,
          background: 'rgba(0,0,0,0.85)',
          backdropFilter: 'blur(24px)',
          borderBottom: '0.5px solid rgba(255,255,255,0.08)',
          padding: '0 24px',
          height: '64px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '32px' }}>
          {/* Brand */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer' }} onClick={onOpenPlayer}>
            <div style={{ width: '36px', height: '36px', borderRadius: '10px', overflow: 'hidden', boxShadow: '0 4px 14px rgba(250,36,60,0.35)' }}>
              <img src="./logo.png" alt="Groovy" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
            </div>
            <div>
              <span style={{ fontSize: '18px', fontWeight: 800, letterSpacing: '-0.4px', color: '#ffffff' }}>Groovy</span>
              <span style={{ fontSize: '10px', marginLeft: '6px', background: 'rgba(250,36,60,0.2)', color: '#FA243C', padding: '2px 6px', borderRadius: '6px', fontWeight: 700 }}>
                MUSIC
              </span>
            </div>
          </div>

          {/* Nav Links */}
          <nav style={{ display: 'none', alignItems: 'center', gap: '24px' }} className="desktop-nav">
            <a href="#caracteristicas" style={{ color: '#B3B3B3', textDecoration: 'none', fontSize: '14px', fontWeight: 500, transition: 'color 0.15s' }} onMouseEnter={e => e.currentTarget.style.color = '#fff'} onMouseLeave={e => e.currentTarget.style.color = '#B3B3B3'}>
              Características
            </a>
            <a href="#descargas" style={{ color: '#B3B3B3', textDecoration: 'none', fontSize: '14px', fontWeight: 500, transition: 'color 0.15s' }} onMouseEnter={e => e.currentTarget.style.color = '#fff'} onMouseLeave={e => e.currentTarget.style.color = '#B3B3B3'}>
              Descargas
            </a>
            <a href="#connect" style={{ color: '#B3B3B3', textDecoration: 'none', fontSize: '14px', fontWeight: 500, transition: 'color 0.15s' }} onMouseEnter={e => e.currentTarget.style.color = '#fff'} onMouseLeave={e => e.currentTarget.style.color = '#B3B3B3'}>
              Groovy Connect
            </a>
            <a href="#comparativa" style={{ color: '#B3B3B3', textDecoration: 'none', fontSize: '14px', fontWeight: 500, transition: 'color 0.15s' }} onMouseEnter={e => e.currentTarget.style.color = '#fff'} onMouseLeave={e => e.currentTarget.style.color = '#B3B3B3'}>
              Ventajas
            </a>
          </nav>
        </div>

        {/* Right CTA */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <a
            href={`https://github.com/${GITHUB_REPO}`}
            target="_blank"
            rel="noreferrer"
            style={{
              display: 'flex', alignItems: 'center', gap: '6px',
              padding: '8px 12px', borderRadius: '20px',
              background: '#181818', border: '0.5px solid #333',
              color: '#fff', fontSize: '13px', fontWeight: 600,
              textDecoration: 'none', transition: 'all 0.15s',
            }}
            onMouseEnter={e => e.currentTarget.style.background = '#282828'}
            onMouseLeave={e => e.currentTarget.style.background = '#181818'}
          >
            <Github size={15} />
            <span className="hide-mobile">GitHub</span>
          </a>

          <button
            onClick={onOpenPlayer}
            style={{
              display: 'flex', alignItems: 'center', gap: '6px',
              padding: '8px 16px', borderRadius: '20px',
              background: '#282828', border: '0.5px solid #404040',
              color: '#fff', fontSize: '13px', fontWeight: 600,
              cursor: 'pointer', transition: 'all 0.15s',
            }}
            onMouseEnter={e => e.currentTarget.style.background = '#333'}
            onMouseLeave={e => e.currentTarget.style.background = '#282828'}
          >
            <Play size={14} fill="#fff" />
            <span>Web Player</span>
          </button>

          <a
            href="#descargas"
            style={{
              display: 'flex', alignItems: 'center', gap: '6px',
              padding: '8px 18px', borderRadius: '20px',
              background: 'linear-gradient(135deg, #FA243C 0%, #FF4D67 100%)',
              color: '#fff', fontSize: '13px', fontWeight: 700,
              textDecoration: 'none', boxShadow: '0 4px 14px rgba(250,36,60,0.4)',
              transition: 'transform 0.15s',
            }}
            onMouseEnter={e => e.currentTarget.style.transform = 'scale(1.03)'}
            onMouseLeave={e => e.currentTarget.style.transform = 'scale(1)'}
          >
            <Download size={14} />
            <span>Descargar</span>
          </a>
        </div>
      </header>

      {/* 2. HERO SECTION */}
      <section
        style={{
          position: 'relative',
          overflow: 'hidden',
          padding: '80px 24px 60px',
          textAlign: 'center',
          maxWidth: '1200px',
          margin: '0 auto',
        }}
      >
        {/* Glow ambient background circles */}
        <div
          style={{
            position: 'absolute',
            top: '-80px',
            left: '50%',
            transform: 'translateX(-50%)',
            width: '600px',
            height: '400px',
            background: 'radial-gradient(circle, rgba(250,36,60,0.25) 0%, rgba(131,56,236,0.15) 50%, rgba(0,0,0,0) 70%)',
            filter: 'blur(60px)',
            pointerEvents: 'none',
            zIndex: 0,
          }}
        />

        <div style={{ position: 'relative', zIndex: 1, maxWidth: '840px', margin: '0 auto' }}>
          {/* Release Badge */}
          <div
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: '8px',
              padding: '6px 14px',
              borderRadius: '24px',
              background: 'rgba(250,36,60,0.12)',
              border: '1px solid rgba(250,36,60,0.3)',
              marginBottom: '24px',
            }}
          >
            <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#34C759', boxShadow: '0 0 8px #34C759' }} />
            <span style={{ fontSize: '13px', fontWeight: 700, color: '#fff' }}>
              Nueva Versión {versionTag} Disponible
            </span>
            <span style={{ fontSize: '11px', color: '#B3B3B3', background: '#1c1c1e', padding: '2px 8px', borderRadius: '12px' }}>
              {publishDate}
            </span>
          </div>

          {/* Headline */}
          <h1
            style={{
              fontSize: 'clamp(36px, 6vw, 68px)',
              fontWeight: 900,
              lineHeight: 1.08,
              letterSpacing: '-1.5px',
              marginBottom: '20px',
              background: 'linear-gradient(180deg, #FFFFFF 30%, #A1A1A6 100%)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
            }}
          >
            Tu música sin límites. En cualquier dispositivo.
          </h1>

          {/* Subtitle */}
          <p
            style={{
              fontSize: 'clamp(16px, 2vw, 20px)',
              lineHeight: 1.5,
              color: '#B3B3B3',
              maxWidth: '680px',
              margin: '0 auto 36px',
              fontWeight: 400,
            }}
          >
            Streaming ultrarrápido sin anuncios, motor de audio de alta fidelidad, control remoto multidispositivo <strong>Groovy Connect</strong> y sincronización en la nube para Windows, Android y la Web.
          </p>

          {/* Primary Quick-Download Buttons based on detected OS */}
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '14px',
              flexWrap: 'wrap',
              marginBottom: '40px',
            }}
          >
            {userOS === 'windows' ? (
              <a
                href={windowsSetupAsset.browser_download_url}
                style={{
                  display: 'flex', alignItems: 'center', gap: '10px',
                  padding: '16px 32px', borderRadius: '16px',
                  background: 'linear-gradient(135deg, #FA243C 0%, #E01A31 100%)',
                  color: '#fff', fontSize: '16px', fontWeight: 700,
                  textDecoration: 'none', boxShadow: '0 8px 24px rgba(250,36,60,0.4)',
                  transition: 'all 0.2s',
                }}
                onMouseEnter={e => e.currentTarget.style.transform = 'translateY(-2px)'}
                onMouseLeave={e => e.currentTarget.style.transform = 'translateY(0)'}
              >
                <Laptop size={22} />
                <div style={{ textAlign: 'left' }}>
                  <div style={{ fontSize: '15px', fontWeight: 800 }}>Descargar para Windows</div>
                  <div style={{ fontSize: '11px', opacity: 0.85, fontWeight: 500 }}>Instalador .exe • {formatFileSize(windowsSetupAsset.size) || versionTag}</div>
                </div>
              </a>
            ) : userOS === 'android' ? (
              <a
                href={androidApkAsset.browser_download_url}
                style={{
                  display: 'flex', alignItems: 'center', gap: '10px',
                  padding: '16px 32px', borderRadius: '16px',
                  background: 'linear-gradient(135deg, #34C759 0%, #28A745 100%)',
                  color: '#fff', fontSize: '16px', fontWeight: 700,
                  textDecoration: 'none', boxShadow: '0 8px 24px rgba(52,199,89,0.4)',
                  transition: 'all 0.2s',
                }}
                onMouseEnter={e => e.currentTarget.style.transform = 'translateY(-2px)'}
                onMouseLeave={e => e.currentTarget.style.transform = 'translateY(0)'}
              >
                <Smartphone size={22} />
                <div style={{ textAlign: 'left' }}>
                  <div style={{ fontSize: '15px', fontWeight: 800 }}>Descargar APK para Android</div>
                  <div style={{ fontSize: '11px', opacity: 0.85, fontWeight: 500 }}>APK Directo • {formatFileSize(androidApkAsset.size) || versionTag}</div>
                </div>
              </a>
            ) : (
              <a
                href="#descargas"
                style={{
                  display: 'flex', alignItems: 'center', gap: '10px',
                  padding: '16px 32px', borderRadius: '16px',
                  background: 'linear-gradient(135deg, #FA243C 0%, #E01A31 100%)',
                  color: '#fff', fontSize: '16px', fontWeight: 700,
                  textDecoration: 'none', boxShadow: '0 8px 24px rgba(250,36,60,0.4)',
                  transition: 'all 0.2s',
                }}
                onMouseEnter={e => e.currentTarget.style.transform = 'translateY(-2px)'}
                onMouseLeave={e => e.currentTarget.style.transform = 'translateY(0)'}
              >
                <Download size={20} />
                <span>Ver Todas las Descargas</span>
              </a>
            )}

            <button
              onClick={onOpenPlayer}
              style={{
                display: 'flex', alignItems: 'center', gap: '10px',
                padding: '16px 28px', borderRadius: '16px',
                background: 'rgba(255,255,255,0.06)', border: '1px solid rgba(255,255,255,0.15)',
                color: '#fff', fontSize: '15px', fontWeight: 700,
                cursor: 'pointer', transition: 'all 0.2s',
              }}
              onMouseEnter={e => { e.currentTarget.style.background = 'rgba(255,255,255,0.12)'; }}
              onMouseLeave={e => { e.currentTarget.style.background = 'rgba(255,255,255,0.06)'; }}
            >
              <Globe size={18} style={{ color: '#007AFF' }} />
              <span>Abrir Reproductor Web</span>
            </button>
          </div>

          {/* Feature Highlights Pills */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '20px', flexWrap: 'wrap', fontSize: '13px', color: '#8E8E93' }}>
            <span style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <CheckCircle size={15} style={{ color: '#34C759' }} /> 100% Gratuito y Sin Anuncios
            </span>
            <span style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <CheckCircle size={15} style={{ color: '#34C759' }} /> Audio Hi-Res Lossless
            </span>
            <span style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <CheckCircle size={15} style={{ color: '#34C759' }} /> Groovy Connect Multidispositivo
            </span>
            <span style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <CheckCircle size={15} style={{ color: '#34C759' }} /> Descargas Offline
            </span>
          </div>
        </div>

        {/* Hero Interactive App Mockup Graphic */}
        <div
          style={{
            marginTop: '56px',
            position: 'relative',
            borderRadius: '24px',
            background: 'linear-gradient(180deg, rgba(30,30,30,0.8) 0%, rgba(15,15,15,0.95) 100%)',
            border: '1px solid rgba(255,255,255,0.12)',
            boxShadow: '0 24px 64px -12px rgba(0,0,0,0.9), 0 0 40px rgba(250,36,60,0.15)',
            padding: '28px',
            overflow: 'hidden',
          }}
        >
          {/* Top Bar of mockup */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', borderBottom: '1px solid rgba(255,255,255,0.08)', paddingBottom: '16px', marginBottom: '20px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <div style={{ width: '12px', height: '12px', borderRadius: '50%', background: '#FF5F56' }} />
              <div style={{ width: '12px', height: '12px', borderRadius: '50%', background: '#FFBD2E' }} />
              <div style={{ width: '12px', height: '12px', borderRadius: '50%', background: '#27C93F' }} />
              <span style={{ fontSize: '12px', color: '#6B6B6B', marginLeft: '12px', fontWeight: 600 }}>Groovy Music • Experiencia de Reproducción</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <span style={{ fontSize: '11px', background: 'rgba(52,199,89,0.15)', color: '#34C759', padding: '3px 10px', borderRadius: '12px', fontWeight: 700 }}>
                ● EN VIVO (Hi-Res Audio 320kbps)
              </span>
            </div>
          </div>

          {/* Mockup Content Grid */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '20px', textAlign: 'left' }}>
            {/* Mock Player Card */}
            <div style={{ background: '#121212', borderRadius: '16px', padding: '20px', border: '1px solid #282828' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '14px', marginBottom: '16px' }}>
                <div style={{ width: '64px', height: '64px', borderRadius: '12px', overflow: 'hidden', background: '#FA243C', flexShrink: 0 }}>
                  <img src="./logo.png" alt="Groovy" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                </div>
                <div>
                  <h3 style={{ fontSize: '16px', fontWeight: 700, color: '#fff', marginBottom: '4px' }}>Groovy Cloud Streaming</h3>
                  <p style={{ fontSize: '13px', color: '#FA243C', fontWeight: 600 }}>Audio sin compresión • FLAC / 320 kbps</p>
                  <p style={{ fontSize: '12px', color: '#6B6B6B', marginTop: '2px' }}>YouTube Music & Cloud DB</p>
                </div>
              </div>

              {/* Progress bar mock */}
              <div style={{ width: '100%', height: '4px', background: '#282828', borderRadius: '2px', overflow: 'hidden', marginBottom: '8px' }}>
                <div style={{ width: '65%', height: '100%', background: '#FA243C' }} />
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '11px', color: '#6B6B6B' }}>
                <span>2:15</span>
                <span>3:40</span>
              </div>
            </div>

            {/* Groovy Connect Mock */}
            <div style={{ background: '#121212', borderRadius: '16px', padding: '20px', border: '1px solid rgba(52,199,89,0.3)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '12px' }}>
                <Radio size={18} style={{ color: '#34C759' }} />
                <h4 style={{ fontSize: '14px', fontWeight: 700, color: '#34C759', textTransform: 'uppercase', letterSpacing: '0.04em' }}>Groovy Connect Activo</h4>
              </div>
              <p style={{ fontSize: '13px', color: '#E0E0E0', marginBottom: '12px', lineHeight: 1.4 }}>
                Controla la música de tu PC desde tu móvil o transfiere la sesión con un solo toque.
              </p>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', background: '#181818', padding: '8px 12px', borderRadius: '10px', fontSize: '12px' }}>
                <Laptop size={15} style={{ color: '#00A4EF' }} />
                <span style={{ color: '#fff', fontWeight: 600 }}>Windows Desktop</span>
                <span style={{ marginLeft: 'auto', color: '#34C759', fontWeight: 700 }}>● Reproduciendo</span>
              </div>
            </div>

            {/* Equalizer & Audio FX Mock */}
            <div style={{ background: '#121212', borderRadius: '16px', padding: '20px', border: '1px solid #282828' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '12px' }}>
                <Sliders size={18} style={{ color: '#FA243C' }} />
                <h4 style={{ fontSize: '14px', fontWeight: 700, color: '#fff' }}>Ecualizador Paramétrico</h4>
              </div>
              <p style={{ fontSize: '13px', color: '#B3B3B3', marginBottom: '12px' }}>
                Ajuste de 10 bandas, refuerzo de graves (*Bass Boost*), control de tono (*Pitch*) y velocidad de reproducción (0.5x - 2.0x).
              </p>
              <div style={{ display: 'flex', gap: '6px', alignItems: 'flex-end', height: '24px' }}>
                {[40, 70, 90, 60, 45, 80, 100, 75, 50, 85].map((h, i) => (
                  <div key={i} style={{ flex: 1, background: '#FA243C', height: `${h}%`, borderRadius: '2px', opacity: 0.8 }} />
                ))}
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* 3. DOWNLOADS SECTION (Real-Time GitHub Releases Connected) */}
      <section id="descargas" style={{ padding: '80px 24px', background: '#0A0A0A', borderTop: '1px solid #1c1c1e', borderBottom: '1px solid #1c1c1e' }}>
        <div style={{ maxWidth: '1100px', margin: '0 auto' }}>
          {/* Section Header */}
          <div style={{ textAlign: 'center', marginBottom: '48px' }}>
            <span style={{ fontSize: '12px', fontWeight: 700, color: '#FA243C', letterSpacing: '0.08em', textTransform: 'uppercase' }}>
              INSTALADORES OFICIALES
            </span>
            <h2 style={{ fontSize: 'clamp(28px, 4vw, 44px)', fontWeight: 800, letterSpacing: '-0.8px', marginTop: '8px', marginBottom: '12px' }}>
              Descarga Groovy para tu Plataforma
            </h2>
            <p style={{ fontSize: '15px', color: '#8E8E93', maxWidth: '600px', margin: '0 auto' }}>
              Actualizaciones automáticas sincronizadas directamente desde los servidores de GitHub Releases.
            </p>

            {/* Platform Filter Tabs */}
            <div style={{ display: 'inline-flex', background: '#181818', padding: '4px', borderRadius: '28px', marginTop: '24px', border: '1px solid #282828' }}>
              {[
                { id: 'all', label: 'Todas las Apps' },
                { id: 'windows', label: '🪟 Windows' },
                { id: 'android', label: '📱 Android' },
                { id: 'linux', label: '🐧 Linux' },
              ].map(t => (
                <button
                  key={t.id}
                  onClick={() => setSelectedTab(t.id)}
                  style={{
                    padding: '8px 18px', borderRadius: '24px', fontSize: '13px', fontWeight: 600,
                    background: selectedTab === t.id ? '#FA243C' : 'transparent',
                    color: selectedTab === t.id ? '#fff' : '#B3B3B3',
                    border: 'none', cursor: 'pointer', transition: 'all 0.15s',
                  }}
                >
                  {t.label}
                </button>
              ))}
            </div>
          </div>

          {/* Cards Grid */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '24px' }}>
            {/* WINDOWS INSTALLER CARD */}
            {(selectedTab === 'all' || selectedTab === 'windows') && (
              <div
                style={{
                  background: '#141414',
                  borderRadius: '20px',
                  border: userOS === 'windows' ? '1.5px solid rgba(250,36,60,0.6)' : '1px solid #282828',
                  padding: '28px',
                  display: 'flex',
                  flexDirection: 'column',
                  position: 'relative',
                  boxShadow: userOS === 'windows' ? '0 12px 32px rgba(250,36,60,0.2)' : 'none',
                }}
              >
                {userOS === 'windows' && (
                  <span style={{ position: 'absolute', top: '16px', right: '16px', background: 'rgba(250,36,60,0.2)', color: '#FA243C', fontSize: '10px', fontWeight: 800, padding: '3px 9px', borderRadius: '12px' }}>
                    RECOMENDADO PARA TU PC
                  </span>
                )}

                <div style={{ display: 'flex', alignItems: 'center', gap: '14px', marginBottom: '18px' }}>
                  <div style={{ width: '48px', height: '48px', borderRadius: '12px', background: 'rgba(0,164,239,0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <Laptop size={26} style={{ color: '#00A4EF' }} />
                  </div>
                  <div>
                    <h3 style={{ fontSize: '18px', fontWeight: 700, color: '#fff' }}>Windows (Instalador)</h3>
                    <p style={{ fontSize: '12px', color: '#8E8E93' }}>Windows 10 / 11 (64-bit)</p>
                  </div>
                </div>

                <p style={{ fontSize: '13px', color: '#B3B3B3', lineHeight: 1.5, marginBottom: '20px', flex: 1 }}>
                  Instalador oficial firmado digitalmente. Se instala en el directorio de usuario seguro sin requerir permisos elevados.
                </p>

                <div style={{ background: '#1c1c1e', borderRadius: '12px', padding: '12px', marginBottom: '18px', fontSize: '12px', color: '#8E8E93', display: 'flex', justifyContent: 'space-between' }}>
                  <span>Archivo: <code>Groovy-Setup.exe</code></span>
                  <span>{formatFileSize(windowsSetupAsset.size) || '38.7 MB'}</span>
                </div>

                <a
                  href={windowsSetupAsset.browser_download_url}
                  style={{
                    display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px',
                    width: '100%', padding: '14px', borderRadius: '12px',
                    background: '#FA243C', color: '#fff', fontSize: '14px', fontWeight: 700,
                    textDecoration: 'none', transition: 'background 0.15s', boxSizing: 'border-box',
                  }}
                  onMouseEnter={e => e.currentTarget.style.background = '#c41c2e'}
                  onMouseLeave={e => e.currentTarget.style.background = '#FA243C'}
                >
                  <Download size={16} />
                  <span>Descargar Instalador .exe ({versionTag})</span>
                </a>
              </div>
            )}

            {/* WINDOWS PORTABLE ZIP CARD */}
            {(selectedTab === 'all' || selectedTab === 'windows') && (
              <div
                style={{
                  background: '#141414',
                  borderRadius: '20px',
                  border: '1px solid #282828',
                  padding: '28px',
                  display: 'flex',
                  flexDirection: 'column',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '14px', marginBottom: '18px' }}>
                  <div style={{ width: '48px', height: '48px', borderRadius: '12px', background: 'rgba(255,189,46,0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <HardDrive size={26} style={{ color: '#FFBD2E' }} />
                  </div>
                  <div>
                    <h3 style={{ fontSize: '18px', fontWeight: 700, color: '#fff' }}>Windows Portable</h3>
                    <p style={{ fontSize: '12px', color: '#8E8E93' }}>Sin instalación • Descomprimir y usar</p>
                  </div>
                </div>

                <p style={{ fontSize: '13px', color: '#B3B3B3', lineHeight: 1.5, marginBottom: '20px', flex: 1 }}>
                  Ideal para memorias USB o si prefieres no instalar programas. Descomprimes el archivo .ZIP y ejecutas <code>groovy.exe</code> directamente.
                </p>

                <div style={{ background: '#1c1c1e', borderRadius: '12px', padding: '12px', marginBottom: '18px', fontSize: '12px', color: '#8E8E93', display: 'flex', justifyContent: 'space-between' }}>
                  <span>Archivo: <code>Groovy-Windows.zip</code></span>
                  <span>{formatFileSize(windowsZipAsset.size) || '45.0 MB'}</span>
                </div>

                <a
                  href={windowsZipAsset.browser_download_url}
                  style={{
                    display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px',
                    width: '100%', padding: '14px', borderRadius: '12px',
                    background: '#282828', border: '1px solid #404040', color: '#fff', fontSize: '14px', fontWeight: 700,
                    textDecoration: 'none', transition: 'background 0.15s', boxSizing: 'border-box',
                  }}
                  onMouseEnter={e => e.currentTarget.style.background = '#333'}
                  onMouseLeave={e => e.currentTarget.style.background = '#282828'}
                >
                  <Download size={16} />
                  <span>Descargar Versión Portable .ZIP</span>
                </a>
              </div>
            )}

            {/* ANDROID APK CARD */}
            {(selectedTab === 'all' || selectedTab === 'android') && (
              <div
                style={{
                  background: '#141414',
                  borderRadius: '20px',
                  border: userOS === 'android' ? '1.5px solid rgba(52,199,89,0.6)' : '1px solid #282828',
                  padding: '28px',
                  display: 'flex',
                  flexDirection: 'column',
                  position: 'relative',
                  boxShadow: userOS === 'android' ? '0 12px 32px rgba(52,199,89,0.2)' : 'none',
                }}
              >
                {userOS === 'android' && (
                  <span style={{ position: 'absolute', top: '16px', right: '16px', background: 'rgba(52,199,89,0.2)', color: '#34C759', fontSize: '10px', fontWeight: 800, padding: '3px 9px', borderRadius: '12px' }}>
                    RECOMENDADO PARA TU MÓVIL
                  </span>
                )}

                <div style={{ display: 'flex', alignItems: 'center', gap: '14px', marginBottom: '18px' }}>
                  <div style={{ width: '48px', height: '48px', borderRadius: '12px', background: 'rgba(52,199,89,0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <Smartphone size={26} style={{ color: '#34C759' }} />
                  </div>
                  <div>
                    <h3 style={{ fontSize: '18px', fontWeight: 700, color: '#fff' }}>Android APK</h3>
                    <p style={{ fontSize: '12px', color: '#8E8E93' }}>Android 7.0 y superior (Universal)</p>
                  </div>
                </div>

                <p style={{ fontSize: '13px', color: '#B3B3B3', lineHeight: 1.5, marginBottom: '20px', flex: 1 }}>
                  Paquete APK universal oficial. Soporta reproducción en segundo plano con pantalla apagada, Android Auto y ecualizador por hardware.
                </p>

                <div style={{ background: '#1c1c1e', borderRadius: '12px', padding: '12px', marginBottom: '18px', fontSize: '12px', color: '#8E8E93', display: 'flex', justifyContent: 'space-between' }}>
                  <span>Archivo: <code>app-release.apk</code></span>
                  <span>{formatFileSize(androidApkAsset.size) || '32.4 MB'}</span>
                </div>

                <a
                  href={androidApkAsset.browser_download_url}
                  style={{
                    display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px',
                    width: '100%', padding: '14px', borderRadius: '12px',
                    background: '#34C759', color: '#000', fontSize: '14px', fontWeight: 800,
                    textDecoration: 'none', transition: 'background 0.15s', boxSizing: 'border-box',
                  }}
                  onMouseEnter={e => e.currentTarget.style.background = '#28A745'}
                  onMouseLeave={e => e.currentTarget.style.background = '#34C759'}
                >
                  <Download size={16} />
                  <span>Descargar APK Android ({versionTag})</span>
                </a>
              </div>
            )}

            {/* LINUX CARD */}
            {(selectedTab === 'all' || selectedTab === 'linux') && (
              <div
                style={{
                  background: '#141414',
                  borderRadius: '20px',
                  border: '1px solid #282828',
                  padding: '28px',
                  display: 'flex',
                  flexDirection: 'column',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '14px', marginBottom: '18px' }}>
                  <div style={{ width: '48px', height: '48px', borderRadius: '12px', background: 'rgba(255,255,255,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <FileCode size={26} style={{ color: '#fff' }} />
                  </div>
                  <div>
                    <h3 style={{ fontSize: '18px', fontWeight: 700, color: '#fff' }}>Linux (x64)</h3>
                    <p style={{ fontSize: '12px', color: '#8E8E93' }}>Ubuntu / Debian / Fedora / Arch</p>
                  </div>
                </div>

                <p style={{ fontSize: '13px', color: '#B3B3B3', lineHeight: 1.5, marginBottom: '20px', flex: 1 }}>
                  Paquete compilado con backend libmpv nativo para distribuciones Linux de 64 bits con soporte MPRIS.
                </p>

                <div style={{ background: '#1c1c1e', borderRadius: '12px', padding: '12px', marginBottom: '18px', fontSize: '12px', color: '#8E8E93', display: 'flex', justifyContent: 'space-between' }}>
                  <span>Archivo: <code>groovy-linux-x64.tar.gz</code></span>
                  <span>{formatFileSize(linuxAsset.size) || '42.0 MB'}</span>
                </div>

                <a
                  href={linuxAsset.browser_download_url}
                  style={{
                    display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px',
                    width: '100%', padding: '14px', borderRadius: '12px',
                    background: '#282828', border: '1px solid #404040', color: '#fff', fontSize: '14px', fontWeight: 700,
                    textDecoration: 'none', transition: 'background 0.15s', boxSizing: 'border-box',
                  }}
                  onMouseEnter={e => e.currentTarget.style.background = '#333'}
                  onMouseLeave={e => e.currentTarget.style.background = '#282828'}
                >
                  <Download size={16} />
                  <span>Descargar Tarball Linux</span>
                </a>
              </div>
            )}
          </div>

          {/* GitHub Sync Status Banner */}
          <div
            style={{
              marginTop: '32px',
              padding: '16px 20px',
              borderRadius: '14px',
              background: '#121212',
              border: '1px solid #282828',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              flexWrap: 'wrap',
              gap: '12px',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <RefreshCw size={16} className={isLoadingRelease ? 'animate-spin' : ''} style={{ color: '#34C759' }} />
              <span style={{ fontSize: '13px', color: '#B3B3B3' }}>
                Conectado a GitHub Releases (<code>{GITHUB_REPO}</code>) • Último release: <strong style={{ color: '#fff' }}>{versionTag}</strong>
              </span>
            </div>
            <a
              href={GITHUB_RELEASES_PAGE}
              target="_blank"
              rel="noreferrer"
              style={{ display: 'flex', alignItems: 'center', gap: '4px', color: '#FA243C', fontSize: '13px', fontWeight: 600, textDecoration: 'none' }}
            >
              <span>Ver todas las versiones en GitHub</span>
              <ExternalLink size={13} />
            </a>
          </div>
        </div>
      </section>

      {/* 4. KEY FEATURES SHOWCASE */}
      <section id="caracteristicas" style={{ padding: '90px 24px', maxWidth: '1200px', margin: '0 auto' }}>
        <div style={{ textAlign: 'center', marginBottom: '56px' }}>
          <span style={{ fontSize: '12px', fontWeight: 700, color: '#FA243C', letterSpacing: '0.08em', textTransform: 'uppercase' }}>
            EXPERIENCIA PREMIUM
          </span>
          <h2 style={{ fontSize: 'clamp(28px, 4vw, 44px)', fontWeight: 800, letterSpacing: '-0.8px', marginTop: '8px' }}>
            Diseñado para amantes de la música
          </h2>
          <p style={{ fontSize: '16px', color: '#8E8E93', maxWidth: '640px', margin: '12px auto 0' }}>
            Una plataforma moderna construida desde cero para ofrecer la máxima calidad y libertad de escucha.
          </p>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '24px' }}>
          {/* Feature 1 */}
          <div style={{ background: '#121212', borderRadius: '20px', padding: '28px', border: '1px solid #242424' }}>
            <div style={{ width: '48px', height: '48px', borderRadius: '14px', background: 'rgba(250,36,60,0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '20px' }}>
              <Zap size={24} style={{ color: '#FA243C' }} />
            </div>
            <h3 style={{ fontSize: '18px', fontWeight: 700, marginBottom: '8px' }}>Streaming Instantáneo sin Anuncios</h3>
            <p style={{ fontSize: '14px', color: '#8E8E93', lineHeight: 1.6 }}>
              Reproducción ultrarrápida con precarga inteligente. Disfruta de millones de canciones sin cortes ni anuncios molestos.
            </p>
          </div>

          {/* Feature 2 */}
          <div style={{ background: '#121212', borderRadius: '20px', padding: '28px', border: '1px solid #242424' }}>
            <div style={{ width: '48px', height: '48px', borderRadius: '14px', background: 'rgba(52,199,89,0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '20px' }}>
              <Radio size={24} style={{ color: '#34C759' }} />
            </div>
            <h3 style={{ fontSize: '18px', fontWeight: 700, marginBottom: '8px' }}>Groovy Connect Multidispositivo</h3>
            <p style={{ fontSize: '14px', color: '#8E8E93', lineHeight: 1.6 }}>
              Cambia de canción o pausa en tu PC con Windows desde tu teléfono Android como un control remoto en tiempo real.
            </p>
          </div>

          {/* Feature 3 */}
          <div style={{ background: '#121212', borderRadius: '20px', padding: '28px', border: '1px solid #242424' }}>
            <div style={{ width: '48px', height: '48px', borderRadius: '14px', background: 'rgba(131,56,236,0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '20px' }}>
              <Sliders size={24} style={{ color: '#8338EC' }} />
            </div>
            <h3 style={{ fontSize: '18px', fontWeight: 700, marginBottom: '8px' }}>Ecualizador y Control de Tono</h3>
            <p style={{ fontSize: '14px', color: '#8E8E93', lineHeight: 1.6 }}>
              Ajusta frecuencias, refuerzo de bajos, velocidad y tono (*pitch shift*) para adaptar cada tema a tus auriculares.
            </p>
          </div>

          {/* Feature 4 */}
          <div style={{ background: '#121212', borderRadius: '20px', padding: '28px', border: '1px solid #242424' }}>
            <div style={{ width: '48px', height: '48px', borderRadius: '14px', background: 'rgba(0,122,255,0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '20px' }}>
              <Cloud size={24} style={{ color: '#007AFF' }} />
            </div>
            <h3 style={{ fontSize: '18px', fontWeight: 700, marginBottom: '8px' }}>Sincronización en la Nube</h3>
            <p style={{ fontSize: '14px', color: '#8E8E93', lineHeight: 1.6 }}>
              Tus listas de reproducción, favoritos e historial de escucha se respaldan automáticamente en la nube con base de datos MySQL en vivo.
            </p>
          </div>

          {/* Feature 5 */}
          <div style={{ background: '#121212', borderRadius: '20px', padding: '28px', border: '1px solid #242424' }}>
            <div style={{ width: '48px', height: '48px', borderRadius: '14px', background: 'rgba(255,149,0,0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '20px' }}>
              <Download size={24} style={{ color: '#FF9500' }} />
            </div>
            <h3 style={{ fontSize: '18px', fontWeight: 700, marginBottom: '8px' }}>Descargas y Modo Sin Conexión</h3>
            <p style={{ fontSize: '14px', color: '#8E8E93', lineHeight: 1.6 }}>
              Descarga canciones completas o álbumes a tu almacenamiento local para escuchar sin internet cuando viajes.
            </p>
          </div>

          {/* Feature 6 */}
          <div style={{ background: '#121212', borderRadius: '20px', padding: '28px', border: '1px solid #242424' }}>
            <div style={{ width: '48px', height: '48px', borderRadius: '14px', background: 'rgba(255,45,85,0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '20px' }}>
              <ShieldCheck size={24} style={{ color: '#FF2D55' }} />
            </div>
            <h3 style={{ fontSize: '18px', fontWeight: 700, marginBottom: '8px' }}>Código Seguro y Firma Digital</h3>
            <p style={{ fontSize: '14px', color: '#8E8E93', lineHeight: 1.6 }}>
              Binarios firmados digitalmente con Authenticode y manifiestos de seguridad integrados, listos para Windows 11 y Android 15.
            </p>
          </div>
        </div>
      </section>

      {/* 5. COMPARISON SECTION */}
      <section id="comparativa" style={{ padding: '80px 24px', background: '#0A0A0A', borderTop: '1px solid #1c1c1e' }}>
        <div style={{ maxWidth: '900px', margin: '0 auto' }}>
          <div style={{ textAlign: 'center', marginBottom: '40px' }}>
            <h2 style={{ fontSize: '32px', fontWeight: 800, letterSpacing: '-0.5px' }}>
              ¿Por qué elegir Groovy?
            </h2>
            <p style={{ fontSize: '15px', color: '#8E8E93', marginTop: '6px' }}>
              Compara Groovy con las versiones gratuitas de otros servicios populares.
            </p>
          </div>

          <div style={{ background: '#141414', borderRadius: '20px', border: '1px solid #282828', overflow: 'hidden' }}>
            <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr 1fr', padding: '18px 24px', background: '#1c1c1e', fontWeight: 700, fontSize: '13px', color: '#8E8E93', borderBottom: '1px solid #282828' }}>
              <div>Característica</div>
              <div style={{ color: '#FA243C', textAlign: 'center' }}>Groovy Music</div>
              <div style={{ textAlign: 'center' }}>Spotify / YT Free</div>
            </div>

            {[
              { label: 'Publicidad / Anuncios', groovy: 'Sin anuncios', others: 'Con anuncios frecuentes' },
              { label: 'Saltos de canciones', groovy: 'Ilimitados', others: 'Limitados (6 por hora)' },
              { label: 'Calidad de audio', groovy: 'Hasta 320 kbps Hi-Fi', others: '128 - 160 kbps' },
              { label: 'Control Multidispositivo', groovy: 'Incluido (Groovy Connect)', others: 'Solo Premium' },
              { label: 'Ecualizador paramétrico y tono', groovy: 'Totalmente libre', others: 'Básico / Bloqueado' },
              { label: 'Descargas para escuchar offline', groovy: 'Disponibles gratis', others: 'Solo Premium de pago' },
              { label: 'Costo mensual', groovy: '$0.00 (Gratuito)', others: '$10.99 / mes' },
            ].map((row, idx) => (
              <div
                key={idx}
                style={{
                  display: 'grid',
                  gridTemplateColumns: '2fr 1fr 1fr',
                  padding: '16px 24px',
                  borderBottom: idx < 6 ? '1px solid #1f1f1f' : 'none',
                  fontSize: '13px',
                  alignItems: 'center',
                }}
              >
                <div style={{ fontWeight: 600, color: '#fff' }}>{row.label}</div>
                <div style={{ textAlign: 'center', color: '#34C759', fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '4px' }}>
                  <Check size={16} />
                  <span>{row.groovy}</span>
                </div>
                <div style={{ textAlign: 'center', color: '#6B6B6B' }}>{row.others}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* 6. CALL TO ACTION FOOTER */}
      <section style={{ padding: '80px 24px', textAlign: 'center', position: 'relative', overflow: 'hidden' }}>
        <div style={{ maxWidth: '640px', margin: '0 auto' }}>
          <h2 style={{ fontSize: 'clamp(28px, 4vw, 40px)', fontWeight: 800, letterSpacing: '-0.8px', marginBottom: '16px' }}>
            Empieza a escuchar tu música hoy
          </h2>
          <p style={{ fontSize: '15px', color: '#8E8E93', marginBottom: '32px' }}>
            Descarga las aplicaciones oficiales o reproduce directamente en tu navegador web.
          </p>

          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '14px', flexWrap: 'wrap' }}>
            <a
              href="#descargas"
              style={{
                padding: '14px 32px', borderRadius: '16px',
                background: 'linear-gradient(135deg, #FA243C 0%, #FF4D67 100%)',
                color: '#fff', fontSize: '15px', fontWeight: 700,
                textDecoration: 'none', boxShadow: '0 8px 24px rgba(250,36,60,0.4)',
              }}
            >
              Descargar Instaladores
            </a>
            <button
              onClick={onOpenPlayer}
              style={{
                padding: '14px 28px', borderRadius: '16px',
                background: '#282828', border: '1px solid #404040',
                color: '#fff', fontSize: '15px', fontWeight: 700,
                cursor: 'pointer',
              }}
            >
              Abrir Reproductor Web
            </button>
          </div>
        </div>
      </section>

      {/* FOOTER */}
      <footer style={{ background: '#050505', borderTop: '1px solid #1c1c1e', padding: '32px 24px', fontSize: '13px', color: '#6B6B6B' }}>
        <div style={{ maxWidth: '1200px', margin: '0 auto', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '16px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <img src="./logo.png" alt="Groovy" style={{ width: '22px', height: '22px', borderRadius: '6px' }} />
            <span style={{ color: '#fff', fontWeight: 700 }}>Groovy Music</span>
            <span>• Desarrollado por Danx016</span>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
            <a href={`https://github.com/${GITHUB_REPO}`} target="_blank" rel="noreferrer" style={{ color: '#B3B3B3', textDecoration: 'none' }}>
              GitHub Repo
            </a>
            <a href={GITHUB_RELEASES_PAGE} target="_blank" rel="noreferrer" style={{ color: '#B3B3B3', textDecoration: 'none' }}>
              Releases
            </a>
            <button onClick={onOpenAdmin} style={{ color: '#B3B3B3', background: 'transparent', border: 'none', cursor: 'pointer', fontSize: '13px' }}>
              Panel Admin
            </button>
          </div>
        </div>
      </footer>
    </div>
  );
};
