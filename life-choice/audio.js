// เสียงประกอบสังเคราะห์ด้วย Web Audio ไม่ใช้ไฟล์เสียง เริ่มได้หลังผู้เล่นแตะครั้งแรกเท่านั้น
(function (root) {
  'use strict';

  const KEY = 'chata.muted';
  let ac = null;
  let master = null;
  let musicBus = null;
  let musicTimer = null;
  let muted = readMuted();

  function readMuted() {
    try {
      return localStorage.getItem(KEY) === '1';
    } catch (e) {
      return false;
    }
  }

  function writeMuted() {
    try {
      localStorage.setItem(KEY, muted ? '1' : '0');
    } catch (e) {
      // ถ้าเบราว์เซอร์ไม่ให้เก็บค่า ก็ใช้ค่าเฉพาะรอบนี้
    }
  }

  function ctx() {
    if (!ac) {
      const AC = root.AudioContext || root.webkitAudioContext;
      if (!AC) return null;
      ac = new AC();
      master = ac.createGain();
      master.gain.value = muted ? 0 : 0.7;
      master.connect(ac.destination);
    }
    if (ac.state === 'suspended') ac.resume();
    return ac;
  }

  function tone(freq, { type = 'sine', dur = 0.4, vol = 0.2, delay = 0, attack = 0.01, dest = null } = {}) {
    const c = ctx();
    if (!c || muted) return;
    const t = c.currentTime + delay;
    const o = c.createOscillator();
    const g = c.createGain();
    o.type = type;
    o.frequency.setValueAtTime(freq, t);
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(vol, t + attack);
    g.gain.exponentialRampToValueAtTime(0.0001, t + attack + dur);
    o.connect(g);
    g.connect(dest || master);
    o.start(t);
    o.stop(t + attack + dur + 0.05);
  }

  let noiseBuffer = null;
  function noise({ dur = 0.1, vol = 0.2, delay = 0, freq = 2000, q = 1 } = {}) {
    const c = ctx();
    if (!c || muted) return;
    if (!noiseBuffer) {
      noiseBuffer = c.createBuffer(1, c.sampleRate, c.sampleRate);
      const d = noiseBuffer.getChannelData(0);
      for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    }
    const t = c.currentTime + delay;
    const src = c.createBufferSource();
    src.buffer = noiseBuffer;
    const f = c.createBiquadFilter();
    f.type = 'bandpass';
    f.frequency.value = freq;
    f.Q.value = q;
    const g = c.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(vol, t + 0.005);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    src.connect(f);
    f.connect(g);
    g.connect(master);
    src.start(t, Math.random() * 0.5);
    src.stop(t + dur + 0.05);
  }

  // ดนตรีพื้นหลังแบบสุ่ม: คอร์ดลากยาวกับโน้ตดีดในบันไดเสียงเพนทาโทนิกไมเนอร์
  const CHORDS = [
    [220, 261.63, 329.63],
    [174.61, 220, 261.63],
    [196, 246.94, 293.66],
    [164.81, 207.65, 246.94],
  ];
  const MELODY = [440, 523.25, 587.33, 659.25, 783.99, 880, 1046.5];

  function startMusic() {
    const c = ctx();
    if (!c || musicTimer) return;
    musicBus = c.createGain();
    musicBus.gain.value = 0.5;
    const lp = c.createBiquadFilter();
    lp.type = 'lowpass';
    lp.frequency.value = 1400;
    const delay = c.createDelay();
    delay.delayTime.value = 0.42;
    const fb = c.createGain();
    fb.gain.value = 0.32;
    musicBus.connect(lp);
    lp.connect(master);
    lp.connect(delay);
    delay.connect(fb);
    fb.connect(delay);
    delay.connect(master);
    let chord = 0;
    let beat = 0;
    const tick = () => {
      if (!muted) {
        if (beat % 16 === 0) {
          for (const f of CHORDS[chord % CHORDS.length]) {
            tone(f / 2, { type: 'triangle', dur: 7, vol: 0.022, attack: 2, dest: musicBus });
            tone(f, { type: 'sine', dur: 6, vol: 0.016, attack: 2.5, dest: musicBus });
          }
          chord++;
        }
        if (Math.random() < 0.38) {
          const n = MELODY[Math.floor(Math.random() * MELODY.length)];
          tone(n, { type: 'triangle', dur: 1.4, vol: 0.028, attack: 0.01, dest: musicBus });
        }
      }
      beat++;
      musicTimer = setTimeout(tick, 440);
    };
    tick();
  }

  const Sound = {
    get muted() {
      return muted;
    },
    toggle() {
      muted = !muted;
      writeMuted();
      if (master) master.gain.value = muted ? 0 : 0.7;
      if (!muted) startMusic();
      return muted;
    },
    startMusic,
    click() {
      tone(720, { type: 'triangle', dur: 0.07, vol: 0.06 });
      tone(1080, { dur: 0.05, vol: 0.035, delay: 0.02 });
    },
    page() {
      noise({ dur: 0.28, vol: 0.05, freq: 1600, q: 0.6 });
    },
    tick() {
      tone(1320, { type: 'sine', dur: 0.04, vol: 0.02 });
    },
    dice() {
      for (let i = 0; i < 9; i++) noise({ dur: 0.05, vol: 0.12, delay: i * 0.1 + Math.random() * 0.03, freq: 2600 + Math.random() * 2400, q: 5 });
    },
    success() {
      [523.25, 659.25, 783.99, 1046.5].forEach((f, i) => tone(f, { type: 'triangle', dur: 0.6, vol: 0.1, delay: i * 0.08 }));
      tone(1567.98, { dur: 1.1, vol: 0.05, delay: 0.34 });
    },
    fail() {
      [392, 311.13, 233.08].forEach((f, i) => tone(f, { type: 'triangle', dur: 0.6, vol: 0.1, delay: i * 0.13 }));
      tone(110, { dur: 1, vol: 0.08, delay: 0.3 });
    },
    chime() {
      [659.25, 987.77, 1318.51, 1975.53].forEach((f, i) => tone(f, { dur: 1.8, vol: 0.05, delay: i * 0.14 }));
    },
    toll() {
      tone(98, { dur: 4, vol: 0.18 });
      tone(196.5, { dur: 3, vol: 0.07 });
      tone(294, { dur: 2.2, vol: 0.04 });
    },
  };

  root.GameSound = Sound;
})(typeof window !== 'undefined' ? window : globalThis);
