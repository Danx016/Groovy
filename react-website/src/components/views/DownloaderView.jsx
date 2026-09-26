import React, { useState, useEffect, useRef } from "react";
import {
  Search, Download, Check, Play, Pause,
  AlertCircle, Copy, RefreshCw,
  Clock, Eye, CheckCircle2, Film, Music2, ExternalLink, Disc3, Layers
} from "lucide-react";
import { downloadApi } from "../../services/api";

// Groovy Light + Red
const R   = "#FA243C";   // Groovy red accent
const BG  = "#F5F6F8";
const WH  = "#FFFFFF";
const BOR = "#E2E5EA";
const TX  = "#111827";
const TX2 = "#6B7280";
const TX3 = "#9CA3AF";
const RL  = "rgba(250,36,60,0.07)";  // red tint

export function DownloaderView({ onBack }) {
  const [query, setQuery]         = useState("");
  const [loading, setLoading]     = useState(false);
  const [searching, setSearching] = useState(false);
  const [results, setResults]     = useState([]);
  const [media, setMedia]         = useState(null);
  const [fmt, setFmt]             = useState("mp3");
  const [qual, setQual]           = useState("320");
  const [dlState, setDlState]     = useState("idle"); // idle | downloading | success | error
  const [dlText, setDlText]       = useState("");
  const [progress, setProgress]   = useState(0);
  const [err, setErr]             = useState("");
  const [prevOn, setPrevOn]       = useState(false);
  const [history, setHistory]     = useState(() => {
    try { return JSON.parse(localStorage.getItem("groovy_dl_h") || "[]"); } catch { return []; }
  });
  const audioRef = useRef(null);

  useEffect(() => {
    if (fmt === "mp3") {
      setQual("320");
    } else {
      const topV = media?.vQ?.[0]?.q || "1080";
      setQual(topV);
    }
  }, [fmt, media?.id]);

  useEffect(() => {
    const a = audioRef.current; if (!a) return;
    const stop = () => setPrevOn(false);
    a.addEventListener("ended", stop);
    return () => a.removeEventListener("ended", stop);
  }, [media]);

  const togglePreview = () => {
    if (!audioRef.current) return;
    if (prevOn) { audioRef.current.pause(); setPrevOn(false); }
    else { audioRef.current.play().then(() => setPrevOn(true)).catch(() => {}); }
  };

  const handlePaste = async () => {
    try { const t = await navigator.clipboard.readText(); if (t?.trim()) { setQuery(t.trim()); analyze(t.trim()); } } catch {}
  };

  const buildMedia = (item) => {
    setErr(""); setDlState("idle"); setProgress(0); setDlText("");
    if (audioRef.current) { audioRef.current.pause(); setPrevOn(false); }
    const d = item.durationSec || 210;

    const vQ = (item.videoQualities && item.videoQualities.length > 0)
      ? item.videoQualities.map((vq, idx) => {
          const numQ = parseInt(vq.quality, 10) || 0;
          return {
            q: String(vq.quality),
            label: vq.label,
            sub: vq.sub || (numQ >= 2160 ? "4K Ultra HD" : numQ >= 1440 ? "2K Quad HD" : numQ >= 1080 ? "Full HD" : numQ >= 720 ? "HD" : "SD"),
            desc: vq.size ? `${vq.note || ''} · ${vq.size}` : (vq.note || ''),
            top: idx === 0,
            badge: vq.badge || (numQ >= 2160 ? "4K" : numQ >= 1440 ? "2K" : numQ >= 1080 ? "1080p" : numQ >= 720 ? "720p" : "SD"),
          };
        })
      : [
          { q:"1080", label:"1080p (Full HD)", sub:"Full HD", desc:"Máxima resolución", top:true, badge:"1080p" },
          { q:"720",  label:"720p (HD)",       sub:"HD",      desc:"Alta definición", badge:"720p" },
          { q:"480",  label:"480p (SD)",       sub:"SD",      desc:"Calidad estándar", badge:"SD" },
          { q:"360",  label:"360p (Móvil)",    sub:"Móvil SD", desc:"Bajo consumo", badge:"SD" },
        ];

    const maxH = item.maxHeight || (vQ.length > 0 ? Math.max(...vQ.map(v => parseInt(v.q, 10) || 0)) : 1080);
    const maxRes = item.maxResolution || (maxH >= 4320 ? "8K" : maxH >= 2160 ? "4K" : maxH >= 1440 ? "2K" : maxH >= 1080 ? "Full HD" : maxH >= 720 ? "HD" : "SD");
    const isSDOnly = item.isSDOnly ?? (maxH < 720);

    const aQ = item.audioQualities || [
      { q:"320", label:"320 kbps", sub:"Ultra HQ",  desc:"Máxima fidelidad", top:true },
      { q:"256", label:"256 kbps", sub:"Alta calidad", desc:"Excelente nitidez" },
      { q:"192", label:"192 kbps", sub:"Estándar",   desc:"Recomendado" },
      { q:"128", label:"128 kbps", sub:"Ligero",     desc:"Ahorro de espacio" },
    ];

    setMedia({
      id: item.id || item.videoId || "x",
      videoId: item.videoId || item.id,
      url: item.url || (item.videoId ? `https://www.youtube.com/watch?v=${item.videoId}` : null),
      query: item.query || `${item.title} ${item.artist}`,
      title: item.title,
      artist: item.artist,
      duration: item.duration || "3:30",
      durationSec: d,
      thumbnail: item.thumbnail,
      previewAudioUrl: item.previewAudioUrl || item.preview || null,
      maxHeight: maxH,
      maxResolution: maxRes,
      isSDOnly,
      is4K: item.is4K ?? (maxH >= 2160),
      is2K: item.is2K ?? (maxH >= 1440 && maxH < 2160),
      isFullHD: item.isFullHD ?? (maxH >= 1080 && maxH < 1440),
      isHD: item.isHD ?? (maxH >= 720 && maxH < 1080),
      aQ,
      vQ,
    });

    if (fmt === "mp4" && vQ.length > 0) {
      setQual(vQ[0].q);
    }
  };

  const analyze = async (target) => {
    const t = target.trim(); if (!t) return;
    setErr(""); setDlState("idle"); setProgress(0); setDlText("");
    const isUrl = /^(https?:\/\/)?(www\.|m\.)?(youtube\.com|youtu\.be)\//i.test(t);
    if (isUrl) {
      setLoading(true); setResults([]);
      try {
        const d = await downloadApi.getInfo({ url: t });
        if (d.success) buildMedia(d);
        else buildMedia({ id:"yt", url:t, title:"Video de YouTube", artist:"YouTube", thumbnail:"https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&auto=format&fit=crop&q=80", duration:"3:45", durationSec:225, query:t });
      } catch {
        buildMedia({ id:"yt", url:t, title:"Video de YouTube", artist:"YouTube", thumbnail:"https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&auto=format&fit=crop&q=80", duration:"3:45", durationSec:225, query:t });
      } finally { setLoading(false); }
    } else {
      setSearching(true);
      try {
        const d = await downloadApi.search(t);
        if (d.success && d.results?.length > 0) {
          setResults(d.results);
          buildMedia(d.results[0]);

          // Fetch exact resolutions for the first item in background
          const targetYt = d.results[0].videoId || d.results[0].id;
          downloadApi.getInfo({ videoId: targetYt, url: d.results[0].url, query: t, title: d.results[0].title, artist: d.results[0].artist })
            .then(info => { if (info && info.success) buildMedia(info); })
            .catch(() => {});
        } else {
          setErr("Sin resultados. Prueba con el link directo de YouTube.");
        }
      } catch (e) { setErr(e.message || "Error al buscar."); }
      finally { setSearching(false); }
    }
  };

  const startDownload = async () => {
    if (!media || dlState === "downloading") return;
    setDlState("downloading");
    setProgress(15);
    setDlText("Conectando con el motor de descarga...");
    setErr("");

    const filename = `${media.artist ? `${media.artist} - ` : ""}${media.title || "groovy_media"}.${fmt}`;

    let p = 15;
    const progressTimer = setInterval(() => {
      p += Math.max(2, Math.floor((92 - p) * 0.2));
      if (p > 92) p = 92;
      setProgress(p);
      if (p < 40) {
        setDlText("Buscando fuentes de audio en alta fidelidad...");
      } else if (p < 75) {
        setDlText(`Generando stream ${fmt.toUpperCase()} (${qual}${fmt === "mp3" ? " kbps" : "p"})...`);
      } else {
        setDlText("Finalizando enlace y transfiriendo...");
      }
    }, 800);

    const payload = {
      id: media.id,
      url: media.url,
      format: fmt,
      quality: qual,
      title: `${media.artist} - ${media.title}`,
      artist: media.artist,
      query: media.query || `${media.title} ${media.artist}`,
      thumbnail: media.thumbnail,
    };

    try {
      // 1. Try to get direct download URL first (fastest, direct CDN speed)
      let directUrl = null;
      try {
        const urlPromise = downloadApi.getUrl(payload);
        const timeoutPromise = new Promise((_, rej) => setTimeout(() => rej(new Error("timeout")), 8000));
        const res = await Promise.race([urlPromise, timeoutPromise]);
        if (res && res.success && res.downloadUrl) {
          directUrl = res.downloadUrl;
        }
      } catch (e) {
        // Fallback silently if direct URL resolution times out
      }

      const finalUrl = directUrl || downloadApi.getDownloadUrl(payload);

      clearInterval(progressTimer);
      setProgress(100);
      setDlState("success");
      setDlText("¡Descarga iniciada en tu navegador!");

      // Trigger direct native browser download
      const a = document.createElement("a");
      a.href = finalUrl;
      a.setAttribute("download", filename);
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);

      // Save to download history
      const hi = {
        id: media.id,
        title: media.title,
        artist: media.artist,
        thumbnail: media.thumbnail,
        format: fmt.toUpperCase(),
        quality: fmt === "mp3" ? `${qual} kbps` : `${qual}p`,
        date: new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
      };
      setHistory(prev => {
        const u = [hi, ...prev.filter(i => i.id !== hi.id)].slice(0, 8);
        localStorage.setItem("groovy_dl_h", JSON.stringify(u));
        return u;
      });
    } catch (e) {
      clearInterval(progressTimer);
      setDlState("error");
      setErr("Error al iniciar la descarga. Por favor intenta nuevamente.");
    }
  };

  const qs = media ? (fmt === "mp3" ? media.aQ : media.vQ) : [];

  return (
    <div style={{ minHeight:"100vh", background:BG, color:TX, fontFamily:"'Inter', system-ui, sans-serif", paddingBottom:"80px" }}>

      {/* NAV */}
      <nav style={{ background:WH, borderBottom:`1px solid ${BOR}`, boxShadow:"0 1px 4px rgba(0,0,0,0.05)", padding:"0 28px", height:"54px", display:"flex", alignItems:"center", gap:"10px" }}>
        <img src="/logo.png" alt="Groovy" style={{ width:"30px", height:"30px", borderRadius:"8px" }} />
        <span style={{ fontWeight:700, fontSize:"15px", color:TX }}>Groovy</span>
      </nav>

      <main className="dl-main">

        {/* Title - original */}
        <h1 style={{ fontSize:"clamp(26px,4vw,42px)", fontWeight:800, margin:"0 0 10px", lineHeight:1.18, color:TX, letterSpacing:"-0.5px" }}>
          Descarga Tu <span style={{ color:R }}>Musica</span> y Videos Favoritos
        </h1>
        <p className="dl-subtitle" style={{ fontSize:"15px", color:TX2, lineHeight:1.6, maxWidth:"560px" }}>
          Pega un link de YouTube o busca por nombre. Descarga en MP3 o MP4 en la calidad que prefieras.
        </p>

        {/* Search bar */}
        <div className="dl-searchbar" style={{ marginBottom: err ? "12px" : "20px" }}>
          <div className="dl-searchbar-input" style={{ background:WH, border:`1.5px solid ${BOR}`, borderRadius:"11px", padding:"0 14px", boxShadow:"0 1px 4px rgba(0,0,0,0.05)", minHeight:"48px" }}>
            <Search size={17} style={{ color:TX3, flexShrink:0, marginRight:"10px" }} />
            <input type="text" value={query} onChange={e => setQuery(e.target.value)}
              onKeyDown={e => e.key === "Enter" && query.trim() && analyze(query)}
              placeholder="Link de YouTube o nombre de canción"
              style={{ flex:1, background:"transparent", border:"none", outline:"none", fontSize:"14px", color:TX, padding:"14px 0", minWidth:0 }} />
            {query && <button onClick={() => { setQuery(""); setResults([]); setMedia(null); setErr(""); }} style={{ background:"none", border:"none", cursor:"pointer", color:TX3, lineHeight:0, padding:"4px" }}>
              <svg width="13" height="13" viewBox="0 0 13 13" fill="none"><path d="M1 1l11 11M12 1L1 12" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/></svg>
            </button>}
          </div>
          <div className="dl-searchbar-actions">
            <button onClick={handlePaste} style={{ background:WH, border:`1.5px solid ${BOR}`, borderRadius:"11px", padding:"0 16px", minHeight:"48px", fontSize:"14px", fontWeight:500, color:TX2, cursor:"pointer", display:"flex", alignItems:"center", justifyContent:"center", gap:"7px", boxShadow:"0 1px 4px rgba(0,0,0,0.05)", transition:"border 0.15s" }}
              onMouseEnter={e => e.currentTarget.style.borderColor = "#c4c9d4"}
              onMouseLeave={e => e.currentTarget.style.borderColor = BOR}>
              <Copy size={14} /> Pegar
            </button>
            <button onClick={() => query.trim() && analyze(query)} disabled={loading || searching || !query.trim()} style={{ background:R, border:"none", borderRadius:"11px", padding:"0 22px", minHeight:"48px", fontSize:"14px", fontWeight:600, color:WH, cursor: !query.trim() ? "not-allowed" : "pointer", opacity: !query.trim() ? 0.55 : 1, display:"flex", alignItems:"center", justifyContent:"center", gap:"7px", boxShadow:"0 3px 10px rgba(250,36,60,0.28)", transition:"opacity 0.15s, transform 0.1s", whiteSpace:"nowrap" }}
              onMouseEnter={e => !e.currentTarget.disabled && (e.currentTarget.style.transform = "scale(1.03)")}
              onMouseLeave={e => (e.currentTarget.style.transform = "scale(1)")}>
              {loading || searching ? <RefreshCw size={15} className="animate-spin" /> : <Search size={15} />}
              {loading || searching ? "Buscando..." : "Buscar"}
            </button>
          </div>
        </div>

        {err && (
          <div style={{ display:"flex", gap:"10px", padding:"12px 15px", background:"#fef2f2", border:"1px solid #fecaca", borderRadius:"9px", marginBottom:"20px", color:"#dc2626", fontSize:"13px" }}>
            <AlertCircle size={15} style={{ flexShrink:0, marginTop:"1px" }} /><span>{err}</span>
          </div>
        )}

        {/* Results list */}
        {results.length > 0 && (
          <div style={{ marginBottom:"20px" }}>
            <div style={{ display:"flex", alignItems:"center", gap:"6px", marginBottom:"10px" }}>
              <Layers size={14} style={{ color:R }} />
              <span style={{ fontSize:"13px", fontWeight:500, color:TX2 }}>{results.length} resultados</span>
            </div>
            <div style={{ display:"flex", flexDirection:"column", gap:"6px" }}>
              {results.map(item => {
                const sel = media && (media.id === item.id || media.id === item.videoId);
                return (
                  <div key={item.id} onClick={() => {
                    buildMedia(item);
                    const targetId = item.videoId || item.id;
                    downloadApi.getInfo({ videoId: targetId, url: item.url, query: item.query, title: item.title, artist: item.artist })
                      .then(info => { if (info && info.success) buildMedia(info); })
                      .catch(() => {});
                  }} style={{ display:"flex", alignItems:"center", gap:"12px", padding:"10px 14px", background: sel ? RL : WH, border:`1.5px solid ${sel ? R : BOR}`, borderRadius:"10px", cursor:"pointer", transition:"all 0.15s", boxShadow: sel ? `0 0 0 3px rgba(250,36,60,0.08)` : "0 1px 3px rgba(0,0,0,0.04)" }}
                    onMouseEnter={e => { if (!sel) { e.currentTarget.style.borderColor = "#c4c9d4"; }}}
                    onMouseLeave={e => { if (!sel) { e.currentTarget.style.borderColor = BOR; }}}>
                    <img src={item.thumbnail} alt="" style={{ width:"54px", height:"38px", borderRadius:"6px", objectFit:"cover", flexShrink:0 }} />
                    <div style={{ flex:1, minWidth:0 }}>
                      <div style={{ fontSize:"13px", fontWeight:500, color:TX, overflow:"hidden", whiteSpace:"nowrap", textOverflow:"ellipsis" }}>{item.title}</div>
                      <div style={{ fontSize:"12px", color:TX3, marginTop:"2px" }}>{item.artist}{item.duration && ` · ${item.duration}`}</div>
                    </div>
                    {sel && <Check size={14} color={R} style={{ flexShrink:0 }} />}
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* Media card */}
        {media && (
          <div style={{ background:WH, border:`1.5px solid ${BOR}`, borderRadius:"16px", overflow:"hidden", boxShadow:"0 2px 12px rgba(0,0,0,0.07)", marginBottom:"20px" }}>

            <div className="dl-card-top">
              <div className="dl-card-thumb">
                <img src={media.thumbnail} alt={media.title} style={{ width:"100%", height:"122px", objectFit:"cover", display:"block" }}
                  onError={e => {
                    const src = e.target.src;
                    if (src.includes('maxresdefault')) { e.target.src = src.replace('maxresdefault', 'hqdefault'); }
                    else if (src.includes('hqdefault')) { e.target.src = src.replace('hqdefault', 'mqdefault'); }
                  }} />
                {media.previewAudioUrl && (
                  <>
                    <audio ref={audioRef} src={media.previewAudioUrl} preload="none" />
                    <button onClick={togglePreview} style={{ position:"absolute", inset:0, margin:"auto", width:"40px", height:"40px", borderRadius:"50%", background: prevOn ? `rgba(250,36,60,0.92)` : "rgba(255,255,255,0.92)", border:"none", color: prevOn ? WH : TX, display:"flex", alignItems:"center", justifyContent:"center", cursor:"pointer", boxShadow:"0 2px 8px rgba(0,0,0,0.25)" }}>
                      {prevOn ? <Pause size={17} fill="currentColor" /> : <Play size={17} fill="currentColor" style={{ marginLeft:"2px" }} />}
                    </button>
                  </>
                )}
                <span style={{ position:"absolute", bottom:"5px", right:"5px", background:"rgba(0,0,0,0.72)", color:WH, fontSize:"11px", padding:"2px 6px", borderRadius:"4px", fontWeight:600 }}>{media.duration}</span>
              </div>
              <div className="dl-card-info">
                <div style={{ display:"flex", alignItems:"center", gap:"8px", marginBottom:"7px", flexWrap:"wrap" }}>
                  <div style={{ fontSize:"10px", fontWeight:700, color:R, textTransform:"uppercase", letterSpacing:"0.6px", display:"flex", alignItems:"center", gap:"4px" }}>
                    <Disc3 size={11} /> Listo para descargar
                  </div>
                  {media.is4K && (
                    <span style={{ background:"linear-gradient(135deg, #7c3aed 0%, #a855f7 100%)", color:WH, fontSize:"10px", fontWeight:800, padding:"2px 8px", borderRadius:"6px", letterSpacing:"0.5px", boxShadow:"0 1px 4px rgba(124,58,237,0.3)" }}>
                      ✨ 4K ULTRA HD
                    </span>
                  )}
                  {media.is2K && (
                    <span style={{ background:"linear-gradient(135deg, #4f46e5 0%, #6366f1 100%)", color:WH, fontSize:"10px", fontWeight:800, padding:"2px 8px", borderRadius:"6px", letterSpacing:"0.5px", boxShadow:"0 1px 4px rgba(79,70,229,0.3)" }}>
                      ✨ 2K QUAD HD
                    </span>
                  )}
                  {media.isFullHD && (
                    <span style={{ background:"#10b981", color:WH, fontSize:"10px", fontWeight:800, padding:"2px 8px", borderRadius:"6px", letterSpacing:"0.5px" }}>
                      FULL HD (1080p)
                    </span>
                  )}
                  {media.isHD && (
                    <span style={{ background:"#0284c7", color:WH, fontSize:"10px", fontWeight:800, padding:"2px 8px", borderRadius:"6px", letterSpacing:"0.5px" }}>
                      HD (720p)
                    </span>
                  )}
                  {media.isSDOnly && (
                    <span style={{ background:"#f59e0b", color:WH, fontSize:"10px", fontWeight:800, padding:"2px 8px", borderRadius:"6px", letterSpacing:"0.5px" }}>
                      RESOLUCIÓN ORIGINAL: SD ({media.maxHeight || 480}p)
                    </span>
                  )}
                </div>
                <h2 style={{ fontSize:"16px", fontWeight:700, color:TX, margin:"0 0 8px", lineHeight:1.3, overflow:"hidden", display:"-webkit-box", WebkitLineClamp:2, WebkitBoxOrient:"vertical" }}>{media.title}</h2>
                <div style={{ fontSize:"12px", color:TX2, display:"flex", alignItems:"center", gap:"12px", flexWrap:"wrap" }}>
                  <span style={{ fontWeight:500 }}>{media.artist}</span>
                  {media.duration && <span style={{ display:"flex", alignItems:"center", gap:"3px" }}><Clock size={11} />{media.duration}</span>}
                  {media.url && <a href={media.url} target="_blank" rel="noreferrer" style={{ display:"flex", alignItems:"center", gap:"3px", color:R, textDecoration:"none", fontWeight:500 }}><ExternalLink size={11} />YouTube</a>}
                </div>
              </div>
            </div>

            <div style={{ padding:"20px" }}>

              {/* Format tabs */}
              <div style={{ display:"flex", gap:"7px", marginBottom:"14px" }}>
                {[["mp3", <Music2 size={13} />, "MP3 Audio"], ["mp4", <Film size={13} />, "MP4 Video"]].map(([f, icon, lbl]) => (
                  <button key={f} onClick={() => setFmt(f)} style={{ display:"flex", alignItems:"center", gap:"6px", padding:"8px 18px", borderRadius:"8px", border:`1.5px solid ${fmt===f ? R : BOR}`, background: fmt===f ? RL : "transparent", color: fmt===f ? R : TX2, fontSize:"13px", fontWeight: fmt===f ? 600 : 400, cursor:"pointer", transition:"all 0.15s" }}>
                    {icon}{lbl}
                  </button>
                ))}
              </div>

              {/* Informative resolution notice for Video */}
              {fmt === "mp4" && media.isSDOnly && (
                <div style={{ background:"#fffbeb", border:"1.5px solid #fde68a", borderRadius:"10px", padding:"10px 14px", marginBottom:"16px", display:"flex", alignItems:"flex-start", gap:"9px", fontSize:"12px", color:"#92400e", lineHeight:1.45 }}>
                  <AlertCircle size={16} style={{ color:"#d97706", flexShrink:0, marginTop:"1px" }} />
                  <div>
                    <strong>Calidad original SD ({media.maxHeight || 480}p):</strong> Este video no está disponible en Full HD ni 4K porque fue grabado o publicado originalmente en definición estándar. Las opciones abajo corresponden a la resolución real del video.
                  </div>
                </div>
              )}

              {fmt === "mp4" && (media.is4K || media.is2K) && (
                <div style={{ background:"#f5f3ff", border:"1.5px solid #ddd6fe", borderRadius:"10px", padding:"10px 14px", marginBottom:"16px", display:"flex", alignItems:"flex-start", gap:"9px", fontSize:"12px", color:"#5b21b6", lineHeight:1.45 }}>
                  <CheckCircle2 size={16} style={{ color:"#7c3aed", flexShrink:0, marginTop:"1px" }} />
                  <div>
                    <strong>¡Resolución cinematográfica detectada!</strong> Puedes descargar este video en <strong>{media.is4K ? "4K Ultra HD (2160p)" : "2K Quad HD (1440p)"}</strong> o en la resolución que prefieras.
                  </div>
                </div>
              )}

              {/* Quality grid */}
              <div style={{ display:"grid", gridTemplateColumns:"repeat(auto-fill, minmax(165px, 1fr))", gap:"8px", marginBottom:"22px" }}>
                {qs.map(q => {
                  const on = qual === q.q;
                  const isBadge4K = q.badge === '4K' || q.badge === '8K';
                  const isBadge2K = q.badge === '2K';
                  const isBadgeFHD = q.badge === '1080p';
                  const isBadgeHD = q.badge === '720p';

                  const badgeStyle = isBadge4K
                    ? { background:"#f5f3ff", color:"#7c3aed", border:"1px solid #ddd6fe" }
                    : isBadge2K
                    ? { background:"#eef2ff", color:"#4f46e5", border:"1px solid #c7d2fe" }
                    : isBadgeFHD
                    ? { background:"#ecfdf5", color:"#059669", border:"1px solid #a7f3d0" }
                    : isBadgeHD
                    ? { background:"#f0f9ff", color:"#0284c7", border:"1px solid #bae6fd" }
                    : { background:"#fffbeb", color:"#b45309", border:"1px solid #fde68a" };

                  return (
                    <div key={q.q} onClick={() => setQual(q.q)} style={{ padding:"12px 14px", border:`1.5px solid ${on ? R : BOR}`, borderRadius:"10px", background: on ? RL : BG, cursor:"pointer", transition:"all 0.15s", boxShadow: on ? `0 0 0 3px rgba(250,36,60,0.08)` : "none" }}
                      onMouseEnter={e => !on && (e.currentTarget.style.borderColor = "#c4c9d4")}
                      onMouseLeave={e => !on && (e.currentTarget.style.borderColor = BOR)}>
                      <div style={{ display:"flex", justifyContent:"space-between", alignItems:"center", marginBottom:"4px" }}>
                        <span style={{ fontWeight:700, fontSize:"14px", color: on ? R : TX }}>{q.label}</span>
                        <div style={{ display:"flex", gap:"4px", alignItems:"center" }}>
                          {fmt === "mp4" && q.badge && (
                            <span style={{ fontSize:"10px", fontWeight:800, padding:"1px 6px", borderRadius:"4px", ...badgeStyle }}>{q.badge}</span>
                          )}
                          {q.top && <span style={{ fontSize:"9px", fontWeight:700, color:R, border:`1px solid ${R}`, padding:"1px 5px", borderRadius:"3px" }}>MÁXIMA</span>}
                        </div>
                      </div>
                      <div style={{ fontSize:"12px", color:TX3 }}>{q.sub} · {q.desc}</div>
                    </div>
                  );
                })}
              </div>

              {/* Download */}
              <div className="dl-download-row">
                <span style={{ fontSize:"13px", color:TX3 }}>
                  {fmt.toUpperCase()} · {qual}{fmt==="mp3" ? " kbps" : "p"} · {qs.find(q => q.q===qual)?.desc || ""}
                </span>
                <button onClick={startDownload} disabled={dlState==="downloading"} style={{
                  display:"flex", alignItems:"center", gap:"8px", padding:"12px 28px",
                  background: dlState==="downloading" ? "#e5e7eb" : R,
                  border:"none", borderRadius:"9px",
                  color: dlState==="downloading" ? TX2 : WH,
                  fontSize:"14px", fontWeight:700,
                  cursor: dlState==="downloading" ? "not-allowed" : "pointer",
                  boxShadow: dlState==="downloading" ? "none" : "0 3px 12px rgba(250,36,60,0.3)",
                  transition:"all 0.15s"
                }}
                  onMouseEnter={e => { if (dlState !== "downloading") e.currentTarget.style.opacity = "0.9"; }}
                  onMouseLeave={e => { if (dlState !== "downloading") e.currentTarget.style.opacity = "1"; }}>
                  {dlState==="downloading" ? (
                    <><RefreshCw size={15} className="animate-spin" /><span>Preparando ({progress}%)</span></>
                  ) : (
                    <><Download size={15} /><span>Descargar</span></>
                  )}
                </button>
              </div>

              {/* Progress Bar & Status */}
              {(dlState === "downloading" || dlState === "success") && (
                <div style={{
                  marginTop:"16px",
                  padding:"16px 18px",
                  borderRadius:"12px",
                  background: dlState === "success" ? "#f0fdf4" : "#fbfbfc",
                  border: `1.5px solid ${dlState === "success" ? "#bbf7d0" : BOR}`,
                  boxShadow: "0 1px 4px rgba(0,0,0,0.03)"
                }}>
                  {/* Status header with label & percentage */}
                  <div style={{ display:"flex", justifyContent:"space-between", alignItems:"center", marginBottom:"10px", gap:"10px" }}>
                    <div style={{ display:"flex", alignItems:"center", gap:"8px", minWidth:0 }}>
                      {dlState === "downloading" ? (
                        <RefreshCw size={15} className="animate-spin" style={{ color: R, flexShrink:0 }} />
                      ) : (
                        <CheckCircle2 size={16} style={{ color: "#16a34a", flexShrink:0 }} />
                      )}
                      <span style={{
                        fontSize:"13px",
                        fontWeight:600,
                        color: dlState === "success" ? "#15803d" : TX,
                        overflow:"hidden",
                        textOverflow:"ellipsis",
                        whiteSpace:"nowrap"
                      }}>
                        {dlText}
                      </span>
                    </div>
                    <span style={{
                      fontSize:"14px",
                      fontWeight:700,
                      color: dlState === "success" ? "#16a34a" : R,
                      flexShrink:0
                    }}>
                      {progress}%
                    </span>
                  </div>

                  {/* Progress bar track */}
                  <div style={{
                    width:"100%",
                    height:"9px",
                    background: dlState === "success" ? "#dcfce7" : "#E5E7EB",
                    borderRadius:"999px",
                    overflow:"hidden"
                  }}>
                    <div style={{
                      width: `${progress}%`,
                      height:"100%",
                      background: dlState === "success"
                        ? "linear-gradient(90deg, #16a34a 0%, #22c55e 100%)"
                        : "linear-gradient(90deg, #FA243C 0%, #FF5267 100%)",
                      borderRadius:"999px",
                      transition: "width 0.35s ease",
                      boxShadow: dlState === "success" ? "none" : "0 0 10px rgba(250,36,60,0.35)"
                    }} />
                  </div>

                  {/* Helper footer */}
                  <div className="dl-progress-footer" style={{ color: dlState === "success" ? "#15803d" : TX3 }}>
                    <span>{fmt.toUpperCase()} · {qual}{fmt === "mp3" ? " kbps" : "p"}</span>
                    <span>{dlState === "success" ? "Descargando en el gestor de tu navegador" : (progress < 70 ? "Compilando en el servidor..." : "Iniciando descarga...")}</span>
                  </div>
                </div>
              )}

              {/* Error banner */}
              {dlState === "error" && err && (
                <div style={{
                  marginTop:"14px",
                  padding:"12px 16px",
                  borderRadius:"10px",
                  background:"#fef2f2",
                  border:"1.5px solid #fecaca",
                  display:"flex",
                  alignItems:"center",
                  justifyContent:"space-between",
                  gap:"12px",
                  fontSize:"13px",
                  color:"#dc2626"
                }}>
                  <div style={{ display:"flex", alignItems:"center", gap:"8px", minWidth:0 }}>
                    <AlertCircle size={16} style={{ flexShrink:0 }} />
                    <span style={{ overflow:"hidden", textOverflow:"ellipsis" }}>{err}</span>
                  </div>
                  <button onClick={startDownload} style={{
                    background: R, color: WH, border: "none",
                    borderRadius: "6px", padding: "6px 14px",
                    fontSize: "12px", fontWeight: 600,
                    cursor: "pointer", flexShrink: 0
                  }}>
                    Reintentar
                  </button>
                </div>
              )}
            </div>
          </div>
        )}

        {/* History */}
        {history.length > 0 && (
          <div>
            <div style={{ display:"flex", justifyContent:"space-between", alignItems:"center", marginBottom:"9px" }}>
              <span style={{ fontSize:"13px", fontWeight:500, color:TX2 }}>Descargados esta sesion</span>
              <button onClick={() => { setHistory([]); localStorage.removeItem("groovy_dl_h"); }} style={{ background:"none", border:"none", fontSize:"12px", color:TX3, cursor:"pointer" }}>Limpiar</button>
            </div>
            <div style={{ display:"flex", flexDirection:"column", gap:"5px" }}>
              {history.map((item, i) => (
                <div key={i} style={{ display:"flex", alignItems:"center", gap:"12px", padding:"10px 14px", background:WH, border:`1px solid ${BOR}`, borderRadius:"10px", boxShadow:"0 1px 3px rgba(0,0,0,0.04)" }}>
                  <img src={item.thumbnail} alt="" style={{ width:"40px", height:"40px", borderRadius:"6px", objectFit:"cover", flexShrink:0 }} />
                  <div style={{ flex:1, minWidth:0 }}>
                    <div style={{ fontSize:"13px", fontWeight:500, color:TX, overflow:"hidden", whiteSpace:"nowrap", textOverflow:"ellipsis" }}>{item.title}</div>
                    <div style={{ fontSize:"11px", color:TX3, marginTop:"2px" }}>{item.artist} · {item.format} {item.quality} · {item.date}</div>
                  </div>
                  <span style={{ fontSize:"11px", color:R, display:"flex", alignItems:"center", gap:"3px", flexShrink:0, fontWeight:500 }}>
                    <Check size={11} /> OK
                  </span>
                </div>
              ))}
            </div>
          </div>
        )}

      </main>
    </div>
  );
}
