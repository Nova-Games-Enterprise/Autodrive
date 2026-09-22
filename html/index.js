'use strict';
(() => {
  const panel = document.getElementById('panel');
  const speed = document.getElementById('speed');
  const units = document.getElementById('units');
  const autopilot = document.getElementById('autopilot');
  const safety = document.getElementById('safety');
  const reason = document.getElementById('reason');
  const modes = new Set(['off', 'driving', 'arrived', 'interrupted']);
  const states = new Set(['off', 'ready', 'warning', 'brake', 'unavailable']);
  let receivedAt = -Infinity;
  let lastBeep = -Infinity;
  let audioContext;
  let audioFailed = false;
  let resumePending = false;

  function beep(state, now) {
    if (audioFailed || now - lastBeep < 500 || !['warning', 'brake'].includes(state)) return;
    const Audio = window.AudioContext || window.webkitAudioContext;
    if (!Audio) return;
    lastBeep = now;
    try {
      audioContext ??= new Audio();
      if (audioContext.state !== 'running') {
        if (resumePending) return;
        resumePending = true;
        Promise.resolve(audioContext.resume())
          .then(() => { resumePending = false; })
          .catch(() => { resumePending = false; audioFailed = true; });
        return;
      }
      const oscillator = audioContext.createOscillator();
      const gain = audioContext.createGain();
      const t = audioContext.currentTime;
      oscillator.frequency.value = state === 'brake' ? 900 : 650;
      gain.gain.setValueAtTime(0, t);
      gain.gain.linearRampToValueAtTime(0.08, t + 0.01);
      gain.gain.linearRampToValueAtTime(0, t + 0.12);
      oscillator.connect(gain);
      gain.connect(audioContext.destination);
      oscillator.onended = () => { oscillator.disconnect(); gain.disconnect(); };
      oscillator.start(t);
      oscillator.stop(t + 0.13);
    } catch { audioFailed = true; }
  }

  window.addEventListener('message', (event) => {
    const d = event.data;
    if (!d || typeof d !== 'object' || Array.isArray(d) || d.type !== 'state' || d.version !== 1
      || typeof d.visible !== 'boolean' || typeof d.audio !== 'boolean'
      || !modes.has(d.autopilot) || !states.has(d.safety)
      || !['kmh', 'mph'].includes(d.units)
      || !Number.isFinite(d.cruiseSpeed) || d.cruiseSpeed < 0 || d.cruiseSpeed > 160
      || typeof d.reason !== 'string' || d.reason.length > 80) return;
    const now = performance.now();
    receivedAt = now;
    panel.hidden = !d.visible;
    speed.textContent = String(Math.round(d.cruiseSpeed));
    units.textContent = d.units === 'kmh' ? 'km/h' : 'mph';
    autopilot.textContent = d.autopilot.toUpperCase();
    safety.textContent = d.safety.toUpperCase();
    safety.dataset.state = d.safety;
    reason.textContent = d.reason.replaceAll('_', ' ');
    if (d.visible && d.audio) beep(d.safety, now);
  });

  // Do not leave a green indicator onscreen after a stalled/crashed Lua bridge.
  window.setInterval(() => {
    if (panel.hidden || performance.now() - receivedAt <= 2500) return;
    autopilot.textContent = 'SIGNAL LOST';
    safety.textContent = 'UNAVAILABLE';
    safety.dataset.state = 'unavailable';
    reason.textContent = 'Assistance status is stale. Take manual control.';
  }, 500);
})();
