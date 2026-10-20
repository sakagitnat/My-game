(function () {
  'use strict';

  const E = window.LifeEngine;
  const A = window.LifeArt;
  const app = document.getElementById('app');
  const rng = Math.random;

  let life = null;
  // ผลที่ต้องแสดงก่อนปีถัดไป: { kind: 'result', text, check } หรือ { kind: 'quiet', text }
  let view = null;

  function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }

  // ใช้เฉพาะกับ SVG ที่ฝังอยู่ในไฟล์ art.js เท่านั้น ไม่รับข้อความจากผู้เล่น
  function svgNode(markup) {
    const holder = el('div');
    holder.innerHTML = markup;
    return holder.firstElementChild;
  }

  function button(className, label, onClick) {
    const node = el('button', className);
    node.type = 'button';
    node.append(document.createTextNode(label));
    node.addEventListener('click', onClick);
    return node;
  }

  function render(children) {
    app.replaceChildren(...children);
  }

  function header() {
    const wrap = el('div');
    wrap.append(el('h1', null, 'ชะตาแห่งอาณาจักร'), svgNode(A.ORNAMENT));
    return wrap;
  }

  function sceneBanner(age) {
    const stage = A.stageOf(age);
    const scene = el('div', 'scene');
    scene.append(svgNode(A.sceneSvg(stage)), el('span', 'scene-label', A.STAGE_TITLES[stage]));
    return scene;
  }

  function statCell(key, value) {
    const cell = el('div');
    cell.append(svgNode(A.statIcon(key)), document.createTextNode(E.STAT_LABELS[key] + ' '), el('b', null, String(value)));
    return cell;
  }

  function healthBar(health) {
    const wrap = el('div', 'bar');
    const fill = el('i');
    fill.style.width = health + '%';
    if (health < 30) fill.className = 'low';
    wrap.append(fill);
    return wrap;
  }

  function logCard(entries) {
    const card = el('div', 'card');
    const list = el('div', 'log');
    for (const entry of entries) {
      const line = el('p');
      line.append(el('b', null, 'อายุ ' + entry.age), document.createTextNode(entry.text));
      list.append(line);
    }
    card.append(el('h2', null, 'บันทึกชีวิต'), list);
    return card;
  }

  function renderStart() {
    life = null;
    view = null;
    const intro = el('p', 'subtitle', 'เลือกจุดเริ่มต้นของชีวิต แล้วตัดสินใจทุกปีตั้งแต่วัยเยาว์จนถึงบั้นปลาย');
    const origins = E.ORIGINS.map((origin) => {
      const node = el('button', 'origin');
      node.type = 'button';
      const text = el('div');
      text.append(el('strong', null, origin.name), el('span', null, origin.desc));
      node.append(svgNode(A.originIcon(origin.id)), text);
      node.addEventListener('click', () => startLife(origin.id));
      return node;
    });
    render([header(), intro, ...origins]);
  }

  function startLife(originId) {
    life = E.createLife(originId, rng);
    advance();
  }

  function advance() {
    const step = E.advanceYear(life, rng);
    if (step.type === 'death') {
      renderEnd();
      return;
    }
    view = step.type === 'quiet' ? { kind: 'quiet', text: step.text } : null;
    renderGame();
  }

  function choose(index) {
    const outcome = E.chooseOption(life, index, rng);
    view = { kind: 'result', text: outcome.result, check: outcome.check };
    renderGame();
  }

  function renderStatsCard() {
    const s = life.stats;
    const card = el('div', 'card');
    card.append(el('div', 'hint', E.STAT_LABELS.health + ' ' + s.health + ' / 100'), healthBar(s.health));
    const grid = el('div', 'stats');
    grid.append(
      statCell('strength', s.strength),
      statCell('wisdom', s.wisdom),
      statCell('charm', s.charm),
      statCell('luck', s.luck),
      statCell('gold', s.gold),
      statCell('reputation', s.reputation)
    );
    card.append(grid);
    return card;
  }

  function eventCard() {
    const card = el('div', 'card parchment');
    card.append(el('h2', null, 'เกิดขึ้นกับคุณ'), el('p', null, life.current.text));
    life.current.choices.forEach((choice, index) => {
      const node = button('btn', choice.label, () => choose(index));
      if (choice.check) {
        const label = E.STAT_LABELS[choice.check.stat];
        node.append(el('small', null, 'ทดสอบ' + label + ' DC ' + choice.check.dc));
      }
      card.append(node);
    });
    return card;
  }

  function continueCard() {
    const card = el('div', 'card');
    if (view && view.kind === 'result') {
      const check = view.check;
      if (check) {
        const roll = el('div', 'roll');
        roll.append(
          svgNode(A.diceSvg()),
          el('span', null, 'ทอยได้ ' + check.roll + ' + โบนัส ' + check.bonus + ' = ' + check.total + ' (ต้องได้ ' + check.dc + ')')
        );
        card.append(roll, el('p', check.success ? 'pass' : 'fail', check.success ? 'ผ่านการทดสอบ' : 'ไม่ผ่านการทดสอบ'));
      }
      card.append(el('p', 'result', view.text));
    } else if (view && view.kind === 'quiet') {
      card.append(el('p', 'result', view.text));
    }
    card.append(button('btn primary', 'ปีถัดไป', advance));
    return card;
  }

  function renderGame() {
    render([
      sceneBanner(life.age),
      el('p', 'year', 'อายุ ' + life.age + ' ปี'),
      renderStatsCard(),
      life.current ? eventCard() : continueCard(),
      logCard(life.log.slice(-6)),
    ]);
  }

  function renderEnd() {
    const summary = E.summarize(life);
    const statsCard = el('div', 'card');
    const grid = el('div', 'stats');
    for (const key of Object.keys(E.STAT_LABELS)) {
      grid.append(statCell(key, summary.stats[key]));
    }
    statsCard.append(grid);

    const fullLog = el('details', 'card');
    fullLog.append(el('summary', null, 'ดูบันทึกชีวิตทั้งหมด'));
    const list = el('div', 'log');
    for (const entry of life.log) {
      const line = el('p');
      line.append(el('b', null, 'อายุ ' + entry.age), document.createTextNode(entry.text));
      list.append(line);
    }
    fullLog.append(list);

    render([
      sceneBanner(summary.age),
      el('h1', null, 'จบชีวิตแล้ว'),
      svgNode(A.ORNAMENT),
      el('p', 'title', summary.title),
      el('p', 'end-ending', 'คุณมีชีวิตอยู่รวม ' + summary.age + ' ปี · ' + summary.cause),
      statsCard,
      fullLog,
      button('btn primary', 'เริ่มชีวิตใหม่', renderStart),
    ]);
  }

  renderStart();
})();
