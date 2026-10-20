const assert = require('node:assert/strict');
const test = require('node:test');
const E = require('./engine.js');

// rng ที่คืนค่าตามลำดับที่กำหนด วนซ้ำเมื่อหมด
function sequence(values) {
  let i = 0;
  return () => values[i++ % values.length];
}

test('ทุกเหตุการณ์มีตัวเลือกอย่างน้อยสองทาง และแต่ละทางมีข้อความผลลัพธ์', () => {
  for (const event of E.EVENTS) {
    assert.ok(event.choices.length >= 2, event.id + ' needs at least two choices');
    for (const choice of event.choices) {
      if (choice.check) {
        assert.ok(choice.check.pass.result && choice.check.fail.result, event.id + ' check needs both results');
      } else {
        assert.ok(choice.result, event.id + ' choice needs a result');
      }
    }
  }
});

test('รหัสเหตุการณ์ไม่ซ้ำกัน และช่วงอายุสมเหตุสมผล', () => {
  const ids = E.EVENTS.map((e) => e.id);
  assert.equal(new Set(ids).size, ids.length);
  for (const event of E.EVENTS) assert.ok(event.minAge <= event.maxAge);
});

test('สร้างชีวิตจากอาชีพเริ่มต้นและรวมโบนัสของอาชีพ', () => {
  const life = E.createLife('merchant', () => 0);
  assert.equal(life.age, E.START_AGE);
  assert.equal(life.stats.gold, 60);
  assert.equal(life.stats.charm, 4);
  assert.equal(life.stats.luck, 3);
  assert.equal(life.log.length, 1);
  assert.throws(() => E.createLife('unknown'), /unknown origin/);
});

test('การทดสอบทอยเต๋า d20 บวกโบนัสจากค่าสถานะและโชค', () => {
  const life = E.createLife('warrior', () => 0);
  life.stats.strength = 8; // โบนัส 4
  life.stats.luck = 6; // โบนัส 2
  const check = E.rollCheck(life, 'strength', 10, sequence([0.5])); // roll 11
  assert.equal(check.roll, 11);
  assert.equal(check.total, 17);
  assert.equal(check.success, true);
  const fail = E.rollCheck(life, 'strength', 20, sequence([0])); // roll 1
  assert.equal(fail.success, false);
});

test('เลือกตัวเลือกที่ไม่มีการทดสอบจะใช้ผลทันที', () => {
  const life = E.createLife('warrior', () => 0);
  const before = life.stats.gold;
  // เลือกเหตุการณ์แรกที่ตรงอายุ โดยให้ rng ผ่านเกณฑ์เหตุการณ์
  life.age = 5;
  const step = E.advanceYear(life, sequence([0.1, 0.0]));
  assert.equal(step.type, 'event');
  const choiceIndex = step.event.choices.findIndex((c) => !c.check);
  const result = E.chooseOption(life, choiceIndex, () => 0);
  assert.equal(result.check, null);
  assert.equal(life.current, null);
  assert.equal(life.stats.gold, before + (step.event.choices[choiceIndex].effects.gold ?? 0));
});

test('ผลของการทดสอบเลือกกิ่งผ่านหรือไม่ผ่าน', () => {
  const event = {
    id: 'test_event',
    minAge: 0,
    maxAge: 100,
    text: 'ทดสอบ',
    choices: [
      {
        label: 'ลอง',
        check: {
          stat: 'wisdom',
          dc: 10,
          pass: { result: 'ผ่าน', effects: { gold: 5 } },
          fail: { result: 'ไม่ผ่าน', effects: { health: -5 } },
        },
      },
    ],
  };
  const life = E.createLife('mage', () => 0);
  life.stats.wisdom = 0;
  life.current = event;
  const failed = E.chooseOption(life, 0, sequence([0])); // roll 1 + 0 โบนัส
  assert.equal(failed.result, 'ไม่ผ่าน');
  assert.equal(life.stats.health, 60 - 5 - 5); // ค่าเริ่มของศิษย์เวทย์ลด 5 แล้วผลที่ไม่ผ่านลดอีก 5
});

