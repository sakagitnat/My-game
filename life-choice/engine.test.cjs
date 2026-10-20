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

test('เหตุการณ์ไม่ถูกเล่นซ้ำ และไม่ให้เหตุการณ์นอกช่วงอายุ', () => {
  const life = E.createLife('warrior', () => 0);
  const seen = new Set();
  for (let i = 0; i < 80 && !life.over; i++) {
    const step = E.advanceYear(life, sequence([0.1, 0.9, 0.3]));
    if (step.type === 'event') {
      assert.ok(!seen.has(step.event.id), 'repeated ' + step.event.id);
      assert.ok(life.age >= step.event.minAge && life.age <= step.event.maxAge);
      seen.add(step.event.id);
      E.chooseOption(life, 0, () => 0);
    }
  }
  assert.ok(seen.size > 0);
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

test('ฉายาของชีวิตขึ้นกับค่าสถานะที่สูงที่สุด', () => {
  const life = E.createLife('merchant', () => 0);
  life.stats.gold = 400;
  assert.equal(E.summarize(life).title, 'เศรษฐีแห่งเมืองท่า');
  life.stats.gold = 0;
  life.stats.wisdom = 15;
  assert.equal(E.summarize(life).title, 'ปราชญ์หอคอย');
  life.stats.wisdom = 2;
  assert.equal(E.summarize(life).title, 'ชาวบ้านผู้ซื่อสัตย์');
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

test('ทุกฉายาใน TITLES ได้มาจาก summarize ได้จริง', () => {
  const base = { health: 50, gold: 0, reputation: 0, strength: 0, wisdom: 0, charm: 0, luck: 0 };
  const cases = [{ gold: 300 }, { reputation: 15 }, { wisdom: 12 }, { strength: 12 }, { charm: 12 }, { luck: 12 }, {}];
  const got = cases.map((c) => E.summarize({ name: 'x', age: 50, cause: '', stats: { ...base, ...c } }).title);
  assert.deepEqual(got, E.TITLES.map((t) => t.title));
});

test('ทุกเหตุการณ์ วัย และต้นกำเนิด ชี้ไปที่ฉากที่มีอยู่จริง', () => {
  const Art = require('./scene.js');
  for (const event of E.EVENTS) assert.ok(Art.SCENES[event.scene], event.id + ' -> ' + event.scene);
  for (const stage of E.STAGES) assert.ok(Art.SCENES[Art.STAGE_SCENES[stage.id]], stage.id);
  for (const origin of E.ORIGINS) assert.ok(Art.SCENES[Art.ORIGIN_SCENES[origin.id]], origin.id);
  assert.ok(Art.SCENES.title && Art.SCENES.ending);
});
