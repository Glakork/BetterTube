/* Original BetterTube segment planner. Shared by the player and Node regression tests. */
(function (root) {
  'use strict';
  const validID = id => typeof id === 'string' && /^[\w-]{11}$/.test(id);
  function videoID(href) {
    try {
      const url = new URL(href);
      if (url.protocol !== 'https:' || (url.port && url.port !== '443')) return null;
      const host = url.hostname.toLowerCase();
      if (!(host === 'youtube.com' || host.endsWith('.youtube.com') || host === 'youtu.be')) return null;
      const p = url.pathname.split('/').filter(Boolean);
      const id = host === 'youtu.be' ? p[0] : ['shorts', 'embed', 'live'].includes(p[0]) ? p[1] : url.pathname === '/watch' ? url.searchParams.get('v') : null;
      return validID(id) ? id : null;
    } catch (_) { return null; }
  }
  function plan(segments, time, duration, categories, ignored = new Set()) {
    if (!Number.isFinite(time) || !Number.isFinite(duration) || duration <= 0) return null;
    const allowed = new Set(categories);
    const candidates = segments.filter(s => s && Array.isArray(s.segment) && s.segment.length === 2 &&
      s.segment.every(Number.isFinite) && s.segment[0] >= 0 && s.segment[1] > s.segment[0] &&
      s.segment[0] < duration && s.segment[1] <= duration + 1 && s.actionType === 'skip' &&
      typeof s.UUID === 'string' && s.UUID.length && !ignored.has(s.UUID) && allowed.has(s.category) &&
      Number.isFinite(s.videoDuration) && s.videoDuration >= 0 && (s.videoDuration === 0 || Math.abs(s.videoDuration - duration) <= 2)
    ).sort((a, b) => a.segment[0] - b.segment[0]);
    const first = candidates.find(s => time >= s.segment[0] && time < s.segment[1] - 0.12);
    if (!first) return null;
    let end = first.segment[1];
    const ids = new Set([first.UUID]);
    for (const s of candidates) {
      if (s.segment[0] <= end && s.segment[1] > time) { end = Math.max(end, s.segment[1]); ids.add(s.UUID); }
    }
    return { from: time, to: Math.min(end, duration), ids: [...ids], category: first.category };
  }
  const api = { videoID, plan };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  root.BetterTubeSegments = api;
})(globalThis);
