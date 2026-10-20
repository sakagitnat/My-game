// ตรรกะล้วนของเกม "ชะตาแห่งอาณาจักร" ไม่มี DOM จึงทดสอบด้วย Node ได้
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  } else {
    root.LifeEngine = api;
  }
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  const START_AGE = 5;
  const MAX_AGE = 100;
  const EVENT_CHANCE = 0.55;
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

  const ORIGINS = [
    {
      id: 'warrior',
      name: 'ลูกชาวบ้านชายแดน',
      desc: 'เติบโตมากับเสียงเขาสู้รบและดาบไม้ที่ใช้ฝึกทุกเช้า',
      effects: { strength: 2, health: 10 },
    },
    {
      id: 'mage',
      name: 'ศิษย์หอคอยเวทย์',
      desc: 'ถูกส่งมาเรียนรู้คาถาตั้งแต่ยังเด็ก ร่างกายจึงอ่อนแอกว่าคนทั่วไป',
      effects: { wisdom: 2, charm: 1, health: -5 },
    },
    {
      id: 'merchant',
      name: 'บุตรพ่อค้าเมืองท่า',
      desc: 'ลืมตาดูโลกท่ามกลางกองสินค้าและเสียงต่อรองราคา',
      effects: { charm: 2, luck: 1, gold: 60 },
    },
    {
      id: 'wanderer',
      name: 'ผู้เร่ร่อนไร้บ้าน',
      desc: 'ไม่มีบ้านให้เรียกว่าบ้าน แต่โชคชะตาเข้าข้างเสมอ',
      effects: { luck: 3, health: -5 },
    },
  ];

  const EVENTS = [
    {
      id: 'dragon_hatchling',
      minAge: 5,
      maxAge: 12,
      text: 'ระหว่างเดินกลับบ้าน คุณพบมังกรน้อยตัวหนึ่งติดอยู่ในกับดักเหล็กข้างทาง มันร้องขอความช่วยเหลือ',
      choices: [
        { label: 'ปลดกับดักให้มัน', effects: { charm: 1, gold: 10 }, result: 'มังกรน้อยเลียมือคุณ แล้วบินจากไปพร้อมทิ้งเกล็ดสีทองไว้หนึ่งเกล็ด' },
        { label: 'เก็บไข่ในรังใกล้ๆ ไปขาย', effects: { gold: 15, reputation: -2 }, result: 'คุณขายไข่ได้เงินก้อนเล็ก แต่ชาวบ้านรู้เรื่องและมองคุณไม่ค่อยดี' },
        { label: 'เดินผ่านไปเฉยๆ', effects: {}, result: 'คุณเดินต่อไปโดยไม่ได้ทำอะไร' },
      ],
    },
    {
      id: 'child_tutor',
      minAge: 6,
      maxAge: 12,
      text: 'อาจารย์ประจำหมู่บ้านให้ท่องคาถาพื้นฐานจำนวนมากในคราวเดียว',
      choices: [
        {
          label: 'ตั้งใจท่องจนขึ้นใจ',
          check: {
            stat: 'wisdom',
            dc: 10,
            pass: { result: 'คุณจำได้ทุกคำ อาจารย์ชมว่าเป็นศิษย์ที่ดี', effects: { wisdom: 2 } },
            fail: { result: 'คุณจำได้ไม่ครบ แต่ก็ได้เรียนรู้มาบ้าง', effects: { wisdom: 1 } },
          },
        },
        { label: 'ไปเล่นกับเพื่อนแทน', effects: { charm: 2, wisdom: -1 }, result: 'คุณสนุกกับเพื่อนมาก แต่ความรู้บางส่วนหายไปด้วย' },
      ],
    },
    {
      id: 'child_wolves',
      minAge: 7,
      maxAge: 12,
      text: 'ฝูงหมาป่าสองตัวขวางทางกลับบ้าน',
      choices: [
        {
          label: 'สู้ด้วยไม้ที่ถืออยู่',
          check: {
            stat: 'strength',
            dc: 9,
            pass: { result: 'คุณไล่หมาป่าไปได้ และชาวบ้านชื่นชมความกล้าของคุณ', effects: { strength: 2, reputation: 2 } },
            fail: { result: 'หมาป่ากัดแขนคุณจนเป็นแผลลึก', effects: { health: -15 } },
          },
        },
        {
          label: 'วิ่งหนีเข้าซอกหิน',
          check: {
            stat: 'luck',
            dc: 8,
            pass: { result: 'คุณหลบเข้าซอกหินได้ทัน หมาป่าตามไม่ถึง', effects: {} },
            fail: { result: 'คุณสะดุดรากไม้ล้มจนเข่าถลอก', effects: { health: -5 } },
          },
        },
      ],
    },
    {
      id: 'youth_army',
      minAge: 13,
      maxAge: 17,
      text: 'กองทหารประกาศรับอาสาสมัครเยาวชนไปป้องกันด่านชายแดน',
      choices: [
        { label: 'สมัครเข้าร่วม', effects: { strength: 3, gold: 30, health: -10 }, result: 'คุณฝึกจนแข็งแกร่งขึ้น แม้จะเหนื่อยและได้เบี้ยเลี้ยงมาบ้าง' },
        { label: 'ช่วยพ่อแม่ทำไร่ต่อ', effects: { health: 5, gold: 10 }, result: 'ชีวิตเรียบง่ายและมั่นคงดี' },
      ],
    },
    {
      id: 'youth_caravan',
      minAge: 14,
      maxAge: 18,
      text: 'พ่อค้าแปลกหน้าเสนองานคุ้มกันขบวนสินค้าไปยังเมืองหลวง',
      choices: [
        {
          label: 'รับงาน',
          check: {
            stat: 'luck',
            dc: 10,
            pass: { result: 'ขบวนไปถึงปลอดภัยทุกคน คุณได้ค่าจ้างก้อนใหญ่', effects: { gold: 60, reputation: 2 } },
            fail: { result: 'ขบวนถูกโจรปล้น คุณได้ค่าจ้างเพียงเล็กน้อยและบาดเจ็บ', effects: { gold: -20, health: -10 } },
          },
        },
        { label: 'ปฏิเสธและอยู่บ้านต่อ', effects: {}, result: 'คุณปฏิเสธและอยู่ช่วยงานในบ้านต่อไป' },
      ],
    },
    {
      id: 'youth_festival',
      minAge: 14,
      maxAge: 19,
      text: 'เทศกาลเก็บเกี่ยวในหมู่บ้านมีการเต้นรำกลางลาน',
      choices: [
        { label: 'ร่วมเต้นรำกับทุกคน', effects: { charm: 3, reputation: 2 }, result: 'คุณกลายเป็นขวัญใจของงานคืนนั้น' },
        { label: 'หลบไปอ่านหนังสือเก่าในห้องสมุด', effects: { wisdom: 3 }, result: 'คุณพบตำราโบราณที่เปลี่ยนมุมมองของคุณไป' },
      ],
    },
    {
      id: 'youth_graveyard',
      minAge: 15,
      maxAge: 19,
      text: 'คืนหนึ่งมีเสียงเรียกชื่อคุณดังมาจากสุสานร้างที่ชายป่า',
      choices: [
        {
          label: 'เข้าไปดูให้รู้แน่',
          check: {
            stat: 'luck',
            dc: 11,
            pass: { result: 'คุณพบแหวนโบราณซ่อนอยู่ใต้หลุมศพเก่า', effects: { gold: 50, reputation: 1 } },
            fail: { result: 'วิญญาณชั่วร้ายทำร้ายคุณก่อนที่จะหนีรอดมาได้', effects: { health: -20 } },
          },
        },
        { label: 'วิ่งกลับบ้านทันที', effects: {}, result: 'คุณวิ่งกลับบ้านโดยไม่หันหลังมอง' },
      ],
    },
    {
      id: 'adult_guild',
      minAge: 30,
      maxAge: 60,
      text: 'สมาคมช่างฝีมือเชิญคุณเข้าร่วมเป็นสมาชิกเต็มตัว',
      choices: [
        { label: 'จ่ายค่าสมาชิกแล้วเข้าร่วม', effects: { gold: -25, reputation: 4, charm: 1 }, result: 'คุณได้รับการยอมรับในวงการช่างฝีมือ' },
        { label: 'ทำงานอิสระต่อไป', effects: { luck: 1, strength: 1 }, result: 'คุณยังคงทำงานตามลำพัง และได้ฝีมือที่แกร่งขึ้น' },
      ],
    },
    {
      id: 'adult_knight_offer',
      minAge: 22,
      maxAge: 45,
      text: 'ผู้ปกครองเมืองเสนอให้คุณเป็นแม่ทัพรักษาป้อมด่านหน้า',
      choices: [
        { label: 'รับตำแหน่ง', effects: { strength: 2, reputation: 5, gold: 50, health: -5 }, result: 'คุณนำกองทัพป้อมจนได้รับความเคารพจากทุกคน' },
        { label: 'ปฏิเสธอย่างสุภาพ', effects: { charm: 1 }, result: 'คุณเลือกใช้ชีวิตอิสระต่อไป' },
      ],
    },
    {
      id: 'adult_investment',
      minAge: 20,
      maxAge: 50,
      text: 'เพื่อนเก่าชวนลงทุนในหอการค้าใหม่ที่บอกว่าจะทำกำไรมหาศาล',
      choices: [
        {
          label: 'ลงทุนเงินส่วนใหญ่ที่มี',
          effects: { gold: -30 },
          check: {
            stat: 'luck',
            dc: 12,
            pass: { result: 'กิจการรุ่งเรือง เงินของคุณงอกเงยเป็นเท่าตัว', effects: { gold: 120, reputation: 2 } },
            fail: { result: 'หอการค้าล้มละลาย เงินของคุณหายไปกับมัน', effects: { gold: -80 } },
          },
        },
        { label: 'ลงทุนเล็กน้อยพอประมาณ', effects: { gold: 20 }, result: 'ได้กำไรเล็กน้อยอย่างมั่นคง' },
      ],
    },
    {
      id: 'adult_relic_quest',
      minAge: 20,
      maxAge: 50,
      text: 'มีผู้ชักชวนให้ร่วมขบวนเดินทางไปค้นหาอาวุธของเทพในซากปรักหักพังโบราณ',
      choices: [
        { label: 'ออกเดินทางร่วมขบวน', effects: { strength: 2, wisdom: 1, health: -15 }, result: 'การเดินทางโหดร้าย แต่คุณได้เห็นสิ่งที่คนทั่วไปไม่เคยเห็น' },
        { label: 'ปฏิเสธและอยู่บ้าน', effects: {}, result: 'คุณไม่มีวันรู้เลยว่าอาวุธนั้นซ่อนอยู่ที่ไหน' },
      ],
    },
    {
      id: 'adult_fever',
      minAge: 18,
      maxAge: 60,
      text: 'คุณล้มป่วยด้วยไข้ป่าที่กำลังระบาดในหมู่บ้าน',
      choices: [
        { label: 'ไปหาหมอแห่งหอคอย', effects: { gold: -30, health: 25 }, result: 'หมอรักษาจนหายดี แม้ค่ารักษาจะแพงไม่น้อย' },
        {
          label: 'รักษาเองด้วยสมุนไพร',
          check: {
            stat: 'wisdom',
            dc: 9,
            pass: { result: 'คุณปรุงยาสมุนไพรได้สำเร็จ อาการหายเป็นปลิดทิ้ง', effects: { health: 15, wisdom: 1 } },
            fail: { result: 'ยาไม่ได้ผล อาการทรุดลงอีกนิด', effects: { health: -10 } },
          },
        },
      ],
    },
    {
      id: 'adult_dinner',
      minAge: 20,
      maxAge: 45,
      text: 'นายอำเภอเชิญคุณไปทานอาหารค่ำ และแนะนำให้รู้จักกับลูกสาวของเขา',
      choices: [
        { label: 'ตอบรับและแสดงตัวให้ดี', effects: { charm: 2, reputation: 3, gold: 20 }, result: 'งานเลี้ยงนั้นทำให้คุณมีเพื่อนในวงสังคมชั้นสูง' },
        { label: 'ขอตัวและไปหาความสงบในป่า', effects: { luck: 2, charm: -1 }, result: 'คุณได้พบความสงบ แต่โอกาสทางสังคมก็หายไป' },
      ],
    },
    {
      id: 'adult_mine',
      minAge: 20,
      maxAge: 55,
      text: 'คุณพบทางเข้าเหมืองลับที่มีแร่เวทมนตร์เรืองแสงอยู่ข้างใน',
      choices: [
        {
          label: 'ลงไปขุดแร่ด้วยตัวเอง',
          check: {
            stat: 'strength',
            dc: 11,
            pass: { result: 'คุณขุดได้แร่ก้อนงาม นำไปขายได้ราคาดี', effects: { gold: 80 } },
            fail: { result: 'อุโมงค์ถล่มลงมาทับคุณ', effects: { health: -25 } },
          },
        },
        { label: 'แจ้งผู้ปกครองให้จัดการ', effects: { reputation: 4, gold: 10 }, result: 'เมืองให้รางวัลเล็กน้อยสำหรับการแจ้งข่าว' },
      ],
    },
    {
      id: 'adult_tax',
      minAge: 25,
      maxAge: 60,
      text: 'ผู้ตรวจการเก็บภาษีมาถึงเมือง และสงสัยว่าบัญชีของคุณไม่ถูกต้อง',
      choices: [
        { label: 'จ่ายภาษีตามที่กฎหมายกำหนด', effects: { gold: -30, reputation: 2 }, result: 'คุณจ่ายครบถ้วน ชื่อเสียงของคุณดีขึ้น' },
        {
          label: 'ติดสินบนเจ้าหน้าที่',
          check: {
            stat: 'charm',
            dc: 12,
            pass: { result: 'เจ้าหน้าที่รับเงินแล้วเงียบไป', effects: { gold: -10 } },
            fail: { result: 'คุณถูกจับได้ ต้องจ่ายค่าปรับและเสียชื่อเสียง', effects: { gold: -60, reputation: -5 } },
          },
        },
      ],
    },
    {
      id: 'adult_wizard_school',
      minAge: 18,
      maxAge: 40,
      text: 'หอคอยเวทมนตร์เปิดรับนักเรียนผู้ใหญ่ที่สนใจศาสตร์ลึกลับ',
      choices: [
        { label: 'สมัครเข้าเรียน', effects: { wisdom: 4, gold: -40 }, result: 'คุณเรียนรู้คาถาขั้นสูง แต่ค่าเล่าเรียนไม่ใช่ถูกๆ' },
        { label: 'ไม่สนใจ ไปฝึกดาบแทน', effects: { strength: 2 }, result: 'คุณเลือกเดินเส้นทางของนักรบ' },
      ],
    },
    {
      id: 'adult_love',
      minAge: 20,
      maxAge: 50,
      text: 'คนรักผู้ซื่อสัตย์คนหนึ่งเข้ามาในชีวิต แต่ดูเหมือนเขาจะปิดบังอดีตบางอย่างไว้',
      choices: [
        { label: 'เชื่อใจและอยู่ด้วยกันอย่างเปิดเผย', effects: { charm: 2, health: 5, reputation: 1 }, result: 'ความอบอุ่นนั้นทำให้ชีวิตของคุณมั่นคงขึ้น' },
        {
          label: 'สืบหาความจริงให้รู้แน่',
          check: {
            stat: 'wisdom',
            dc: 10,
            pass: { result: 'คุณพบความจริงและยุติความสัมพันธ์อย่างสงบ', effects: { wisdom: 2 } },
            fail: { result: 'ความลับนั้นทำให้คุณเสียใจจนนอนไม่หลับหลายคืน', effects: { health: -10 } },
          },
        },
      ],
    },
    {
      id: 'adult_bandit',
      minAge: 25,
      maxAge: 55,
      text: 'ผู้นำโจรป่าเสนอให้คุณร่วมแผนปล้นขบวนพ่อค้าใหญ่ที่ผ่านทาง',
      choices: [
        {
          label: 'ตกลงร่วมแผน',
          check: {
            stat: 'luck',
            dc: 11,
            pass: { result: 'แผนสำเร็จ คุณได้ทองจำนวนมาก แต่ชื่อเสียงเสียหาย', effects: { gold: 100, reputation: -8 } },
            fail: { result: 'ทหารรักษาการณ์มาถึงก่อน คุณถูกจับเข้าคุก', effects: { health: -20, reputation: -10 } },
          },
        },
        { label: 'ปฏิเสธและแจ้งทหาร', effects: { reputation: 5 }, result: 'ทหารยกย่องความซื่อสัตย์ของคุณ' },
      ],
    },
    {
      id: 'elder_chronicle',
      minAge: 60,
      maxAge: 95,
      text: 'ผู้เฒ่าในหมู่บ้านขอให้คุณเล่าเรื่องราวชีวิตให้คนรุ่นหลังจดบันทึกไว้',
      choices: [
        { label: 'เล่าอย่างละเอียดทุกเรื่อง', effects: { wisdom: 3, reputation: 6 }, result: 'เรื่องราวของคุณกลายเป็นตำนานประจำหมู่บ้าน' },
        { label: 'เล่าเพียงเล็กน้อย', effects: { health: 5 }, result: 'คุณนั่งพักกลางแดดอย่างสบายใจ' },
      ],
    },
    {
      id: 'elder_joint',
      minAge: 60,
      maxAge: 90,
      text: 'ข้อต่อของคุณเริ่มปวดจนเดินลำบาก',
      choices: [
        { label: 'ไปหาหมอผู้เชี่ยวชาญ', effects: { gold: -40, health: 15 }, result: 'อาการดีขึ้นมาก' },
        { label: 'ทนรอให้หายเอง', effects: { health: -8 }, result: 'อาการไม่ดีขึ้นเลย' },
      ],
    },
    {
      id: 'elder_blessing',
      minAge: 60,
      maxAge: 95,
      text: 'เด็กหนุ่มคนหนึ่งขอให้คุณให้พรก่อนเดินทางไปเมืองหลวง',
      choices: [
        { label: 'ให้พรด้วยความเมตตา', effects: { charm: 2, reputation: 3, luck: 1 }, result: 'เด็กคนนั้นจดจำคำอวยพรของคุณไปตลอดชีวิต' },
        { label: 'บอกว่าไม่มีเวลา', effects: { reputation: -1 }, result: 'เขาเดินจากไปอย่างผิดหวัง' },
      ],
    },
  ];

  const QUIET_YEARS = [
    { text: 'ปีนี้ผ่านไปอย่างเงียบสงบ ฤดูกาลดีและไม่มีเรื่องวุ่นวาย', effects: { health: 1 } },
    { text: 'คุณช่วยงานในหมู่บ้านทั้งปี ได้ทักทายเพื่อนบ้านมากมาย', effects: { charm: 1 } },
    { text: 'ฝนตกหนักติดต่อกันหลายวัน คุณอ่านหนังสือไปพลางรอฟ้าเปิด', effects: { wisdom: 1 } },
    { text: 'คุณทำงานหนักตลอดปีและเก็บเงินได้เพิ่มขึ้นเล็กน้อย', effects: { gold: 8 } },
    { text: 'คุณฝึกฝีมือทุกวันจนร่างกายแข็งแรงขึ้น', effects: { strength: 1 } },
  ];

  const DEATH_CAUSES = {
    exhausted: 'ร่างกายอ่อนล้าจนไม่อาจฟื้นคืนได้อีก ชีวิตของคุณจึงสิ้นสุดลงอย่างเงียบงัน',
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

  function addLog(life, text) {
    life.log.push({ age: life.age, text });
  }

  function createLife(originId, rng = Math.random) {
    const origin = ORIGINS.find((o) => o.id === originId);
    if (!origin) throw new Error('unknown origin: ' + originId);
    const stats = { health: 60, gold: 0, reputation: 0, strength: 2, wisdom: 2, charm: 2, luck: 2 };
    applyEffects(stats, origin.effects);
    stats.luck = clamp(stats.luck + Math.floor(rng() * 4), 0, STAT_MAX);
    const life = {
      origin: origin.id,
      age: START_AGE,
      stats,
      log: [],
      seen: [],
      current: null,
      over: false,
      cause: null,
    };
    addLog(life, 'เกิดเป็น' + origin.name + ' ' + origin.desc);
    return life;
  }

  function rollCheck(life, stat, dc, rng = Math.random) {
    const roll = Math.floor(rng() * 20) + 1;
    const bonus = Math.floor(life.stats[stat] / 2) + Math.floor(life.stats.luck / 3);
    const total = roll + bonus;
    return { stat, roll, bonus, total, dc, success: total >= dc };
  }

  function die(life, cause) {
    life.over = true;
    life.cause = cause;
    addLog(life, cause);
    return { type: 'death', cause };
  }

  // ขยับไปอีกหนึ่งปี คืนค่าเป็นเหตุการณ์ที่ต้องเลือก ผลของปีที่เงียบ หรือการตาย
  function advanceYear(life, rng = Math.random) {
    if (life.over) return { type: 'death', cause: life.cause };
    if (life.current) return { type: 'event', event: life.current };

    life.age += 1;
    const decay = life.age >= 40 ? Math.floor((life.age - 30) / 10) : 0;
    const recovery = life.age < 40 ? 2 : 0;
    applyEffects(life.stats, { health: recovery - decay });

    if (life.stats.health <= 0) return die(life, DEATH_CAUSES.exhausted);
    if (life.age >= MAX_AGE) return die(life, DEATH_CAUSES.centenarian);
    if (life.age >= 70 && rng() < (life.age - 69) * 0.02) return die(life, DEATH_CAUSES.oldAge);

    const pool = EVENTS.filter((e) => life.age >= e.minAge && life.age <= e.maxAge && !life.seen.includes(e.id));
    if (pool.length && rng() < EVENT_CHANCE) {
      const event = pool[Math.floor(rng() * pool.length)];
      life.seen.push(event.id);
      life.current = event;
      return { type: 'event', event };
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

    applyEffects(life.stats, choice.effects);
    let result = choice.result;
    let check = null;
    if (choice.check) {
      check = rollCheck(life, choice.check.stat, choice.check.dc, rng);
      const branch = check.success ? choice.check.pass : choice.check.fail;
      applyEffects(life.stats, branch.effects);
      result = branch.result;
    }
    life.current = null;
    addLog(life, result);
    return { result, check, choice };
  }

  // สรุปชีวิตเป็นฉายาจากค่าที่สูงที่สุดก่อน
  function summarize(life) {
    const s = life.stats;
    let title = 'ชาวบ้านผู้ซื่อสัตย์';
    if (s.gold >= 300) title = 'เศรษฐีแห่งเมืองท่า';
    else if (s.reputation >= 15) title = 'ผู้กล้าที่ชาวบ้านจดจำ';
    else if (s.wisdom >= 12) title = 'ปราชญ์หอคอย';
    else if (s.strength >= 12) title = 'นักรบผู้ผ่านศึก';
    else if (s.charm >= 12) title = 'กวีผู้เป็นที่รัก';
    else if (s.luck >= 12) title = 'ผู้โชคดีแห่งทวีป';
    return { title, age: life.age, cause: life.cause, stats: { ...s } };
  }

  return {
    START_AGE,
    MAX_AGE,
    STAT_LABELS,
    ORIGINS,
    EVENTS,
    QUIET_YEARS,
    createLife,
    advanceYear,
    chooseOption,
    rollCheck,
    summarize,
  };
});