test('ค่าสุขภาพไม่ต่ำกว่า 0 และไม่สูงกว่า 100 และทองไม่ติดลบ', () => {
  const life = E.createLife('warrior', () => 0);
  life.stats.health = 95;
  life.stats.gold = 5;
  life.current = { id: 'x', choices: [{ label: 'a', effects: { health: 50, gold: -100 }, result: 'r' }] };
  E.chooseOption(life, 0, () => 0);
  assert.equal(life.stats.health, 100);
  assert.equal(life.stats.gold, 0);
});

test('ปีที่สุขภาพหมดจะจบชีวิต และหลังจบแล้วไม่ขยับต่อ', () => {
  const life = E.createLife('wanderer', () => 0);
  life.age = 44; // อายุ 45 ปีโดนหักสุขภาพ 1 ทำให้สุขภาพต่ำกว่า 0
  life.stats.health = 0;
  const step = E.advanceYear(life, () => 0.99);
  assert.equal(step.type, 'death');
  assert.equal(life.over, true);
  assert.equal(E.advanceYear(life, () => 0.99).type, 'death');
  const summary = E.summarize(life);
  assert.equal(summary.age, 45);
  assert.ok(summary.cause);
});

test('อายุครบ 100 ปีจะจบชีวิตอย่างสงบ', () => {
  const life = E.createLife('warrior', () => 0);
  life.age = E.MAX_AGE - 1;
  life.stats.health = 100;
  const step = E.advanceYear(life, () => 0.99);
  assert.equal(step.type, 'death');
  assert.equal(life.age, E.MAX_AGE);
});

test('เหตุการณ์ที่ไม่ใช่แบบซ้ำได้ ไม่ถูกเล่นซ้ำ และไม่เกิดนอกช่วงอายุ', () => {
  const life = E.createLife('warrior', () => 0);
  const seen = new Set();
  for (let i = 0; i < 95 && !life.over; i++) {
    const step = E.advanceYear(life, sequence([0.1, 0.9, 0.3]));
    if (step.type === 'event') {
      if (!step.event.repeatable) assert.ok(!seen.has(step.event.id), 'repeated ' + step.event.id);
      assert.ok(life.age >= step.event.minAge && life.age <= step.event.maxAge);
      seen.add(step.event.id);
      const pick = step.event.choices.findIndex((c) => E.canChoose(life, c).ok);
      E.chooseOption(life, pick, () => 0.99);
    }
  }
  assert.ok(seen.size > 3);
});

test('ต้องเลือกเหตุการณ์ก่อนจึงจะขยับปีต่อได้ และเลือกตัวเลือกที่ไม่มีอยู่ไม่ได้', () => {
  const life = E.createLife('warrior', () => 0);
  assert.throws(() => E.chooseOption(life, 0), /no pending event/);
  life.current = E.EVENTS[0];
  assert.throws(() => E.chooseOption(life, 99), /invalid choice/);
  const step = E.advanceYear(life, () => 0.99);
  assert.equal(step.type, 'event');
  assert.equal(step.event, E.EVENTS[0]);
});

test('ตอนจบตามค่าสถานะ เลือกจากค่าที่โดดเด่นตามลำดับ', () => {
  const life = E.createLife('merchant', () => 0);
  life.age = 50;
  life.stats.gold = 400;
  assert.equal(E.summarize(life).ending, 'rich');
  life.stats.gold = 0;
  life.stats.wisdom = 18;
  assert.equal(E.summarize(life).ending, 'sage');
  life.stats.wisdom = 2;
  assert.equal(E.summarize(life).ending, 'villager');
  assert.match(E.summarize(life).text, /ผู้ไร้นาม/);
});

console.log('engine tests done');

