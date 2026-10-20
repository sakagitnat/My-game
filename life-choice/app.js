(function () {
  'use strict';

  const E = window.LifeEngine;
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

  function statCell(label, value) {
    const cell = el('div');
    cell.append(document.createTextNode(label + ' '), el('b', null, String(value)));
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
    const intro = [
      el('h1', null, 'ชะตาแห่งอาณาจักร'),
      el('p', 'subtitle', 'เลือกจุดเริ่มต้นของชีวิต แล้วตัดสินใจทุกปีตั้งแต่วัยเยาว์จนถึงบั้นปลาย'),
    ];
    const origins = E.ORIGINS.map((origin) => {
      const node = el('button', 'origin');
      node.type = 'button';
      node.append(el('strong', null, origin.name), el('span', null, origin.desc));
      node.addEventListener('click', () => startLife(origin.id));
      return node;
    });
    render([...intro, ...origins]);
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
    card.append(el('div', 'hint', 'สุขภาพ ' + s.health + ' / 100'), healthBar(s.health));
    const grid = el('div', 'stats');
    grid.append(
      statCell(E.STAT_LABELS.strength, s.strength),
      statCell(E.STAT_LABELS.wisdom, s.wisdom),
      statCell(E.STAT_LABELS.charm, s.charm),
      statCell(E.STAT_LABELS.luck, s.luck),
      statCell(E.STAT_LABELS.gold, s.gold),
      statCell(E.STAT_LABELS.reputation, s.reputation)
    );
    card.append(grid);
    return card;
  }

  function eventCard() {
    const card = el('div', 'card');
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
        card.append(el('p', 'roll', 'ทอย d20 ได้ ' + check.roll + ' + โบนัส ' + check.bonus + ' = ' + check.total + ' (ต้องได้ ' + check.dc + ' ขึ้นไป)'));
      }
      card.append(el('p', 'result', view.text));
    } else if (view && view.kind === 'quiet') {
      card.append(el('p', 'result', view.text));
    }
    card.append(button('btn primary', 'ปีถัดไป', advance));
    return card;
  }

  function renderGame() {
    const children = [
      el('h1', null, 'ชะตาแห่งอาณาจักร'),
      el('p', 'year', 'อายุ ' + life.age + ' ปี'),
      renderStatsCard(),
      life.current ? eventCard() : continueCard(),
      logCard(life.log.slice(-6)),
    ];
    render(children);
  }

  function renderEnd() {
    const summary = E.summarize(life);
    const statsCard = el('div', 'card');
    const grid = el('div', 'stats');
    for (const key of Object.keys(E.STAT_LABELS)) {
      grid.append(statCell(E.STAT_LABELS[key], summary.stats[key]));
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
      el('h1', null, 'จบชีวิตแล้ว'),
      el('p', 'title', summary.title),
      el('p', null, 'คุณมีชีวิตอยู่รวม ' + summary.age + ' ปี'),
      el('p', 'hint', summary.cause),
      statsCard,
      fullLog,
      button('btn primary', 'เริ่มชีวิตใหม่', renderStart),
    ]);
  }

  renderStart();
})();
