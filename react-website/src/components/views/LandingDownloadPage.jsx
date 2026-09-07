import React, { useState, useEffect } from 'react';
import {
  Download,
  Laptop,
  Smartphone,
  Globe,
  Radio,
  Music,
  Sliders,
  Check,
  ChevronDown,
  Github,
  Play,
  ArrowRight,
  HardDrive,
  Sparkles,
  ExternalLink,
  Shield,
  Layers,
  FileText
} from 'lucide-react';

const GITHUB_REPO = 'Danx016/Groovy';
const GITHUB_API_RELEASE = `https://api.github.com/repos/${GITHUB_REPO}/releases/latest`;
const GITHUB_RELEASES_PAGE = `https://github.com/${GITHUB_REPO}/releases`;

export const LandingDownloadPage = ({ onOpenPlayer, onOpenAdmin }) => {
  const [releaseInfo, setReleaseInfo] = useState(null);
  const [isLoadingRelease, setIsLoadingRelease] = useState(true);
  const [userOS, setUserOS] = useState('windows');
  const [activeScreenshotTab, setActiveScreenshotTab] = useState(0);
  const [showSmartScreenGuide, setShowSmartScreenGuide] = useState(false);

  // Detect user OS
  useEffect(() => {
    const ua = navigator.userAgent || navigator.vendor || window.opera || '';
    if (/android/i.test(ua)) {
      setUserOS('android');
    } else if (/windows|win32|win64/i.test(ua)) {
      setUserOS('windows');
    } else if (/linux/i.test(ua)) {
      setUserOS('linux');
    } else if (/macintosh|mac os x/i.test(ua)) {
      setUserOS('mac');
    } else {
      setUserOS('windows');
    }
  }, []);

  // Fetch real release info from GitHub
  useEffect(() => {
    let isMounted = true;
    async function fetchRelease() {
      setIsLoadingRelease(true);
      try {
        const res = await fetch(GITHUB_API_RELEASE, {
          headers: { Accept: 'application/vnd.github.v3+json' },
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        if (isMounted) setReleaseInfo(data);
      } catch (err) {
        if (isMounted) {
          setReleaseInfo({
            tag_name: 'v1.0.65',
            name: 'Groovy v1.0.65',
            published_at: new Date().toISOString(),
            html_url: GITHUB_RELEASES_PAGE,
            assets: [
              {
                name: 'Groovy-Setup.exe',
                browser_download_url: `https://github.com/${GITHUB_REPO}/releases/latest/download/Groovy-Setup.exe`,
                size: 38709480,
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
              {
                name: 'groovy-linux-x64.tar.gz',
                browser_download_url: `https://github.com/${GITHUB_REPO}/releases/latest/download/groovy-linux-x64.tar.gz`,
                size: 42000000,
              },
            ],
          });
        }
      } finally {
        if (isMounted) setIsLoadingRelease(false);
      }
    }

    fetchRelease();
    return () => {
      isMounted = false;
    };
  }, []);

  const formatSize = (bytes) => {
    if (!bytes) return '';
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  };

  const getAsset = (pattern) => {
    if (!releaseInfo?.assets) return null;
    return releaseInfo.assets.find((a) =>
      a.name.toLowerCase().includes(pattern.toLowerCase())
    );
  };

  const windowsExe = getAsset('setup') || getAsset('.exe') || {
    name: 'Groovy-Setup.exe',
    browser_download_url: `https://github.com/${GITHUB_REPO}/releases/latest/download/Groovy-Setup.exe`,
    size: 38709480,
  };

  const windowsZip = getAsset('portable') || getAsset('windows') || {
    name: 'Groovy-Windows-Portable.zip',
    browser_download_url: `https://github.com/${GITHUB_REPO}/releases/latest/download/Groovy-Windows-Portable.zip`,
    size: 45068261,
  };

  const androidApk = getAsset('app-release') || getAsset('.apk') || {
    name: 'app-release.apk',
    browser_download_url: `https://github.com/${GITHUB_REPO}/releases/latest/download/app-release.apk`,
    size: 32400000,
  };

  const linuxTar = getAsset('linux') || getAsset('.tar.gz') || {
    name: 'groovy-linux-x64.tar.gz',
    browser_download_url: `https://github.com/${GITHUB_REPO}/releases/latest/download/groovy-linux-x64.tar.gz`,
    size: 42000000,
  };

  const versionTag = releaseInfo?.tag_name || 'v1.0.65';

  const screenshots = [
    {
      title: 'Reproductor & Biblioteca',
      desc: 'Interfaz oscura, navegación fluida a 120 FPS y acceso a millones de canciones sin interrupciones.',
      src: './screenshots/Screenshot_20260101_024726.png',
    },
    {
      title: 'Letras en Tiempo Real',
      desc: 'Seguimiento sincronizado verso a verso con tipografía interactiva estilo karaoke.',
      src: './screenshots/Screenshot_20260101_024746.png',
    },
    {
      title: 'Groovy Connect',
      desc: 'Controla la reproducción de tu PC directamente desde tu teléfono móvil en tiempo real.',
      src: './screenshots/Screenshot_20260101_024751.png',
    },
    {
      title: 'Ecualizador & Audio FX',
      desc: '10 bandas de ecualización, refuerzo de graves y ajuste dinámico de tono y velocidad.',
      src: './screenshots/Screenshot_20260101_024803.png',
    },
  ];

  return (
    <div style={{ minHeight: '100vh', background: '#09090b', color: '#f4f4f5', fontFamily: 'Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif' }}>
      
      {/* 1. MINIMAL NAVBAR */}
      <header
        style={{
          position: 'sticky',
          top: 0,
          zIndex: 100,
          background: 'rgba(9, 9, 11, 0.8)',
          backdropFilter: 'blur(16px)',
          borderBottom: '1px solid rgba(255, 255, 255, 0.08)',
          padding: '0 28px',
          height: '60px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '32px' }}>
          <div
            style={{ display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer' }}
            onClick={onOpenPlayer}
          >
            <div style={{ width: '32px', height: '32px', borderRadius: '8px', overflow: 'hidden' }}>
              <img src="./logo.png" alt="Groovy" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
            </div>
            <span style={{ fontSize: '17px', fontWeight: 700, letterSpacing: '-0.3px', color: '#ffffff' }}>
              Groovy
            </span>
          </div>

          <nav style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
            <a href="#descargas" style={{ color: '#a1a1aa', textDecoration: 'none', fontSize: '13px', fontWeight: 500, transition: 'color 0.15s' }} onMouseEnter={e => e.currentTarget.style.color = '#fff'} onMouseLeave={e => e.currentTarget.style.color = '#a1a1aa'}>
              Descargas
            </a>
            <a href="#funciones" style={{ color: '#a1a1aa', textDecoration: 'none', fontSize: '13px', fontWeight: 500, transition: 'color 0.15s' }} onMouseEnter={e => e.currentTarget.style.color = '#fff'} onMouseLeave={e => e.currentTarget.style.color = '#a1a1aa'}>
              Características
            </a>
            <a href="#capturas" style={{ color: '#a1a1aa', textDecoration: 'none', fontSize: '13px', fontWeight: 500, transition: 'color 0.15s' }} onMouseEnter={e => e.currentTarget.style.color = '#fff'} onMouseLeave={e => e.currentTarget.style.color = '#a1a1aa'}>
              Capturas
            </a>
          </nav>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <a
            href={`https://github.com/${GITHUB_REPO}`}
            target="_blank"
            rel="noreferrer"
            style={{
              display: 'flex', alignItems: 'center', gap: '6px',
              padding: '6px 12px', borderRadius: '8px',
              background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)',
              color: '#d4d4d8', fontSize: '12px', fontWeight: 500,
              textDecoration: 'none', transition: 'background 0.15s',
            }}
            onMouseEnter={e => e.currentTarget.style.background = 'rgba(255,255,255,0.1)'}
            onMouseLeave={e => e.currentTarget.style.background = 'rgba(255,255,255,0.05)'}
          >
            <Github size={14} />
            <span>GitHub</span>
          </a>

          <button
            onClick={onOpenPlayer}
            style={{
              display: 'flex', alignItems: 'center', gap: '6px',
              padding: '6px 14px', borderRadius: '8px',
              background: '#fa2d48', border: 'none',
              color: '#ffffff', fontSize: '12px', fontWeight: 600,
              cursor: 'pointer', transition: 'opacity 0.15s',
            }}
            onMouseEnter={e => e.currentTarget.style.opacity = '0.9'}
            onMouseLeave={e => e.currentTarget.style.opacity = '1'}
          >
            <Play size={12} fill="#ffffff" />
            <span>Web Player</span>
          </button>
        </div>
      </header>

      {/* 2. HERO SECTION */}
      <section style={{ maxWidth: '1080px', margin: '0 auto', padding: '72px 24px 48px', textAlign: 'center' }}>
        
        {/* Release Pill */}
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: '8px', padding: '4px 12px', borderRadius: '16px', background: 'rgba(250, 45, 72, 0.1)', border: '1px solid rgba(250, 45, 72, 0.25)', marginBottom: '20px' }}>
          <span style={{ fontSize: '11px', fontWeight: 600, color: '#fa2d48' }}>Versión {versionTag}</span>
          <span style={{ color: 'rgba(255,255,255,0.2)' }}>•</span>
          <span style={{ fontSize: '11px', color: '#a1a1aa' }}>Actualizado automáticamente</span>
        </div>

        {/* Main Headline */}
        <h1 style={{ fontSize: 'clamp(32px, 5vw, 56px)', fontWeight: 800, letterSpacing: '-1px', lineHeight: 1.15, margin: '0 auto 16px', maxWidth: '820px' }}>
          Música sin anuncios.<br />
          <span style={{ color: '#fa2d48' }}>En todos tus dispositivos.</span>
        </h1>

        {/* Subtitle */}
        <p style={{ fontSize: 'clamp(15px, 2vw, 18px)', color: '#a1a1aa', maxWidth: '640px', margin: '0 auto 36px', lineHeight: 1.6 }}>
          Reproductor de música de alto rendimiento. Audio de alta fidelidad, sincronización multidispositivo con Groovy Connect y soporte para Windows, Android y Web.
        </p>

        {/* Main CTA Action */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '12px', flexWrap: 'wrap', marginBottom: '32px' }}>
          {userOS === 'windows' && (
            <a
              href={windowsExe.browser_download_url}
              style={{
                display: 'inline-flex', alignItems: 'center', gap: '10px',
                padding: '14px 28px', borderRadius: '12px',
                background: '#fa2d48', color: '#ffffff',
                fontSize: '15px', fontWeight: 600, textDecoration: 'none',
                boxShadow: '0 4px 20px rgba(250, 45, 72, 0.3)',
                transition: 'transform 0.15s, background 0.15s',
              }}
              onMouseEnter={e => { e.currentTarget.style.transform = 'translateY(-1px)'; e.currentTarget.style.background = '#e0243d'; }}
              onMouseLeave={e => { e.currentTarget.style.transform = 'translateY(0)'; e.currentTarget.style.background = '#fa2d48'; }}
            >
              <Laptop size={18} />
              <span>Descargar para Windows ({formatSize(windowsExe.size) || '38.7 MB'})</span>
            </a>
          )}

          {userOS === 'android' && (
            <a
              href={androidApk.browser_download_url}
              style={{
                display: 'inline-flex', alignItems: 'center', gap: '10px',
                padding: '14px 28px', borderRadius: '12px',
                background: '#22c55e', color: '#000000',
                fontSize: '15px', fontWeight: 700, textDecoration: 'none',
                boxShadow: '0 4px 20px rgba(34, 197, 94, 0.25)',
                transition: 'transform 0.15s, background 0.15s',
              }}
              onMouseEnter={e => { e.currentTarget.style.transform = 'translateY(-1px)'; }}
              onMouseLeave={e => { e.currentTarget.style.transform = 'translateY(0)'; }}
            >
              <Smartphone size={18} />
              <span>Descargar APK para Android ({formatSize(androidApk.size) || '32.4 MB'})</span>
            </a>
          )}

          <a
            href="#descargas"
            style={{
              display: 'inline-flex', alignItems: 'center', gap: '8px',
              padding: '14px 22px', borderRadius: '12px',
              background: 'rgba(255,255,255,0.06)', border: '1px solid rgba(255,255,255,0.12)',
              color: '#f4f4f5', fontSize: '14px', fontWeight: 500,
              textDecoration: 'none', transition: 'background 0.15s',
            }}
            onMouseEnter={e => e.currentTarget.style.background = 'rgba(255,255,255,0.1)'}
            onMouseLeave={e => e.currentTarget.style.background = 'rgba(255,255,255,0.06)'}
          >
            <Download size={16} />
            <span>Otras plataformas</span>
          </a>

          <button
            onClick={onOpenPlayer}
            style={{
              display: 'inline-flex', alignItems: 'center', gap: '8px',
              padding: '14px 22px', borderRadius: '12px',
              background: 'transparent', border: '1px solid rgba(255,255,255,0.12)',
              color: '#a1a1aa', fontSize: '14px', fontWeight: 500,
              cursor: 'pointer', transition: 'color 0.15s, border-color 0.15s',
            }}
            onMouseEnter={e => { e.currentTarget.style.color = '#fff'; e.currentTarget.style.borderColor = 'rgba(255,255,255,0.3)'; }}
            onMouseLeave={e => { e.currentTarget.style.color = '#a1a1aa'; e.currentTarget.style.borderColor = 'rgba(255,255,255,0.12)'; }}
          >
            <Globe size={16} />
            <span>Abrir en Navegador</span>
          </button>
        </div>

        {/* Feature Highlights Pills */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '24px', flexWrap: 'wrap', fontSize: '13px', color: '#71717a' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <Check size={14} style={{ color: '#22c55e' }} />
            <span>Gratis y sin publicidad</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <Check size={14} style={{ color: '#22c55e' }} />
            <span>Audio en alta fidelidad</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <Check size={14} style={{ color: '#22c55e' }} />
            <span>Control multidispositivo</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <Check size={14} style={{ color: '#22c55e' }} />
            <span>Reproducción offline</span>
          </div>
        </div>

      </section>

      {/* 3. REAL APP SHOWCASE / SCREENSHOTS SECTION */}
      <section id="capturas" style={{ maxWidth: '1080px', margin: '0 auto', padding: '32px 24px 64px' }}>
        
        {/* Screenshot Tab Selector */}
        <div style={{ display: 'flex', justifyContent: 'center', gap: '8px', marginBottom: '24px', flexWrap: 'wrap' }}>
          {screenshots.map((s, idx) => (
            <button
              key={idx}
              onClick={() => setActiveScreenshotTab(idx)}
              style={{
                padding: '8px 16px', borderRadius: '10px',
                background: activeScreenshotTab === idx ? 'rgba(250, 45, 72, 0.15)' : 'rgba(255,255,255,0.04)',
                border: activeScreenshotTab === idx ? '1px solid rgba(250, 45, 72, 0.4)' : '1px solid rgba(255,255,255,0.06)',
                color: activeScreenshotTab === idx ? '#fa2d48' : '#a1a1aa',
                fontSize: '13px', fontWeight: 600,
                cursor: 'pointer', transition: 'all 0.15s',
              }}
            >
              {s.title}
            </button>
          ))}
        </div>

        {/* Screenshot Frame */}
        <div
          style={{
            background: '#121215',
            borderRadius: '16px',
            border: '1px solid rgba(255,255,255,0.08)',
            boxShadow: '0 24px 48px -12px rgba(0,0,0,0.8)',
            overflow: 'hidden',
          }}
        >
          {/* Header of frame */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px 18px', borderBottom: '1px solid rgba(255,255,255,0.06)', background: 'rgba(0,0,0,0.3)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <div style={{ width: '10px', height: '10px', borderRadius: '50%', background: '#ef4444' }} />
              <div style={{ width: '10px', height: '10px', borderRadius: '50%', background: '#f59e0b' }} />
              <div style={{ width: '10px', height: '10px', borderRadius: '50%', background: '#10b981' }} />
              <span style={{ fontSize: '12px', color: '#71717a', marginLeft: '10px', fontWeight: 500 }}>
                Groovy — {screenshots[activeScreenshotTab].title}
              </span>
            </div>
            <span style={{ fontSize: '11px', color: '#52525b' }}>
              {screenshots[activeScreenshotTab].desc}
            </span>
          </div>

          {/* Screenshot image */}
          <div style={{ position: 'relative', width: '100%', maxHeight: '560px', overflow: 'hidden', display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#09090b' }}>
            <img
              src={screenshots[activeScreenshotTab].src}
              alt={screenshots[activeScreenshotTab].title}
              style={{ width: '100%', height: 'auto', maxHeight: '560px', objectFit: 'contain', display: 'block' }}
            />
          </div>
        </div>
      </section>

      {/* 4. DOWNLOADS MATRIX (Directly connected to GitHub Releases) */}
      <section id="descargas" style={{ padding: '64px 24px', background: '#0c0c0e', borderTop: '1px solid rgba(255,255,255,0.06)', borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
        <div style={{ maxWidth: '1080px', margin: '0 auto' }}>
          
          <div style={{ textAlign: 'center', marginBottom: '40px' }}>
            <h2 style={{ fontSize: '28px', fontWeight: 700, letterSpacing: '-0.5px', marginBottom: '8px' }}>
              Descarga Groovy
            </h2>
            <p style={{ fontSize: '14px', color: '#71717a' }}>
              Versión estable {versionTag} disponible para las principales plataformas
            </p>
          </div>

          {/* Platform Cards Grid */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '16px', marginBottom: '32px' }}>
            
            {/* Windows Setup Card */}
            <div style={{ background: '#141417', borderRadius: '12px', border: userOS === 'windows' ? '1px solid rgba(250, 45, 72, 0.5)' : '1px solid rgba(255,255,255,0.06)', padding: '20px', display: 'flex', flexDirection: 'column' }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '14px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <Laptop size={20} style={{ color: '#38bdf8' }} />
                  <span style={{ fontSize: '15px', fontWeight: 600 }}>Windows Setup</span>
                </div>
                {userOS === 'windows' && (
                  <span style={{ fontSize: '10px', background: 'rgba(250, 45, 72, 0.15)', color: '#fa2d48', padding: '2px 6px', borderRadius: '4px', fontWeight: 600 }}>
                    Tu sistema
                  </span>
                )}
              </div>
              <p style={{ fontSize: '12px', color: '#71717a', lineHeight: 1.5, marginBottom: '16px', flex: 1 }}>
                Instalador con asistente y accesos directos. Se actualiza de forma automática.
              </p>
              <div style={{ fontSize: '11px', color: '#52525b', marginBottom: '12px' }}>
                <code>Groovy-Setup.exe</code> • {formatSize(windowsExe.size) || '38.7 MB'}
              </div>
              <a
                href={windowsExe.browser_download_url}
                style={{
                  display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px',
                  padding: '10px', borderRadius: '8px',
                  background: '#fa2d48', color: '#ffffff',
                  fontSize: '13px', fontWeight: 600, textDecoration: 'none',
                }}
              >
                <Download size={14} />
                <span>Descargar .exe</span>
              </a>
            </div>

            {/* Windows Portable Card */}
            <div style={{ background: '#141417', borderRadius: '12px', border: '1px solid rgba(255,255,255,0.06)', padding: '20px', display: 'flex', flexDirection: 'column' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '14px' }}>
                <HardDrive size={20} style={{ color: '#fbbf24' }} />
                <span style={{ fontSize: '15px', fontWeight: 600 }}>Windows Portable</span>
              </div>
              <p style={{ fontSize: '12px', color: '#71717a', lineHeight: 1.5, marginBottom: '16px', flex: 1 }}>
                Versión comprimida lista para usar sin necesidad de instalación ni permisos especiales.
              </p>
              <div style={{ fontSize: '11px', color: '#52525b', marginBottom: '12px' }}>
                <code>Groovy-Windows-Portable.zip</code> • {formatSize(windowsZip.size) || '45.0 MB'}
              </div>
              <a
                href={windowsZip.browser_download_url}
                style={{
                  display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px',
                  padding: '10px', borderRadius: '8px',
                  background: 'rgba(255,255,255,0.08)', color: '#f4f4f5',
                  fontSize: '13px', fontWeight: 500, textDecoration: 'none',
                }}
              >
                <Download size={14} />
                <span>Descargar .zip</span>
              </a>
            </div>

            {/* Android APK Card */}
            <div style={{ background: '#141417', borderRadius: '12px', border: userOS === 'android' ? '1px solid rgba(34, 197, 94, 0.5)' : '1px solid rgba(255,255,255,0.06)', padding: '20px', display: 'flex', flexDirection: 'column' }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '14px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <Smartphone size={20} style={{ color: '#22c55e' }} />
                  <span style={{ fontSize: '15px', fontWeight: 600 }}>Android APK</span>
                </div>
                {userOS === 'android' && (
                  <span style={{ fontSize: '10px', background: 'rgba(34, 197, 94, 0.15)', color: '#22c55e', padding: '2px 6px', borderRadius: '4px', fontWeight: 600 }}>
                    Tu sistema
                  </span>
                )}
              </div>
              <p style={{ fontSize: '12px', color: '#71717a', lineHeight: 1.5, marginBottom: '16px', flex: 1 }}>
                APK universal compatible con Android 7.0+. Soporta reproducción en segundo plano y Android Auto.
              </p>
              <div style={{ fontSize: '11px', color: '#52525b', marginBottom: '12px' }}>
                <code>app-release.apk</code> • {formatSize(androidApk.size) || '32.4 MB'}
              </div>
              <a
                href={androidApk.browser_download_url}
                style={{
                  display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px',
                  padding: '10px', borderRadius: '8px',
                  background: '#22c55e', color: '#000000',
                  fontSize: '13px', fontWeight: 600, textDecoration: 'none',
                }}
              >
                <Download size={14} />
                <span>Descargar APK</span>
              </a>
            </div>

            {/* Linux Package Card */}
            <div style={{ background: '#141417', borderRadius: '12px', border: '1px solid rgba(255,255,255,0.06)', padding: '20px', display: 'flex', flexDirection: 'column' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '14px' }}>
                <Layers size={20} style={{ color: '#a78bfa' }} />
                <span style={{ fontSize: '15px', fontWeight: 600 }}>Linux x64</span>
              </div>
              <p style={{ fontSize: '12px', color: '#71717a', lineHeight: 1.5, marginBottom: '16px', flex: 1 }}>
                Paquete binario para distribuciones Linux x64 con integración MPRIS nativa.
              </p>
              <div style={{ fontSize: '11px', color: '#52525b', marginBottom: '12px' }}>
                <code>groovy-linux-x64.tar.gz</code> • {formatSize(linuxTar.size) || '42.0 MB'}
              </div>
              <a
                href={linuxTar.browser_download_url}
                style={{
                  display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px',
                  padding: '10px', borderRadius: '8px',
                  background: 'rgba(255,255,255,0.08)', color: '#f4f4f5',
                  fontSize: '13px', fontWeight: 500, textDecoration: 'none',
                }}
              >
                <Download size={14} />
                <span>Descargar tar.gz</span>
              </a>
            </div>

          </div>

          {/* Windows SmartScreen Quick Tip Accordion */}
          <div style={{ background: '#121215', borderRadius: '10px', border: '1px solid rgba(255,255,255,0.06)', overflow: 'hidden' }}>
            <button
              onClick={() => setShowSmartScreenGuide(!showSmartScreenGuide)}
              style={{
                width: '100%', padding: '14px 18px',
                display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                background: 'none', border: 'none', color: '#a1a1aa',
                fontSize: '13px', fontWeight: 500, cursor: 'pointer', textAlign: 'left',
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Shield size={16} style={{ color: '#60a5fa' }} />
                <span>¿Primera vez ejecutando el instalador en Windows? Haz clic aquí para ver instrucciones</span>
              </div>
              <ChevronDown size={16} style={{ transform: showSmartScreenGuide ? 'rotate(180deg)' : 'rotate(0deg)', transition: 'transform 0.2s' }} />
            </button>

            {showSmartScreenGuide && (
              <div style={{ padding: '0 18px 18px', borderTop: '1px solid rgba(255,255,255,0.04)', fontSize: '13px', color: '#a1a1aa', lineHeight: 1.6 }}>
                <p style={{ margin: '12px 0 8px', color: '#d4d4d8' }}>
                  Al ser un software nuevo, Windows SmartScreen puede mostrar una advertencia de protección preventiva. Para abrirlo:
                </p>
                <ol style={{ margin: 0, paddingLeft: '20px' }}>
                  <li>Haz clic en <strong>"Más información"</strong> en la ventana azul.</li>
                  <li>Selecciona <strong>"Ejecutar de todas formas"</strong>.</li>
                  <li>O bien, utiliza la versión <strong>Windows Portable (.zip)</strong> para ejecutarlo sin asistente.</li>
                </ol>
              </div>
            )}
          </div>

        </div>
      </section>

      {/* 5. CORE FEATURES (Simple & Direct) */}
      <section id="funciones" style={{ maxWidth: '1080px', margin: '0 auto', padding: '64px 24px' }}>
        <div style={{ textAlign: 'center', marginBottom: '40px' }}>
          <h2 style={{ fontSize: '28px', fontWeight: 700, letterSpacing: '-0.5px', marginBottom: '8px' }}>
            Diseñado para amantes de la música
          </h2>
          <p style={{ fontSize: '14px', color: '#71717a' }}>
            Todas las herramientas necesarias para escuchar sin restricciones
          </p>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '20px' }}>
          
          <div style={{ background: '#121215', borderRadius: '12px', border: '1px solid rgba(255,255,255,0.06)', padding: '24px' }}>
            <div style={{ width: '36px', height: '36px', borderRadius: '8px', background: 'rgba(250, 45, 72, 0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '16px' }}>
              <Radio size={18} style={{ color: '#fa2d48' }} />
            </div>
            <h3 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px', color: '#f4f4f5' }}>Groovy Connect</h3>
            <p style={{ fontSize: '13px', color: '#71717a', lineHeight: 1.5 }}>
              Controla lo que suena en tu ordenador desde tu teléfono móvil o transfiere la sesión sin cortar la canción.
            </p>
          </div>

          <div style={{ background: '#121215', borderRadius: '12px', border: '1px solid rgba(255,255,255,0.06)', padding: '24px' }}>
            <div style={{ width: '36px', height: '36px', borderRadius: '8px', background: 'rgba(56, 189, 248, 0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '16px' }}>
              <Music size={18} style={{ color: '#38bdf8' }} />
            </div>
            <h3 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px', color: '#f4f4f5' }}>Letras en Vivo</h3>
            <p style={{ fontSize: '13px', color: '#71717a', lineHeight: 1.5 }}>
              Sigue la letra sincronizada verso a verso en tiempo real con opción de traducción e interacción dinámica.
            </p>
          </div>

          <div style={{ background: '#121215', borderRadius: '12px', border: '1px solid rgba(255,255,255,0.06)', padding: '24px' }}>
            <div style={{ width: '36px', height: '36px', borderRadius: '8px', background: 'rgba(251, 191, 36, 0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '16px' }}>
              <Sliders size={18} style={{ color: '#fbbf24' }} />
            </div>
            <h3 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px', color: '#f4f4f5' }}>Ecualizador de 10 Bandas</h3>
            <p style={{ fontSize: '13px', color: '#71717a', lineHeight: 1.5 }}>
              Personaliza el audio a tu gusto con refuerzo de frecuencias bajas, modulación de tono (pitch) y velocidad.
            </p>
          </div>

          <div style={{ background: '#121215', borderRadius: '12px', border: '1px solid rgba(255,255,255,0.06)', padding: '24px' }}>
            <div style={{ width: '36px', height: '36px', borderRadius: '8px', background: 'rgba(34, 197, 94, 0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '16px' }}>
              <Download size={18} style={{ color: '#22c55e' }} />
            </div>
            <h3 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px', color: '#f4f4f5' }}>Modo Sin Conexión</h3>
            <p style={{ fontSize: '13px', color: '#71717a', lineHeight: 1.5 }}>
              Descarga canciones y listas completas en almacenamiento local para escucharlas en cualquier viaje sin gastar datos.
            </p>
          </div>

        </div>
      </section>

      {/* 6. MINIMAL FOOTER */}
      <footer style={{ borderTop: '1px solid rgba(255,255,255,0.06)', padding: '36px 24px', background: '#09090b', textAlign: 'center', fontSize: '13px', color: '#52525b' }}>
        <div style={{ maxWidth: '1080px', margin: '0 auto', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '16px' }}>
          
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <img src="./logo.png" alt="Groovy" style={{ width: '20px', height: '20px', borderRadius: '4px' }} />
            <span style={{ color: '#a1a1aa', fontWeight: 600 }}>Groovy Music</span>
            <span>— Software libre bajo licencia GPL-3.0</span>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
            <button onClick={onOpenPlayer} style={{ background: 'none', border: 'none', color: '#a1a1aa', cursor: 'pointer', fontSize: '13px' }}>
              Web Player
            </button>
            <a href={`https://github.com/${GITHUB_REPO}`} target="_blank" rel="noreferrer" style={{ color: '#a1a1aa', textDecoration: 'none' }}>
              GitHub
            </a>
            <a href={`https://github.com/${GITHUB_REPO}/releases`} target="_blank" rel="noreferrer" style={{ color: '#a1a1aa', textDecoration: 'none' }}>
              Releases ({versionTag})
            </a>
          </div>

        </div>
      </footer>

    </div>
  );
};

export default LandingDownloadPage;