test('โอกาสผ่านการทดสอบตรงกับการทอย d20 ทุกหน้า', () => {
  const life = E.createLife('warrior', () => 0);
  life.stats.wisdom = 4; // โบนัส 2
  life.stats.luck = 3; // โบนัส 1
  // ต้องทอยได้อย่างน้อย 10 - 3 = 7 คือ 14 หน้าจาก 20
  assert.equal(E.checkChance(life, 'wisdom', 10), 14 / 20);
  assert.equal(E.checkChance(life, 'wisdom', 1), 1);
  assert.equal(E.checkChance(life, 'wisdom', 40), 0);
  // นับจากการทอยจริงทุกหน้าแล้วต้องได้ค่าเดียวกัน
  let pass = 0;
  for (let face = 0; face < 20; face++) {
    if (E.rollCheck(life, 'wisdom', 10, () => face / 20).success) pass++;
  }
  assert.equal(pass / 20, E.checkChance(life, 'wisdom', 10));
});

test('ช่วงวัยแบ่งตามอายุ และเหตุการณ์ทุกอันมีชื่อเรื่อง', () => {
  assert.equal(E.stageOf(5).id, 'child');
  assert.equal(E.stageOf(13).id, 'youth');
  assert.equal(E.stageOf(18).id, 'adult');
  assert.equal(E.stageOf(60).id, 'elder');
  for (const event of E.EVENTS) assert.ok(event.title, event.id + ' needs a title');
});

test('ชื่อตัวละครและชนิดของบันทึก', () => {
  const life = E.createLife('mage', () => 0, 'ไลรา');
  assert.equal(life.name, 'ไลรา');
  assert.equal(E.createLife('mage', () => 0).name, 'ผู้ไร้นาม');
  assert.equal(life.log[0].kind, 'birth');
  life.current = E.EVENTS[0];
  E.chooseOption(life, 2, () => 0);
  assert.equal(life.log.at(-1).kind, 'event');
  assert.equal(E.summarize(life).name, 'ไลรา');
});

test('ตอนจบมีรหัสไม่ซ้ำ ข้อความ คำใบ้ และตอนจบสุดท้ายรับทุกกรณี', () => {
  const ids = E.ENDINGS.map((e) => e.id);
  assert.equal(new Set(ids).size, ids.length);
  for (const e of E.ENDINGS) {
    assert.ok(e.title && e.text && e.hint, e.id);
    assert.ok(e.forced || typeof e.test === 'function', e.id);
  }
  const last = E.ENDINGS[E.ENDINGS.length - 1];
  assert.equal(last.test({}), true);
  assert.ok(E.ENDINGS.length >= 25);
});

test('ทุกเหตุการณ์ วัย และต้นกำเนิด ชี้ไปที่ฉากที่มีอยู่จริง', () => {
  const Art = require('./scene.js');
  for (const event of E.EVENTS) assert.ok(Art.SCENES[event.scene], event.id + ' -> ' + event.scene);
  for (const stage of E.STAGES) assert.ok(Art.SCENES[Art.STAGE_SCENES[stage.id]], stage.id);
  for (const origin of E.ORIGINS) assert.ok(Art.SCENES[Art.ORIGIN_SCENES[origin.id]], origin.id);
  assert.ok(Art.SCENES.title && Art.SCENES.ending);
});

// ---------- ระบบเส้นเรื่อง อาชีพ ครอบครัว และตอนจบ ----------

function at(life, eventId) {
  const event = E.EVENTS.find((e) => e.id === eventId);
  life.current = event;
  return event;
}

