(function () {
  'use strict';

  const E = window.LifeEngine;
  const Art = window.SceneArt;
  const Sound = window.GameSound;
  const SVG_NS = 'http://www.w3.org/2000/svg';
  const ENDINGS_KEY = 'chata.endings';
  const rng = Math.random;

  const STAT_ICONS = {
    health: 'i-health',
    gold: 'i-gold',
    reputation: 'i-rep',
    strength: 'i-str',
    wisdom: 'i-wis',
    charm: 'i-cha',
    luck: 'i-luck',
  };
  const HUD_STATS = ['strength', 'wisdom', 'charm', 'luck', 'gold', 'reputation'];
  const DELTA_ORDER = ['health', ...HUD_STATS];
  const STAGE_LINES = {
    child: 'โลกยังกว้างใหญ่ และทุกสิ่งยังเป็นไปได้',
    youth: 'หัวใจร้อนแรง เส้นทางเริ่มแตกแขนง',
    adult: 'ทุกการตัดสินใจล้วนมีราคาที่ต้องจ่าย',
    elder: 'เวลาที่เหลืออยู่ มีค่ากว่าทองคำ',
  };
  const NAMES = ['อาริน', 'เอลวิน', 'ไคล์', 'ลูน่า', 'เซเรน', 'ธาเลีย', 'โรวัน', 'ไอริส', 'คาเอล', 'มิร่า', 'ซีเอล', 'ราวี', 'นาลา', 'ฟินน์', 'ลีออน', 'ไลรา', 'ดาเรน', 'เอลาร่า', 'ทอริน', 'เวสเปอร์'];

  const ui = document.getElementById('ui');
  const overlay = document.getElementById('overlay');
  const modal = document.getElementById('modal');
  const renderer = Art.createRenderer(document.getElementById('scene'));
  renderer.start();

  let life = null;
  let hud = null;
  let panel = null;

  // ---------- เครื่องมือ ----------

  function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }

  function icon(id, className) {
    const svg = document.createElementNS(SVG_NS, 'svg');
    svg.setAttribute('class', 'icon' + (className ? ' ' + className : ''));
    svg.setAttribute('aria-hidden', 'true');
    const use = document.createElementNS(SVG_NS, 'use');
    use.setAttribute('href', '#' + id);
    svg.append(use);
    return svg;
  }

  function crest(originId, className) {
    const svg = icon('crest-' + originId, className);
    svg.setAttribute('viewBox', '0 0 64 74');
    return svg;
  }

  function ornament() {
    const svg = icon('i-ornament', 'ornament');
    svg.setAttribute('viewBox', '0 0 220 18');
    return svg;
  }

  function corners(target) {
    for (const pos of ['tl', 'tr', 'bl', 'br']) target.append(icon('i-corner', 'corner ' + pos));
  }

  function wait(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  function goldButton(label, onClick) {
    const b = el('button', 'btn-gold', label);
    b.type = 'button';
    b.addEventListener('click', () => {
      Sound.click();
      onClick();
    });
    return b;
  }

  function ghostButton(label, onClick) {
    const b = el('button', 'btn-ghost', label);
    b.type = 'button';
    b.addEventListener('click', () => {
      Sound.click();
      onClick();
    });
    return b;
  }

  function soundButton() {
    const b = el('button', 'icon-btn');
    b.type = 'button';
    const sync = () => {
      b.replaceChildren(icon(Sound.muted ? 'i-sound-off' : 'i-sound-on'));
      b.setAttribute('aria-label', Sound.muted ? 'เปิดเสียง' : 'ปิดเสียง');
    };
    b.addEventListener('click', () => {
      Sound.toggle();
      Sound.click();
      sync();
    });
    sync();
    return b;
  }

  function signed(n) {
    return (n > 0 ? '+' : '') + n;
  }

  function statChip(key, delta) {
    const chip = el('span', 'chip ' + (delta > 0 ? 'up' : 'down'));
    chip.append(icon(STAT_ICONS[key]), document.createTextNode(signed(delta) + ' ' + E.STAT_LABELS[key]));
    return chip;
  }

  function randomName() {
    return NAMES[Math.floor(Math.random() * NAMES.length)];
  }

  function loadEndings() {
    try {
      const raw = JSON.parse(localStorage.getItem(ENDINGS_KEY) || '[]');
      return Array.isArray(raw) ? raw : [];
    } catch (e) {
      return [];
    }
  }

  function saveEndings(list) {
    try {
      localStorage.setItem(ENDINGS_KEY, JSON.stringify(list));
    } catch (e) {
      // บันทึกไม่ได้ก็เล่นต่อได้ตามปกติ
    }
  }

  // แบ่งข้อความเป็นอักขระที่มองเห็น เพื่อไม่ให้สระและวรรณยุกต์ไทยแยกจากพยัญชนะตอนพิมพ์ทีละตัว
  function graphemes(text) {
    if (typeof Intl !== 'undefined' && Intl.Segmenter) {
      return Array.from(new Intl.Segmenter('th', { granularity: 'grapheme' }).segment(text), (s) => s.segment);
    }
    return Array.from(text);
  }

  function typewrite(node, text, host) {
    return new Promise((resolve) => {
      const parts = graphemes(text);
      let i = 0;
      let done = false;
      node.classList.add('typing');
      const finish = () => {
        if (done) return;
        done = true;
        clearInterval(timer);
        host.removeEventListener('click', finish);
        node.textContent = text;
        node.classList.remove('typing');
        resolve();
      };
      const timer = setInterval(() => {
        i += 1;
        node.textContent = parts.slice(0, i).join('');
        if (i >= parts.length) finish();
      }, 26);
      host.addEventListener('click', finish);
    });
  }

  // ---------- หน้าแรก ----------

  function renderTitle() {
    renderer.setScene('title');
    life = null;
    const screen = el('section', 'screen');
    const logo = el('div', 'logo');
    const title = el('h1', 'logo-title');
    title.append(el('span', 'big', 'ชะตา'), el('span', 'small', 'แห่งอาณาจักร'));
    logo.append(el('p', 'logo-kicker', 'เส้นทางชีวิตในดินแดนเวทมนตร์'), title, ornament());

    const unlocked = loadEndings().filter((id) => E.ENDINGS.some((e) => e.id === id)).length;
    const actions = el('div', 'title-actions');
    actions.append(
      goldButton('เริ่มการเดินทาง', () => {
        Sound.startMusic();
        renderCreate();
      }),
      ghostButton('ตอนจบที่ค้นพบ ' + unlocked + ' / ' + E.ENDINGS.length, openEndings),
      el('p', 'credit', 'ทุกการตัดสินใจ จะกลายเป็นตำนานของคุณ')
    );
    const tools = el('div', 'corner-tools');
    tools.append(soundButton());
    screen.append(tools, logo, el('div', 'spacer'), actions);
    ui.replaceChildren(screen);
  }

  // ตอนจบที่ยังไม่ปลดล็อกแสดงเพียงคำใบ้ เพื่อให้รู้ว่ายังมีเส้นทางอะไรรออยู่
  function openEndings() {
    const have = loadEndings();
    const list = el('div', 'modal-list');
    for (const e of E.ENDINGS) {
      const owned = have.includes(e.id);
      const row = el('div', 'title-item' + (owned ? '' : ' locked'));
      const text = el('span', 'title-text');
      text.append(el('strong', null, owned ? e.title : '? ? ?'), el('small', null, 'คำใบ้: ' + e.hint));
      row.append(icon(owned ? 'i-rep' : 'i-gem'), text);
      list.append(row);
    }
    openModal('ตอนจบแห่งตำนาน ' + have.length + ' / ' + E.ENDINGS.length, list);
  }

  function openModal(heading, content) {
    const card = el('div', 'frame modal-card');
    corners(card);
    card.append(el('h2', null, heading), content, ghostButton('ปิด', closeModal));
    modal.replaceChildren(card);
    modal.classList.add('show');
    modal.onclick = (ev) => {
      if (ev.target === modal) closeModal();
    };
  }

  function closeModal() {
    modal.classList.remove('show');
    modal.replaceChildren();
  }

  // ---------- สร้างตัวละคร ----------

  function renderCreate() {
    let selected = null;
    const screen = el('section', 'screen');
    const head = el('div', 'create-head');
    head.append(el('h2', null, 'เลือกต้นกำเนิด'), el('p', null, 'ชีวิตแต่ละแบบเริ่มต้นด้วยพรสวรรค์ที่ต่างกัน'));

    const grid = el('div', 'origins');
    const cards = [];
    E.ORIGINS.forEach((origin, i) => {
      const card = el('button', 'origin-card');
      card.type = 'button';
      card.style.animationDelay = i * 70 + 'ms';
      const canvas = el('canvas');
      const info = el('div', 'origin-info');
      const chips = el('div', 'chips');
      for (const [key, value] of Object.entries(origin.effects)) chips.append(statChip(key, value));
      info.append(el('h3', null, origin.name), el('p', null, origin.desc), chips);
      card.append(canvas, crest(origin.id, 'crest'), info);
      card.addEventListener('click', () => {
        Sound.click();
        selected = origin.id;
        for (const c of cards) c.classList.toggle('selected', c === card);
        renderer.setScene(Art.ORIGIN_SCENES[origin.id]);
        start.disabled = false;
      });
      cards.push(card);
      grid.append(card);
      requestAnimationFrame(() => Art.renderStill(canvas, Art.ORIGIN_SCENES[origin.id]));
    });

    const nameRow = el('div', 'frame name-row');
    const label = el('label', null, 'ชื่อของคุณ');
    const input = el('input');
    input.id = 'hero-name';
    label.htmlFor = 'hero-name';
    input.maxLength = 18;
    input.value = randomName();
    input.autocomplete = 'off';
    const dice = el('button', 'icon-btn');
    dice.type = 'button';
    dice.setAttribute('aria-label', 'สุ่มชื่อ');
    dice.append(icon('i-dice'));
    dice.addEventListener('click', () => {
      Sound.click();
      input.value = randomName();
    });
    nameRow.append(label, input, dice);

    const start = goldButton('เริ่มชีวิต', () => beginLife(selected, input.value.trim() || randomName()));
    start.disabled = true;
    const back = el('button', 'link-btn', 'ย้อนกลับ');
    back.type = 'button';
    back.addEventListener('click', renderTitle);

    screen.append(head, grid, el('div', 'spacer'), nameRow, start, back);
    ui.replaceChildren(screen);
  }

  // ---------- หน้าเล่น ----------

  async function beginLife(originId, name) {
    if (!originId) return;
    life = E.createLife(originId, rng, name);
    const screen = el('section', 'screen game');
    hud = buildHud();
    panel = el('div', 'frame panel');
    screen.append(hud.root, el('div', 'spacer'), panel);
    ui.replaceChildren(screen);
    setPanel([el('p', 'story', life.log[0].text)], 'การเดินทางเริ่มต้น');
    await chapterCard(E.stageOf(life.age));
    liveOn();
  }

  function buildHud() {
    const root = el('header', 'hud');
    const top = el('div', 'hud-top');
    const medal = el('div', 'medallion');
    medal.append(crest(life.origin));
    const who = el('div', 'who');
    const name = el('div', 'name', life.name);
    const meta = el('div', 'meta');
    const meta2 = el('div', 'meta2');
    who.append(name, meta, meta2);
    const logBtn = el('button', 'icon-btn');
    logBtn.type = 'button';
    logBtn.setAttribute('aria-label', 'บันทึกชีวิต');
    logBtn.append(icon('i-scroll'));
    logBtn.addEventListener('click', () => {
      Sound.click();
      openLog();
    });
    top.append(medal, who, logBtn, soundButton());

    const hp = el('div', 'hp');
    const track = el('div', 'hp-track');
    const fill = el('div', 'hp-fill');
    track.append(fill);
    const hpValue = el('span', 'hp-value');
    hp.append(icon('i-health'), track, hpValue);

    const attrs = el('div', 'attrs');
    const cells = {};
    for (const key of HUD_STATS) {
      const cell = el('div', 'attr');
      const value = el('span');
      cell.append(icon(STAT_ICONS[key]), value, el('small', null, E.STAT_LABELS[key]));
      cells[key] = { cell, value };
      attrs.append(cell);
    }
    cells.health = { cell: hp, value: hpValue };
    root.append(top, hp, attrs);

    function update(before) {
      const s = life.stats;
      const stage = E.stageOf(life.age);
      meta.replaceChildren(document.createTextNode('อายุ '), el('b', null, String(life.age)), document.createTextNode(' ปี · ' + stage.name));
      const profile = [life.career ? E.CAREERS[life.career].name : 'ยังไม่มีอาชีพ'];
      if (life.partner) profile.push('มีคู่ชีวิต');
      if (life.children) profile.push('ลูก ' + life.children + ' คน');
      meta2.textContent = profile.join(' · ');
      fill.style.width = s.health + '%';
      hp.classList.toggle('low', s.health < 30);
      hpValue.textContent = s.health + '/100';
      for (const key of HUD_STATS) cells[key].value.textContent = String(s[key]);
      if (!before) return;
      for (const key of DELTA_ORDER) {
        const d = s[key] - before[key];
        if (!d) continue;
        const target = key === 'health' ? hp : cells[key].cell;
        target.classList.remove('bump');
        void target.offsetWidth;
        target.classList.add('bump');
        const f = el('span', 'float ' + (d > 0 ? 'up' : 'down'), signed(d));
        if (key === 'health') f.style.left = '88%';
        target.append(f);
        setTimeout(() => f.remove(), 1500);
      }
    }
    update(null);
    return { root, update };
  }

  function openLog() {
    const list = el('div', 'modal-list');
    for (const entry of life.log) {
      const line = el('div', 'year-line' + (entry.kind === 'death' ? ' death' : ''));
      line.append(el('b', null, 'อายุ ' + entry.age), el('span', null, entry.text));
      list.append(line);
    }
    openModal('บันทึกชีวิตของ ' + life.name, list);
    list.scrollTop = list.scrollHeight;
  }

  function setPanel(children, plaque) {
    const body = el('div', 'body');
    body.append(...children);
    panel.replaceChildren();
    corners(panel);
    if (plaque) panel.append(el('div', 'plaque', plaque));
    panel.append(body);
    panel.classList.add('swap');
    return body;
  }

  // ใช้ชีวิตไปทีละปี จนเจอเหตุการณ์หรือจบชีวิต
  async function liveOn() {
    renderer.setScene(Art.STAGE_SCENES[E.stageOf(life.age).id]);
    const years = el('div', 'years');
    setPanel([years, el('p', 'tap-hint', 'แตะเพื่อเร่งเวลา')], 'กาลเวลาผ่านไป');
    let fast = false;
    const hurry = () => {
      fast = true;
    };
    panel.addEventListener('click', hurry);
    try {
      for (;;) {
        const before = { ...life.stats };
        const prevStage = E.stageOf(life.age).id;
        const step = E.advanceYear(life, rng);
        hud.update(before);
        if (step.type === 'death') {
          addYear(years, life.age, step.cause, 'death');
          await wait(1100);
          endLife();
          return;
        }
        const stage = E.stageOf(life.age);
        if (stage.id !== prevStage) {
          await chapterCard(stage);
          renderer.setScene(Art.STAGE_SCENES[stage.id]);
        }
        if (step.type === 'event') {
          await wait(fast ? 120 : 380);
          showEvent();
          return;
        }
        addYear(years, life.age, step.text);
        Sound.tick();
        await wait(fast ? 90 : 650);
      }
    } finally {
      panel.removeEventListener('click', hurry);
    }
  }

  function addYear(list, age, text, kind) {
    const line = el('div', 'year-line' + (kind ? ' ' + kind : ''));
    line.append(el('b', null, 'อายุ ' + age), el('span', null, text));
    list.append(line);
    const lines = list.children;
    for (let i = 0; i < lines.length - 1; i++) lines[i].classList.add('old');
    while (list.children.length > 5) list.firstChild.remove();
  }

  async function showEvent() {
    const event = life.current;
    renderer.setScene(event.scene);
    Sound.page();
    const story = el('p', 'story');
    const choices = el('div', 'choices');
    setPanel([story, choices], event.title);
    await typewrite(story, event.text, panel);
    event.choices.forEach((choice, index) => {
      const b = choiceButton(choice, index);
      b.style.animationDelay = index * 90 + 'ms';
      choices.append(b);
    });
  }

  function choiceButton(choice, index) {
    const b = el('button', 'choice');
    b.type = 'button';
    const gem = el('span', 'gem');
    gem.append(icon(choice.check ? STAT_ICONS[choice.check.stat] : 'i-gem'));
    const text = el('span', 'choice-text');
    text.append(el('strong', null, choice.label));
    b.append(gem, text);
    if (choice.check) {
      const { stat, dc } = choice.check;
      text.append(el('small', null, 'ทดสอบ' + E.STAT_LABELS[stat] + ' · ต้องทอยได้ ' + dc));
      const pct = Math.round(E.checkChance(life, stat, dc) * 100);
      const badge = el('span', 'chance ' + (pct >= 65 ? 'good' : pct >= 40 ? 'mid' : 'bad'), pct + '%');
      badge.append(el('small', null, 'โอกาส'));
      b.append(badge);
    }
    const allowed = E.canChoose(life, choice);
    if (!allowed.ok) {
      b.disabled = true;
      b.classList.add('locked');
      text.append(el('small', 'need', '🔒 ' + allowed.reason));
    }
    b.addEventListener('click', () => {
      Sound.click();
      for (const other of b.parentNode.children) other.disabled = true;
      b.classList.add('picked');
      resolveChoice(index);
    });
    return b;
  }

  async function resolveChoice(index) {
    const title = life.current.title;
    const before = { ...life.stats };
    const outcome = E.chooseOption(life, index, rng);
    if (outcome.check) await diceRoll(outcome.check);
    hud.update(before);
    Sound.page();
    const body = [];
    if (outcome.check) {
      const c = outcome.check;
      body.push(el('p', 'verdict ' + (c.success ? 'ok' : 'bad'), c.success ? 'สำเร็จ!' : 'ล้มเหลว'));
      body.push(el('p', 'roll-line', 'ทอยได้ ' + c.roll + ' + โบนัส ' + c.bonus + ' = ' + c.total + ' (ต้องได้ ' + c.dc + ')'));
    }
    const story = el('p', 'story', outcome.result);
    body.push(story);
    const deltas = el('div', 'delta-row');
    DELTA_ORDER.forEach((key, i) => {
      const d = life.stats[key] - before[key];
      if (!d) return;
      const chip = statChip(key, d);
      chip.style.animationDelay = 200 + i * 80 + 'ms';
      deltas.append(chip);
    });
    if (deltas.childNodes.length) body.push(deltas);
    if (outcome.over && life.cause !== outcome.result) body.push(el('p', 'death-line', life.cause));
    const next = goldButton(outcome.over ? 'บทสุดท้าย' : 'ใช้ชีวิตต่อไป', () => {
      next.disabled = true;
      if (outcome.over) endLife();
      else liveOn();
    });
    body.push(next);
    setPanel(body, title);
  }

  // ---------- ชั้นซ้อน ----------

  function chapterCard(stage) {
    return new Promise((resolve) => {
      Sound.chime();
      const card = el('div', 'chapter');
      card.append(el('p', 'chapter-num', 'บทที่ ' + stage.numeral), el('h2', 'chapter-name', stage.name), ornament(), el('p', 'chapter-line', STAGE_LINES[stage.id]));
      overlay.replaceChildren(card);
      overlay.classList.add('show');
      let done = false;
      const finish = () => {
        if (done) return;
        done = true;
        card.classList.add('leave');
        setTimeout(() => {
          overlay.classList.remove('show');
          overlay.replaceChildren();
          overlay.onclick = null;
          resolve();
        }, 450);
      };
      overlay.onclick = finish;
      setTimeout(finish, 2600);
    });
  }

  const D20 = `<svg viewBox="0 0 100 100" class="d20" aria-hidden="true">
    <g stroke="#f2cf7e" stroke-width="1.2" stroke-linejoin="round">
      <polygon points="50,4 90,27 50,22" fill="url(#g-d20c)"/>
      <polygon points="50,4 50,22 10,27" fill="url(#g-d20a)"/>
      <polygon points="10,27 50,22 22,66" fill="url(#g-d20b)"/>
      <polygon points="10,27 22,66 10,73" fill="#22124e"/>
      <polygon points="90,27 78,66 50,22" fill="url(#g-d20a)"/>
      <polygon points="90,27 90,73 78,66" fill="#2e1a66"/>
      <polygon points="10,73 22,66 50,96" fill="#1a0e3e"/>
      <polygon points="22,66 78,66 50,96" fill="url(#g-d20b)"/>
      <polygon points="78,66 90,73 50,96" fill="#22124e"/>
      <polygon points="50,22 78,66 22,66" fill="url(#g-d20c)"/>
    </g>
    <text class="num" x="50" y="58" text-anchor="middle">20</text>
  </svg>`;

  function diceRoll(check) {
    return new Promise((resolve) => {
      const wrap = el('div', 'dice-wrap');
      wrap.append(el('p', 'dice-info', 'ทดสอบ' + E.STAT_LABELS[check.stat] + ' · ต้องได้ ' + check.dc));
      const holder = el('div');
      holder.innerHTML = D20;
      const die = holder.firstElementChild;
      const num = die.querySelector('.num');
      const total = el('p', 'dice-total');
      const stamp = el('div', 'stamp');
      wrap.append(die, total, stamp);
      overlay.replaceChildren(wrap);
      overlay.classList.add('show');
      Sound.dice();
      let landed = false;
      let done = false;
      const spin = setInterval(() => {
        num.textContent = String(1 + Math.floor(Math.random() * 20));
      }, 55);
      const finish = () => {
        if (done || !landed) return;
        done = true;
        overlay.classList.remove('show');
        overlay.replaceChildren();
        overlay.onclick = null;
        resolve();
      };
      setTimeout(() => {
        clearInterval(spin);
        landed = true;
        num.textContent = String(check.roll);
        die.classList.add('landed');
        total.textContent = 'ทอยได้ ' + check.roll + ' + โบนัส ' + check.bonus + ' = ' + check.total;
        stamp.textContent = check.success ? 'สำเร็จ!' : 'ล้มเหลว';
        stamp.classList.add(check.success ? 'ok' : 'bad', 'show');
        if (check.success) Sound.success();
        else Sound.fail();
        setTimeout(finish, 1500);
      }, 1150);
      overlay.onclick = finish;
    });
  }

  // ---------- จบชีวิต ----------

  async function endLife() {
    const summary = E.summarize(life);
    const found = loadEndings();
    const isNew = !found.includes(summary.ending);
    if (isNew) {
      found.push(summary.ending);
      saveEndings(found);
    }
    Sound.toll();
    renderer.setScene(summary.scene);
    await wait(500);

    const scroll = el('div', 'scroll');
    scroll.append(el('p', 'epitaph-kicker', 'ณ ที่แห่งนี้ ขอไว้อาลัยแด่'), el('h1', 'epitaph-name', summary.name));
    const ribbon = el('div', 'ribbon', summary.title);
    scroll.append(ribbon);
    if (isNew) scroll.append(el('p', 'new-title', 'ค้นพบตอนจบใหม่! (' + found.length + ' / ' + E.ENDINGS.length + ')'));
    const profile = [summary.career || 'ไม่มีอาชีพ', summary.partner ? 'มีคู่ชีวิต' : 'ไร้คู่ครอง'];
    if (summary.children) profile.push('ลูก ' + summary.children + ' คน');
    scroll.append(
      el('p', 'ending-text', summary.text),
      el('p', 'epitaph-age', 'สิริอายุ ' + summary.age + ' ปี'),
      el('p', 'epitaph-profile', profile.join(' · ')),
      el('p', 'epitaph-cause', summary.cause)
    );
    const stats = el('div', 'end-stats');
    for (const key of HUD_STATS) {
      const cell = el('div');
      cell.append(icon(STAT_ICONS[key]), el('b', null, String(summary.stats[key])), document.createTextNode(E.STAT_LABELS[key]));
      stats.append(cell);
    }
    const yearsCell = el('div');
    yearsCell.append(icon('i-scroll'), el('b', null, String(life.log.filter((e) => e.kind === 'event').length)), document.createTextNode('เหตุการณ์'));
    stats.append(yearsCell);
    scroll.append(stats);
    const moments = life.log.filter((e) => e.kind === 'event');
    if (moments.length) {
      scroll.append(el('p', 'moments-title', 'เรื่องราวที่ถูกจารึก'));
      const list = el('ul', 'moments');
      for (const m of moments) {
        const li = el('li');
        li.append(el('b', null, 'อายุ ' + m.age), el('span', null, m.text));
        list.append(li);
      }
      scroll.append(list);
    }

    const actions = el('div', 'end-actions');
    actions.append(goldButton('เริ่มชีวิตใหม่', renderCreate), ghostButton('กลับหน้าแรก', renderTitle));
    const screen = el('section', 'screen');
    screen.append(scroll, actions);
    ui.replaceChildren(screen);
    ui.scrollTop = 0;
  }

  renderTitle();
})();
