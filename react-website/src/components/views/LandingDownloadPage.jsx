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
  FileText,
  Volume2,
  Zap,
  Cloud,
  Headphones,
  CheckCircle2,
  RefreshCw,
  HelpCircle
} from 'lucide-react';

const GITHUB_REPO = 'Danx016/Groovy';
const GITHUB_API_RELEASE = `https://api.github.com/repos/${GITHUB_REPO}/releases/latest`;
const GITHUB_RELEASES_PAGE = `https://github.com/${GITHUB_REPO}/releases`;

export const LandingDownloadPage = ({ onOpenPlayer, onOpenAdmin }) => {
  const [releaseInfo, setReleaseInfo] = useState(null);
  const [isLoadingRelease, setIsLoadingRelease] = useState(true);
  const [userOS, setUserOS] = useState('windows');
  const [activePlatformTab, setActivePlatformTab] = useState('desktop');
  const [openFaq, setOpenFaq] = useState(null);
  const [showSmartScreenGuide, setShowSmartScreenGuide] = useState(false);

  // Detect user OS
  useEffect(() => {
    const ua = navigator.userAgent || navigator.vendor || window.opera || '';
    if (/android/i.test(ua)) {
      setUserOS('android');
      setActivePlatformTab('mobile');
    } else if (/windows|win32|win64/i.test(ua)) {
      setUserOS('windows');
      setActivePlatformTab('desktop');
    } else if (/linux/i.test(ua)) {
      setUserOS('linux');
      setActivePlatformTab('desktop');
    } else if (/macintosh|mac os x/i.test(ua)) {
      setUserOS('mac');
      setActivePlatformTab('desktop');
    } else {
      setUserOS('windows');
      setActivePlatformTab('desktop');
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
            tag_name: 'v1.0.76',
            name: 'Groovy v1.0.76',
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

  const scrollToSection = (e, sectionId) => {
    if (e && e.preventDefault) e.preventDefault();
    const el = document.getElementById(sectionId);
    if (el) {
      el.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  };

  const versionTag = releaseInfo?.tag_name || 'v1.0.76';

  const faqs = [
    {
      q: '¿Cómo instalo la aplicación en Android?',
      a: 'Descarga el archivo APK directo (app-release.apk) pulsando el botón verde. Al abrirlo, tu navegador te pedirá confirmar "Instalar aplicaciones de fuentes desconocidas". Concédele el permiso y se instalará en segundos.',
    },
    {
      q: '¿Cómo funciona Groovy Connect?',
      a: 'Inicia sesión con tu misma cuenta en tu PC y en tu móvil. Ambas aplicaciones se sincronizan automáticamente: puedes poner música en tu ordenador y cambiar de canción o subir el volumen directamente desde el teléfono.',
    },
    {
      q: '¿Dónde se guardan las descargas sin conexión?',
      a: 'Las canciones se almacenan de forma local y cifrada en el almacenamiento de tu dispositivo para que puedas escucharlas en modo avión o sin gastar tus datos móviles.',
    },
    {
      q: '¿Qué diferencia hay entre el instalador .exe y la versión .zip de Windows?',
      a: 'El instalador .exe crea accesos directos en el menú inicio y escritorio. La versión Portable .zip no requiere instalación: simplemente descomprimes la carpeta en cualquier ubicación (o memoria USB) y ejecutas groovy.exe.',
    },
  ];

  return (
    <div style={{ minHeight: '100vh', background: '#09090b', color: '#f4f4f5', fontFamily: 'Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif' }}>
      
      {/* 1. TOP NAVBAR */}
      <header
        style={{
          position: 'sticky',
          top: 0,
          zIndex: 100,
          background: 'rgba(9, 9, 11, 0.85)',
          backdropFilter: 'blur(16px)',
          borderBottom: '1px solid rgba(255, 255, 255, 0.08)',
          padding: '0 28px',
          height: '62px',
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

          <nav style={{ display: 'flex', alignItems: 'center', gap: '22px' }}>
            <a
              href="#descargas"
              onClick={(e) => scrollToSection(e, 'descargas')}
              style={{ color: '#a1a1aa', textDecoration: 'none', fontSize: '13px', fontWeight: 500, transition: 'color 0.15s', cursor: 'pointer' }}
              onMouseEnter={e => e.currentTarget.style.color = '#fff'}
              onMouseLeave={e => e.currentTarget.style.color = '#a1a1aa'}
            >
              Descargas
            </a>
            <a
              href="#interfaz"
              onClick={(e) => scrollToSection(e, 'interfaz')}
              style={{ color: '#a1a1aa', textDecoration: 'none', fontSize: '13px', fontWeight: 500, transition: 'color 0.15s', cursor: 'pointer' }}
              onMouseEnter={e => e.currentTarget.style.color = '#fff'}
              onMouseLeave={e => e.currentTarget.style.color = '#a1a1aa'}
            >
              Interfaz
            </a>
            <a
              href="#funciones"
              onClick={(e) => scrollToSection(e, 'funciones')}
              style={{ color: '#a1a1aa', textDecoration: 'none', fontSize: '13px', fontWeight: 500, transition: 'color 0.15s', cursor: 'pointer' }}
              onMouseEnter={e => e.currentTarget.style.color = '#fff'}
              onMouseLeave={e => e.currentTarget.style.color = '#a1a1aa'}
            >
              Características
            </a>
            <a
              href="#preguntas"
              onClick={(e) => scrollToSection(e, 'preguntas')}
              style={{ color: '#a1a1aa', textDecoration: 'none', fontSize: '13px', fontWeight: 500, transition: 'color 0.15s', cursor: 'pointer' }}
              onMouseEnter={e => e.currentTarget.style.color = '#fff'}
              onMouseLeave={e => e.currentTarget.style.color = '#a1a1aa'}
            >
              FAQ
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
      <section style={{ maxWidth: '1120px', margin: '0 auto', padding: '64px 24px 32px', textAlign: 'center' }}>
        
        {/* Release Tag Pill */}
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: '8px', padding: '4px 14px', borderRadius: '20px', background: 'rgba(250, 45, 72, 0.1)', border: '1px solid rgba(250, 45, 72, 0.25)', marginBottom: '24px' }}>
          <span style={{ fontSize: '11px', fontWeight: 600, color: '#fa2d48' }}>Versión {versionTag} Disponible</span>
          <span style={{ color: 'rgba(255,255,255,0.2)' }}>•</span>
          <span style={{ fontSize: '11px', color: '#a1a1aa' }}>Sincronizada con GitHub Releases</span>
        </div>

        {/* Main Headline */}
        <h1 style={{ fontSize: 'clamp(34px, 5.2vw, 60px)', fontWeight: 800, letterSpacing: '-1.2px', lineHeight: 1.12, margin: '0 auto 18px', maxWidth: '880px' }}>
          Tu música favorita sin límites.<br />
          <span style={{ color: '#fa2d48' }}>Diseñado para escritorio y móvil.</span>
        </h1>

        {/* Subtitle */}
        <p style={{ fontSize: 'clamp(15px, 2vw, 18px)', color: '#a1a1aa', maxWidth: '680px', margin: '0 auto 36px', lineHeight: 1.6 }}>
          Streaming rápido, audio de alta calidad, letras sincronizadas en tiempo real y sincronización multidispositivo con Groovy Connect.
        </p>

        {/* Main CTA Actions */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '14px', flexWrap: 'wrap', marginBottom: '36px' }}>
          {userOS === 'windows' && (
            <a
              href={windowsExe.browser_download_url}
              style={{
                display: 'inline-flex', alignItems: 'center', gap: '10px',
                padding: '14px 28px', borderRadius: '12px',
                background: '#fa2d48', color: '#ffffff',
                fontSize: '15px', fontWeight: 600, textDecoration: 'none',
                boxShadow: '0 4px 20px rgba(250, 45, 72, 0.35)',
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
                boxShadow: '0 4px 20px rgba(34, 197, 94, 0.3)',
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
            onClick={(e) => scrollToSection(e, 'descargas')}
            style={{
              display: 'inline-flex', alignItems: 'center', gap: '8px',
              padding: '14px 22px', borderRadius: '12px',
              background: 'rgba(255,255,255,0.06)', border: '1px solid rgba(255,255,255,0.12)',
              color: '#f4f4f5', fontSize: '14px', fontWeight: 500,
              textDecoration: 'none', transition: 'background 0.15s', cursor: 'pointer',
            }}
            onMouseEnter={e => e.currentTarget.style.background = 'rgba(255,255,255,0.1)'}
            onMouseLeave={e => e.currentTarget.style.background = 'rgba(255,255,255,0.06)'}
          >
            <Download size={16} />
            <span>Ver Todos los Instaladores</span>
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
            <span>Reproductor Web</span>
          </button>
        </div>

        {/* Value Props Row */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '28px', flexWrap: 'wrap', fontSize: '13px', color: '#71717a' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <Check size={14} style={{ color: '#22c55e' }} />
            <span>0 Anuncios / 100% Gratuito</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <Check size={14} style={{ color: '#22c55e' }} />
            <span>Calidad de Audio 320 kbps</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <Check size={14} style={{ color: '#22c55e' }} />
            <span>Control Groovy Connect</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <Check size={14} style={{ color: '#22c55e' }} />
            <span>Descargas Locales</span>
          </div>
        </div>

      </section>

      {/* 3. REAL APP SHOWCASE (Desktop & Mobile Authentic Screenshots) */}
      <section id="interfaz" style={{ maxWidth: '1120px', margin: '0 auto', padding: '32px 24px 64px' }}>
        
        {/* Platform Toggle */}
        <div style={{ display: 'flex', justifyContent: 'center', gap: '10px', marginBottom: '28px' }}>
          <button
            onClick={() => setActivePlatformTab('desktop')}
            style={{
              display: 'flex', alignItems: 'center', gap: '8px',
              padding: '10px 20px', borderRadius: '10px',
              background: activePlatformTab === 'desktop' ? 'rgba(250, 45, 72, 0.15)' : 'rgba(255,255,255,0.04)',
              border: activePlatformTab === 'desktop' ? '1px solid rgba(250, 45, 72, 0.4)' : '1px solid rgba(255,255,255,0.06)',
              color: activePlatformTab === 'desktop' ? '#fa2d48' : '#a1a1aa',
              fontSize: '14px', fontWeight: 600,
              cursor: 'pointer', transition: 'all 0.15s',
            }}
          >
            <Laptop size={16} />
            <span>Versión de Escritorio (Windows & Web)</span>
          </button>

          <button
            onClick={() => setActivePlatformTab('mobile')}
            style={{
              display: 'flex', alignItems: 'center', gap: '8px',
              padding: '10px 20px', borderRadius: '10px',
              background: activePlatformTab === 'mobile' ? 'rgba(34, 197, 94, 0.15)' : 'rgba(255,255,255,0.04)',
              border: activePlatformTab === 'mobile' ? '1px solid rgba(34, 197, 94, 0.4)' : '1px solid rgba(255,255,255,0.06)',
              color: activePlatformTab === 'mobile' ? '#22c55e' : '#a1a1aa',
              fontSize: '14px', fontWeight: 600,
              cursor: 'pointer', transition: 'all 0.15s',
            }}
          >
            <Smartphone size={16} />
            <span>Versión Móvil (Android)</span>
          </button>
        </div>

        {/* Display Active Real Screenshot */}
        {activePlatformTab === 'desktop' ? (
          <div
            style={{
              background: '#121215',
              borderRadius: '16px',
              border: '1px solid rgba(255,255,255,0.08)',
              boxShadow: '0 24px 56px -12px rgba(0,0,0,0.85)',
              overflow: 'hidden',
            }}
          >
            {/* Desktop Window Frame */}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px 18px', borderBottom: '1px solid rgba(255,255,255,0.06)', background: '#18181c' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <div style={{ width: '10px', height: '10px', borderRadius: '50%', background: '#ef4444' }} />
                <div style={{ width: '10px', height: '10px', borderRadius: '50%', background: '#f59e0b' }} />
                <div style={{ width: '10px', height: '10px', borderRadius: '50%', background: '#10b981' }} />
                <span style={{ fontSize: '12px', color: '#a1a1aa', marginLeft: '12px', fontWeight: 600 }}>
                  Groovy — Reproductor de Escritorio
                </span>
              </div>
              <span style={{ fontSize: '11px', color: '#71717a' }}>
                Panel de artista, cola de reproducción y barra inferior sincronizada
              </span>
            </div>

            <div style={{ background: '#000000', display: 'flex', justifyContent: 'center' }}>
              <img
                src="./screenshots/groovy_desktop.png"
                alt="Groovy Desktop App"
                style={{ width: '100%', height: 'auto', maxHeight: '680px', objectFit: 'contain', display: 'block' }}
              />
            </div>
          </div>
        ) : (
          <div
            style={{
              background: '#121215',
              borderRadius: '16px',
              border: '1px solid rgba(255,255,255,0.08)',
              boxShadow: '0 24px 56px -12px rgba(0,0,0,0.85)',
              padding: '32px 24px',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
            }}
          >
            <div style={{ textAlign: 'center', marginBottom: '24px' }}>
              <h3 style={{ fontSize: '20px', fontWeight: 700, marginBottom: '6px' }}>Groovy para Android</h3>
              <p style={{ fontSize: '13px', color: '#71717a' }}>Diseño adaptado para móviles, navegación táctil y reproducción en segundo plano</p>
            </div>

            <div
              style={{
                maxWidth: '360px',
                borderRadius: '32px',
                border: '6px solid #27272a',
                overflow: 'hidden',
                boxShadow: '0 20px 40px rgba(0,0,0,0.8)',
                background: '#000000',
              }}
            >
              <img
                src="./screenshots/groovy_mobile.jpg"
                alt="Groovy Mobile App"
                style={{ width: '100%', height: 'auto', display: 'block' }}
              />
            </div>
          </div>
        )}

      </section>

      {/* 4. CORE FEATURES GRID */}
      <section id="funciones" style={{ maxWidth: '1120px', margin: '0 auto', padding: '48px 24px 64px' }}>
        <div style={{ textAlign: 'center', marginBottom: '44px' }}>
          <h2 style={{ fontSize: '30px', fontWeight: 700, letterSpacing: '-0.6px', marginBottom: '8px' }}>
            Todo lo que necesitas en un reproductor
          </h2>
          <p style={{ fontSize: '14px', color: '#71717a' }}>
            Funciones avanzadas diseñadas con rendimiento nativo y libertad total
          </p>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))', gap: '20px' }}>
          
          <div style={{ background: '#121215', borderRadius: '12px', border: '1px solid rgba(255,255,255,0.06)', padding: '24px' }}>
            <div style={{ width: '40px', height: '40px', borderRadius: '10px', background: 'rgba(250, 45, 72, 0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '16px' }}>
              <Radio size={20} style={{ color: '#fa2d48' }} />
            </div>
            <h3 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px', color: '#f4f4f5' }}>Groovy Connect</h3>
            <p style={{ fontSize: '13px', color: '#71717a', lineHeight: 1.5 }}>
              Controla la música de tu PC desde tu teléfono o transfiere la sesión activa en tiempo real sin cortar la canción.
            </p>
          </div>

          <div style={{ background: '#121215', borderRadius: '12px', border: '1px solid rgba(255,255,255,0.06)', padding: '24px' }}>
            <div style={{ width: '40px', height: '40px', borderRadius: '10px', background: 'rgba(56, 189, 248, 0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '16px' }}>
              <Music size={20} style={{ color: '#38bdf8' }} />
            </div>
            <h3 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px', color: '#f4f4f5' }}>Letras Sincronizadas</h3>
            <p style={{ fontSize: '13px', color: '#71717a', lineHeight: 1.5 }}>
              Seguimiento interactivo verso a verso con estilo karaoke y panel lateral de artista integrado.
            </p>
          </div>

          <div style={{ background: '#121215', borderRadius: '12px', border: '1px solid rgba(255,255,255,0.06)', padding: '24px' }}>
            <div style={{ width: '40px', height: '40px', borderRadius: '10px', background: 'rgba(251, 191, 36, 0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '16px' }}>
              <Sliders size={20} style={{ color: '#fbbf24' }} />
            </div>
            <h3 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px', color: '#f4f4f5' }}>Ecualizador & Tono</h3>
            <p style={{ fontSize: '13px', color: '#71717a', lineHeight: 1.5 }}>
              Ajuste de 10 bandas de frecuencia, refuerzo de graves (*Bass Boost*), modulación de tono (*pitch*) y control de tempo.
            </p>
          </div>

          <div style={{ background: '#121215', borderRadius: '12px', border: '1px solid rgba(255,255,255,0.06)', padding: '24px' }}>
            <div style={{ width: '40px', height: '40px', borderRadius: '10px', background: 'rgba(34, 197, 94, 0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '16px' }}>
              <Cloud size={20} style={{ color: '#22c55e' }} />
            </div>
            <h3 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px', color: '#f4f4f5' }}>Nube & Modo Offline</h3>
            <p style={{ fontSize: '13px', color: '#71717a', lineHeight: 1.5 }}>
              Tus listas y canciones favoritas se sincronizan en la base de datos de tu cuenta y puedes descargarlas para reproducir sin conexión.
            </p>
          </div>

        </div>
      </section>

      {/* 5. DOWNLOAD MATRIX SECTION */}
      <section id="descargas" style={{ padding: '64px 24px', background: '#0c0c0e', borderTop: '1px solid rgba(255,255,255,0.06)', borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
        <div style={{ maxWidth: '1120px', margin: '0 auto' }}>
          
          <div style={{ textAlign: 'center', marginBottom: '40px' }}>
            <h2 style={{ fontSize: '30px', fontWeight: 700, letterSpacing: '-0.6px', marginBottom: '8px' }}>
              Instaladores Oficiales
            </h2>
            <p style={{ fontSize: '14px', color: '#71717a' }}>
              Elige el paquete correspondiente a tu plataforma. Enlaces directos desde GitHub Releases.
            </p>
          </div>

          {/* Cards Grid */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))', gap: '18px', marginBottom: '32px' }}>
            
            {/* Windows Setup Card */}
            <div style={{ background: '#141417', borderRadius: '14px', border: userOS === 'windows' ? '1px solid rgba(250, 45, 72, 0.5)' : '1px solid rgba(255,255,255,0.06)', padding: '22px', display: 'flex', flexDirection: 'column' }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '14px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <Laptop size={22} style={{ color: '#38bdf8' }} />
                  <span style={{ fontSize: '16px', fontWeight: 600 }}>Windows Setup</span>
                </div>
                {userOS === 'windows' && (
                  <span style={{ fontSize: '10px', background: 'rgba(250, 45, 72, 0.15)', color: '#fa2d48', padding: '2px 8px', borderRadius: '6px', fontWeight: 600 }}>
                    Tu sistema
                  </span>
                )}
              </div>
              <p style={{ fontSize: '13px', color: '#71717a', lineHeight: 1.5, marginBottom: '16px', flex: 1 }}>
                Instalador con asistente, accesos directos y configuración de usuario segura.
              </p>
              <div style={{ fontSize: '11px', color: '#52525b', marginBottom: '14px' }}>
                <code>Groovy-Setup.exe</code> • {formatSize(windowsExe.size) || '38.7 MB'}
              </div>
              <a
                href={windowsExe.browser_download_url}
                style={{
                  display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px',
                  padding: '11px', borderRadius: '8px',
                  background: '#fa2d48', color: '#ffffff',
                  fontSize: '13px', fontWeight: 600, textDecoration: 'none',
                }}
              >
                <Download size={15} />
                <span>Descargar .exe ({versionTag})</span>
              </a>
            </div>

            {/* Windows Portable Card */}
            <div style={{ background: '#141417', borderRadius: '14px', border: '1px solid rgba(255,255,255,0.06)', padding: '22px', display: 'flex', flexDirection: 'column' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '14px' }}>
                <HardDrive size={22} style={{ color: '#fbbf24' }} />
                <span style={{ fontSize: '16px', fontWeight: 600 }}>Windows Portable</span>
              </div>
              <p style={{ fontSize: '13px', color: '#71717a', lineHeight: 1.5, marginBottom: '16px', flex: 1 }}>
                Versión comprimida (.zip) que no requiere instalación. Descomprime y ejecuta directamente.
              </p>
              <div style={{ fontSize: '11px', color: '#52525b', marginBottom: '14px' }}>
                <code>Groovy-Windows-Portable.zip</code> • {formatSize(windowsZip.size) || '45.0 MB'}
              </div>
              <a
                href={windowsZip.browser_download_url}
                style={{
                  display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px',
                  padding: '11px', borderRadius: '8px',
                  background: 'rgba(255,255,255,0.08)', color: '#f4f4f5',
                  fontSize: '13px', fontWeight: 500, textDecoration: 'none',
                }}
              >
                <Download size={15} />
                <span>Descargar .zip ({versionTag})</span>
              </a>
            </div>

            {/* Android APK Card */}
            <div style={{ background: '#141417', borderRadius: '14px', border: userOS === 'android' ? '1px solid rgba(34, 197, 94, 0.5)' : '1px solid rgba(255,255,255,0.06)', padding: '22px', display: 'flex', flexDirection: 'column' }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '14px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <Smartphone size={22} style={{ color: '#22c55e' }} />
                  <span style={{ fontSize: '16px', fontWeight: 600 }}>Android APK</span>
                </div>
                {userOS === 'android' && (
                  <span style={{ fontSize: '10px', background: 'rgba(34, 197, 94, 0.15)', color: '#22c55e', padding: '2px 8px', borderRadius: '6px', fontWeight: 600 }}>
                    Tu sistema
                  </span>
                )}
              </div>
              <p style={{ fontSize: '13px', color: '#71717a', lineHeight: 1.5, marginBottom: '16px', flex: 1 }}>
                APK universal compatible con Android 7.0 o superior. Reproducción con pantalla apagada.
              </p>
              <div style={{ fontSize: '11px', color: '#52525b', marginBottom: '14px' }}>
                <code>app-release.apk</code> • {formatSize(androidApk.size) || '32.4 MB'}
              </div>
              <a
                href={androidApk.browser_download_url}
                style={{
                  display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px',
                  padding: '11px', borderRadius: '8px',
                  background: '#22c55e', color: '#000000',
                  fontSize: '13px', fontWeight: 700, textDecoration: 'none',
                }}
              >
                <Download size={15} />
                <span>Descargar APK ({versionTag})</span>
              </a>
            </div>

            {/* Linux Package Card */}
            <div style={{ background: '#141417', borderRadius: '14px', border: '1px solid rgba(255,255,255,0.06)', padding: '22px', display: 'flex', flexDirection: 'column' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '14px' }}>
                <Layers size={22} style={{ color: '#a78bfa' }} />
                <span style={{ fontSize: '16px', fontWeight: 600 }}>Linux x64</span>
              </div>
              <p style={{ fontSize: '13px', color: '#71717a', lineHeight: 1.5, marginBottom: '16px', flex: 1 }}>
                Paquete binario para distribuciones Linux x64 con integración nativa MPRIS.
              </p>
              <div style={{ fontSize: '11px', color: '#52525b', marginBottom: '14px' }}>
                <code>groovy-linux-x64.tar.gz</code> • {formatSize(linuxTar.size) || '42.0 MB'}
              </div>
              <a
                href={linuxTar.browser_download_url}
                style={{
                  display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px',
                  padding: '11px', borderRadius: '8px',
                  background: 'rgba(255,255,255,0.08)', color: '#f4f4f5',
                  fontSize: '13px', fontWeight: 500, textDecoration: 'none',
                }}
              >
                <Download size={15} />
                <span>Descargar tar.gz</span>
              </a>
            </div>

          </div>

          {/* Windows SmartScreen Quick Tip */}
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
                  Al ser un software nuevo descargado de internet, Windows SmartScreen puede mostrar una advertencia preventiva de protección. Para abrirlo:
                </p>
                <ol style={{ margin: 0, paddingLeft: '20px' }}>
                  <li>Haz clic en <strong>"Más información"</strong> en la ventana informativa.</li>
                  <li>Selecciona <strong>"Ejecutar de todas formas"</strong>.</li>
                  <li>O bien, utiliza la versión <strong>Windows Portable (.zip)</strong> para ejecutarlo directamente.</li>
                </ol>
              </div>
            )}
          </div>

        </div>
      </section>

      {/* 6. FAQ SECTION */}
      <section id="preguntas" style={{ maxWidth: '840px', margin: '0 auto', padding: '64px 24px' }}>
        <div style={{ textAlign: 'center', marginBottom: '36px' }}>
          <h2 style={{ fontSize: '28px', fontWeight: 700, letterSpacing: '-0.5px', marginBottom: '8px' }}>
            Preguntas Frecuentes
          </h2>
          <p style={{ fontSize: '14px', color: '#71717a' }}>
            Respuestas a las dudas más comunes sobre la instalación y el uso de Groovy
          </p>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          {faqs.map((faq, idx) => (
            <div
              key={idx}
              style={{
                background: '#121215',
                borderRadius: '12px',
                border: '1px solid rgba(255,255,255,0.06)',
                overflow: 'hidden',
              }}
            >
              <button
                onClick={() => setOpenFaq(openFaq === idx ? null : idx)}
                style={{
                  width: '100%',
                  padding: '16px 20px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  background: 'none',
                  border: 'none',
                  color: '#f4f4f5',
                  fontSize: '14px',
                  fontWeight: 600,
                  cursor: 'pointer',
                  textAlign: 'left',
                }}
              >
                <span>{faq.q}</span>
                <ChevronDown
                  size={16}
                  style={{
                    color: '#71717a',
                    transform: openFaq === idx ? 'rotate(180deg)' : 'rotate(0deg)',
                    transition: 'transform 0.2s',
                    flexShrink: 0,
                    marginLeft: '12px',
                  }}
                />
              </button>

              {openFaq === idx && (
                <div style={{ padding: '0 20px 18px', color: '#a1a1aa', fontSize: '13px', lineHeight: 1.6, borderTop: '1px solid rgba(255,255,255,0.04)' }}>
                  {faq.a}
                </div>
              )}
            </div>
          ))}
        </div>
      </section>

      {/* 7. MINIMAL FOOTER */}
      <footer style={{ borderTop: '1px solid rgba(255,255,255,0.06)', padding: '36px 24px', background: '#09090b', fontSize: '13px', color: '#52525b' }}>
        <div style={{ maxWidth: '1120px', margin: '0 auto', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '16px' }}>
          
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <img src="./logo.png" alt="Groovy" style={{ width: '20px', height: '20px', borderRadius: '4px' }} />
            <span style={{ color: '#a1a1aa', fontWeight: 600 }}>Groovy</span>
            <span>— Reproductor de música libre</span>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '18px' }}>
            <button onClick={onOpenPlayer} style={{ background: 'none', border: 'none', color: '#a1a1aa', cursor: 'pointer', fontSize: '13px' }}>
              Abrir Web Player
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