test('ข้อมูลเนื้อเรื่องเชื่อมกันครบ: ธงที่ถูกใช้ต้องมีที่มา อาชีพและตอนจบที่อ้างถึงต้องมีอยู่จริง', () => {
  const setFlags = new Set();
  const outcomes = [];
  for (const e of E.EVENTS) {
    for (const c of e.choices) {
      outcomes.push(c);
      if (c.check) outcomes.push(c.check.pass, c.check.fail);
    }
  }
  for (const o of outcomes) for (const f of o.set || []) setFlags.add(f);
  for (const e of E.EVENTS) {
    const w = e.when || {};
    for (const f of [...(w.flags || []), ...(w.anyFlags || []), ...(w.notFlags || [])]) assert.ok(setFlags.has(f), e.id + ' needs flag ' + f + ' that nothing sets');
    for (const c of [].concat(w.career ?? [], w.notCareer ?? [])) if (c !== null) assert.ok(E.CAREERS[c], e.id + ' career ' + c);
  }
  for (const o of outcomes) {
    if (o.career) assert.ok(E.CAREERS[o.career], 'career ' + o.career);
    if (o.ending) assert.ok(E.ENDINGS.find((x) => x.id === o.ending && x.forced), 'ending ' + o.ending);
    if (o.die) assert.ok(o.die.cause && o.die.tag);
  }
  // ตอนจบที่บังคับด้วยเหตุการณ์ ต้องมีเหตุการณ์ที่พาไปถึง
  for (const ending of E.ENDINGS.filter((x) => x.forced)) assert.ok(outcomes.some((o) => o.ending === ending.id), ending.id + ' unreachable');
});

test('เส้นเรื่องมังกร: ช่วยมังกรตอนเด็ก ทำให้มังกรกลับมาหาและได้ขี่มังกร', () => {
  const life = E.createLife('warrior', () => 0);
  at(life, 'dragon_hatchling');
  E.chooseOption(life, 0, () => 0);
  assert.ok(life.flags.dragon_friend);
  const returnEvent = E.EVENTS.find((e) => e.id === 'dragon_return');
  life.age = 30;
  assert.equal(E.isEligible(life, returnEvent), true);
  at(life, 'dragon_return');
  E.chooseOption(life, 0, () => 0);
  assert.equal(life.career, 'dragonrider');
  // ชนะศึกเหนือเมฆาจะได้ตอนจบพิเศษทันที
  life.stats.strength = 20;
  at(life, 'dragon_war');
  const out = E.chooseOption(life, 0, () => 0.99);
  assert.equal(out.over, true);
  assert.equal(E.summarize(life).ending, 'dragon_legend');
});

test('เหตุการณ์ที่ต้องมีเงื่อนไข จะไม่เกิดถ้ายังไม่ถึงเงื่อนไข', () => {
  const life = E.createLife('warrior', () => 0);
  life.age = 30;
  const returnEvent = E.EVENTS.find((e) => e.id === 'dragon_return');
  assert.equal(E.isEligible(life, returnEvent), false);
  const kingRule = E.EVENTS.find((e) => e.id === 'king_rule');
  assert.equal(E.isEligible(life, kingRule), false);
  life.career = 'king';
  assert.equal(E.isEligible(life, kingRule), true);
});

test('ตัวเลือกที่ต้องใช้ทองจะเลือกไม่ได้เมื่อเงินไม่พอ และบอกเหตุผล', () => {
  const life = E.createLife('wanderer', () => 0);
  life.age = 25;
  const event = at(life, 'adult_wizard_school');
  const status = E.canChoose(life, event.choices[0]);
  assert.equal(status.ok, false);
  assert.match(status.reason, /ทอง 40/);
  assert.throws(() => E.chooseOption(life, 0), /not available/);
  life.stats.gold = 50;
  E.chooseOption(life, 0, () => 0);
  assert.equal(life.career, 'mage');
  assert.equal(life.stats.gold, 10);
});

test('อาชีพให้รายได้ในปีที่สงบ', () => {
  const life = E.createLife('warrior', () => 0);
  life.age = 30;
  life.career = 'merchant';
  life.seen = E.EVENTS.map((e) => e.id);
  const before = life.stats.gold;
  // ไม่มีเหตุการณ์ (0.9 ไม่ผ่านเกณฑ์) แล้วโยนเข้าปีของอาชีพ (0.1)
  const step = E.advanceYear(life, sequence([0.9, 0.1]));
  assert.equal(step.type, 'quiet');
  assert.equal(step.text, E.CAREERS.merchant.quiet);
  assert.equal(life.stats.gold, before + E.CAREERS.merchant.yearly.gold);
});

