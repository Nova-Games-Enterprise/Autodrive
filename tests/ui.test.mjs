import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const source = fs.readFileSync('html/index.js', 'utf8');
const cssSource = fs.readFileSync('html/index.css', 'utf8');

function fixture(options = {}) {
  let now = 0;
  const elements = Object.fromEntries(['panel','speed','units','autopilot','safety','reason']
    .map(id => [id, { hidden: id === 'panel', textContent: '', dataset: {} }]));
  const handlers = {};
  const timers = [];
  const audio = { created: 0, tones: 0, disconnected: 0, resumes: 0 };
  class Audio {
    constructor() {
      if (options.failAudio) throw new Error('audio unavailable');
      audio.created++;
      this.state = options.suspended ? 'suspended' : 'running';
      this.currentTime = 0;
      this.destination = {};
    }
    resume() {
      audio.resumes++;
      return options.hangResume ? new Promise(() => {}) : Promise.reject(new Error('autoplay denied'));
    }
    createOscillator() {
      audio.tones++;
      return { frequency: {}, connect() {}, start() {},
        disconnect() { audio.disconnected++; }, stop() { this.onended?.(); } };
    }
    createGain() {
      return { gain: { setValueAtTime() {}, linearRampToValueAtTime() {} },
        connect() {}, disconnect() { audio.disconnected++; } };
    }
  }
  vm.runInNewContext(source, {
    document: { getElementById: id => elements[id] },
    window: { addEventListener: (name, fn) => { handlers[name] = fn; },
      setInterval: fn => timers.push(fn), AudioContext: options.noAudio ? undefined : Audio },
    performance: { now: () => now }, Promise, Set, Number, String, Math, Infinity
  });
  const state = { type: 'state', version: 1, visible: true, audio: false,
    autopilot: 'driving', safety: 'ready', cruiseSpeed: 50, units: 'kmh', reason: 'route_active' };
  return { elements, audio, state, timers,
    send: data => handlers.message({ data }), time: value => { now = value; } };
}

test('HUD starts hidden', () => { assert.equal(fixture().elements.panel.hidden, true); });
test('NUI canvas stays explicitly transparent', () => {
  assert.doesNotMatch(cssSource, /color-scheme\s*:/i);
  assert.ok(cssSource.includes('html, body { margin: 0; width: 100%; height: 100%; background: transparent !important; overflow: hidden; }'));
});
test('valid snapshot renders speed, units, route and safety', () => {
  const f = fixture(); f.send(f.state);
  assert.equal(f.elements.panel.hidden, false);
  assert.equal(f.elements.speed.textContent, '50');
  assert.equal(f.elements.units.textContent, 'km/h');
  assert.equal(f.elements.autopilot.textContent, 'DRIVING');
  assert.equal(f.elements.safety.dataset.state, 'ready');
});
test('mph is labelled explicitly', () => {
  const f = fixture(); f.send({ ...f.state, units: 'mph' });
  assert.equal(f.elements.units.textContent, 'mph');
});
test('cleanup snapshot hides panel', () => {
  const f = fixture(); f.send(f.state); f.send({ ...f.state, visible: false });
  assert.equal(f.elements.panel.hidden, true);
});
for (const [label, value] of Object.entries({ null: null, undefined, string: 'state', array: [],
  wrongType: {type:'angleinfo'}, wrongVersion: {version:2}, invalidSpeed: {cruiseSpeed:NaN},
  infiniteSpeed: {cruiseSpeed:Infinity}, negativeSpeed: {cruiseSpeed:-1}, excessiveSpeed: {cruiseSpeed:161},
  invalidMode: {autopilot:'certified'}, invalidSafety: {safety:'safe_forever'},
  invalidUnits: {units:'knots'}, nonBoolean: {visible:1}, invalidAudio: {audio:'yes'},
  invalidReason: {reason:[]}, hugeReason: {reason:'x'.repeat(81)} })) {
  test(`malformed message rejected without changing UI: ${label}`, () => {
    const f = fixture();
    const data = value && typeof value === 'object' && !Array.isArray(value) ? { ...f.state, ...value } : value;
    assert.doesNotThrow(() => f.send(data));
    assert.equal(f.elements.panel.hidden, true);
  });
}
test('untrusted reason uses literal text, never HTML', () => {
  const f = fixture(); const reason = '<img src=x onerror=alert(1)>';
  f.send({ ...f.state, reason });
  assert.equal(f.elements.reason.textContent, reason);
  assert.equal(f.elements.reason.innerHTML, undefined);
});
test('stale Lua heartbeat replaces green safety with unavailable', () => {
  const f = fixture(); f.send(f.state); f.time(2501); f.timers[0]();
  assert.equal(f.elements.safety.dataset.state, 'unavailable');
  assert.equal(f.elements.autopilot.textContent, 'SIGNAL LOST');
});
test('fresh snapshot recovers after stale heartbeat', () => {
  const f = fixture(); f.send(f.state); f.time(3000); f.timers[0](); f.send(f.state);
  assert.equal(f.elements.safety.dataset.state, 'ready');
});
test('hidden HUD does not show a stale warning', () => {
  const f = fixture(); f.time(3000); f.timers[0](); assert.equal(f.elements.panel.hidden, true);
});
test('audio is disabled by default', () => {
  const f = fixture(); f.send({ ...f.state, safety: 'brake' }); assert.equal(f.audio.created, 0);
});
test('local alert audio is bounded and nodes are disconnected', () => {
  const f = fixture(); const state = { ...f.state, safety:'brake', audio:true };
  f.send(state); f.time(499); f.send(state); assert.equal(f.audio.tones,1);
  f.time(500); f.send(state); assert.equal(f.audio.tones,2); assert.equal(f.audio.disconnected,4);
});
test('missing AudioContext does not break the HUD', () => {
  const f = fixture({ noAudio:true });
  assert.doesNotThrow(() => f.send({ ...f.state, safety:'warning', audio:true }));
});
test('audio constructor failure is contained', () => {
  const f = fixture({ failAudio:true });
  assert.doesNotThrow(() => f.send({ ...f.state, safety:'warning', audio:true }));
});
test('autoplay rejection is handled without an unhandled promise', async () => {
  const f = fixture({ suspended:true }); f.send({ ...f.state, safety:'warning', audio:true });
  await Promise.resolve(); await Promise.resolve();
  f.time(1000); f.send({ ...f.state, safety:'warning', audio:true });
  assert.equal(f.audio.tones,0);
});
test('UI contains no remote loader, network API or dynamic code execution', () => {
  assert.doesNotMatch(source, /\b(?:fetch|XMLHttpRequest|WebSocket|eval)\s*\(/);
  const html = fs.readFileSync('html/index.html','utf8');
  assert.match(html, /connect-src 'none'/);
  assert.doesNotMatch(html, /(?:src|href)=["']https?:/);
});

test('a suspended audio context cannot accumulate pending resume promises', () => {
  const f = fixture({ suspended:true, hangResume:true });
  for (let time=0; time<20000; time+=501) {
    f.time(time); f.send({ ...f.state, safety:'warning', audio:true });
  }
  assert.equal(f.audio.created,1);
  assert.equal(f.audio.resumes,1);
  assert.equal(f.audio.tones,0);
});
