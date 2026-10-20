// ฉากวาดด้วย Canvas: ท้องฟ้า ภูเขาหลายชั้น สิ่งก่อสร้าง หมอก แสง และอนุภาค
// ส่วนนิ่งถูกวาดล่วงหน้าเป็นชั้น (ท้องฟ้า ไกล กลาง ใกล้) แล้วเลื่อนแบบพารัลแลกซ์ ส่วนที่ขยับวาดใหม่ทุกเฟรม
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  } else {
    root.SceneArt = api;
  }
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  const TAU = Math.PI * 2;

  // ---------- เครื่องมือพื้นฐาน ----------

  function mulberry32(seed) {
    return function () {
      seed = (seed + 0x6d2b79f5) | 0;
      let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function hashString(str) {
    let h = 2166136261;
    for (let i = 0; i < str.length; i++) {
      h ^= str.charCodeAt(i);
      h = Math.imul(h, 16777619);
    }
    return h >>> 0;
  }

  // value noise หนึ่งมิติแบบหลายอ็อกเทฟ คืนค่าประมาณ 0..1
  function makeNoise(rng) {
    const N = 512;
    const v = new Float32Array(N);
    for (let i = 0; i < N; i++) v[i] = rng();
    function base(x) {
      const i = Math.floor(x);
      const f = x - i;
      const a = v[((i % N) + N) % N];
      const b = v[(((i + 1) % N) + N) % N];
      const t = f * f * (3 - 2 * f);
      return a + (b - a) * t;
    }
    return function (x, octaves = 5, rough = 0.5) {
      let sum = 0;
      let amp = 1;
      let freq = 1;
      let norm = 0;
      for (let o = 0; o < octaves; o++) {
        sum += base(x * freq + o * 31.7) * amp;
        norm += amp;
        amp *= rough;
        freq *= 2;
      }
      return sum / norm;
    };
  }

  function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v));
  }

  function lerp(a, b, t) {
    return a + (b - a) * t;
  }

  function hexToRgb(hex) {
    let h = hex.replace('#', '');
    if (h.length === 3) h = h.split('').map((c) => c + c).join('');
    const n = parseInt(h, 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  }

  function mix(a, b, t) {
    const A = hexToRgb(a);
    const B = hexToRgb(b);
    return '#' + A.map((v, i) => Math.round(v + (B[i] - v) * t).toString(16).padStart(2, '0')).join('');
  }

  function rgba(hex, a) {
    const [r, g, b] = hexToRgb(hex);
    return `rgba(${r},${g},${b},${a})`;
  }

  function makeCanvas(w, h) {
    const c = document.createElement('canvas');
    c.width = Math.max(1, Math.round(w));
    c.height = Math.max(1, Math.round(h));
    return c;
  }

  const glowCache = new Map();
  // สไปรต์แสงฟุ้งทรงกลม ใช้วาดซ้ำแทนการสร้าง gradient ทุกเฟรม
  function glowSprite(color, hard = 0) {
    const key = color + '|' + hard;
    if (glowCache.has(key)) return glowCache.get(key);
    const c = makeCanvas(64, 64);
    const g = c.getContext('2d');
    const grad = g.createRadialGradient(32, 32, 0, 32, 32, 32);
    grad.addColorStop(0, rgba(color, 1));
    grad.addColorStop(clamp(0.15 + hard, 0, 0.9), rgba(color, 0.65));
    grad.addColorStop(0.5, rgba(color, 0.18));
    grad.addColorStop(1, rgba(color, 0));
    g.fillStyle = grad;
    g.fillRect(0, 0, 64, 64);
    glowCache.set(key, c);
    return c;
  }

  function drawGlow(ctx, x, y, r, color, alpha, hard) {
    if (alpha <= 0 || r <= 0) return;
    ctx.globalAlpha = Math.min(1, alpha);
    ctx.drawImage(glowSprite(color, hard), x - r, y - r, r * 2, r * 2);
  }

  // ระบายเงาทึบพร้อมขอบแสงฝั่งที่แสงส่องมา
  function paint(ctx, S, path, fill, rim) {
    if (rim) {
      ctx.save();
      ctx.translate(S.lightDir * Math.max(1.2, 2.2 * S.u), -Math.max(0.6, S.u));
      ctx.fillStyle = rim;
      ctx.fill(path);
      ctx.restore();
    }
    ctx.fillStyle = fill;
    ctx.fill(path);
  }

  // ---------- เส้นสันเขาและพื้นดิน ----------

  function ridge(S, L) {
    const pts = [];
    const step = Math.max(2, S.W / 260);
    const seed = S.rng() * 1000;
    const freq = (L.freq || 3) / S.W;
    const x0 = -S.pad - step;
    for (let x = x0; x <= S.W + S.pad + step; x += step) {
      const n = S.noise(seed + x * freq, L.octaves || 6, L.rough || 0.52);
      let h = clamp((n - 0.5) * (L.contrast || 1.8) + 0.5, 0, 1) * (L.amp || 0);
      if (L.bumps) {
        for (const b of L.bumps) {
          const d = Math.abs(x / S.W - b.x) / b.w;
          if (d < 1) h += b.h * Math.pow(1 - d, b.sharp || 1.6);
        }
      }
      pts.push([x, S.H * ((L.y || 0.5) - h)]);
    }
    pts.step = step;
    pts.x0 = x0;
    return pts;
  }

  function yAt(pts, x) {
    const f = (x - pts.x0) / pts.step;
    const i = clamp(Math.floor(f), 0, pts.length - 2);
    const t = clamp(f - i, 0, 1);
    return lerp(pts[i][1], pts[i + 1][1], t);
  }

  function minY(pts) {
    let m = Infinity;
    for (const p of pts) m = Math.min(m, p[1]);
    return m;
  }

  function ridgePath(pts, bottom) {
    const p = new Path2D();
    p.moveTo(pts[0][0], bottom);
    for (const [x, y] of pts) p.lineTo(x, y);
    p.lineTo(pts[pts.length - 1][0], bottom);
    p.closePath();
    return p;
  }

  function drawFlowers(ctx, S, pts, L) {
    const colors = L.flowerColors || ['#ffe08a', '#ffffff', '#f7a8c8', '#c8a8ff'];
    for (let i = 0; i < L.flowers; i++) {
      const x = -S.pad + S.rng() * (S.W + 2 * S.pad);
      const y = yAt(pts, x) + S.rng() * S.H * 0.12;
      const r = (0.8 + S.rng() * 1.6) * S.u;
      ctx.fillStyle = colors[Math.floor(S.rng() * colors.length)];
      ctx.globalAlpha = 0.55 + S.rng() * 0.45;
      ctx.beginPath();
      ctx.arc(x, y, r, 0, TAU);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }

  // ---------- ต้นไม้ ----------

  function pinePath(p, x, y, h, rng) {
    const tiers = 4 + Math.floor(rng() * 3);
    const w = h * (0.3 + rng() * 0.1);
    const right = [];
    for (let i = 1; i <= tiers; i++) {
      const t = i / tiers;
      const ty = y - h + t * h * 0.86;
      const tw = w * t * (0.75 + rng() * 0.35);
      right.push([tw, ty]);
    }
    p.moveTo(x, y - h);
    for (const [tw, ty] of right) {
      p.lineTo(x + tw, ty);
      p.lineTo(x + tw * 0.42, ty - h * 0.025);
    }
    p.lineTo(x + w * 0.09, y - h * 0.12);
    p.lineTo(x + w * 0.07, y);
    p.lineTo(x - w * 0.07, y);
    p.lineTo(x - w * 0.09, y - h * 0.12);
    for (let i = right.length - 1; i >= 0; i--) {
      const [tw, ty] = right[i];
      p.lineTo(x - tw * 0.42, ty - h * 0.025);
      p.lineTo(x - tw, ty);
    }
    p.closePath();
    return w;
  }

  function roundBlobs(x, y, h, rng) {
    const blobs = [];
    const n = 5 + Math.floor(rng() * 4);
    for (let i = 0; i < n; i++) {
      const a = (i / n) * TAU + rng();
      const d = rng() * h * 0.2;
      blobs.push([x + Math.cos(a) * d * 1.2, y - h * 0.66 + Math.sin(a) * d * 0.8, h * (0.17 + rng() * 0.12)]);
    }
    blobs.push([x, y - h * 0.72, h * 0.26]);
    return blobs;
  }

  function drawTree(ctx, S, kind, x, y, h, L) {
    const p = new Path2D();
    if (kind === 'mixed') kind = S.rng() < 0.55 ? 'pine' : 'round';
    if (kind === 'pine') {
      const w = pinePath(p, x, y, h, S.rng);
      paint(ctx, S, p, L.color, L.rim);
      if (L.light) {
        ctx.save();
        ctx.clip(p);
        const g = ctx.createLinearGradient(x - w * S.lightDir, 0, x + w * S.lightDir, 0);
        g.addColorStop(0, rgba(L.light, 0));
        g.addColorStop(1, rgba(L.light, 0.45));
        ctx.fillStyle = g;
        ctx.fillRect(x - w, y - h, w * 2, h);
        ctx.restore();
      }
      return;
    }
    // ต้นไม้ใบกลม: ลำต้นกับกลุ่มพุ่มใบ
    const trunkW = h * 0.07;
    p.rect(x - trunkW / 2, y - h * 0.5, trunkW, h * 0.5);
    const blobs = roundBlobs(x, y, h, S.rng);
    for (const [bx, by, r] of blobs) {
      p.moveTo(bx + r, by);
      p.arc(bx, by, r, 0, TAU);
    }
    paint(ctx, S, p, L.color, L.rim);
    if (L.light) {
      ctx.save();
      ctx.clip(p);
      ctx.fillStyle = rgba(L.light, 0.5);
      for (const [bx, by, r] of blobs) {
        ctx.beginPath();
        ctx.arc(bx + S.lightDir * r * 0.3, by - r * 0.3, r * 0.62, 0, TAU);
        ctx.fill();
      }
      const g = ctx.createLinearGradient(0, y - h, 0, y);
      g.addColorStop(0.5, 'rgba(0,0,0,0)');
      g.addColorStop(1, 'rgba(0,0,0,0.3)');
      ctx.fillStyle = g;
      ctx.fillRect(x - h, y - h, h * 2, h);
      ctx.restore();
    }
  }

  function branch(ctx, x, y, len, ang, w, depth, rng, tips) {
    const ex = x + Math.cos(ang) * len;
    const ey = y + Math.sin(ang) * len;
    ctx.lineWidth = w;
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.quadraticCurveTo(x + Math.cos(ang + 0.3) * len * 0.5, y + Math.sin(ang + 0.3) * len * 0.5, ex, ey);
    ctx.stroke();
    if (depth <= 0) {
      if (tips) tips.push([ex, ey]);
      return;
    }
    const n = 2 + (rng() < 0.4 ? 1 : 0);
    for (let i = 0; i < n; i++) {
      const spread = (i / (n - 1 || 1) - 0.5) * 1.1 + (rng() - 0.5) * 0.4;
      branch(ctx, ex, ey, len * (0.62 + rng() * 0.18), ang + spread, w * 0.62, depth - 1, rng, tips);
    }
  }

  // ---------- องค์ประกอบของฉาก ----------

  const PRIMS = {
    range(ctx, S, L) {
      const pts = ridge(S, L);
      const top = minY(pts);
      const baseY = S.H * (L.y + 0.03);
      const path = ridgePath(pts, S.floor + 2);
      const g = ctx.createLinearGradient(0, top, 0, L.solid ? S.floor : baseY + S.H * 0.08);
      g.addColorStop(0, L.color);
      g.addColorStop(1, L.bottom || mix(L.color, S.haze, L.fade ?? 0.35));
      paint(ctx, S, path, g, L.rim && rgba(L.rim, L.rimAlpha ?? 0.6));
      ctx.save();
      ctx.clip(path);
      if (L.facets) {
        // ระนาบหน้าผาที่หันเข้าแสงสว่างกว่า ด้านหลังมืดกว่า
        const win = 9;
        for (let i = win; i < pts.length - win - 1; i++) {
          const [x0, y0] = pts[i];
          const [x1, y1] = pts[i + 1];
          const slope = ((pts[i + win][1] - pts[i - win][1]) / (pts[i + win][0] - pts[i - win][0])) * S.lightDir;
          const k = clamp(slope * 1.6, -1, 1);
          ctx.fillStyle = k > 0 ? rgba(L.litColor || '#fff0dc', k * L.facets) : rgba(L.shadeColor || '#0a0a22', -k * L.facets);
          ctx.beginPath();
          ctx.moveTo(x0, y0);
          ctx.lineTo(x1 + 0.6, y1);
          ctx.lineTo(x1 + 0.6, baseY);
          ctx.lineTo(x0, baseY);
          ctx.fill();
        }
        const hg = ctx.createLinearGradient(0, top, 0, baseY);
        hg.addColorStop(0.35, rgba(S.haze, 0));
        hg.addColorStop(1, rgba(S.haze, L.fade ?? 0.35));
        ctx.fillStyle = hg;
        ctx.fillRect(-S.pad, top, S.W + S.pad * 2, baseY - top + S.H * 0.1);
      }
      if (L.snow) {
        const sg = ctx.createLinearGradient(0, top, 0, top + S.H * L.amp * (L.snowDepth || 0.55));
        sg.addColorStop(0, rgba(L.snow, 0.92));
        sg.addColorStop(0.55, rgba(L.snow, 0.45));
        sg.addColorStop(1, rgba(L.snow, 0));
        ctx.fillStyle = sg;
        ctx.fillRect(-S.pad, top, S.W + 2 * S.pad, S.H * L.amp);
      }
      ctx.restore();
      if (L.flowers) drawFlowers(ctx, S, pts, L);
      return pts;
    },

    // เพดานถ้ำพร้อมหินย้อย
    ceiling(ctx, S, L) {
      const pts = ridge(S, L).map(([x, y]) => [x, 2 * S.H * L.y - y]);
      pts.step = Math.max(2, S.W / 260);
      pts.x0 = pts[0][0];
      const p = new Path2D();
      p.moveTo(pts[0][0], -2);
      for (const [x, y] of pts) p.lineTo(x, y);
      p.lineTo(pts[pts.length - 1][0], -2);
      p.closePath();
      const count = Math.round((S.W / 1000) * (L.stalactites || 30));
      for (let i = 0; i < count; i++) {
        const x = -S.pad + S.rng() * (S.W + 2 * S.pad);
        const y = yAt(pts, x) - 2;
        const w = (4 + S.rng() * 10) * S.u * (L.scale || 1);
        const len = w * (2.5 + S.rng() * 4);
        p.moveTo(x - w, y);
        p.lineTo(x - w * 0.2, y + len * 0.7);
        p.lineTo(x, y + len);
        p.lineTo(x + w * 0.25, y + len * 0.65);
        p.lineTo(x + w, y);
        p.closePath();
      }
      const top = 0;
      const g = ctx.createLinearGradient(0, top, 0, S.H * (L.y + L.amp + 0.1));
      g.addColorStop(0, L.top || mix(L.color, '#000000', 0.5));
      g.addColorStop(1, L.color);
      ctx.save();
      ctx.translate(0, 0);
      if (L.rim) {
        ctx.save();
        ctx.translate(0, 1.5 * S.u);
        ctx.fillStyle = rgba(L.rim, 0.5);
        ctx.fill(p);
        ctx.restore();
      }
      ctx.fillStyle = g;
      ctx.fill(p);
      ctx.restore();
    },

    trees(ctx, S, L) {
      if (L.items) {
        for (const it of L.items) {
          drawTree(ctx, S, it.kind || L.kind, it.x * S.W, (it.y ?? L.y) * S.H, it.s * S.u, L);
        }
        return;
      }
      const pts = ridge(S, { ...L, amp: L.amp ?? 0.03 });
      const ground = ridgePath(pts, S.floor + 2);
      const size = L.size * S.u;
      const trees = [];
      for (let x = -S.pad; x < S.W + S.pad; x += size * (L.spacing || 0.22) * (0.5 + S.rng())) {
        if (S.rng() > (L.density ?? 0.6)) continue;
        trees.push([x, yAt(pts, x) + size * 0.08, size * (0.6 + S.rng() * 0.7)]);
      }
      // ต้นเล็กอยู่หลัง ต้นใหญ่อยู่หน้า
      trees.sort((a, b) => a[2] - b[2]);
      for (const [x, y, h] of trees) drawTree(ctx, S, L.kind, x, y, h, L);
      const g = ctx.createLinearGradient(0, minY(pts), 0, S.floor);
      g.addColorStop(0, L.ground || L.color);
      g.addColorStop(1, mix(L.ground || L.color, '#000000', 0.35));
      ctx.fillStyle = g;
      ctx.fill(ground);
    },

    deadTree(ctx, S, L) {
      const k = (L.size * S.u) / 100;
      const x = L.x * S.W;
      const y = L.y * S.H;
      ctx.save();
      ctx.strokeStyle = L.color;
      ctx.lineCap = 'round';
      const rng = mulberry32(hashString('dead' + L.x));
      branch(ctx, x, y, 34 * k, -Math.PI / 2 + (L.lean || 0), 9 * k, 5, rng, null);
      ctx.restore();
    },

    bigTree(ctx, S, L) {
      const k = (L.size * S.u) / 100;
      const x = L.x * S.W;
      const y = L.y * S.H;
      const rng = mulberry32(hashString('big' + L.x + L.size));
      // ลำต้นและกิ่ง
      ctx.save();
      ctx.strokeStyle = L.trunk || L.color;
      ctx.lineCap = 'round';
      const tips = [];
      branch(ctx, x, y + 2, 30 * k, -Math.PI / 2, 12 * k, 4, rng, tips);
      ctx.fillStyle = L.trunk || L.color;
      ctx.beginPath();
      ctx.moveTo(x - 14 * k, y + 2);
      ctx.quadraticCurveTo(x - 5 * k, y - 4 * k, x - 4 * k, y - 22 * k);
      ctx.lineTo(x + 4 * k, y - 22 * k);
      ctx.quadraticCurveTo(x + 5 * k, y - 4 * k, x + 15 * k, y + 2);
      ctx.fill();
      ctx.restore();
      const leaves = L.leaves;
      if (!leaves) return;
      // พุ่มใบระบายสามชั้น: เงา กลาง แสง
      const cx = x;
      const cy = y - 78 * k;
      const passes = [
        { color: leaves[0], n: 46, spread: 1, dy: 5, r: [9, 15] },
        { color: leaves[1], n: 54, spread: 0.85, dy: -2, r: [7, 12] },
        { color: leaves[2], n: 34, spread: 0.6, dy: -7, r: [4, 8], shift: 6 },
      ];
      for (const pass of passes) {
        ctx.fillStyle = pass.color;
        for (let i = 0; i < pass.n; i++) {
          const tip = tips[Math.floor(rng() * tips.length)];
          const atTip = tip && rng() < 0.85;
          const bx = atTip ? tip[0] + (rng() - 0.5) * 26 * k * pass.spread : cx + (rng() - 0.5) * 100 * k * pass.spread;
          const by = atTip ? tip[1] + (rng() - 0.5) * 18 * k * pass.spread : cy + (rng() - 0.5) * 50 * k * pass.spread;
          const r = lerp(pass.r[0], pass.r[1], rng()) * k;
          ctx.beginPath();
          ctx.arc(bx + (pass.shift || 0) * k * S.lightDir, by + pass.dy * k, r, 0, TAU);
          ctx.fill();
        }
      }
    },

    cottages(ctx, S, L) {
      for (const it of L.items) cottage(ctx, S, it, L);
    },

    windmill(ctx, S, L) {
      const k = (L.size * S.u) / 100;
      const x = L.x * S.W;
      const y = L.y * S.H;
      const p = new Path2D();
      p.moveTo(x - 13 * k, y);
      p.lineTo(x - 7 * k, y - 70 * k);
      p.lineTo(x + 7 * k, y - 70 * k);
      p.lineTo(x + 13 * k, y);
      p.closePath();
      const g = ctx.createLinearGradient(x - 13 * k * S.lightDir, 0, x + 13 * k * S.lightDir, 0);
      g.addColorStop(0, mix(L.color, '#000000', 0.25));
      g.addColorStop(1, L.color);
      paint(ctx, S, p, g, null);
      const cap = new Path2D();
      cap.moveTo(x - 10 * k, y - 69 * k);
      cap.quadraticCurveTo(x, y - 88 * k, x + 10 * k, y - 69 * k);
      cap.closePath();
      paint(ctx, S, cap, L.cap, null);
      ctx.fillStyle = L.door || '#4a2e1e';
      ctx.fillRect(x - 3 * k, y - 12 * k, 6 * k, 12 * k);
      ctx.fillStyle = '#ffd88a';
      ctx.fillRect(x - 2 * k, y - 44 * k, 4 * k, 6 * k);
      S.emitters.push({ type: 'windmill', x, y: y - 72 * k, r: 50 * k, color: L.blade, group: S.group });
    },

    castle(ctx, S, L) {
      const k = (L.size * S.u) / 100;
      const x = L.x * S.W;
      const y = L.y * S.H;
      const rng = S.rng;
      const p = new Path2D();
      if (L.cliff) {
        const left = [];
        const right = [];
        for (let i = 0; i <= 10; i++) {
          const t = i / 10;
          left.push([x - 50 * k - t * 46 * k + (rng() - 0.5) * 12 * k, y + t * 150 * k]);
          right.push([x + 50 * k + t * 40 * k + (rng() - 0.5) * 12 * k, y + t * 150 * k]);
        }
        p.moveTo(x - 50 * k, y - 1);
        for (const [px, py] of left) p.lineTo(px, py);
        p.lineTo(left[left.length - 1][0], S.floor + 2);
        p.lineTo(right[right.length - 1][0], S.floor + 2);
        for (let i = right.length - 1; i >= 0; i--) p.lineTo(right[i][0], right[i][1]);
        p.lineTo(x + 50 * k, y - 1);
        p.closePath();
      }
      const cren = (x0, x1, top, mh, mw) => {
        for (let cx = x0; cx < x1 - mw * 0.5; cx += mw * 2) p.rect(cx, top - mh, mw, mh + 1);
      };
      p.rect(x - 46 * k, y - 26 * k, 92 * k, 27 * k);
      cren(x - 46 * k, x + 46 * k, y - 26 * k, 4 * k, 4 * k);
      p.rect(x - 16 * k, y - 64 * k, 32 * k, 64 * k);
      cren(x - 16 * k, x + 16 * k, y - 64 * k, 5 * k, 4 * k);
      const towers = [
        { dx: -46, w: 13, h: 48, roof: true },
        { dx: 46, w: 13, h: 44, roof: true },
        { dx: -28, w: 10, h: 58, roof: false },
        { dx: 24, w: 11, h: 82, roof: true },
        { dx: 4, w: 8, h: 92, roof: true },
      ];
      let flagAt = null;
      for (const t of towers) {
        const tx = x + t.dx * k;
        const top = y - t.h * k;
        p.rect(tx - (t.w / 2) * k, top, t.w * k, t.h * k);
        if (t.roof) {
          const apex = top - t.w * 1.5 * k;
          p.moveTo(tx - (t.w / 2 + 2) * k, top + 1);
          p.lineTo(tx, apex);
          p.lineTo(tx + (t.w / 2 + 2) * k, top + 1);
          p.closePath();
          if (!flagAt || apex < flagAt[1]) flagAt = [tx, apex];
        } else {
          cren(tx - (t.w / 2) * k, tx + (t.w / 2) * k, top, 3.5 * k, 3 * k);
        }
      }
      if (flagAt) p.rect(flagAt[0] - 0.5 * k, flagAt[1] - 12 * k, 1.2 * k, 12 * k);
      paint(ctx, S, p, L.color, L.rim);
      // หน้าต่างที่มีแสงไฟ
      const wins = [];
      for (let i = 0; i < 4; i++) wins.push([x - 9 * k + (i % 2) * 18 * k, y - 50 * k + Math.floor(i / 2) * 18 * k]);
      for (const t of towers) {
        for (let j = 0; j < 2; j++) {
          if (rng() < 0.6) wins.push([x + t.dx * k, y - t.h * k + (10 + j * 14) * k]);
        }
      }
      let glows = 0;
      for (const [wx, wy] of wins) {
        ctx.fillStyle = L.windows || '#ffcf7a';
        ctx.beginPath();
        ctx.moveTo(wx - 1.4 * k, wy + 3 * k);
        ctx.lineTo(wx - 1.4 * k, wy);
        ctx.arc(wx, wy, 1.4 * k, Math.PI, 0);
        ctx.lineTo(wx + 1.4 * k, wy + 3 * k);
        ctx.fill();
        if (glows++ < 8) S.emitters.push({ type: 'window', x: wx, y: wy + k, r: 9 * k, color: L.windows || '#ffcf7a', group: S.group, phase: rng() * TAU });
      }
      // ประตูโค้ง
      ctx.fillStyle = mix(L.color, '#000000', 0.4);
      ctx.beginPath();
      ctx.moveTo(x - 6 * k, y);
      ctx.lineTo(x - 6 * k, y - 10 * k);
      ctx.arc(x, y - 10 * k, 6 * k, Math.PI, 0);
      ctx.lineTo(x + 6 * k, y);
      ctx.fill();
      if (flagAt && L.flags) S.emitters.push({ type: 'flag', x: flagAt[0] + 0.6 * k, y: flagAt[1] - 12 * k, w: 13 * k, h: 7 * k, color: L.flags, group: S.group });
    },

    tower(ctx, S, L) {
      const k = (L.size * S.u) / 100;
      const x = L.x * S.W;
      const y = L.y * S.H;
      const p = new Path2D();
      p.moveTo(x - 46 * k, y + 4 * k);
      p.quadraticCurveTo(x - 20 * k, y - 16 * k, x, y - 14 * k);
      p.quadraticCurveTo(x + 22 * k, y - 16 * k, x + 50 * k, y + 4 * k);
      p.lineTo(x + 50 * k, S.floor + 2);
      p.lineTo(x - 46 * k, S.floor + 2);
      p.closePath();
      p.moveTo(x - 10 * k, y - 8 * k);
      p.lineTo(x - 7 * k, y - 104 * k);
      p.lineTo(x + 7 * k, y - 104 * k);
      p.lineTo(x + 10 * k, y - 8 * k);
      p.closePath();
      for (const ly of [36, 72]) p.rect(x - 11 * k, y - ly * k, 22 * k, 3 * k);
      p.rect(x - 13 * k, y - 107 * k, 26 * k, 4 * k);
      p.moveTo(x - 12 * k, y - 106 * k);
      p.quadraticCurveTo(x - 4 * k, y - 118 * k, x + 5 * k, y - 150 * k);
      p.quadraticCurveTo(x + 3 * k, y - 120 * k, x + 13 * k, y - 106 * k);
      p.closePath();
      paint(ctx, S, p, L.color, L.rim);
      for (let i = 0; i < 6; i++) {
        const wy = y - (18 + i * 14) * k;
        const wx = x + Math.sin(i * 1.7) * 3.5 * k;
        ctx.fillStyle = L.windows || '#bfe4ff';
        ctx.fillRect(wx - 1.1 * k, wy - 2.5 * k, 2.2 * k, 4.5 * k);
        if (i % 2 === 0) S.emitters.push({ type: 'window', x: wx, y: wy, r: 7 * k, color: L.windows || '#bfe4ff', group: S.group, phase: i });
      }
      S.emitters.push({ type: 'orb', x: x + 5 * k, y: y - 160 * k, r: 5 * k, color: L.orb || '#9fe0ff', group: S.group });
    },

    city(ctx, S, L) {
      const rng = S.rng;
      const base = L.y * S.H;
      const hmax = L.h * S.u;
      const p = new Path2D();
      const wins = [];
      let x = L.x0 * S.W;
      const x1 = L.x1 * S.W;
      while (x < x1) {
        const w = (12 + rng() * 26) * S.u * (L.scale || 1);
        const h = hmax * (0.3 + rng() * 0.7);
        const top = base - h;
        p.rect(x, top, w, S.floor - top + 2);
        const type = rng();
        if (type < 0.25) {
          p.moveTo(x - 1, top + 1);
          p.lineTo(x + w / 2, top - w * 0.55);
          p.lineTo(x + w + 1, top + 1);
          p.closePath();
        } else if (type < 0.38) {
          p.moveTo(x + w * 0.1, top + 1);
          p.arc(x + w / 2, top + 1, w * 0.4, Math.PI, 0);
          p.closePath();
          p.rect(x + w / 2 - 0.6 * S.u, top - w * 0.4 - 6 * S.u, 1.2 * S.u, 6 * S.u);
        } else if (type < 0.48) {
          p.moveTo(x + w * 0.25, top + 1);
          p.lineTo(x + w / 2, top - w * 1.4);
          p.lineTo(x + w * 0.75, top + 1);
          p.closePath();
        } else if (type < 0.62) {
          for (let cx = x; cx < x + w - 2 * S.u; cx += 4 * S.u) p.rect(cx, top - 2.5 * S.u, 2 * S.u, 2.6 * S.u);
        }
        const cols = Math.max(1, Math.floor(w / (6 * S.u)));
        const rows = Math.max(1, Math.floor(h / (8 * S.u)));
        for (let r = 0; r < rows; r++) {
          for (let c = 0; c < cols; c++) {
            if (rng() < (L.lit ?? 0.25)) wins.push([x + (c + 0.5) * (w / cols), top + (r + 0.6) * 8 * S.u]);
          }
        }
        x += w + rng() * 2 * S.u;
      }
      if (L.palace) {
        const px = L.palace * S.W;
        const pw = 60 * S.u;
        const ph = hmax * 1.15;
        p.rect(px - pw / 2, base - ph, pw, ph);
        p.moveTo(px - pw * 0.3, base - ph + 1);
        p.arc(px, base - ph + 1, pw * 0.3, Math.PI, 0);
        p.closePath();
        p.rect(px - 0.8 * S.u, base - ph - pw * 0.3 - 12 * S.u, 1.6 * S.u, 12 * S.u);
        for (const side of [-1, 1]) {
          const mx = px + side * pw * 0.62;
          p.rect(mx - 4 * S.u, base - ph * 1.2, 8 * S.u, ph * 1.2);
          p.moveTo(mx - 5 * S.u, base - ph * 1.2 + 1);
          p.lineTo(mx, base - ph * 1.2 - 16 * S.u);
          p.lineTo(mx + 5 * S.u, base - ph * 1.2 + 1);
          p.closePath();
        }
      }
      paint(ctx, S, p, L.color, L.rim);
      ctx.fillStyle = L.windows || '#ffcf7a';
      for (const [wx, wy] of wins) ctx.fillRect(wx - 1 * S.u, wy - 1.5 * S.u, 2 * S.u, 3 * S.u);
      for (let i = 0; i < Math.min(10, wins.length); i++) {
        const [wx, wy] = wins[Math.floor(rng() * wins.length)];
        S.emitters.push({ type: 'window', x: wx, y: wy, r: 10 * S.u, color: L.windows || '#ffcf7a', group: S.group, phase: rng() * TAU });
      }
    },

    water(ctx, S, L) {
      const y = L.y * S.H;
      ctx.save();
      ctx.beginPath();
      ctx.rect(-S.pad, y, S.W + 2 * S.pad, S.floor - y + 2);
      ctx.clip();
      const g = ctx.createLinearGradient(0, y, 0, S.H);
      g.addColorStop(0, L.top);
      g.addColorStop(1, L.bottom);
      ctx.fillStyle = g;
      ctx.fillRect(-S.pad, y, S.W + 2 * S.pad, S.floor - y + 2);
      if (L.reflect) {
        ctx.save();
        ctx.globalAlpha = L.reflect;
        ctx.translate(0, 2 * y);
        ctx.scale(1, -1);
        for (const src of S.reflectSources) ctx.drawImage(src, -S.pad, 0, S.W + 2 * S.pad, S.floor);
        ctx.restore();
        const fade = ctx.createLinearGradient(0, y, 0, S.H);
        fade.addColorStop(0, rgba(L.bottom, 0.1));
        fade.addColorStop(1, rgba(L.bottom, 0.85));
        ctx.fillStyle = fade;
        ctx.fillRect(-S.pad, y, S.W + 2 * S.pad, S.floor - y + 2);
      }
      for (let i = 0; i < 160; i++) {
        const t = S.rng();
        const yy = y + t * t * (S.H - y);
        const len = (10 + S.rng() * 60) * S.u * (0.3 + t);
        ctx.fillStyle = rgba(L.streak || '#ffffff', 0.04 + S.rng() * 0.08);
        ctx.fillRect(-S.pad + S.rng() * (S.W + 2 * S.pad), yy, len, Math.max(1, S.u * 0.8));
      }
      ctx.fillStyle = rgba(L.streak || '#ffffff', 0.25);
      ctx.fillRect(-S.pad, y, S.W + 2 * S.pad, Math.max(1, S.u));
      ctx.restore();
      S.emitters.push({ type: 'water', y, x: (L.glintX ?? 0.5) * S.W, color: L.glint || '#fff0c0', group: S.group, spread: L.spread || 0.12 });
    },

    ships(ctx, S, L) {
      for (const it of L.items) {
        const k = (it.s * S.u) / 100;
        const x = it.x * S.W;
        const y = L.y * S.H;
        const hull = new Path2D();
        hull.moveTo(x - 42 * k, y - 9 * k);
        hull.lineTo(x + 46 * k, y - 12 * k);
        hull.quadraticCurveTo(x + 32 * k, y + 4 * k, x + 20 * k, y + 4 * k);
        hull.lineTo(x - 30 * k, y + 4 * k);
        hull.quadraticCurveTo(x - 40 * k, y + 2 * k, x - 42 * k, y - 9 * k);
        hull.closePath();
        hull.rect(x - 12 * k, y - 76 * k, 1.8 * k, 68 * k);
        hull.rect(x + 14 * k, y - 62 * k, 1.6 * k, 52 * k);
        paint(ctx, S, hull, L.color, L.rim);
        for (const [mx, top, h] of [[x - 11 * k, y - 72 * k, 26 * k], [x - 11 * k, y - 43 * k, 24 * k], [x + 15 * k, y - 58 * k, 22 * k], [x + 15 * k, y - 33 * k, 18 * k]]) {
          const sw = h * 0.62;
          const sail = new Path2D();
          sail.moveTo(mx - sw, top);
          sail.lineTo(mx + sw, top);
          sail.quadraticCurveTo(mx + sw * 1.25, top + h / 2, mx + sw * 0.92, top + h);
          sail.lineTo(mx - sw * 0.92, top + h);
          sail.quadraticCurveTo(mx - sw * 0.7, top + h / 2, mx - sw, top);
          sail.closePath();
          const sg = ctx.createLinearGradient(mx - sw * S.lightDir, 0, mx + sw * S.lightDir, 0);
          sg.addColorStop(0, mix(L.sail, '#000000', 0.35));
          sg.addColorStop(1, L.sail);
          ctx.fillStyle = sg;
          ctx.fill(sail);
        }
        ctx.fillStyle = rgba(L.color, 0.35);
        for (let i = 0; i < 6; i++) ctx.fillRect(x - 36 * k + (S.rng() - 0.5) * 6 * k, y + (6 + i * 4) * k, 70 * k * (1 - i * 0.12), 1.4 * k);
        S.emitters.push({ type: 'flag', x: x - 11 * k, y: y - 76 * k, w: 9 * k, h: 5 * k, color: L.flags || '#c94a4a', group: S.group });
      }
    },

    lighthouse(ctx, S, L) {
      const k = (L.size * S.u) / 100;
      const x = L.x * S.W;
      const y = L.y * S.H;
      const p = new Path2D();
      p.moveTo(x - 52 * k, y + 8 * k);
      p.quadraticCurveTo(x - 20 * k, y - 14 * k, x, y - 8 * k);
      p.quadraticCurveTo(x + 26 * k, y - 12 * k, x + 58 * k, y + 8 * k);
      p.quadraticCurveTo(x, y + 20 * k, x - 52 * k, y + 8 * k);
      p.closePath();
      p.moveTo(x - 8 * k, y - 4 * k);
      p.lineTo(x - 5 * k, y - 70 * k);
      p.lineTo(x + 5 * k, y - 70 * k);
      p.lineTo(x + 8 * k, y - 4 * k);
      p.closePath();
      p.rect(x - 7 * k, y - 72 * k, 14 * k, 3 * k);
      p.moveTo(x - 6 * k, y - 82 * k);
      p.lineTo(x, y - 90 * k);
      p.lineTo(x + 6 * k, y - 82 * k);
      p.closePath();
      paint(ctx, S, p, L.color, L.rim);
      ctx.fillStyle = '#fff1c4';
      ctx.fillRect(x - 4 * k, y - 82 * k, 8 * k, 10 * k);
      S.emitters.push({ type: 'beacon', x, y: y - 77 * k, r: 10 * k, color: '#fff1c4', group: S.group });
    },

    tombs(ctx, S, L) {
      const items = [];
      for (let i = 0; i < L.count; i++) {
        items.push({ x: lerp(L.x0, L.x1, S.rng()) * S.W, y: (L.y + S.rng() * 0.05) * S.H, k: ((0.6 + S.rng() * 0.7) * L.size * S.u) / 100, type: S.rng(), tilt: (S.rng() - 0.5) * 0.3 });
      }
      items.sort((a, b) => a.y - b.y);
      for (const t of items) {
        ctx.save();
        ctx.translate(t.x, t.y);
        ctx.rotate(t.tilt);
        const p = new Path2D();
        const k = t.k;
        if (t.type < 0.45) {
          p.moveTo(-7 * k, 0);
          p.lineTo(-7 * k, -14 * k);
          p.arc(0, -14 * k, 7 * k, Math.PI, 0);
          p.lineTo(7 * k, 0);
          p.closePath();
        } else if (t.type < 0.8) {
          p.rect(-1.8 * k, -26 * k, 3.6 * k, 26 * k);
          p.rect(-8 * k, -20 * k, 16 * k, 3.6 * k);
        } else {
          p.moveTo(-5 * k, 0);
          p.lineTo(-3.5 * k, -26 * k);
          p.lineTo(0, -31 * k);
          p.lineTo(3.5 * k, -26 * k);
          p.lineTo(5 * k, 0);
          p.closePath();
        }
        p.rect(-9 * k, -1.5 * k, 18 * k, 3 * k);
        paint(ctx, S, p, L.color, L.rim);
        ctx.restore();
      }
      if (L.fence) {
        const fy = (L.y + 0.07) * S.H;
        ctx.strokeStyle = L.color;
        ctx.fillStyle = L.color;
        ctx.lineWidth = 1.2 * S.u;
        ctx.beginPath();
        ctx.moveTo(-S.pad, fy - 12 * S.u);
        ctx.lineTo(S.W + S.pad, fy - 12 * S.u);
        ctx.moveTo(-S.pad, fy - 4 * S.u);
        ctx.lineTo(S.W + S.pad, fy - 4 * S.u);
        ctx.stroke();
        for (let fx = -S.pad; fx < S.W + S.pad; fx += 7 * S.u) {
          ctx.fillRect(fx, fy - 20 * S.u, 1.4 * S.u, 22 * S.u);
          ctx.beginPath();
          ctx.moveTo(fx - 1.6 * S.u, fy - 20 * S.u);
          ctx.lineTo(fx + 0.7 * S.u, fy - 25 * S.u);
          ctx.lineTo(fx + 3 * S.u, fy - 20 * S.u);
          ctx.fill();
        }
      }
    },

    ruins(ctx, S, L) {
      for (const it of L.items) {
        const k = ((it.s || 100) * S.u) / 100;
        const x = it.x * S.W;
        const y = (it.y ?? L.y) * S.H;
        // เงาทอดบนพื้น
        ctx.fillStyle = 'rgba(60,30,10,0.22)';
        ctx.beginPath();
        ctx.ellipse(x - S.lightDir * 18 * k, y + 1, 26 * k, 3.5 * k, 0, 0, TAU);
        ctx.fill();
        if (it.type === 'column') column(ctx, S, L, x, y, k, it.h || 80, it.broken);
        else if (it.type === 'arch') {
          column(ctx, S, L, x - 26 * k, y, k, 74, false);
          column(ctx, S, L, x + 26 * k, y, k, it.broken ? 40 : 74, it.broken);
          ctx.strokeStyle = L.color;
          ctx.lineWidth = 9 * k;
          ctx.beginPath();
          ctx.arc(x, y - 76 * k, 26 * k, Math.PI, it.broken ? Math.PI * 1.62 : TAU);
          ctx.stroke();
          ctx.strokeStyle = L.shade;
          ctx.lineWidth = 2 * k;
          ctx.beginPath();
          ctx.arc(x, y - 76 * k, 22 * k, Math.PI, it.broken ? Math.PI * 1.6 : TAU);
          ctx.stroke();
        } else {
          ctx.save();
          ctx.translate(x, y - 6 * k);
          ctx.rotate((S.rng() - 0.5) * 0.4);
          ctx.fillStyle = L.color;
          ctx.fillRect(-12 * k, -6 * k, 24 * k, 12 * k);
          ctx.fillStyle = L.shade;
          ctx.fillRect(S.lightDir > 0 ? -12 * k : 6 * k, -6 * k, 6 * k, 12 * k);
          ctx.restore();
        }
      }
    },

    road(ctx, S, L) {
      const hy = L.y * S.H;
      const vx = L.vx * S.W;
      const left = [];
      const right = [];
      const N = 48;
      for (let i = 0; i <= N; i++) {
        const t = i / N;
        const depth = Math.pow(1 - t, 2.2);
        const yy = hy + (S.H * 1.05 - hy) * depth;
        const cx = lerp(vx, S.W * 0.5, depth) + Math.sin(t * Math.PI * 2) * S.W * 0.1 * depth * (1 - depth) * 4;
        const w = S.W * 0.45 * depth + 1.5 * S.u;
        left.push([cx - w, yy]);
        right.push([cx + w, yy]);
      }
      const p = new Path2D();
      p.moveTo(left[0][0], left[0][1]);
      for (const [x, y] of left) p.lineTo(x, y);
      for (let i = right.length - 1; i >= 0; i--) p.lineTo(right[i][0], right[i][1]);
      p.closePath();
      const g = ctx.createLinearGradient(0, hy, 0, S.H);
      g.addColorStop(0, L.far || mix(L.color, S.haze, 0.5));
      g.addColorStop(1, L.color);
      ctx.fillStyle = g;
      ctx.fill(p);
      ctx.strokeStyle = rgba('#000000', 0.18);
      ctx.lineWidth = Math.max(1, S.u);
      for (const side of [-0.35, 0.35]) {
        ctx.beginPath();
        for (let i = 0; i <= N; i++) {
          const x = lerp(left[i][0], right[i][0], 0.5 + side);
          if (i === 0) ctx.moveTo(x, left[i][1]);
          else ctx.lineTo(x, left[i][1]);
        }
        ctx.stroke();
      }
    },

    wagon(ctx, S, L) {
      const k = (L.size * S.u) / 100;
      const x = L.x * S.W;
      const y = L.y * S.H;
      const p = new Path2D();
      p.rect(x - 22 * k, y - 20 * k, 44 * k, 9 * k);
      p.rect(x + 22 * k, y - 15 * k, 18 * k, 1.6 * k);
      // วัวลากเกวียน
      p.ellipse(x + 50 * k, y - 18 * k, 12 * k, 7 * k, 0, 0, TAU);
      p.ellipse(x + 62 * k, y - 20 * k, 4.5 * k, 3.5 * k, -0.3, 0, TAU);
      for (const lx of [41, 46, 54, 58]) p.rect(x + lx * k, y - 13 * k, 2 * k, 13 * k);
      paint(ctx, S, p, L.color, L.rim);
      const cover = new Path2D();
      cover.moveTo(x - 21 * k, y - 20 * k);
      cover.bezierCurveTo(x - 24 * k, y - 48 * k, x + 24 * k, y - 48 * k, x + 21 * k, y - 20 * k);
      cover.closePath();
      const cg = ctx.createLinearGradient(x - 20 * k * S.lightDir, 0, x + 20 * k * S.lightDir, 0);
      cg.addColorStop(0, mix(L.cover, '#000000', 0.35));
      cg.addColorStop(1, L.cover);
      ctx.fillStyle = cg;
      ctx.fill(cover);
      ctx.strokeStyle = L.color;
      ctx.lineWidth = 1.6 * k;
      for (const wx of [-13, 13]) {
        ctx.beginPath();
        ctx.arc(x + wx * k, y - 7 * k, 7 * k, 0, TAU);
        ctx.stroke();
        for (let a = 0; a < 6; a++) {
          ctx.beginPath();
          ctx.moveTo(x + wx * k, y - 7 * k);
          ctx.lineTo(x + wx * k + Math.cos((a / 6) * TAU) * 7 * k, y - 7 * k + Math.sin((a / 6) * TAU) * 7 * k);
          ctx.stroke();
        }
      }
      S.emitters.push({ type: 'window', x: x + 23 * k, y: y - 26 * k, r: 10 * k, color: '#ffc870', group: S.group, phase: 0 });
    },

    lanterns(ctx, S, L) {
      const colors = L.colors || ['#ffb060', '#ff7a6a', '#ffd88a'];
      let ci = 0;
      for (const [x0, y0, x1, y1, sag] of L.strings) {
        const ax = x0 * S.W;
        const ay = y0 * S.H;
        const bx = x1 * S.W;
        const by = y1 * S.H;
        const mx = (ax + bx) / 2;
        const my = (ay + by) / 2 + sag * S.H;
        ctx.strokeStyle = L.rope || '#1a1222';
        ctx.lineWidth = Math.max(1, S.u);
        ctx.beginPath();
        ctx.moveTo(ax, ay);
        ctx.quadraticCurveTo(mx, my, bx, by);
        ctx.stroke();
        const n = L.count || 9;
        for (let i = 1; i < n; i++) {
          const t = i / n;
          const px = (1 - t) * (1 - t) * ax + 2 * (1 - t) * t * mx + t * t * bx;
          const py = (1 - t) * (1 - t) * ay + 2 * (1 - t) * t * my + t * t * by;
          const color = colors[ci++ % colors.length];
          ctx.fillStyle = color;
          ctx.beginPath();
          ctx.ellipse(px, py + 4 * S.u, 3 * S.u, 4 * S.u, 0, 0, TAU);
          ctx.fill();
          S.emitters.push({ type: 'lantern', x: px, y: py + 4 * S.u, r: 14 * S.u, color, group: S.group, phase: S.rng() * TAU });
        }
      }
    },

    fire(ctx, S, L) {
      const k = (L.size * S.u) / 100;
      const x = L.x * S.W;
      const y = L.y * S.H;
      ctx.fillStyle = L.wood || '#2a160c';
      for (const a of [-0.5, 0.5, 0.05]) {
        ctx.save();
        ctx.translate(x, y - 3 * k);
        ctx.rotate(a);
        ctx.fillRect(-18 * k, -2.5 * k, 36 * k, 5 * k);
        ctx.restore();
      }
      if (L.stones) {
        ctx.fillStyle = L.stones;
        for (let i = 0; i < 9; i++) {
          const a = (i / 9) * Math.PI + Math.PI;
          ctx.beginPath();
          ctx.ellipse(x + Math.cos(a) * 22 * k, y + Math.sin(a) * -4 * k, 5 * k, 3.5 * k, 0, 0, TAU);
          ctx.fill();
        }
      }
      S.emitters.push({ type: 'fire', x, y: y - 4 * k, size: 22 * k, group: S.group });
    },

    tents(ctx, S, L) {
      for (const it of L.items) {
        const k = (it.s * S.u) / 100;
        const x = it.x * S.W;
        const y = L.y * S.H;
        const p = new Path2D();
        p.moveTo(x - 28 * k, y);
        p.quadraticCurveTo(x - 12 * k, y - 18 * k, x, y - 32 * k);
        p.quadraticCurveTo(x + 12 * k, y - 18 * k, x + 28 * k, y);
        p.closePath();
        const toward = Math.sign((L.fireX ?? 0.5) * S.W - x) || 1;
        const g = ctx.createLinearGradient(x - 28 * k * toward, 0, x + 28 * k * toward, 0);
        g.addColorStop(0, mix(L.color, '#000000', 0.45));
        g.addColorStop(1, L.lit || L.color);
        ctx.fillStyle = g;
        ctx.fill(p);
        ctx.fillStyle = 'rgba(0,0,0,0.6)';
        ctx.beginPath();
        ctx.moveTo(x - 5 * k, y);
        ctx.lineTo(x + 1 * k, y - 20 * k);
        ctx.lineTo(x + 7 * k, y);
        ctx.fill();
      }
    },

    crowd(ctx, S, L) {
      const fireX = (L.fireX ?? 0.5) * S.W;
      for (let i = 0; i < L.count; i++) {
        let fx = lerp(L.x0, L.x1, S.rng()) * S.W;
        if (Math.abs(fx - fireX) < 26 * S.u) fx += (fx < fireX ? -1 : 1) * 30 * S.u;
        const y = (L.y + S.rng() * 0.02) * S.H;
        const h = (24 + S.rng() * 12) * S.u * (L.scale || 1);
        const dancing = S.rng() < (L.dance ?? 0.4);
        const toward = Math.sign(fireX - fx) || 1;
        for (const pass of [0, 1]) {
          ctx.save();
          if (pass === 0) {
            ctx.translate(toward * 1.4 * S.u, 0);
            ctx.fillStyle = ctx.strokeStyle = L.rim || '#ff9a4a';
          } else {
            ctx.fillStyle = ctx.strokeStyle = L.color;
          }
          ctx.lineCap = 'round';
          ctx.beginPath();
          ctx.arc(fx, y - h + h * 0.1, h * 0.1, 0, TAU);
          ctx.fill();
          ctx.beginPath();
          ctx.moveTo(fx - h * 0.14, y - h * 0.78);
          ctx.lineTo(fx + h * 0.14, y - h * 0.78);
          ctx.lineTo(fx + h * 0.11, y - h * 0.38);
          ctx.lineTo(fx - h * 0.11, y - h * 0.38);
          ctx.fill();
          ctx.lineWidth = h * 0.08;
          ctx.beginPath();
          ctx.moveTo(fx - h * 0.06, y - h * 0.4);
          ctx.lineTo(fx - h * 0.08, y);
          ctx.moveTo(fx + h * 0.06, y - h * 0.4);
          ctx.lineTo(fx + h * 0.09, y);
          ctx.moveTo(fx - h * 0.13, y - h * 0.74);
          ctx.lineTo(fx - h * (dancing ? 0.24 : 0.16), y - h * (dancing ? 1.0 : 0.42));
          ctx.moveTo(fx + h * 0.13, y - h * 0.74);
          ctx.lineTo(fx + h * (dancing ? 0.26 : 0.16), y - h * (dancing ? 0.98 : 0.42));
          ctx.stroke();
          ctx.restore();
        }
      }
    },

    crystals(ctx, S, L) {
      for (const it of L.items) {
        const k = ((it.s || 100) * S.u) / 100;
        const x = it.x * S.W;
        const y = it.y * S.H;
        const shards = [];
        const n = 4 + Math.floor(S.rng() * 3);
        for (let i = 0; i < n; i++) {
          shards.push({ a: -Math.PI / 2 + (S.rng() - 0.5) * 1.2, len: (18 + S.rng() * 32) * k, w: (4 + S.rng() * 4) * k, ox: (S.rng() - 0.5) * 16 * k });
        }
        shards.sort((a, b) => b.len - a.len);
        for (const s of shards) {
          ctx.save();
          ctx.translate(x + s.ox, y);
          ctx.rotate(s.a + Math.PI / 2);
          const p = new Path2D();
          p.moveTo(-s.w, 0);
          p.lineTo(-s.w, -s.len * 0.75);
          p.lineTo(0, -s.len);
          p.lineTo(s.w, -s.len * 0.75);
          p.lineTo(s.w, 0);
          p.closePath();
          const g = ctx.createLinearGradient(0, 0, 0, -s.len);
          g.addColorStop(0, mix(it.color, '#000000', 0.55));
          g.addColorStop(1, mix(it.color, '#ffffff', 0.35));
          ctx.fillStyle = g;
          ctx.fill(p);
          ctx.fillStyle = 'rgba(255,255,255,0.22)';
          ctx.beginPath();
          ctx.moveTo(0, 0);
          ctx.lineTo(0, -s.len);
          ctx.lineTo(s.w, -s.len * 0.75);
          ctx.lineTo(s.w, 0);
          ctx.fill();
          ctx.restore();
        }
        S.emitters.push({ type: 'crystal', x, y: y - 20 * k, r: 46 * k, color: it.color, group: S.group, phase: S.rng() * TAU });
      }
    },

    reeds(ctx, S, L) {
      ctx.strokeStyle = L.color;
      ctx.fillStyle = L.color;
      ctx.lineCap = 'round';
      for (let i = 0; i < L.count; i++) {
        const side = S.rng() < 0.5;
        const x = (side ? S.rng() * 0.22 : 0.78 + S.rng() * 0.22) * S.W;
        const y = (L.y + S.rng() * 0.08) * S.H;
        const h = (30 + S.rng() * 60) * S.u;
        const bend = (S.rng() - 0.5) * 16 * S.u;
        ctx.lineWidth = (1 + S.rng()) * S.u;
        ctx.beginPath();
        ctx.moveTo(x, y);
        ctx.quadraticCurveTo(x + bend * 0.3, y - h * 0.5, x + bend, y - h);
        ctx.stroke();
        if (S.rng() < 0.35) {
          ctx.beginPath();
          ctx.ellipse(x + bend * 0.9, y - h * 0.86, 1.8 * S.u, 6 * S.u, bend * 0.01, 0, TAU);
          ctx.fill();
        }
      }
    },

    rocks(ctx, S, L) {
      for (const it of L.items) {
        const k = (it.s * S.u) / 100;
        const x = it.x * S.W;
        const y = it.y * S.H;
        const p = new Path2D();
        const n = 9;
        for (let i = 0; i <= n; i++) {
          const a = Math.PI + (i / n) * Math.PI;
          const r = 20 * k * (0.75 + S.rng() * 0.4);
          const px = x + Math.cos(a) * r * 1.4;
          const py = y + Math.sin(a) * r;
          if (i === 0) p.moveTo(px, y);
          p.lineTo(px, py);
        }
        p.lineTo(x + 28 * k, y + 2);
        p.closePath();
        paint(ctx, S, p, L.color, L.rim);
      }
    },
  };

  function column(ctx, S, L, x, y, k, h, broken) {
    const w = 7 * k;
    const top = y - h * k;
    const p = new Path2D();
    p.rect(x - w - 2 * k, y - 4 * k, (w + 2 * k) * 2, 4 * k);
    p.moveTo(x - w, y - 4 * k);
    if (broken) {
      p.lineTo(x - w, top + 6 * k);
      p.lineTo(x - w * 0.3, top);
      p.lineTo(x + w * 0.2, top + 8 * k);
      p.lineTo(x + w * 0.7, top + 3 * k);
      p.lineTo(x + w, top + 10 * k);
    } else {
      p.lineTo(x - w, top + 4 * k);
      p.lineTo(x + w, top + 4 * k);
    }
    p.lineTo(x + w, y - 4 * k);
    p.closePath();
    if (!broken) p.rect(x - w - 3 * k, top, (w + 3 * k) * 2, 4 * k);
    const g = ctx.createLinearGradient(x - w * S.lightDir, 0, x + w * S.lightDir, 0);
    g.addColorStop(0, L.shade);
    g.addColorStop(0.6, L.color);
    g.addColorStop(1, mix(L.color, '#ffffff', 0.25));
    ctx.fillStyle = g;
    ctx.fill(p);
    ctx.strokeStyle = rgba(L.shade, 0.5);
    ctx.lineWidth = Math.max(1, 0.8 * k);
    for (const fx of [-0.45, 0, 0.45]) {
      ctx.beginPath();
      ctx.moveTo(x + fx * w, y - 5 * k);
      ctx.lineTo(x + fx * w, top + 10 * k);
      ctx.stroke();
    }
  }

  function cottage(ctx, S, it, L) {
    const k = ((it.s || 100) * S.u) / 100;
    const x = it.x * S.W;
    const y = (it.y ?? L.y) * S.H;
    const sil = L.silhouette;
    const pal = Object.assign(
      { wall: '#eadcbc', wallShade: '#bfa680', beam: '#5e3f2a', roof: '#8e3f2c', roofLight: '#c46a42', window: '#ffd88a', door: '#4e321f', chimney: '#6e6058' },
      L.palette || {}
    );
    const haze = it.haze ?? L.haze ?? 0;
    const c = (col) => (sil ? sil : haze ? mix(col, S.haze, haze) : col);
    const w = 52 * k;
    const h = 30 * k;
    const long = it.style === 'long';
    const rh = (long ? 18 : 26) * k;
    const over = 6 * k;
    // ปล่องไฟ
    ctx.fillStyle = c(pal.chimney);
    ctx.fillRect(x + w * 0.2, y - h - rh * 0.95, 7 * k, rh * 0.9);
    if (L.smoke !== false) S.emitters.push({ type: 'smoke', x: x + w * 0.2 + 3.5 * k, y: y - h - rh * 0.95, group: S.group, k });
    // ผนัง
    const wg = ctx.createLinearGradient(0, y - h, 0, y);
    wg.addColorStop(0, c(pal.wall));
    wg.addColorStop(1, c(pal.wallShade));
    ctx.fillStyle = wg;
    ctx.fillRect(x - w / 2, y - h, w, h);
    if (!sil) {
      ctx.strokeStyle = c(pal.beam);
      ctx.lineWidth = 1.8 * k;
      ctx.strokeRect(x - w / 2, y - h, w, h);
      ctx.beginPath();
      for (const bx of [-w / 6, w / 6]) {
        ctx.moveTo(x + bx, y - h);
        ctx.lineTo(x + bx, y);
      }
      ctx.moveTo(x - w / 2, y - h * 0.48);
      ctx.lineTo(x + w / 2, y - h * 0.48);
      ctx.stroke();
    }
    // หลังคา
    const roof = new Path2D();
    if (long) {
      roof.moveTo(x - w / 2 - over, y - h + 1);
      roof.lineTo(x - w / 2 + w * 0.14, y - h - rh);
      roof.lineTo(x + w / 2 - w * 0.14, y - h - rh);
      roof.lineTo(x + w / 2 + over, y - h + 1);
    } else {
      roof.moveTo(x - w / 2 - over, y - h + 1);
      roof.lineTo(x, y - h - rh);
      roof.lineTo(x + w / 2 + over, y - h + 1);
    }
    roof.closePath();
    const rg = ctx.createLinearGradient(0, y - h - rh, 0, y - h);
    rg.addColorStop(0, c(pal.roofLight));
    rg.addColorStop(1, c(pal.roof));
    paint(ctx, S, roof, rg, L.rim);
    if (!sil) {
      ctx.save();
      ctx.clip(roof);
      ctx.strokeStyle = 'rgba(40,20,10,0.18)';
      ctx.lineWidth = 1;
      for (let i = -10; i <= 10; i++) {
        ctx.beginPath();
        ctx.moveTo(x + i * 3.2 * k, y - h - rh);
        ctx.lineTo(x + i * 4.2 * k, y - h);
        ctx.stroke();
      }
      ctx.restore();
      ctx.fillStyle = 'rgba(0,0,0,0.25)';
      ctx.fillRect(x - w / 2, y - h, w, 2.5 * k);
    }
    // ประตูและหน้าต่าง
    ctx.fillStyle = c(pal.door);
    ctx.beginPath();
    ctx.moveTo(x - 5 * k, y);
    ctx.lineTo(x - 5 * k, y - 13 * k);
    ctx.arc(x, y - 13 * k, 5 * k, Math.PI, 0);
    ctx.lineTo(x + 5 * k, y);
    ctx.fill();
    const lit = L.lit ?? true;
    for (const wx of [x - w * 0.32, x + w * 0.32]) {
      ctx.fillStyle = lit ? pal.window : c('#5d6f86');
      ctx.fillRect(wx - 4.5 * k, y - h * 0.72, 9 * k, 9 * k);
      if (!sil) {
        ctx.strokeStyle = c(pal.beam);
        ctx.lineWidth = 1.2 * k;
        ctx.strokeRect(wx - 4.5 * k, y - h * 0.72, 9 * k, 9 * k);
        ctx.beginPath();
        ctx.moveTo(wx, y - h * 0.72);
        ctx.lineTo(wx, y - h * 0.72 + 9 * k);
        ctx.stroke();
      }
      if (lit) S.emitters.push({ type: 'window', x: wx, y: y - h * 0.72 + 4.5 * k, r: 13 * k, color: pal.window, group: S.group, phase: S.rng() * TAU });
    }
  }

  // ---------- ท้องฟ้าและเมฆ ----------

  function drawSky(ctx, S, sky) {
    const g = ctx.createLinearGradient(0, 0, 0, S.H);
    for (const [o, c] of sky.stops) g.addColorStop(o, c);
    ctx.fillStyle = g;
    ctx.fillRect(-S.pad, 0, S.W + 2 * S.pad, S.floor);
    if (sky.milky) {
      ctx.save();
      ctx.translate(S.W * 0.5, S.H * 0.25);
      ctx.rotate(-0.45);
      const band = ctx.createLinearGradient(0, -S.H * 0.12, 0, S.H * 0.12);
      band.addColorStop(0, 'rgba(180,170,255,0)');
      band.addColorStop(0.5, 'rgba(200,190,255,0.13)');
      band.addColorStop(1, 'rgba(180,170,255,0)');
      ctx.fillStyle = band;
      ctx.fillRect(-S.W, -S.H * 0.12, S.W * 2, S.H * 0.24);
      ctx.fillStyle = '#ffffff';
      for (let i = 0; i < 700; i++) {
        const x = (S.rng() - 0.5) * S.W * 2;
        const y = (S.rng() + S.rng() + S.rng() - 1.5) * S.H * 0.07;
        ctx.globalAlpha = S.rng() * 0.5;
        ctx.fillRect(x, y, 0.8, 0.8);
      }
      ctx.restore();
      ctx.globalAlpha = 1;
    }
    if (sky.aurora) {
      ctx.save();
      ctx.globalCompositeOperation = 'lighter';
      for (let band = 0; band < 3; band++) {
        const baseY = S.H * (0.12 + band * 0.06);
        const seed = S.rng() * 100;
        for (let x = -S.pad; x < S.W + S.pad; x += 3) {
          const n = S.noise(seed + x * 0.004, 3, 0.5);
          const y = baseY + (n - 0.5) * S.H * 0.18;
          const hgt = S.H * (0.08 + S.noise(seed + 50 + x * 0.01, 2) * 0.12);
          const ag = ctx.createLinearGradient(0, y - hgt, 0, y + 6);
          ag.addColorStop(0, rgba(sky.aurora, 0));
          ag.addColorStop(0.8, rgba(sky.aurora, (sky.auroraAlpha || 0.1) * (0.6 + n)));
          ag.addColorStop(1, rgba(sky.aurora, 0));
          ctx.fillStyle = ag;
          ctx.fillRect(x, y - hgt, 3, hgt + 6);
        }
      }
      ctx.restore();
    }
    if (sky.stars) {
      for (let i = 0; i < sky.stars; i++) {
        const x = -S.pad + S.rng() * (S.W + 2 * S.pad);
        const y = Math.pow(S.rng(), 1.4) * S.H * (sky.starDepth || 0.6);
        const fade = 1 - y / (S.H * (sky.starDepth || 0.6));
        ctx.globalAlpha = (0.25 + S.rng() * 0.75) * fade;
        ctx.fillStyle = S.rng() < 0.15 ? '#ffe3c0' : S.rng() < 0.2 ? '#c8d8ff' : '#ffffff';
        const r = S.rng() < 0.92 ? 0.6 + S.rng() * 0.6 : 1.3 + S.rng() * 0.6;
        ctx.beginPath();
        ctx.arc(x, y, r, 0, TAU);
        ctx.fill();
        if (r > 1.3) S.twinkles.push({ x, y, r, phase: S.rng() * TAU });
      }
      ctx.globalAlpha = 1;
    }
    const body = sky.sun || sky.moon;
    if (body) {
      const x = body.x * S.W;
      const y = body.y * S.H;
      const r = body.r * S.u;
      const glow = body.glow || body.color;
      ctx.save();
      ctx.globalCompositeOperation = 'lighter';
      drawGlow(ctx, x, y, r * (sky.sun ? 14 : 9), glow, sky.sun ? 0.55 : 0.28);
      drawGlow(ctx, x, y, r * 4, glow, 0.5);
      ctx.restore();
      ctx.globalAlpha = 1;
      const bg = ctx.createRadialGradient(x - r * 0.3, y - r * 0.3, r * 0.1, x, y, r);
      bg.addColorStop(0, '#ffffff');
      bg.addColorStop(1, body.color);
      ctx.fillStyle = bg;
      ctx.beginPath();
      ctx.arc(x, y, r, 0, TAU);
      ctx.fill();
      if (sky.moon) {
        ctx.fillStyle = 'rgba(120,130,170,0.16)';
        for (const [dx, dy, cr] of [[-0.3, -0.2, 0.22], [0.25, 0.1, 0.16], [-0.05, 0.35, 0.12], [0.35, -0.35, 0.1]]) {
          ctx.beginPath();
          ctx.arc(x + dx * r, y + dy * r, cr * r, 0, TAU);
          ctx.fill();
        }
      }
    }
  }

  function makeCloud(S, cfg, dpr) {
    const w = (140 + S.rng() * 200) * S.u * (cfg.scale || 1.3);
    const h = w * 0.42;
    const c = makeCanvas(w * dpr, h * dpr);
    const g = c.getContext('2d');
    g.scale(dpr, dpr);
    const puffs = [];
    const n = 12 + Math.floor(S.rng() * 8);
    for (let i = 0; i < n; i++) {
      const t = S.rng();
      const r = h * (0.16 + S.rng() * 0.2) * (0.6 + Math.sin(t * Math.PI) * 0.6);
      puffs.push([w * (0.12 + t * 0.76), h * 0.68 - Math.sin(t * Math.PI) * h * 0.28 * S.rng(), r]);
    }
    const blob = (cx, cy, r, color, a) => {
      const rg = g.createRadialGradient(cx, cy, 0, cx, cy, r);
      rg.addColorStop(0, rgba(color, a));
      rg.addColorStop(0.65, rgba(color, a * 0.8));
      rg.addColorStop(1, rgba(color, 0));
      g.fillStyle = rg;
      g.beginPath();
      g.arc(cx, cy, r, 0, TAU);
      g.fill();
    };
    for (const [cx, cy, r] of puffs) blob(cx, cy + r * 0.2, r * 1.05, cfg.shade, 0.9);
    for (const [cx, cy, r] of puffs) blob(cx + S.lightDir * r * 0.15, cy - r * 0.25, r * 0.8, cfg.light, 0.85);
    return {
      canvas: c,
      w,
      h,
      x: -S.pad + S.rng() * (S.W + 2 * S.pad),
      y: lerp(cfg.y0, cfg.y1, S.rng()) * S.H,
      speed: (4 + S.rng() * 8) * S.u * (cfg.speed || 1),
      alpha: cfg.alpha ?? 0.9,
    };
  }

  function makeFog(color) {
    const c = makeCanvas(512, 96);
    const g = c.getContext('2d');
    for (let i = 0; i < 16; i++) {
      const x = 110 + Math.random() * 292;
      const r = 50 + Math.random() * 50;
      const rg = g.createRadialGradient(x, 48, 0, x, 48, r);
      rg.addColorStop(0, rgba(color, 0.55));
      rg.addColorStop(1, rgba(color, 0));
      g.fillStyle = rg;
      g.fillRect(0, 0, 512, 96);
    }
    return c;
  }

  // ---------- ฉากทั้งหมด ----------

  const SCENES = {
    title: {
      sky: { stops: [[0, '#070a24'], [0.38, '#1e2152'], [0.62, '#5a3c6e'], [0.8, '#c06a6a'], [1, '#f2a668']], stars: 320, milky: true, starDepth: 0.55, moon: { x: 0.8, y: 0.17, r: 20, color: '#f6efd8', glow: '#c8b8ff' }, aurora: '#5fe0b0', auroraAlpha: 0.07 },
      haze: '#b8708a',
      layers: [
        { type: 'range', group: 'far', y: 0.5, amp: 0.14, freq: 4, color: '#463a72', snow: '#e6dcff', facets: 0.12, fade: 0.55, bumps: [{ x: 0.3, w: 0.16, h: 0.16 }, { x: 0.82, w: 0.12, h: 0.08 }], rim: '#ffb490', rimAlpha: 0.35 },
        { type: 'range', group: 'far', y: 0.56, amp: 0.06, freq: 5, color: '#30285a', fade: 0.45 },
        { type: 'castle', group: 'mid', x: 0.68, y: 0.5, size: 230, cliff: true, color: '#1a1530', rim: 'rgba(255,170,120,0.55)', windows: '#ffcf7a', flags: '#d0504a' },
        { type: 'tower', group: 'mid', x: 0.17, y: 0.6, size: 170, color: '#16132a', rim: 'rgba(170,150,255,0.45)', orb: '#9fe0ff' },
        { type: 'trees', group: 'mid', kind: 'pine', y: 0.62, amp: 0.03, size: 44, density: 0.75, color: '#130f24' },
        { type: 'trees', group: 'near', kind: 'pine', y: 0.74, amp: 0.05, size: 96, density: 0.7, color: '#080614' },
      ],
      fog: [{ after: 'far', y: 0.55, h: 0.09, color: '#c88aa0', alpha: 0.32 }, { after: 'mid', y: 0.66, h: 0.08, color: '#5a4278', alpha: 0.4 }],
      particles: [{ type: 'fireflies', count: 38, y0: 0.5, y1: 0.95, color: '#ffe9a0' }],
      dragon: { y: 0.3, size: 58, speed: 0.018, color: '#141028' },
      post: { vignette: 0.6, grade: '#ff9a6a', gradeAlpha: 0.08 },
    },

    village: {
      sky: { stops: [[0, '#5b93cf'], [0.5, '#a9cfea'], [0.78, '#f2e2c4'], [1, '#f8e6c0']], sun: { x: 0.82, y: 0.16, r: 24, color: '#fff6d6', glow: '#ffe2a0' } },
      clouds: { count: 6, light: '#ffffff', shade: '#c9c0d8', y0: 0.05, y1: 0.3 },
      haze: '#dfe8f0',
      layers: [
        { type: 'range', group: 'far', y: 0.42, amp: 0.12, freq: 3.5, color: '#7489b8', snow: '#ffffff', facets: 0.16, fade: 0.7, bumps: [{ x: 0.35, w: 0.18, h: 0.1 }] },
        { type: 'range', group: 'far', y: 0.5, amp: 0.06, freq: 2.5, color: '#86ad84', fade: 0.4 },
        { type: 'trees', group: 'mid', kind: 'round', y: 0.56, amp: 0.03, size: 56, density: 0.5, color: '#5b8a52', light: '#b2d38a', ground: '#78a463' },
        { type: 'windmill', group: 'mid', x: 0.8, y: 0.57, size: 130, color: '#e6d6b4', cap: '#8a4b35', blade: '#f2e8d0' },
        { type: 'cottages', group: 'mid', y: 0.61, items: [{ x: 0.16, s: 150 }, { x: 0.38, s: 125, style: 'long' }, { x: 0.58, s: 140 }], lit: false },
        { type: 'range', group: 'near', y: 0.7, amp: 0.03, freq: 2, color: '#5b8f4c', fade: 0, bottom: '#2e4f2a', solid: true, flowers: 140 },
        { type: 'trees', group: 'near', kind: 'round', items: [{ x: 0.02, y: 0.76, s: 190 }, { x: 0.98, y: 0.74, s: 170 }], color: '#3a6236', light: '#8fbf6a' },
      ],
      particles: [{ type: 'petals', count: 22 }, { type: 'birds', count: 5, y0: 0.12, y1: 0.3 }],
      rays: { x: 0.82, y: 0.16, color: '#fff2c0', alpha: 0.05 },
      post: { vignette: 0.35, grade: '#ffd9a0', gradeAlpha: 0.06 },
    },

    rain_village: {
      sky: { stops: [[0, '#262e40'], [0.55, '#46506a'], [1, '#6c7084']] },
      clouds: { count: 10, light: '#5c6377', shade: '#22263a', y0: 0, y1: 0.32, scale: 1.8, alpha: 0.95 },
      haze: '#4a5164',
      layers: [
        { type: 'range', group: 'far', y: 0.5, amp: 0.1, color: '#2d3346', fade: 0.4 },
        { type: 'trees', group: 'mid', kind: 'round', y: 0.6, amp: 0.02, size: 46, density: 0.55, color: '#1d2331' },
        { type: 'cottages', group: 'mid', y: 0.64, items: [{ x: 0.2, s: 150 }, { x: 0.5, s: 135, style: 'long' }, { x: 0.8, s: 145 }], silhouette: '#1b2030', smoke: false },
        { type: 'range', group: 'near', y: 0.74, amp: 0.02, color: '#10131c', fade: 0, solid: true },
      ],
      particles: [{ type: 'rain', count: 170 }],
      lightning: true,
      post: { vignette: 0.6, grade: '#5a7a9a', gradeAlpha: 0.1 },
    },

    dragon_vale: {
      sky: { stops: [[0, '#4a82c4'], [0.55, '#a6cde8'], [1, '#e8f1e4']], sun: { x: 0.18, y: 0.14, r: 22, color: '#fffbe6', glow: '#fff0b0' } },
      clouds: { count: 5, light: '#ffffff', shade: '#c0cce0', y0: 0.04, y1: 0.26 },
      haze: '#d2e2ec',
      layers: [
        { type: 'range', group: 'far', y: 0.44, amp: 0.12, freq: 3, color: '#6a7fae', snow: '#ffffff', facets: 0.2, fade: 0.65, bumps: [{ x: 0.66, w: 0.2, h: 0.2, sharp: 1.3 }] },
        { type: 'range', group: 'far', y: 0.52, amp: 0.07, color: '#77a294', fade: 0.45 },
        { type: 'trees', group: 'mid', kind: 'pine', y: 0.58, amp: 0.04, size: 38, density: 0.45, color: '#3c6a4a', light: '#9cc89a', ground: '#6a9a5a' },
        { type: 'range', group: 'near', y: 0.7, amp: 0.03, color: '#5b8c48', fade: 0, bottom: '#2a4a24', solid: true, flowers: 120 },
        { type: 'trees', group: 'near', kind: 'pine', items: [{ x: 0.04, y: 0.78, s: 200 }, { x: 0.94, y: 0.76, s: 160 }], color: '#244a30', light: '#6aa070' },
      ],
      dragon: { y: 0.24, size: 105, speed: 0.025, color: '#3a3452' },
      particles: [{ type: 'petals', count: 14, colors: ['#fff7c0', '#ffffff', '#ffe08a'] }],
      rays: { x: 0.18, y: 0.14, color: '#fff6d0', alpha: 0.05 },
      post: { vignette: 0.35, grade: '#ffe6b0', gradeAlpha: 0.05 },
    },

    tower: {
      sky: { stops: [[0, '#080a24'], [0.45, '#1c1d50'], [0.8, '#463878'], [1, '#76589a']], stars: 260, milky: true, moon: { x: 0.22, y: 0.18, r: 16, color: '#eef0ff', glow: '#a8b0ff' }, aurora: '#7d6bff', auroraAlpha: 0.08 },
      haze: '#5a4a8c',
      layers: [
        { type: 'range', group: 'far', y: 0.56, amp: 0.12, freq: 4, color: '#2a295c', facets: 0.12, fade: 0.5, rim: '#a090ff', rimAlpha: 0.25 },
        { type: 'tower', group: 'mid', x: 0.6, y: 0.64, size: 290, color: '#181634', rim: 'rgba(160,140,255,0.6)', orb: '#9fe0ff' },
        { type: 'trees', group: 'mid', kind: 'pine', y: 0.66, amp: 0.03, size: 40, density: 0.55, color: '#12112a' },
        { type: 'rocks', group: 'near', color: '#0a0918', rim: 'rgba(150,130,255,0.4)', items: [{ x: 0.12, y: 0.8, s: 120 }, { x: 0.9, y: 0.82, s: 150 }] },
        { type: 'range', group: 'near', y: 0.78, amp: 0.02, color: '#0a0918', fade: 0, solid: true },
      ],
      fog: [{ after: 'mid', y: 0.68, h: 0.08, color: '#6a5aa8', alpha: 0.32 }],
      particles: [{ type: 'fireflies', count: 26, y0: 0.45, y1: 0.95, color: '#9fe0ff' }],
      post: { vignette: 0.55, grade: '#7a6aff', gradeAlpha: 0.06 },
    },

    forest_night: {
      sky: { stops: [[0, '#04070f'], [0.55, '#122038'], [1, '#2a3a56']], stars: 120, moon: { x: 0.5, y: 0.2, r: 32, color: '#eef4ff', glow: '#9ab8ff' } },
      haze: '#2a3a56',
      layers: [
        { type: 'trees', group: 'far', kind: 'pine', y: 0.52, amp: 0.03, size: 62, density: 0.95, color: '#18263e', spacing: 0.18 },
        { type: 'trees', group: 'mid', kind: 'pine', y: 0.63, amp: 0.03, size: 110, density: 0.9, color: '#0d1828', rim: 'rgba(140,170,230,0.3)', spacing: 0.2 },
        { type: 'trees', group: 'near', kind: 'pine', items: [{ x: 0.02, y: 0.9, s: 380 }, { x: 0.97, y: 0.88, s: 340 }], color: '#03060c' },
        { type: 'range', group: 'near', y: 0.8, amp: 0.02, color: '#04070c', fade: 0, solid: true },
      ],
      eyes: [{ x: 0.38, y: 0.6 }, { x: 0.62, y: 0.61 }],
      fog: [{ after: 'far', y: 0.56, h: 0.08, color: '#4a6286', alpha: 0.4 }, { after: 'mid', y: 0.68, h: 0.08, color: '#3a4a68', alpha: 0.45 }],
      particles: [{ type: 'fireflies', count: 20, y0: 0.45, y1: 0.95, color: '#c8ffb0' }],
      rays: { x: 0.5, y: 0.2, color: '#cfe0ff', alpha: 0.05 },
      post: { vignette: 0.7, grade: '#4060a0', gradeAlpha: 0.1 },
    },

    fortress: {
      sky: { stops: [[0, '#281a34'], [0.4, '#62293e'], [0.7, '#c45a3c'], [1, '#f2a65a']], sun: { x: 0.28, y: 0.46, r: 28, color: '#ffd9a0', glow: '#ff8a50' } },
      clouds: { count: 7, light: '#f2a070', shade: '#43243a', y0: 0.04, y1: 0.32, scale: 1.6 },
      haze: '#c06a5a',
      layers: [
        { type: 'range', group: 'far', y: 0.5, amp: 0.14, freq: 3.5, color: '#4a2c48', facets: 0.15, fade: 0.5, rim: '#ffb070', rimAlpha: 0.45 },
        { type: 'castle', group: 'mid', x: 0.64, y: 0.48, size: 290, cliff: true, color: '#22142a', rim: 'rgba(255,150,90,0.65)', windows: '#ffc870', flags: '#e0b050' },
        { type: 'range', group: 'mid', y: 0.62, amp: 0.04, color: '#2a1a2c', fade: 0.2 },
        { type: 'trees', group: 'near', kind: 'pine', y: 0.75, amp: 0.04, size: 80, density: 0.4, color: '#100810' },
      ],
      particles: [{ type: 'embers', count: 30 }, { type: 'birds', count: 6, y0: 0.15, y1: 0.35, color: '#1a0e1a' }],
      rays: { x: 0.28, y: 0.46, color: '#ffc080', alpha: 0.07 },
      post: { vignette: 0.6, grade: '#ff7040', gradeAlpha: 0.08 },
    },

    road: {
      sky: { stops: [[0, '#3a3f78'], [0.45, '#b4747c'], [0.75, '#f0b070'], [1, '#f8d8a0']], sun: { x: 0.56, y: 0.5, r: 22, color: '#fff0c8', glow: '#ffb070' } },
      clouds: { count: 5, light: '#ffc890', shade: '#8a5a78', y0: 0.08, y1: 0.3 },
      haze: '#e2a284',
      layers: [
        { type: 'range', group: 'far', y: 0.5, amp: 0.08, color: '#7a5a7c', fade: 0.6 },
        { type: 'city', group: 'far', x0: 0.46, x1: 0.68, y: 0.525, h: 50, color: '#6a4a6c', lit: 0.15, scale: 0.6, palace: 0.57 },
        { type: 'range', group: 'mid', y: 0.56, amp: 0.035, color: '#b58a52', fade: 0.25, bottom: '#7a5a34', solid: true },
        { type: 'road', group: 'mid', vx: 0.57, y: 0.535, color: '#d8b07a', far: '#e8c8a0' },
        { type: 'trees', group: 'mid', kind: 'round', items: [{ x: 0.24, y: 0.6, s: 70 }, { x: 0.8, y: 0.62, s: 90 }, { x: 0.12, y: 0.66, s: 110 }], color: '#4a4030', light: '#c89a60' },
        { type: 'wagon', group: 'near', x: 0.3, y: 0.7, size: 150, color: '#2e2016', cover: '#efe0c0', rim: 'rgba(255,190,120,0.5)' },
      ],
      particles: [{ type: 'dust', count: 30 }, { type: 'birds', count: 4, y0: 0.15, y1: 0.35 }],
      rays: { x: 0.56, y: 0.5, color: '#ffd090', alpha: 0.07 },
      post: { vignette: 0.5, grade: '#ffb070', gradeAlpha: 0.08 },
    },

    festival: {
      sky: { stops: [[0, '#0a0c26'], [0.6, '#26205a'], [1, '#5c3a6a']], stars: 150 },
      haze: '#3a2a5a',
      layers: [
        { type: 'range', group: 'far', y: 0.55, amp: 0.08, color: '#1e1a42', fade: 0.4 },
        { type: 'cottages', group: 'mid', y: 0.64, items: [{ x: 0.08, s: 150 }, { x: 0.3, s: 130, style: 'long' }, { x: 0.72, s: 140 }, { x: 0.93, s: 125 }], silhouette: '#18122a', smoke: false },
        { type: 'lanterns', group: 'mid', strings: [[-0.05, 0.5, 0.5, 0.48, 0.07], [0.5, 0.48, 1.05, 0.5, 0.07], [0.15, 0.55, 0.85, 0.55, 0.05]], count: 8 },
        { type: 'range', group: 'mid', y: 0.7, amp: 0.01, color: '#120c20', fade: 0, solid: true },
        { type: 'fire', group: 'mid', x: 0.5, y: 0.7, size: 170 },
        { type: 'crowd', group: 'mid', x0: 0.25, x1: 0.75, y: 0.71, count: 12, scale: 1.6, color: '#0c0814', rim: '#ff9a4a', fireX: 0.5 },
      ],
      fireworks: true,
      particles: [{ type: 'embers', count: 18 }],
      post: { vignette: 0.55, grade: '#ff9a50', gradeAlpha: 0.06 },
    },

    graveyard: {
      sky: { stops: [[0, '#04060c'], [0.55, '#16223a'], [1, '#33435a']], stars: 100, moon: { x: 0.7, y: 0.2, r: 38, color: '#e8f0ff', glow: '#a0c0ff' } },
      haze: '#2a3a52',
      layers: [
        { type: 'trees', group: 'far', kind: 'pine', y: 0.55, amp: 0.03, size: 50, density: 0.7, color: '#141e30' },
        { type: 'deadTree', group: 'mid', x: 0.22, y: 0.66, size: 170, color: '#0b0f18', lean: -0.1 },
        { type: 'range', group: 'mid', y: 0.66, amp: 0.02, color: '#121a28', fade: 0.1, solid: true },
        { type: 'tombs', group: 'mid', x0: 0.3, x1: 0.95, y: 0.66, count: 13, size: 170, color: '#222c40', rim: 'rgba(170,200,250,0.75)', fence: true },
        { type: 'range', group: 'near', y: 0.8, amp: 0.02, color: '#05070d', fade: 0, solid: true },
        { type: 'deadTree', group: 'near', x: 0.93, y: 0.84, size: 260, color: '#03050a', lean: 0.15 },
      ],
      fog: [{ after: 'far', y: 0.58, h: 0.08, color: '#4a6080', alpha: 0.35 }, { after: 'mid', y: 0.74, h: 0.08, color: '#5a7090', alpha: 0.3 }],
      particles: [{ type: 'wisps', count: 10, color: '#7affc0' }],
      rays: { x: 0.7, y: 0.2, color: '#cfe0ff', alpha: 0.05 },
      post: { vignette: 0.7, grade: '#3a6a8a', gradeAlpha: 0.1 },
    },

    city: {
      sky: { stops: [[0, '#181a3a'], [0.45, '#46386a'], [0.75, '#bc6c62'], [1, '#f0a070']], stars: 50, moon: { x: 0.18, y: 0.18, r: 12, color: '#fff2d8', glow: '#ffc890' } },
      clouds: { count: 4, light: '#e08a7a', shade: '#3a2a4a', y0: 0.1, y1: 0.3 },
      haze: '#a86a7a',
      layers: [
        { type: 'range', group: 'far', y: 0.55, amp: 0.06, color: '#3a2e52', fade: 0.5 },
        { type: 'city', group: 'far', x0: -0.05, x1: 1.05, y: 0.6, h: 140, color: '#2e2442', lit: 0.18, palace: 0.55, rim: 'rgba(255,170,130,0.35)' },
        { type: 'city', group: 'mid', x0: -0.08, x1: 1.08, y: 0.68, h: 100, color: '#1c1630', lit: 0.3, scale: 1.3 },
        { type: 'range', group: 'near', y: 0.76, amp: 0.01, color: '#100c1a', fade: 0, solid: true },
      ],
      fog: [{ after: 'far', y: 0.6, h: 0.07, color: '#c07080', alpha: 0.25 }],
      particles: [{ type: 'birds', count: 3, y0: 0.15, y1: 0.3 }, { type: 'dust', count: 12, color: '#ffd090' }],
      post: { vignette: 0.55, grade: '#ff9a60', gradeAlpha: 0.06 },
    },

    harbor: {
      sky: { stops: [[0, '#2a3a6c'], [0.45, '#d8866c'], [0.72, '#f6be80'], [1, '#fde0a8']], sun: { x: 0.6, y: 0.48, r: 28, color: '#fff2c8', glow: '#ffa060' } },
      clouds: { count: 5, light: '#ffc8a0', shade: '#8a5070', y0: 0.08, y1: 0.3 },
      haze: '#f0a082',
      layers: [
        { type: 'range', group: 'far', y: 0.5, amp: 0.05, color: '#8a6a8c', fade: 0.6 },
        { type: 'city', group: 'far', x0: 0.0, x1: 0.26, y: 0.515, h: 60, color: '#5a3a5c', lit: 0.25, scale: 0.7 },
        { type: 'water', group: 'mid', y: 0.52, top: '#f2b088', bottom: '#2a2a52', reflect: 0.38, glintX: 0.6, glint: '#fff0c0' },
        { type: 'lighthouse', group: 'mid', x: 0.1, y: 0.56, size: 160, color: '#24182a', rim: 'rgba(255,170,120,0.5)' },
        { type: 'ships', group: 'mid', y: 0.6, items: [{ x: 0.38, s: 165 }, { x: 0.84, s: 110 }], color: '#2a1c30', sail: '#f2dcb4', rim: 'rgba(255,180,120,0.5)' },
      ],
      particles: [{ type: 'birds', count: 6, y0: 0.15, y1: 0.35 }],
      rays: { x: 0.6, y: 0.48, color: '#ffd090', alpha: 0.06 },
      post: { vignette: 0.45, grade: '#ffa070', gradeAlpha: 0.06 },
    },

    ruins: {
      sky: { stops: [[0, '#3a6aa2'], [0.55, '#9ac0d8'], [1, '#f4dcb0']], sun: { x: 0.76, y: 0.14, r: 26, color: '#fffbe8', glow: '#ffe8a0' } },
      haze: '#ead2a2',
      layers: [
        { type: 'range', group: 'far', y: 0.54, amp: 0.06, freq: 2, color: '#c8a070', fade: 0.6, rough: 0.35 },
        { type: 'range', group: 'mid', y: 0.66, amp: 0.035, freq: 2, color: '#d0a46a', fade: 0.2, rough: 0.3, bottom: '#b88a52', solid: true },
        { type: 'ruins', group: 'mid', y: 0.66, color: '#e2c496', shade: '#9a7a56', items: [{ type: 'column', x: 0.14, s: 210, h: 90 }, { type: 'arch', x: 0.45, s: 230, broken: true }, { type: 'column', x: 0.72, s: 200, h: 60, broken: true }, { type: 'column', x: 0.88, s: 220, h: 96 }, { type: 'block', x: 0.62, s: 180 }, { type: 'block', x: 0.28, s: 150 }] },
        { type: 'range', group: 'near', y: 0.78, amp: 0.04, freq: 2, color: '#a87a48', fade: 0, rough: 0.3, bottom: '#6a4a2a', solid: true },
      ],
      particles: [{ type: 'dust', count: 40, color: '#ffe8b0' }],
      rays: { x: 0.76, y: 0.14, color: '#fff2c0', alpha: 0.08 },
      post: { vignette: 0.4, grade: '#ffc080', gradeAlpha: 0.07 },
    },

    cave: {
      sky: { stops: [[0, '#04050b'], [0.5, '#0c1022'], [1, '#18142e']] },
      haze: '#1a2042',
      layers: [
        { type: 'range', group: 'far', y: 0.68, amp: 0.08, color: '#141a2e', fade: 0.3 },
        { type: 'ceiling', group: 'far', y: 0.22, amp: 0.08, color: '#121628', stalactites: 40 },
        { type: 'crystals', group: 'mid', items: [{ x: 0.2, y: 0.72, s: 280, color: '#7af0ff' }, { x: 0.52, y: 0.67, s: 200, color: '#c08aff' }, { x: 0.82, y: 0.74, s: 300, color: '#7af0ff' }] },
        { type: 'range', group: 'mid', y: 0.76, amp: 0.04, color: '#0b0d1a', fade: 0, solid: true },
        { type: 'ceiling', group: 'near', y: 0.08, amp: 0.07, color: '#07080f', stalactites: 24, scale: 2, rim: '#5a7aff' },
        { type: 'rocks', group: 'near', color: '#05060c', rim: 'rgba(120,220,255,0.45)', items: [{ x: 0.06, y: 0.86, s: 220 }, { x: 0.95, y: 0.84, s: 200 }] },
      ],
      rays: { x: 0.5, y: -0.05, color: '#9ac8ff', alpha: 0.06, spread: 0.5 },
      particles: [{ type: 'dust', count: 30, color: '#9ae0ff' }],
      post: { vignette: 0.7, grade: '#6a7aff', gradeAlpha: 0.08 },
    },

    lake: {
      sky: { stops: [[0, '#2a2a6a'], [0.38, '#9a5a8a'], [0.68, '#f0907a'], [1, '#ffd0a0']], sun: { x: 0.5, y: 0.47, r: 32, color: '#fff0d0', glow: '#ffb080' } },
      clouds: { count: 4, light: '#ffb8a0', shade: '#7a4a7a', y0: 0.08, y1: 0.28 },
      haze: '#f0a092',
      layers: [
        { type: 'range', group: 'far', y: 0.5, amp: 0.12, freq: 3, color: '#6a4a7c', facets: 0.12, fade: 0.5, rim: '#ffc0a0', rimAlpha: 0.4 },
        { type: 'trees', group: 'far', kind: 'pine', y: 0.52, amp: 0.01, size: 22, density: 0.55, color: '#4a3a5a' },
        { type: 'water', group: 'mid', y: 0.53, top: '#f0a090', bottom: '#2e2252', reflect: 0.45, glintX: 0.5, glint: '#ffe8c0' },
        { type: 'trees', group: 'mid', kind: 'round', items: [{ x: 0.04, y: 0.62, s: 200 }, { x: 0.94, y: 0.6, s: 170 }], color: '#2a1a2e', rim: 'rgba(255,170,140,0.45)' },
        { type: 'reeds', group: 'near', y: 0.74, count: 60, color: '#1a0f1e' },
      ],
      particles: [{ type: 'petals', count: 24 }, { type: 'fireflies', count: 14, y0: 0.55, y1: 0.9, color: '#ffd8a0' }],
      rays: { x: 0.5, y: 0.47, color: '#ffd0b0', alpha: 0.05 },
      post: { vignette: 0.5, grade: '#ff8aa0', gradeAlpha: 0.07 },
    },

    camp: {
      sky: { stops: [[0, '#05070e'], [0.6, '#131a2a'], [1, '#202838']], stars: 140 },
      haze: '#1a2030',
      layers: [
        { type: 'trees', group: 'far', kind: 'pine', y: 0.52, amp: 0.03, size: 70, density: 0.9, color: '#121a28', spacing: 0.18 },
        { type: 'trees', group: 'mid', kind: 'pine', y: 0.62, amp: 0.02, size: 110, density: 0.6, color: '#0a0f18' },
        { type: 'range', group: 'mid', y: 0.7, amp: 0.01, color: '#0c0f16', fade: 0, solid: true },
        { type: 'tents', group: 'mid', y: 0.68, fireX: 0.52, color: '#3a2a20', lit: '#c47a3a', items: [{ x: 0.28, s: 170 }, { x: 0.76, s: 150 }] },
        { type: 'fire', group: 'mid', x: 0.52, y: 0.71, size: 130, stones: '#1a1414' },
        { type: 'crowd', group: 'mid', x0: 0.4, x1: 0.64, y: 0.715, count: 4, dance: 0, scale: 1.6, color: '#06070c', rim: '#ff9a4a', fireX: 0.52 },
        { type: 'trees', group: 'near', kind: 'pine', items: [{ x: 0.02, y: 0.9, s: 360 }, { x: 0.98, y: 0.9, s: 320 }], color: '#020305' },
      ],
      fog: [{ after: 'far', y: 0.56, h: 0.07, color: '#3a4a60', alpha: 0.3 }],
      particles: [{ type: 'fireflies', count: 16, y0: 0.45, y1: 0.9, color: '#d8ffa0' }],
      post: { vignette: 0.7, grade: '#ff8040', gradeAlpha: 0.06 },
    },

    elder_home: {
      sky: { stops: [[0, '#4a5a9a'], [0.42, '#cc8a6c'], [0.72, '#f6c070'], [1, '#fde8b0']], sun: { x: 0.24, y: 0.47, r: 28, color: '#fff2c8', glow: '#ffb060' } },
      clouds: { count: 4, light: '#ffd8a0', shade: '#a06a7a', y0: 0.08, y1: 0.3 },
      haze: '#f0b880',
      layers: [
        { type: 'range', group: 'far', y: 0.5, amp: 0.08, color: '#8a6a8a', fade: 0.6 },
        { type: 'range', group: 'mid', y: 0.62, amp: 0.05, freq: 1.5, color: '#9a7038', fade: 0.2, bottom: '#6a4a24', solid: true, rough: 0.35 },
        { type: 'cottages', group: 'mid', y: 0.6, items: [{ x: 0.7, s: 160 }], palette: { wall: '#f0d8b0', wallShade: '#b88a60' } },
        { type: 'bigTree', group: 'mid', x: 0.4, y: 0.62, size: 200, trunk: '#3a2416', leaves: ['#6a2418', '#c4562a', '#f2a040'] },
        { type: 'range', group: 'near', y: 0.76, amp: 0.02, color: '#5a3a1e', fade: 0, solid: true },
      ],
      particles: [{ type: 'leaves', count: 30 }, { type: 'birds', count: 4, y0: 0.15, y1: 0.35 }],
      rays: { x: 0.24, y: 0.47, color: '#ffd090', alpha: 0.07 },
      post: { vignette: 0.45, grade: '#ffb060', gradeAlpha: 0.08 },
    },

    ending: {
      sky: { stops: [[0, '#03040c'], [0.5, '#10163a'], [0.85, '#3a2a5a'], [1, '#6a3a5a']], stars: 320, milky: true, aurora: '#4affc0', auroraAlpha: 0.08 },
      haze: '#3a2a5a',
      layers: [
        { type: 'range', group: 'far', y: 0.58, amp: 0.1, color: '#141838', fade: 0.4 },
        { type: 'range', group: 'mid', y: 0.67, amp: 0.05, freq: 1.2, color: '#0c0e22', fade: 0, solid: true, rough: 0.3, bumps: [{ x: 0.5, w: 0.3, h: 0.03 }] },
        { type: 'bigTree', group: 'mid', x: 0.5, y: 0.64, size: 170, trunk: '#05061a', leaves: ['#05061a', '#070826', '#0a0b2e'] },
        { type: 'range', group: 'near', y: 0.8, amp: 0.02, color: '#04050e', fade: 0, solid: true },
      ],
      fog: [{ after: 'far', y: 0.62, h: 0.08, color: '#4a3a7a', alpha: 0.3 }],
      particles: [{ type: 'skylanterns', count: 26 }, { type: 'fireflies', count: 16, y0: 0.6, y1: 0.95, color: '#ffe0a0' }],
      post: { vignette: 0.6, grade: '#ffa060', gradeAlpha: 0.04 },
    },
  };

  // ฉากพื้นหลังของแต่ละช่วงวัย และฉากตัวอย่างของต้นกำเนิด
  const STAGE_SCENES = { child: 'village', youth: 'dragon_vale', adult: 'city', elder: 'elder_home' };
  const ORIGIN_SCENES = { warrior: 'fortress', mage: 'tower', merchant: 'harbor', wanderer: 'road' };

  // ---------- สร้างฉาก ----------

  const GROUPS = ['far', 'mid', 'near'];
  const PARALLAX = { sky: 0.08, far: 0.25, mid: 0.55, near: 1 };

  function buildScene(key, W, H, dpr, view = 1) {
    const spec = SCENES[key] || SCENES.title;
    const rng = mulberry32(hashString(key));
    const body = spec.sky.sun || spec.sky.moon;
    const pad = Math.round(Math.max(16, W * 0.04));
    const S = {
      W,
      H: H * view,
      floor: H,
      pad,
      dpr,
      u: Math.max(0.5, Math.min(H, W * 1.25) / 1000),
      rng,
      noise: makeNoise(rng),
      haze: spec.haze,
      lightDir: body ? (body.x < 0.5 ? -1 : 1) : 1,
      emitters: [],
      twinkles: [],
      reflectSources: [],
      group: 'far',
    };
    const layerCanvas = () => {
      const c = makeCanvas((W + 2 * pad) * dpr, H * dpr);
      const g = c.getContext('2d');
      g.setTransform(dpr, 0, 0, dpr, pad * dpr, 0);
      return { canvas: c, ctx: g };
    };
    const sky = layerCanvas();
    drawSky(sky.ctx, S, spec.sky);
    const groups = {};
    S.reflectSources = [sky.canvas];
    for (const name of GROUPS) {
      groups[name] = layerCanvas();
      S.group = name;
      for (const L of spec.layers) {
        if ((L.group || 'mid') !== name) continue;
        PRIMS[L.type](groups[name].ctx, S, L);
      }
      if (name === 'far') S.reflectSources.push(groups.far.canvas);
    }
    const clouds = [];
    if (spec.clouds) for (let i = 0; i < spec.clouds.count; i++) clouds.push(makeCloud(S, spec.clouds, dpr));
    const fog = (spec.fog || []).map((f) => ({ ...f, sprite: makeFog(f.color), offset: rng() * 1000 }));
    const scene = { key, spec, S, sky: sky.canvas, groups, clouds, fog, emitters: S.emitters, twinkles: S.twinkles.slice(0, 40), particles: [], fx: [], post: buildPost(W, H, dpr, spec.post || {}), flash: 0, nextFirework: 1, nextBolt: 3 };
    for (const cfg of spec.particles || []) {
      for (let i = 0; i < cfg.count; i++) scene.particles.push(spawnParticle(cfg, S, true));
    }
    for (const e of spec.eyes || []) scene.emitters.push({ type: 'eyes', x: e.x * W, y: e.y * S.H, group: 'mid', phase: rng() * 10 });
    return scene;
  }

  function buildPost(W, H, dpr, post) {
    const c = makeCanvas(W * dpr, H * dpr);
    const g = c.getContext('2d');
    g.scale(dpr, dpr);
    const v = g.createRadialGradient(W / 2, H * 0.42, Math.min(W, H) * 0.25, W / 2, H * 0.5, Math.max(W, H) * 0.8);
    v.addColorStop(0, 'rgba(0,0,0,0)');
    v.addColorStop(1, `rgba(0,0,0,${post.vignette ?? 0.5})`);
    g.fillStyle = v;
    g.fillRect(0, 0, W, H);
    // ไล่มืดด้านล่างให้แผงข้อความอ่านง่าย
    const b = g.createLinearGradient(0, H * 0.5, 0, H);
    b.addColorStop(0, 'rgba(6,4,12,0)');
    b.addColorStop(1, 'rgba(6,4,12,0.55)');
    g.fillStyle = b;
    g.fillRect(0, 0, W, H);
    // เกรนบางๆ ให้ภาพดูเป็นงานวาด
    const n = makeCanvas(128, 128);
    const ng = n.getContext('2d');
    const img = ng.createImageData(128, 128);
    for (let i = 0; i < img.data.length; i += 4) {
      const v2 = Math.random() * 255;
      img.data[i] = img.data[i + 1] = img.data[i + 2] = v2;
      img.data[i + 3] = 9;
    }
    ng.putImageData(img, 0, 0);
    g.fillStyle = g.createPattern(n, 'repeat');
    g.fillRect(0, 0, W, H);
    return { canvas: c, grade: post.grade, gradeAlpha: post.gradeAlpha || 0 };
  }

  // ---------- อนุภาค ----------

  function spawnParticle(cfg, S, fresh) {
    const p = { type: cfg.type, cfg, t: 0 };
    const W = S.W;
    const H = S.H;
    const r = Math.random;
    switch (cfg.type) {
      case 'fireflies':
      case 'wisps':
        p.x = r() * W;
        p.y = lerp(cfg.y0 ?? 0.45, cfg.y1 ?? 0.95, r()) * H;
        p.vx = (r() - 0.5) * 12 * S.u;
        p.vy = (r() - 0.5) * 8 * S.u;
        p.phase = r() * TAU;
        p.size = (cfg.type === 'wisps' ? 22 + r() * 18 : 6 + r() * 6) * S.u;
        p.life = Infinity;
        break;
      case 'embers':
        p.x = r() * W;
        p.y = fresh ? lerp(0.3, 1, r()) * H : H * (0.9 + r() * 0.15);
        p.vx = (r() - 0.5) * 10 * S.u;
        p.vy = -(18 + r() * 30) * S.u;
        p.phase = r() * TAU;
        p.size = (3 + r() * 4) * S.u;
        p.life = 4 + r() * 4;
        p.t = fresh ? r() * p.life : 0;
        break;
      case 'petals':
      case 'leaves':
        p.x = fresh ? r() * W : -20;
        p.y = fresh ? r() * H : r() * H * 0.6;
        p.vx = (18 + r() * 24) * S.u;
        p.vy = (10 + r() * 16) * S.u;
        p.rot = r() * TAU;
        p.spin = (r() - 0.5) * 3;
        p.phase = r() * TAU;
        p.size = (cfg.type === 'leaves' ? 4 + r() * 3 : 2.6 + r() * 2) * S.u;
        p.color = (cfg.colors || (cfg.type === 'leaves' ? ['#d0602a', '#f2a040', '#a83a1a', '#e8c050'] : ['#ffd0e0', '#ffffff', '#ffb0c8']))[Math.floor(r() * 3.99) % 4] || '#ffffff';
        p.life = Infinity;
        break;
      case 'rain':
        p.x = r() * (W + 100) - 50;
        p.y = fresh ? r() * S.floor : -20;
        p.vy = S.floor * (1.3 + r() * 0.5);
        p.vx = -p.vy * 0.12;
        p.len = (14 + r() * 12) * S.u;
        p.life = Infinity;
        break;
      case 'dust':
        p.x = r() * W;
        p.y = r() * H * 0.9;
        p.vx = (4 + r() * 8) * S.u;
        p.vy = (r() - 0.5) * 4 * S.u;
        p.phase = r() * TAU;
        p.size = (2 + r() * 3) * S.u;
        p.life = Infinity;
        break;
      case 'birds':
        p.x = fresh ? r() * W : -30;
        p.y = lerp(cfg.y0 ?? 0.15, cfg.y1 ?? 0.35, r()) * H;
        p.vx = (24 + r() * 20) * S.u;
        p.phase = r() * TAU;
        p.size = (4 + r() * 3) * S.u;
        p.life = Infinity;
        break;
      case 'skylanterns': {
        const depth = r();
        p.x = r() * W;
        p.y = fresh ? lerp(0.1, 1, r()) * H : H * (0.95 + r() * 0.1);
        p.vy = -(6 + depth * 14) * S.u;
        p.vx = (r() - 0.3) * 4 * S.u;
        p.size = (3 + depth * 6) * S.u;
        p.phase = r() * TAU;
        p.life = Infinity;
        break;
      }
      default:
        p.life = 0;
    }
    return p;
  }

  function updateParticle(p, dt, S) {
    p.t += dt;
    const W = S.W;
    const H = S.H;
    switch (p.type) {
      case 'fireflies':
      case 'wisps':
        p.vx += (Math.random() - 0.5) * 20 * S.u * dt;
        p.vy += (Math.random() - 0.5) * 20 * S.u * dt;
        p.vx = clamp(p.vx, -14 * S.u, 14 * S.u);
        p.vy = clamp(p.vy, -10 * S.u, 10 * S.u);
        p.x += p.vx * dt;
        p.y += p.vy * dt;
        if (p.x < -20) p.x = W + 20;
        if (p.x > W + 20) p.x = -20;
        p.y = clamp(p.y, (p.cfg.y0 ?? 0.45) * H, (p.cfg.y1 ?? 0.95) * H);
        return true;
      case 'embers':
        p.x += (p.vx + Math.sin(p.t * 2 + p.phase) * 10 * S.u) * dt;
        p.y += p.vy * dt;
        return p.t < p.life;
      case 'petals':
      case 'leaves':
        p.x += (p.vx + Math.sin(p.t * 1.5 + p.phase) * 14 * S.u) * dt;
        p.y += p.vy * dt;
        p.rot += p.spin * dt;
        return p.x < W + 30 && p.y < H + 30;
      case 'rain':
        p.x += p.vx * dt;
        p.y += p.vy * dt;
        return p.y < S.floor + 30;
      case 'dust':
        p.x += p.vx * dt;
        p.y += (p.vy + Math.sin(p.t + p.phase) * 3 * S.u) * dt;
        if (p.x > W + 10) p.x = -10;
        return true;
      case 'birds':
        p.x += p.vx * dt;
        p.y += Math.sin(p.t * 0.8 + p.phase) * 4 * S.u * dt;
        return p.x < W + 40;
      case 'skylanterns':
        p.x += (p.vx + Math.sin(p.t * 0.6 + p.phase) * 3 * S.u) * dt;
        p.y += p.vy * dt;
        return p.y > -40;
      default:
        return false;
    }
  }

  function drawParticle(ctx, p, t, S) {
    switch (p.type) {
      case 'fireflies': {
        const a = 0.35 + 0.65 * Math.max(0, Math.sin(t * 2.2 + p.phase));
        drawGlow(ctx, p.x, p.y, p.size * 2.4, p.cfg.color || '#ffe9a0', a * 0.8, 0.2);
        break;
      }
      case 'wisps': {
        const a = 0.3 + 0.3 * Math.sin(t * 1.3 + p.phase);
        drawGlow(ctx, p.x, p.y, p.size, p.cfg.color || '#7affc0', a, 0.05);
        drawGlow(ctx, p.x, p.y, p.size * 0.25, '#ffffff', a, 0.4);
        break;
      }
      case 'embers': {
        const a = Math.max(0, 1 - p.t / p.life);
        drawGlow(ctx, p.x, p.y, p.size * 1.8, '#ff9a40', a, 0.35);
        break;
      }
      case 'dust': {
        const a = 0.2 + 0.25 * Math.sin(t * 1.4 + p.phase);
        drawGlow(ctx, p.x, p.y, p.size, p.cfg.color || '#ffe0b0', a, 0.3);
        break;
      }
      case 'skylanterns': {
        const flick = 0.85 + 0.15 * Math.sin(t * 6 + p.phase);
        drawGlow(ctx, p.x, p.y, p.size * 5, '#ff9a40', 0.35 * flick, 0.1);
        ctx.globalAlpha = 1;
        ctx.fillStyle = '#ffcf70';
        ctx.beginPath();
        ctx.moveTo(p.x - p.size * 0.6, p.y - p.size * 0.8);
        ctx.lineTo(p.x + p.size * 0.6, p.y - p.size * 0.8);
        ctx.lineTo(p.x + p.size * 0.45, p.y + p.size * 0.7);
        ctx.lineTo(p.x - p.size * 0.45, p.y + p.size * 0.7);
        ctx.closePath();
        ctx.fill();
        drawGlow(ctx, p.x, p.y + p.size * 0.4, p.size * 0.9, '#fff4c8', flick, 0.5);
        break;
      }
      default:
        break;
    }
  }

  // อนุภาคที่ไม่ใช้การผสมสีแบบเพิ่มแสง
  function drawSolidParticle(ctx, p, t, S) {
    switch (p.type) {
      case 'petals':
      case 'leaves':
        ctx.save();
        ctx.translate(p.x, p.y);
        ctx.rotate(p.rot);
        ctx.scale(1, Math.abs(Math.sin(p.t * 2 + p.phase)) * 0.7 + 0.3);
        ctx.globalAlpha = 0.9;
        ctx.fillStyle = p.color;
        ctx.beginPath();
        ctx.ellipse(0, 0, p.size, p.size * 0.55, 0, 0, TAU);
        ctx.fill();
        ctx.restore();
        break;
      case 'rain':
        ctx.globalAlpha = 0.32;
        ctx.strokeStyle = '#c8d4e8';
        ctx.lineWidth = Math.max(1, S.u);
        ctx.beginPath();
        ctx.moveTo(p.x, p.y);
        ctx.lineTo(p.x + p.vx * 0.012, p.y + p.len);
        ctx.stroke();
        break;
      case 'birds': {
        const f = Math.sin(t * 9 + p.phase) * p.size * 0.6;
        ctx.globalAlpha = 0.85;
        ctx.strokeStyle = p.cfg.color || '#2a2030';
        ctx.lineWidth = Math.max(1, S.u * 1.2);
        ctx.lineCap = 'round';
        ctx.beginPath();
        ctx.moveTo(p.x - p.size, p.y - f);
        ctx.quadraticCurveTo(p.x - p.size * 0.4, p.y - p.size * 0.3, p.x, p.y);
        ctx.quadraticCurveTo(p.x + p.size * 0.4, p.y - p.size * 0.3, p.x + p.size, p.y - f);
        ctx.stroke();
        break;
      }
      default:
        break;
    }
  }

  // ---------- เอฟเฟกต์ของสิ่งก่อสร้างที่ขยับ ----------

  function updateEmitter(scene, e, dt) {
    const S = scene.S;
    if (e.type === 'smoke') {
      e.acc = (e.acc || Math.random()) + dt;
      if (e.acc > 0.45) {
        e.acc = 0;
        scene.fx.push({ kind: 'smoke', x: e.x, y: e.y, vx: (5 + Math.random() * 5) * S.u, vy: -(10 + Math.random() * 6) * S.u, r: 2.5 * e.k, grow: 4 * e.k, t: 0, life: 4 + Math.random() * 2, group: e.group });
      }
    } else if (e.type === 'fire') {
      e.acc = (e.acc || 0) + dt;
      while (e.acc > 0.025) {
        e.acc -= 0.025;
        scene.fx.push({ kind: 'flame', x: e.x + (Math.random() - 0.5) * e.size * 0.9, y: e.y, vx: (Math.random() - 0.5) * 8 * S.u, vy: -(30 + Math.random() * 50) * S.u * (e.size / (22 * S.u)), r: e.size * (0.35 + Math.random() * 0.25), t: 0, life: 0.5 + Math.random() * 0.5, group: e.group });
        if (Math.random() < 0.06) scene.fx.push({ kind: 'spark', x: e.x, y: e.y - e.size * 0.5, vx: (Math.random() - 0.5) * 30 * S.u, vy: -(40 + Math.random() * 60) * S.u, r: 2 * S.u, t: 0, life: 1.5 + Math.random() * 1.5, group: e.group });
      }
    } else if (e.type === 'orb') {
      e.acc = (e.acc || 0) + dt;
      if (e.acc > 0.12) {
        e.acc = 0;
        const a = Math.random() * TAU;
        const d = (8 + Math.random() * 30) * e.r * 0.25;
        scene.fx.push({ kind: 'sparkle', x: e.x + Math.cos(a) * d, y: e.y + Math.sin(a) * d, vx: 0, vy: -6 * S.u, r: (1.5 + Math.random() * 2.5) * S.u, t: 0, life: 1 + Math.random(), color: e.color, group: e.group });
      }
    }
  }

  function drawEmitter(ctx, scene, e, t, ox) {
    const x = e.x + ox;
    const y = e.y;
    switch (e.type) {
      case 'window':
        drawGlow(ctx, x, y, e.r, e.color, 0.3 + 0.08 * Math.sin(t * 3 + (e.phase || 0)) + 0.04 * Math.sin(t * 11 + (e.phase || 0)), 0.1);
        break;
      case 'lantern': {
        const a = 0.55 + 0.12 * Math.sin(t * 4 + e.phase);
        drawGlow(ctx, x, y, e.r, e.color, a, 0.15);
        drawGlow(ctx, x, y, e.r * 0.25, '#fff4d0', 0.8, 0.5);
        break;
      }
      case 'fire': {
        const a = 0.55 + 0.15 * Math.sin(t * 13) + 0.1 * Math.sin(t * 7.3);
        drawGlow(ctx, x, y - e.size * 0.6, e.size * 9, '#ff8a3a', a * 0.5, 0);
        drawGlow(ctx, x, y - e.size * 0.4, e.size * 2.6, '#ffd070', a, 0.2);
        break;
      }
      case 'orb': {
        const pulse = 1 + 0.15 * Math.sin(t * 2.4);
        drawGlow(ctx, x, y, e.r * 14 * pulse, e.color, 0.35, 0);
        drawGlow(ctx, x, y, e.r * 4 * pulse, e.color, 0.9, 0.2);
        drawGlow(ctx, x, y, e.r * 1.6, '#ffffff', 1, 0.6);
        break;
      }
      case 'crystal':
        drawGlow(ctx, x, y, e.r * (1 + 0.1 * Math.sin(t * 1.8 + e.phase)), e.color, 0.4 + 0.12 * Math.sin(t * 2.3 + e.phase), 0);
        break;
      case 'beacon': {
        drawGlow(ctx, x, y, e.r * 3, e.color, 0.9, 0.3);
        const a = t * 0.9;
        const len = scene.S.W * 0.5;
        const side = Math.cos(a);
        ctx.globalAlpha = 0.16 * Math.abs(side);
        const dir = Math.sign(side) || 1;
        const g = ctx.createLinearGradient(x, y, x + dir * len, y);
        g.addColorStop(0, rgba(e.color, 1));
        g.addColorStop(1, rgba(e.color, 0));
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.moveTo(x, y);
        ctx.lineTo(x + dir * len, y - len * 0.1);
        ctx.lineTo(x + dir * len, y + len * 0.08);
        ctx.closePath();
        ctx.fill();
        break;
      }
      case 'eyes': {
        const blink = Math.sin(t * 0.7 + e.phase) > 0.93 ? 0 : 1;
        const gap = 5 * scene.S.u;
        for (const s of [-1, 1]) drawGlow(ctx, x + s * gap, y, 4 * scene.S.u, '#ffd84a', blink * 0.95, 0.6);
        break;
      }
      case 'water': {
        const S = scene.S;
        for (let i = 0; i < 40; i++) {
          const depth = ((i * 0.6180339) % 1);
          const yy = y + 2 + depth * depth * (S.H - y) * 0.7;
          const spread = S.W * e.spread * (0.3 + depth * 1.4);
          const xx = x + Math.sin(i * 12.9898) * spread;
          const a = Math.max(0, Math.sin(t * (1.5 + (i % 5) * 0.3) + i));
          ctx.globalAlpha = a * 0.55;
          ctx.fillStyle = e.color;
          ctx.fillRect(xx - (4 + depth * 14) * S.u, yy, (8 + depth * 28) * S.u, Math.max(1, S.u * (0.8 + depth)));
        }
        break;
      }
      default:
        break;
    }
  }

  function drawSolidEmitter(ctx, scene, e, t, ox) {
    const x = e.x + ox;
    const y = e.y;
    if (e.type === 'flag') {
      ctx.globalAlpha = 1;
      ctx.fillStyle = e.color;
      ctx.beginPath();
      ctx.moveTo(x, y);
      const n = 6;
      for (let i = 1; i <= n; i++) {
        const fx = x + (e.w * i) / n;
        ctx.lineTo(fx, y + Math.sin(t * 5 - i * 0.9) * e.h * 0.2 * (i / n));
      }
      for (let i = n; i >= 0; i--) {
        const fx = x + (e.w * i) / n;
        ctx.lineTo(fx, y + e.h + Math.sin(t * 5 - i * 0.9) * e.h * 0.2 * (i / n));
      }
      ctx.closePath();
      ctx.fill();
    } else if (e.type === 'windmill') {
      const a0 = t * 0.6;
      ctx.globalAlpha = 1;
      for (let i = 0; i < 4; i++) {
        const a = a0 + (i * Math.PI) / 2;
        ctx.save();
        ctx.translate(x, y);
        ctx.rotate(a);
        ctx.fillStyle = '#5a3a26';
        ctx.fillRect(-e.r * 0.02, 0, e.r * 0.04, e.r);
        ctx.fillStyle = e.color;
        ctx.globalAlpha = 0.92;
        ctx.fillRect(e.r * 0.03, e.r * 0.22, e.r * 0.17, e.r * 0.76);
        ctx.strokeStyle = 'rgba(90,58,38,0.6)';
        ctx.lineWidth = 1;
        for (let j = 1; j < 5; j++) {
          ctx.beginPath();
          ctx.moveTo(e.r * 0.03, e.r * (0.22 + j * 0.15));
          ctx.lineTo(e.r * 0.2, e.r * (0.22 + j * 0.15));
          ctx.stroke();
        }
        ctx.restore();
      }
      ctx.fillStyle = '#3a2416';
      ctx.beginPath();
      ctx.arc(x, y, e.r * 0.06, 0, TAU);
      ctx.fill();
    }
  }

  function drawDragon(ctx, x, y, s, phase, color) {
    ctx.save();
    ctx.translate(x, y);
    ctx.scale(s / 100, s / 100);
    ctx.fillStyle = color;
    const flap = Math.sin(phase);
    const wing = (f, alpha) => {
      ctx.globalAlpha = alpha;
      ctx.beginPath();
      ctx.moveTo(4, -2);
      ctx.lineTo(22, -4);
      ctx.quadraticCurveTo(8, -30 * f - 6, -14, -52 * f - 4);
      ctx.quadraticCurveTo(-12, -30 * f, -22, -26 * f);
      ctx.quadraticCurveTo(-10, -16 * f, -14, -8 * f);
      ctx.quadraticCurveTo(-4, -6 * f, -2, 0);
      ctx.closePath();
      ctx.fill();
    };
    wing(flap * 0.8 + 0.2, 0.7);
    ctx.globalAlpha = 1;
    ctx.beginPath();
    ctx.moveTo(-70, 10);
    ctx.quadraticCurveTo(-40, 18, -14, 4);
    ctx.quadraticCurveTo(8, -6, 28, -4);
    ctx.quadraticCurveTo(40, -8, 48, -16);
    ctx.lineTo(56, -19);
    ctx.lineTo(66, -15);
    ctx.lineTo(54, -11);
    ctx.quadraticCurveTo(42, -2, 30, 6);
    ctx.quadraticCurveTo(10, 12, -14, 9);
    ctx.quadraticCurveTo(-40, 22, -70, 10);
    ctx.closePath();
    ctx.fill();
    ctx.beginPath();
    ctx.moveTo(-70, 10);
    ctx.lineTo(-80, 4);
    ctx.lineTo(-76, 14);
    ctx.fill();
    ctx.beginPath();
    ctx.moveTo(52, -18);
    ctx.lineTo(46, -27);
    ctx.lineTo(55, -20);
    ctx.fill();
    wing(flap, 1);
    ctx.restore();
  }

  // ---------- ตัววาด ----------

  function createRenderer(canvas, opts = {}) {
    const ctx = canvas.getContext('2d');
    const still = !!opts.still;
    const view = opts.view ?? 0.8;
    const reduced = typeof matchMedia === 'function' && matchMedia('(prefers-reduced-motion: reduce)').matches;
    let W = 0;
    let H = 0;
    let dpr = 1;
    let key = null;
    let scene = null;
    let prev = null;
    let prevAlpha = 0;
    let t = 0;
    let last = 0;
    let running = false;
    let pointer = 0;
    let cam = 0;

    function resize() {
      const rect = canvas.getBoundingClientRect();
      const nw = Math.max(1, Math.round(rect.width));
      const nh = Math.max(1, Math.round(rect.height));
      const ndpr = Math.min(window.devicePixelRatio || 1, opts.maxDpr || 1.5);
      if (nw === W && nh === H && ndpr === dpr && scene) return;
      W = nw;
      H = nh;
      dpr = ndpr;
      canvas.width = Math.round(W * dpr);
      canvas.height = Math.round(H * dpr);
      prev = null;
      if (key) scene = buildScene(key, W, H, dpr, view);
    }

    function setScene(next, { instant = false } = {}) {
      if (!SCENES[next]) next = 'title';
      if (next === key && scene) return;
      if (scene && !instant && !still) {
        prev = makeCanvas(canvas.width, canvas.height);
        prev.getContext('2d').drawImage(canvas, 0, 0);
        prevAlpha = 1;
      }
      key = next;
      if (!W) resize();
      scene = buildScene(key, W, H, dpr, view);
      if (still) draw(0);
    }

    function update(dt) {
      const sc = scene;
      const S = sc.S;
      for (const c of sc.clouds) {
        c.x += c.speed * dt;
        if (c.x > S.W + S.pad) c.x = -S.pad - c.w;
      }
      for (const f of sc.fog) f.offset += dt * 8 * S.u * (f.speed || 1);
      for (let i = 0; i < sc.particles.length; i++) {
        const p = sc.particles[i];
        if (!updateParticle(p, dt, S)) sc.particles[i] = spawnParticle(p.cfg, S, false);
      }
      for (const e of sc.emitters) updateEmitter(sc, e, dt);
      sc.fx = sc.fx.filter((f) => {
        f.t += dt;
        f.x += f.vx * dt;
        f.y += f.vy * dt;
        if (f.kind === 'spark') f.vy += 20 * S.u * dt;
        if (f.kind === 'firework') f.vy += 40 * S.u * dt;
        return f.t < f.life;
      });
      if (sc.spec.fireworks) {
        sc.nextFirework -= dt;
        if (sc.nextFirework <= 0) {
          sc.nextFirework = 1.2 + Math.random() * 2.5;
          const fx = S.W * (0.15 + Math.random() * 0.7);
          const fy = S.H * (0.1 + Math.random() * 0.25);
          const color = ['#ffd070', '#ff7aa0', '#8fd8ff', '#b8ff8a'][Math.floor(Math.random() * 4)];
          for (let i = 0; i < 46; i++) {
            const a = (i / 46) * TAU;
            const v = (50 + Math.random() * 30) * S.u;
            sc.fx.push({ kind: 'firework', x: fx, y: fy, vx: Math.cos(a) * v, vy: Math.sin(a) * v, r: 2.4 * S.u, t: 0, life: 1.4 + Math.random() * 0.5, color, group: 'sky' });
          }
        }
      }
      if (sc.spec.lightning) {
        sc.nextBolt -= dt;
        if (sc.nextBolt <= 0) {
          sc.nextBolt = 4 + Math.random() * 7;
          sc.flash = 1;
        }
        sc.flash = Math.max(0, sc.flash - dt * 2.5);
      }
    }

    function groupOffset(name) {
      return -cam * scene.S.pad * (PARALLAX[name] ?? 0.55);
    }

    function draw(time) {
      if (!scene) return;
      const sc = scene;
      const S = sc.S;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.globalAlpha = 1;
      ctx.globalCompositeOperation = 'source-over';
      const blit = (c, name) => ctx.drawImage(c, -S.pad + groupOffset(name), 0, W + 2 * S.pad, H);
      blit(sc.sky, 'sky');
      // ดาวระยิบระยับ
      ctx.globalCompositeOperation = 'lighter';
      for (const s of sc.twinkles) {
        const a = Math.max(0, Math.sin(time * 1.7 + s.phase));
        drawGlow(ctx, s.x + groupOffset('sky'), s.y, s.r * 5, '#dfe8ff', a * 0.5, 0.4);
      }
      for (const f of sc.fx) {
        if (f.kind !== 'firework') continue;
        const a = 1 - f.t / f.life;
        drawGlow(ctx, f.x, f.y, f.r * 3, f.color, a, 0.5);
      }
      ctx.globalCompositeOperation = 'source-over';
      for (const c of sc.clouds) {
        ctx.globalAlpha = c.alpha;
        ctx.drawImage(c.canvas, c.x + groupOffset('sky'), c.y, c.w, c.h);
      }
      ctx.globalAlpha = 1;
      blit(sc.groups.far.canvas, 'far');
      if (sc.spec.dragon) {
        const d = sc.spec.dragon;
        const span = W + 300 * S.u;
        const x = ((time * d.speed * W * 0.4) % span) - 150 * S.u;
        drawDragon(ctx, x, d.y * S.H + Math.sin(time * 0.8) * 8 * S.u, d.size * S.u, time * 3.2, d.color);
      }
      drawFog(sc, 'far');
      blit(sc.groups.mid.canvas, 'mid');
      drawFog(sc, 'mid');
      blit(sc.groups.near.canvas, 'near');
      // ควันและสิ่งที่ทึบ
      for (const e of sc.emitters) drawSolidEmitter(ctx, sc, e, time, groupOffset(e.group));
      for (const f of sc.fx) {
        if (f.kind !== 'smoke') continue;
        const a = (1 - f.t / f.life) * 0.22;
        drawGlow(ctx, f.x + groupOffset(f.group), f.y, f.r + f.grow * f.t, '#c8c0c8', a, 0.1);
      }
      ctx.globalAlpha = 1;
      for (const p of sc.particles) drawSolidParticle(ctx, p, time, S);
      // แสงต่างๆ ผสมแบบเพิ่มความสว่าง
      ctx.globalCompositeOperation = 'lighter';
      for (const e of sc.emitters) drawEmitter(ctx, sc, e, time, groupOffset(e.group));
      for (const f of sc.fx) {
        const ox = groupOffset(f.group);
        const a = 1 - f.t / f.life;
        if (f.kind === 'flame') {
          const r = f.r * (1 - f.t / f.life * 0.6);
          drawGlow(ctx, f.x + ox, f.y, r, a > 0.6 ? '#fff0b0' : a > 0.3 ? '#ffb040' : '#ff5a20', a * 0.9, 0.3);
        } else if (f.kind === 'spark') {
          drawGlow(ctx, f.x + ox, f.y, f.r * 2, '#ffc060', a, 0.5);
        } else if (f.kind === 'sparkle') {
          const tw = Math.sin((f.t / f.life) * Math.PI);
          drawGlow(ctx, f.x + ox, f.y, f.r * 3, f.color, tw, 0.5);
        }
      }
      for (const p of sc.particles) drawParticle(ctx, p, time, S);
      if (sc.spec.rays) drawRays(ctx, sc, time);
      ctx.globalCompositeOperation = 'source-over';
      ctx.globalAlpha = 1;
      if (sc.post.grade) {
        ctx.globalCompositeOperation = 'soft-light';
        ctx.globalAlpha = sc.post.gradeAlpha * 4;
        ctx.fillStyle = sc.post.grade;
        ctx.fillRect(0, 0, W, H);
        ctx.globalCompositeOperation = 'source-over';
        ctx.globalAlpha = 1;
      }
      ctx.drawImage(sc.post.canvas, 0, 0, W, H);
      if (sc.flash > 0) {
        ctx.globalAlpha = sc.flash * 0.45;
        ctx.fillStyle = '#dfe8ff';
        ctx.fillRect(0, 0, W, H);
        ctx.globalAlpha = 1;
      }
      if (prev && prevAlpha > 0) {
        ctx.globalAlpha = prevAlpha;
        ctx.drawImage(prev, 0, 0, W, H);
        ctx.globalAlpha = 1;
      }
    }

    function drawFog(sc, after) {
      for (const f of sc.fog) {
        if (f.after !== after) continue;
        const S = sc.S;
        const w = S.W * 0.9;
        const h = S.H * f.h * 2;
        ctx.globalAlpha = f.alpha;
        for (let i = -1; i < 5; i++) {
          const x = ((f.offset + i * w * 0.6) % (w * 3)) - w + groupOffset(after);
          ctx.drawImage(f.sprite, x, f.y * S.H - h / 2, w * 1.1, h);
        }
        ctx.globalAlpha = 1;
      }
    }

    function drawRays(c, sc, time) {
      const r = sc.spec.rays;
      const S = sc.S;
      const x = r.x * S.W + groupOffset('sky');
      const y = r.y * S.H;
      const len = Math.hypot(S.W, S.H);
      const n = 7;
      for (let i = 0; i < n; i++) {
        const base = Math.PI / 2 + ((i / (n - 1)) - 0.5) * Math.PI * (r.spread || 0.85);
        const a = base + Math.sin(time * 0.1 + i) * 0.03;
        const w = 0.035 + ((i * 37) % 5) * 0.008;
        const g = c.createRadialGradient(x, y, 0, x, y, len * 0.8);
        g.addColorStop(0, rgba(r.color, r.alpha * (0.7 + 0.3 * Math.sin(time * 0.4 + i * 1.7))));
        g.addColorStop(1, rgba(r.color, 0));
        c.globalAlpha = 1;
        c.fillStyle = g;
        c.beginPath();
        c.moveTo(x, y);
        c.lineTo(x + Math.cos(a - w) * len, y + Math.sin(a - w) * len);
        c.lineTo(x + Math.cos(a + w) * len, y + Math.sin(a + w) * len);
        c.closePath();
        c.fill();
      }
    }

    function frame(now) {
      if (!running) return;
      const dt = last ? Math.min(0.05, (now - last) / 1000) : 0.016;
      last = now;
      const speed = reduced ? 0.25 : 1;
      t += dt * speed;
      const target = clamp(pointer * 0.7 + Math.sin(t * 0.05) * 0.4, -1, 1);
      cam += (target - cam) * Math.min(1, dt * 2);
      if (scene) {
        update(dt * speed);
        draw(t);
      }
      if (prevAlpha > 0) {
        prevAlpha -= dt / 0.9;
        if (prevAlpha <= 0) prev = null;
      }
      requestAnimationFrame(frame);
    }

    function start() {
      if (running || still) return;
      running = true;
      last = 0;
      requestAnimationFrame(frame);
    }

    function stop() {
      running = false;
    }

    if (!still) {
      let pending = null;
      window.addEventListener('resize', () => {
        clearTimeout(pending);
        pending = setTimeout(resize, 120);
      });
      window.addEventListener('pointermove', (ev) => {
        pointer = (ev.clientX / Math.max(1, window.innerWidth)) * 2 - 1;
      });
      document.addEventListener('visibilitychange', () => {
        if (document.hidden) stop();
        else start();
      });
    }

    resize();
    return { setScene, start, stop, resize, get key() { return key; } };
  }

  // วาดภาพนิ่งหนึ่งเฟรมลงบน canvas ขนาดเล็ก ใช้กับการ์ดตัวอย่าง
  function renderStill(canvas, key) {
    const r = createRenderer(canvas, { still: true, maxDpr: 2, view: 1 });
    r.setScene(key, { instant: true });
    return r;
  }

  return { SCENES, STAGE_SCENES, ORIGIN_SCENES, createRenderer, renderStill };
});
