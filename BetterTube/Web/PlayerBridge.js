(function () {
  'use strict';
  if (window.BetterTube) return;
  const engine = globalThis.BetterTubeSegments;
  let config = globalThis.BetterTubeConfig || {};
  let currentID = null, route = '', segments = [], ignored = new Set(), lastSkip = null, serial = 0;
  let style, timer, lastAdSeek = 0, lastAdSource = '', adActive = false;
  function post(type, data = {}) {
    try { window.webkit.messageHandlers.betterTube.postMessage({ type, ...data }); } catch (_) {}
  }
  function applyStyle() {
    if (!document.documentElement) return;
    if (!style || !style.isConnected) {
      style = document.createElement('style');
      style.id = 'bettertube-style';
      (document.head || document.documentElement).appendChild(style);
    }
    const accent = /^#[0-9a-f]{6}$/i.test(config.accent) ? config.accent : '#FF0000';
    const dark = config.appearance === 'dark' || (config.appearance === 'system' && matchMedia('(prefers-color-scheme: dark)').matches);
    document.documentElement.toggleAttribute('dark', dark);
    style.textContent = `
      :root { --bt-accent: ${accent}; --yt-spec-call-to-action: ${accent}; --yt-spec-static-brand-red: ${accent}; --yt-spec-brand-button-background: ${accent}; --yt-spec-themed-blue: ${accent}; color-scheme: ${dark ? 'dark' : 'light'}; }
      html, body, ytm-app { background-color: ${dark ? '#0f0f0f' : '#ffffff'} !important; color: ${dark ? '#f1f1f1' : '#0f0f0f'} !important; }
      .ytp-play-progress, .ytp-scrubber-button, .ytm-progress-bar-played, .player-controls-progress-bar-played { background: ${accent} !important; }
      ytm-pivot-bar-renderer .pivot-bar-item-tab.pivot-bar-item-selected { color: ${accent} !important; }
      ${config.adBlock ? `ytm-promoted-sparkles-web-renderer, ytm-promoted-sparkles-text-search-renderer, ytm-display-ad-renderer, ytm-ad-slot-renderer, ytd-ad-slot-renderer, ytd-promoted-sparkles-web-renderer, .ytp-ad-overlay-container, #masthead-ad, #player-ads { display: none !important; }` : ''}
    `;
  }
  function updateRoute() {
    if (location.href === route) return;
    route = location.href;
    const nextID = engine.videoID(route);
    if (nextID !== currentID) {
      currentID = nextID; segments = []; ignored.clear(); lastSkip = null; adActive = false;
      post('video', { videoID: currentID || '', url: route });
    }
  }
  function activeVideo() {
    const videos = [...document.querySelectorAll('video')].filter(v => {
      const r = v.getBoundingClientRect();
      return r.width > 0 && r.height > 0 && r.bottom > 0 && r.top < innerHeight;
    });
    return videos.find(v => !v.paused) || videos[0];
  }
  function tick() {
    updateRoute();
    const v = activeVideo();
    if (!v) return;
    const player = v.closest('.html5-video-player') || document.querySelector('#movie_player');
    // Only act on a player explicitly marked as showing an advertisement.
    const isAd = !!player && (player.classList.contains('ad-showing') || player.classList.contains('ad-interrupting'));
    if (!isAd) adActive = false;
    if (isAd) {
      if (config.adBlock) {
        const skip = player.querySelector('.ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-skip-ad-button');
        if (skip && !skip.disabled && skip.getBoundingClientRect().width > 0) skip.click();
        if (Number.isFinite(v.duration) && v.duration > 0 && v.duration < 600 && !v.paused && !v.seeking &&
            v.currentTime < v.duration - 0.2 && (Date.now() - lastAdSeek > 1500 || lastAdSource !== v.currentSrc)) {
          try {
            v.currentTime = Math.max(0, v.duration - 0.05);
            lastAdSeek = Date.now(); lastAdSource = v.currentSrc;
            if (!adActive) { adActive = true; post('adSkipped'); }
          } catch (_) {}
        }
      }
      return; // Never apply content timestamps to an ad, including with ad blocking disabled.
    }
    if (!config.sponsorBlock || !currentID || v.paused || v.seeking || v.readyState < 2) return;
    const next = engine.plan(segments, v.currentTime, v.duration, config.categories || [], ignored);
    if (next) {
      try {
        v.currentTime = next.to;
        const token = `${currentID}:${++serial}`;
        lastSkip = { ...next, token, video: v, videoID: currentID };
        post('skipped', { category: next.category, seconds: next.to - next.from, token, videoID: currentID });
      } catch (_) {}
    }
  }
  window.BetterTube = {
    configure(value) { config = value; if (!config.sponsorBlock) lastSkip = null; applyStyle(); tick(); },
    setSegments(id, value) {
      updateRoute();
      if (id !== currentID) return false;
      segments = Array.isArray(value) ? value : []; tick(); return true;
    },
    undo(token) {
      updateRoute();
      if (!lastSkip || lastSkip.token !== token || lastSkip.videoID !== currentID || !lastSkip.video.isConnected) return false;
      lastSkip.ids.forEach(id => ignored.add(id));
      lastSkip.video.currentTime = lastSkip.from;
      lastSkip = null;
      return true;
    }
  };
  function start() {
    applyStyle(); updateRoute(); post('ready');
    timer = setInterval(tick, 300);
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, { once: true }); else start();
  document.addEventListener('yt-navigate-finish', tick);
  window.addEventListener('popstate', tick);
  window.addEventListener('pageshow', () => { applyStyle(); tick(); });
  matchMedia('(prefers-color-scheme: dark)').addEventListener('change', applyStyle);
})();
