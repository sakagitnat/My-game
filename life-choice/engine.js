// ตรรกะล้วนของเกม "ชะตาแห่งอาณาจักร" ไม่มี DOM จึงทดสอบด้วย Node ได้
// เนื้อเรื่องทั้งหมดอยู่ใน story.js ไฟล์นี้มีแค่กฎของเกม
(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory(require('./story.js'));
  } else {
    root.LifeEngine = factory(root.LifeStory);
  }
})(typeof globalThis !== 'undefined' ? globalThis : this, function (story) {
  'use strict';

  const { ORIGINS, CAREERS, EVENTS, QUIET_YEARS, ENDINGS } = story;

  const START_AGE = 5;
  const MAX_AGE = 100;
  const EVENT_CHANCE = 0.55;
  const CAREER_YEAR_CHANCE = 0.6;
  const STAT_MAX = 20;
  const ATTRIBUTES = ['strength', 'wisdom', 'charm', 'luck'];

  const STAT_LABELS = {
    health: 'สุขภาพ',
    gold: 'ทอง',
    reputation: 'ชื่อเสียง',
    strength: 'กำลัง',
    wisdom: 'ปัญญา',
    charm: 'เสน่ห์',
    luck: 'โชค',
  };

  // ช่วงวัยของชีวิต ใช้แบ่งบทและเลือกฉากพื้นหลัง
  const STAGES = [
    { id: 'child', minAge: 0, numeral: 'I', name: 'วัยเยาว์' },
    { id: 'youth', minAge: 13, numeral: 'II', name: 'วัยหนุ่มสาว' },
    { id: 'adult', minAge: 18, numeral: 'III', name: 'วัยทำงาน' },
    { id: 'elder', minAge: 60, numeral: 'IV', name: 'วัยชรา' },
  ];

  const DEATH_CAUSES = {
    exhausted: 'ร่างกายอ่อนล้าจนไม่อาจฟื้นคืนได้อีก ชีวิตของคุณจึงสิ้นสุดลงอย่างเงียบงัน',
    wounds: 'บาดแผลสาหัสเกินกว่าร่างกายจะทนไหว คุณสิ้นใจในคืนนั้น',
    oldAge: 'สิ้นลมอย่างสงบในวัยชรา ท่ามกลางคนที่คุณรัก',
    centenarian: 'คุณมีอายุยืนครบหนึ่งร้อยปี และจากโลกนี้ไปอย่างสงบ',
  };

  function clamp(value, min, max) {
    return Math.min(max, Math.max(min, value));
  }

  function applyEffects(stats, effects = {}) {
    for (const [key, delta] of Object.entries(effects)) {
      const next = (stats[key] ?? 0) + delta;
      if (key === 'health') {
        stats[key] = clamp(next, 0, 100);
      } else if (key === 'gold') {
        stats[key] = Math.max(0, next);
      } else if (ATTRIBUTES.includes(key)) {
        stats[key] = clamp(next, 0, STAT_MAX);
      } else {
        stats[key] = next;
      }
    }
  }

  // ผลของตัวเลือกหรือของการทดสอบ: ค่าสถานะ ธง อาชีพ และครอบครัว
  function applyOutcome(life, o) {
    applyEffects(life.stats, o.effects);
    for (const f of o.set || []) life.flags[f] = true;
    for (const f of o.unset || []) delete life.flags[f];
    if (o.career !== undefined) life.career = o.career;
    if (o.partner !== undefined) life.partner = o.partner;
    if (o.children) life.children = Math.max(0, life.children + o.children);
  }

  function stageOf(age) {
    let stage = STAGES[0];
    for (const s of STAGES) if (age >= s.minAge) stage = s;
    return stage;
  }

  function addLog(life, text, kind = 'quiet') {
    life.log.push({ age: life.age, text, kind });
  }

  function createLife(originId, rng = Math.random, name = '') {
    const origin = ORIGINS.find((o) => o.id === originId);
    if (!origin) throw new Error('unknown origin: ' + originId);
    const stats = { health: 60, gold: 0, reputation: 0, strength: 2, wisdom: 2, charm: 2, luck: 2 };
    applyEffects(stats, origin.effects);
    stats.luck = clamp(stats.luck + Math.floor(rng() * 4), 0, STAT_MAX);
    const life = {
      name: name || 'ผู้ไร้นาม',
      origin: origin.id,
      age: START_AGE,
      stats,
      flags: {},
      career: null,
      partner: false,
      children: 0,
      log: [],
      seen: [],
      lastSeen: {},
      current: null,
      over: false,
      cause: null,
      deathTag: null,
      endingId: null,
    };
    addLog(life, 'เกิดเป็น' + origin.name + ' ' + origin.desc, 'birth');
    return life;
  }

  // ตรวจเงื่อนไข when ของเหตุการณ์
  function meets(life, cond) {
    if (!cond) return true;
    if (cond.flags && !cond.flags.every((f) => life.flags[f])) return false;
    if (cond.anyFlags && !cond.anyFlags.some((f) => life.flags[f])) return false;
    if (cond.notFlags && cond.notFlags.some((f) => life.flags[f])) return false;
    if (cond.career !== undefined && ![].concat(cond.career).includes(life.career)) return false;
    if (cond.notCareer && [].concat(cond.notCareer).includes(life.career)) return false;
    if (cond.partner !== undefined && !!life.partner !== cond.partner) return false;
    if (cond.minChildren !== undefined && life.children < cond.minChildren) return false;
    if (cond.maxChildren !== undefined && life.children > cond.maxChildren) return false;
    if (cond.stats) {
      for (const [k, v] of Object.entries(cond.stats)) if (life.stats[k] < v) return false;
    }
    return true;
  }

  function isEligible(life, event) {
    if (life.age < event.minAge || life.age > event.maxAge) return false;
    if (event.repeatable) {
      const last = life.lastSeen[event.id];
      if (last !== undefined && life.age - last < (event.cooldown ?? 8)) return false;
    } else if (life.seen.includes(event.id)) {
      return false;
    }
    return meets(life, event.when);
  }

  // ตัวเลือกที่ต้องมีทองหรือค่าสถานะถึงเกณฑ์ คืนเหตุผลเมื่อเลือกไม่ได้
  function canChoose(life, choice) {
    const need = choice.need;
    if (!need) return { ok: true, reason: '' };
    if (need.gold && life.stats.gold < need.gold) return { ok: false, reason: 'ต้องมีทอง ' + need.gold };
    for (const [k, v] of Object.entries(need.stats || {})) {
      if (life.stats[k] < v) return { ok: false, reason: 'ต้องมี' + STAT_LABELS[k] + ' ' + v };
    }
    return { ok: true, reason: '' };
  }

  function checkBonus(life, stat) {
    return Math.floor(life.stats[stat] / 2) + Math.floor(life.stats.luck / 3);
  }

  function rollCheck(life, stat, dc, rng = Math.random) {
    const roll = Math.floor(rng() * 20) + 1;
    const bonus = checkBonus(life, stat);
    const total = roll + bonus;
    return { stat, roll, bonus, total, dc, success: total >= dc };
  }

  // โอกาสผ่านการทดสอบ 0..1 จากการทอย d20 ที่ออกแต่ละหน้าเท่ากัน
  function checkChance(life, stat, dc) {
    const needed = dc - checkBonus(life, stat);
    return clamp((21 - needed) / 20, 0, 1);
  }

  function die(life, cause, tag = 'illness') {
    life.over = true;
    life.cause = cause;
    life.deathTag = tag;
    addLog(life, cause, 'death');
    return { type: 'death', cause };
  }

  function pickWeighted(pool, rng) {
    const total = pool.reduce((sum, e) => sum + (e.weight ?? 1), 0);
    let r = rng() * total;
    for (const e of pool) {
      r -= e.weight ?? 1;
      if (r < 0) return e;
    }
    return pool[pool.length - 1];
  }

  // ขยับไปอีกหนึ่งปี คืนค่าเป็นเหตุการณ์ที่ต้องเลือก ผลของปีที่เงียบ หรือการตาย
  function advanceYear(life, rng = Math.random) {
    if (life.over) return { type: 'death', cause: life.cause };
    if (life.current) return { type: 'event', event: life.current };

    life.age += 1;
    const decay = life.age >= 40 ? Math.floor((life.age - 30) / 10) : 0;
    const recovery = life.age < 40 ? 2 : 0;
    applyEffects(life.stats, { health: recovery - decay });

    if (life.stats.health <= 0) return die(life, DEATH_CAUSES.exhausted, 'illness');
    if (life.age >= MAX_AGE) return die(life, DEATH_CAUSES.centenarian, 'oldAge');
    if (life.age >= 70 && rng() < (life.age - 69) * 0.02) return die(life, DEATH_CAUSES.oldAge, 'oldAge');

    const pool = EVENTS.filter((e) => isEligible(life, e));
    if (pool.length && rng() < EVENT_CHANCE) {
      const event = pickWeighted(pool, rng);
      if (event.repeatable) life.lastSeen[event.id] = life.age;
      else life.seen.push(event.id);
      life.current = event;
      return { type: 'event', event };
    }

    const career = life.career && CAREERS[life.career];
    if (career && rng() < CAREER_YEAR_CHANCE) {
      applyEffects(life.stats, career.yearly);
      addLog(life, career.quiet);
      return { type: 'quiet', text: career.quiet };
    }
    const quiet = QUIET_YEARS[Math.floor(rng() * QUIET_YEARS.length)];
    applyEffects(life.stats, quiet.effects);
    addLog(life, quiet.text);
    return { type: 'quiet', text: quiet.text };
  }

  // เลือกตัวเลือกที่ index ของเหตุการณ์ที่รออยู่ ผลของการทดสอบจะถูกทอยด้วย rng
  function chooseOption(life, index, rng = Math.random) {
    const event = life.current;
    if (!event) throw new Error('no pending event');
    const choice = event.choices[index];
    if (!choice) throw new Error('invalid choice: ' + index);
    const allowed = canChoose(life, choice);
    if (!allowed.ok) throw new Error('choice not available: ' + allowed.reason);

    applyOutcome(life, choice);
    let outcome = choice;
    let check = null;
    if (choice.check) {
      check = rollCheck(life, choice.check.stat, choice.check.dc, rng);
      outcome = check.success ? choice.check.pass : choice.check.fail;
      applyOutcome(life, outcome);
    }
    life.current = null;
    addLog(life, outcome.result, 'event');
    if (outcome.ending) {
      life.over = true;
      life.endingId = outcome.ending;
      life.cause = outcome.result;
    } else if (outcome.die) {
      die(life, outcome.die.cause, outcome.die.tag);
    } else if (life.stats.health <= 0) {
      die(life, DEATH_CAUSES.wounds, 'wounds');
    }
    return { result: outcome.result, check, choice, over: life.over };
  }

  function resolveEnding(life) {
    if (life.endingId) return ENDINGS.find((e) => e.id === life.endingId);
    return ENDINGS.find((e) => !e.forced && e.test(life));
  }

  // สรุปชีวิตเป็นตอนจบ พร้อมข้อความจารึกที่ใส่ชื่อตัวละครแล้ว
  function summarize(life) {
    const ending = resolveEnding(life);
    return {
      ending: ending.id,
      title: ending.title,
      text: ending.text.split('{name}').join(life.name),
      scene: ending.scene,
      name: life.name,
      age: life.age,
      cause: life.cause,
      career: life.career ? CAREERS[life.career].name : null,
      partner: !!life.partner,
      children: life.children,
      stats: { ...life.stats },
    };
  }

  return {
    START_AGE,
    MAX_AGE,
    STAT_LABELS,
    STAGES,
    ORIGINS,
    CAREERS,
    EVENTS,
    QUIET_YEARS,
    ENDINGS,
    stageOf,
    createLife,
    advanceYear,
    chooseOption,
    canChoose,
    isEligible,
    rollCheck,
    checkChance,
    resolveEnding,
    summarize,
  };
});