test('ครอบครัว: แต่งงานแล้วมีลูกได้ไม่เกินสามคน', () => {
  const life = E.createLife('warrior', () => 0);
  life.age = 25;
  at(life, 'adult_marriage');
  E.chooseOption(life, 0, () => 0);
  assert.equal(life.partner, true);
  const born = E.EVENTS.find((e) => e.id === 'child_born');
  for (let i = 0; i < 3; i++) {
    life.lastSeen = {};
    assert.equal(E.isEligible(life, born), true);
    at(life, 'child_born');
    E.chooseOption(life, 0, () => 0);
  }
  assert.equal(life.children, 3);
  life.lastSeen = {};
  assert.equal(E.isEligible(life, born), false);
});

test('เหตุการณ์ที่เกิดซ้ำได้ ต้องเว้นช่วงตามที่กำหนด', () => {
  const life = E.createLife('warrior', () => 0);
  const fair = E.EVENTS.find((e) => e.id === 'market_fair');
  life.age = 20;
  life.lastSeen.market_fair = 18;
  assert.equal(E.isEligible(life, fair), false);
  life.age = 18 + fair.cooldown;
  assert.equal(E.isEligible(life, fair), true);
});

test('ความตายจากเหตุการณ์ใช้ตอนจบตามสาเหตุ', () => {
  const life = E.createLife('warrior', () => 0);
  life.age = 40;
  life.career = 'knight';
  life.stats.strength = 0;
  life.stats.luck = 0;
  at(life, 'knight_coup');
  const out = E.chooseOption(life, 0, () => 0);
  assert.equal(out.over, true);
  assert.equal(life.deathTag, 'executed');
  assert.equal(E.summarize(life).ending, 'executed');
});

test('บาดเจ็บจนสุขภาพหมดในเหตุการณ์ ทำให้ตายทันที', () => {
  const life = E.createLife('warrior', () => 0);
  life.age = 30;
  life.stats.health = 10;
  life.stats.strength = 0;
  life.stats.luck = 0;
  at(life, 'adult_mine');
  const out = E.chooseOption(life, 0, () => 0);
  assert.equal(out.over, true);
  assert.equal(life.deathTag, 'wounds');
});

test('ตอนจบตามเส้นทางชีวิตมาก่อนตอนจบตามค่าสถานะ', () => {
  const life = E.createLife('merchant', () => 0);
  life.age = 70;
  life.stats.gold = 999;
  life.flags.king = true;
  assert.equal(E.summarize(life).ending, 'good_king');
  life.flags.tyrant = true;
  assert.equal(E.summarize(life).ending, 'tyrant');
  const young = E.createLife('mage', () => 0);
  young.age = 20;
  young.flags.king = true;
  assert.equal(E.summarize(young).ending, 'died_young');
});

test('ทุกตอนจบชี้ไปที่ฉากที่มีอยู่จริง', () => {
  const Art = require('./scene.js');
  for (const ending of E.ENDINGS) assert.ok(Art.SCENES[ending.scene], ending.id + ' -> ' + ending.scene);
});

test('เล่นสุ่มหลายร้อยชีวิตจนจบได้เสมอ และได้ตอนจบหลากหลาย', () => {
  let seed = 7;
  const rng = () => {
    seed = (seed * 16807) % 2147483647;
    return (seed - 1) / 2147483646;
  };
  const endings = new Set();
  for (let run = 0; run < 400; run++) {
    const origin = E.ORIGINS[run % E.ORIGINS.length].id;
    const life = E.createLife(origin, rng);
    for (let guard = 0; guard < 200 && !life.over; guard++) {
      const step = E.advanceYear(life, rng);
      if (step.type === 'event') {
        const open = step.event.choices.map((c, i) => i).filter((i) => E.canChoose(life, step.event.choices[i]).ok);
        E.chooseOption(life, open[Math.floor(rng() * open.length)], rng);
      }
    }
    assert.ok(life.over, 'life did not end');
    endings.add(E.summarize(life).ending);
  }
  assert.ok(endings.size >= 15, 'only ' + endings.size + ' endings: ' + [...endings].join(','));
});
