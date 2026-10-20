// เนื้อเรื่องทั้งหมดของ "ชะตาแห่งอาณาจักร": ต้นกำเนิด อาชีพ เหตุการณ์ และตอนจบ
// ตรรกะที่อ่านข้อมูลนี้อยู่ใน engine.js
//
// เหตุการณ์ (EVENTS)
//   when: เงื่อนไขที่ต้องเป็นจริงจึงจะเกิด { flags, anyFlags, notFlags, career, notCareer, partner, minChildren, maxChildren, stats }
//   weight: น้ำหนักในการสุ่ม (ค่าเริ่ม 1) เรื่องต่อเนื่องให้สูงเพื่อให้เส้นเรื่องเดินหน้า
//   repeatable / cooldown: เกิดซ้ำได้เมื่อเว้นไปอย่างน้อย cooldown ปี
// ตัวเลือกและผลของการทดสอบ ใช้ช่องเดียวกัน
//   effects: เปลี่ยนค่าสถานะ  set / unset: ติดหรือลบธง  career: เปลี่ยนอาชีพ (null คือว่างงาน)
//   partner: มีหรือเสียคู่ชีวิต  children: จำนวนลูกที่เพิ่ม  die: { cause, tag } ตายทันที  ending: จบชีวิตด้วยตอนจบพิเศษ
//   need: { gold, stats } ต้องมีจึงจะเลือกได้
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  } else {
    root.LifeStory = api;
  }
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

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

  // อาชีพให้ผลทุกปีที่สงบ และปลดล็อกเหตุการณ์เฉพาะทาง
  const CAREERS = {
    soldier: { name: 'ทหาร', yearly: { gold: 8 }, quiet: 'คุณประจำการที่ด่านชายแดน ได้รับเบี้ยเลี้ยงตามปกติ' },
    knight: { name: 'อัศวิน', yearly: { gold: 15, reputation: 1 }, quiet: 'คุณออกตรวจตราดินแดนในฐานะอัศวิน ชาวบ้านต่างคำนับเมื่อคุณผ่าน' },
    mage: { name: 'จอมเวทย์', yearly: { wisdom: 1 }, quiet: 'คุณขลุกอยู่กับตำราเวทย์ทั้งปี ความรู้เพิ่มพูนอีกขั้น' },
    merchant: { name: 'พ่อค้า', yearly: { gold: 20 }, quiet: 'ร้านของคุณขายดีตลอดปี เงินในหีบเพิ่มขึ้นเรื่อยๆ' },
    adventurer: { name: 'นักผจญภัย', yearly: { gold: 12, health: -2 }, quiet: 'คุณรับงานจากกิลด์นักผจญภัยหลายงาน ได้ทั้งเงินและแผลเป็น' },
    outlaw: { name: 'โจรป่า', yearly: { gold: 15, reputation: -1 }, quiet: 'คุณดักปล้นตามเส้นทางป่า ชื่อเสียงในทางร้ายแพร่สะพัด' },
    healer: { name: 'หมอยา', yearly: { reputation: 1, gold: 6 }, quiet: 'คุณรักษาชาวบ้านทั้งปี ใครๆ ก็มาขอบคุณถึงบ้าน' },
    hermit: { name: 'ฤๅษี', yearly: { wisdom: 1, health: 2 }, quiet: 'คุณนั่งสมาธิบนยอดเขา จิตใจสงบดั่งผืนน้ำ' },
    king: { name: 'กษัตริย์', yearly: { gold: 40 }, quiet: 'คุณบริหารราชการแผ่นดิน ท้องพระคลังเพิ่มพูน' },
    dragonrider: { name: 'ผู้ขี่มังกร', yearly: { reputation: 1, strength: 1 }, quiet: 'คุณกับมังกรบินลาดตระเวนเหนือเมฆ เป็นที่เกรงขามทั่วแผ่นดิน' },
  };

  const EVENTS = [
    // ---------- วัยเยาว์ ----------
    {
      id: 'dragon_hatchling',
      title: 'มังกรน้อยในกับดัก',
      scene: 'dragon_vale',
      minAge: 5,
      maxAge: 12,
      text: 'ระหว่างเดินกลับบ้าน คุณพบมังกรน้อยตัวหนึ่งติดอยู่ในกับดักเหล็กข้างทาง มันร้องขอความช่วยเหลือ',
      choices: [
        { label: 'ปลดกับดักให้มัน', effects: { charm: 1, gold: 10 }, set: ['dragon_friend'], result: 'มังกรน้อยเลียมือคุณ แล้วบินจากไปพร้อมทิ้งเกล็ดสีทองไว้หนึ่งเกล็ด ราวกับสัญญาว่าจะกลับมา' },
        { label: 'เก็บไข่ในรังใกล้ๆ ไปขาย', effects: { gold: 15, reputation: -2 }, set: ['dragon_thief'], result: 'คุณขายไข่ได้เงินก้อนเล็ก แต่ไกลออกไปบนภูเขา มีเสียงคำรามโกรธแค้นดังก้อง' },
        { label: 'เดินผ่านไปเฉยๆ', effects: {}, result: 'คุณเดินต่อไปโดยไม่ได้ทำอะไร' },
      ],
    },
    {
      id: 'child_tutor',
      title: 'บทเรียนคาถาแรก',
      scene: 'tower',
      minAge: 6,
      maxAge: 12,
      text: 'อาจารย์ประจำหมู่บ้านให้ท่องคาถาพื้นฐานจำนวนมากในคราวเดียว',
      choices: [
        {
          label: 'ตั้งใจท่องจนขึ้นใจ',
          check: {
            stat: 'wisdom',
            dc: 10,
            pass: { result: 'คุณจำได้ทุกคำ อาจารย์บอกว่าคุณมีพรสวรรค์ด้านเวทมนตร์', effects: { wisdom: 2 }, set: ['gifted'] },
            fail: { result: 'คุณจำได้ไม่ครบ แต่ก็ได้เรียนรู้มาบ้าง', effects: { wisdom: 1 } },
          },
        },
        { label: 'ไปเล่นกับเพื่อนแทน', effects: { charm: 2, wisdom: -1 }, result: 'คุณสนุกกับเพื่อนมาก แต่ความรู้บางส่วนหายไปด้วย' },
      ],
    },
    {
      id: 'child_wolves',
      title: 'เงาหมาป่า',
      scene: 'forest_night',
      minAge: 7,
      maxAge: 12,
      text: 'ฝูงหมาป่าสองตัวขวางทางกลับบ้าน',
      choices: [
        {
          label: 'สู้ด้วยไม้ที่ถืออยู่',
          check: {
            stat: 'strength',
            dc: 9,
            pass: { result: 'คุณไล่หมาป่าไปได้ ชาวบ้านเล่าขานความกล้าของคุณ', effects: { strength: 2, reputation: 2 }, set: ['brave'] },
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
      id: 'child_stray',
      title: 'เด็กกำพร้าที่ประตู',
      scene: 'village',
      minAge: 5,
      maxAge: 12,
      text: 'เด็กกำพร้าตัวผอมคนหนึ่งมายืนเคาะประตูบ้าน ขออาหารสักชิ้น',
      choices: [
        { label: 'แบ่งอาหารของตัวเองให้', effects: { charm: 1, reputation: 1, health: -2 }, set: ['kind_heart'], result: 'เด็กคนนั้นยิ้มทั้งน้ำตา คุณหิวไปทั้งคืนแต่หัวใจอิ่มเอม' },
        { label: 'ปิดประตูใส่', effects: { gold: 2 }, result: 'คุณเก็บอาหารไว้กินเอง เสียงฝีเท้าเล็กๆ ค่อยๆ ห่างไป' },
      ],
    },
    {
      id: 'child_old_sword',
      title: 'ดาบในบ่อร้าง',
      scene: 'village',
      minAge: 8,
      maxAge: 12,
      text: 'คุณเห็นด้ามดาบเก่าโผล่พ้นน้ำในบ่อร้างหลังหมู่บ้าน',
      choices: [
        { label: 'เก็บไว้ฝึกฟันทุกวัน', effects: { strength: 2 }, set: ['old_sword'], result: 'ดาบสนิมเขรอะ แต่คุณฝึกกับมันทุกเช้าจนแขนแข็งแรง' },
        { label: 'นำไปขายให้ช่างตีเหล็ก', effects: { gold: 15 }, result: 'ช่างตีเหล็กยอมจ่ายเงินพอสมควรให้กับเหล็กเก่าชิ้นนั้น' },
      ],
    },

    // ---------- วัยหนุ่มสาว ----------
    {
      id: 'youth_army',
      title: 'เสียงกลองรบ',
      scene: 'fortress',
      minAge: 13,
      maxAge: 17,
      text: 'กองทหารประกาศรับอาสาสมัครเยาวชนไปป้องกันด่านชายแดน',
      choices: [
        { label: 'สมัครเป็นทหาร', effects: { strength: 3, gold: 30, health: -10 }, career: 'soldier', set: ['soldier'], result: 'คุณสวมเครื่องแบบทหารเป็นครั้งแรก การฝึกโหดแต่ทำให้คุณแข็งแกร่งขึ้นมาก' },
        { label: 'ช่วยพ่อแม่ทำไร่ต่อ', effects: { health: 5, gold: 10 }, result: 'ชีวิตเรียบง่ายและมั่นคงดี' },
      ],
    },
    {
      id: 'youth_caravan',
      title: 'ขบวนสินค้าสู่เมืองหลวง',
      scene: 'road',
      minAge: 14,
      maxAge: 18,
      text: 'พ่อค้าแปลกหน้าเสนองานคุ้มกันขบวนสินค้าไปยังเมืองหลวง',
      choices: [
        {
          label: 'รับงาน',
          check: {
            stat: 'luck',
            dc: 10,
            pass: { result: 'ขบวนไปถึงปลอดภัยทุกคน คุณได้ค่าจ้างก้อนใหญ่และได้เห็นโลกกว้าง', effects: { gold: 60, reputation: 2 }, set: ['traveled'] },
            fail: { result: 'ขบวนถูกโจรปล้น คุณได้ค่าจ้างเพียงเล็กน้อยและบาดเจ็บ', effects: { gold: -20, health: -10 } },
          },
        },
        { label: 'ปฏิเสธและอยู่บ้านต่อ', effects: {}, result: 'คุณปฏิเสธและอยู่ช่วยงานในบ้านต่อไป' },
      ],
    },
    {
      id: 'youth_festival',
      title: 'เทศกาลเก็บเกี่ยว',
      scene: 'festival',
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
      title: 'เสียงเรียกจากสุสาน',
      scene: 'graveyard',
      minAge: 15,
      maxAge: 19,
      text: 'คืนหนึ่งมีเสียงเรียกชื่อคุณดังมาจากสุสานร้างที่ชายป่า',
      choices: [
        {
          label: 'เข้าไปดูให้รู้แน่',
          check: {
            stat: 'luck',
            dc: 11,
            pass: { result: 'คุณพบแหวนโบราณสีดำซ่อนอยู่ใต้หลุมศพ มันเย็นเฉียบเมื่อสวมนิ้ว', effects: { gold: 30, reputation: 1 }, set: ['dark_ring'] },
            fail: { result: 'วิญญาณชั่วร้ายทำร้ายคุณก่อนที่จะหนีรอดมาได้', effects: { health: -20 } },
          },
        },
        { label: 'วิ่งกลับบ้านทันที', effects: {}, result: 'คุณวิ่งกลับบ้านโดยไม่หันหลังมอง' },
      ],
    },
    {
      id: 'youth_first_love',
      title: 'ดอกไม้ริมทะเลสาบ',
      scene: 'lake',
      minAge: 15,
      maxAge: 19,
      text: 'คนที่คุณแอบชอบมานาน ยื่นดอกไม้ป่าให้คุณริมทะเลสาบยามเย็น',
      choices: [
        { label: 'รับดอกไม้และจับมือเขาไว้', effects: { charm: 2, health: 3 }, set: ['sweetheart'], result: 'หัวใจของคุณเต้นแรงกว่าเสียงกลองในงานเทศกาล' },
        { label: 'อายจนวิ่งหนี', effects: { wisdom: 1 }, result: 'คุณวิ่งหนีไปโดยไม่ได้พูดอะไร และนึกเสียดายไปอีกนาน' },
      ],
    },
    {
      id: 'youth_theft',
      title: 'ขนมปังหน้าร้าน',
      scene: 'city',
      minAge: 13,
      maxAge: 17,
      text: 'ปีนี้ข้าวยากหมากแพง ความหิวทำให้คุณจ้องขนมปังที่วางหน้าร้านไม่วางตา',
      choices: [
        {
          label: 'ฉกขนมปังแล้ววิ่ง',
          check: {
            stat: 'luck',
            dc: 9,
            pass: { result: 'คุณหนีรอดไปได้ และพบว่าตัวเองมีฝีมือทางนี้ไม่น้อย', effects: { health: 3 }, set: ['thief'] },
            fail: { result: 'เจ้าของร้านจับได้และประจานคุณกลางตลาด', effects: { reputation: -3, health: -3 }, set: ['thief'] },
          },
        },
        { label: 'ขอทำงานแลกขนมปัง', effects: { strength: 1, reputation: 1 }, result: 'คุณขนแป้งจนหลังแทบหัก แต่ได้กินอิ่มอย่างภาคภูมิ' },
      ],
    },
    {
      id: 'youth_mentor',
      title: 'นักเวทย์เร่ร่อน',
      scene: 'tower',
      minAge: 14,
      maxAge: 18,
      when: { stats: { wisdom: 4 } },
      text: 'นักเวทย์ชราผู้เดินทางผ่านหมู่บ้าน มองเห็นประกายบางอย่างในดวงตาของคุณ',
      choices: [
        { label: 'ขอเป็นศิษย์', effects: { wisdom: 3, health: -3 }, set: ['gifted'], result: 'คุณติดตามนักเวทย์ไปหนึ่งฤดู ได้เรียนรู้ความลับที่ตำราไม่ได้เขียนไว้' },
        { label: 'ขอบคุณแต่ปฏิเสธ', effects: { luck: 1 }, result: 'นักเวทย์ยิ้มและวางเหรียญนำโชคไว้ในมือคุณก่อนจากไป' },
      ],
    },

    // ---------- ความรักและครอบครัว ----------
    {
      id: 'sweetheart_wedding',
      title: 'รักแรกกลับมา',
      scene: 'festival',
      minAge: 18,
      maxAge: 30,
      weight: 3,
      when: { flags: ['sweetheart'], partner: false },
      text: 'รักแรกของคุณยังรออยู่ที่หมู่บ้านเดิม ทั้งคู่ต่างรู้ว่าถึงเวลาต้องตัดสินใจ',
      choices: [
        { label: 'แต่งงานกับรักแรก', effects: { charm: 2, health: 10 }, partner: true, set: ['true_love'], result: 'งานแต่งงานเรียบง่ายแต่อบอุ่นที่สุดในหมู่บ้าน ทั้งคู่สัญญาจะอยู่ด้วยกันจนวันสุดท้าย' },
        { label: 'เลิกรากันด้วยดี', effects: { wisdom: 1 }, unset: ['sweetheart'], result: 'คุณเลือกเส้นทางของตัวเอง ความทรงจำริมทะเลสาบยังอยู่ในใจเสมอ' },
      ],
    },
    {
      id: 'adult_marriage',
      title: 'งานหมั้นหมาย',
      scene: 'festival',
      minAge: 20,
      maxAge: 40,
      weight: 2,
      when: { partner: false, notFlags: ['free_spirit'] },
      text: 'ครอบครัวจัดงานหมั้นหมายให้คุณกับคนจากหมู่บ้านข้างเคียง ผู้มีนิสัยอ่อนโยนและขยันขันแข็ง',
      choices: [
        { label: 'ตกลงแต่งงาน', effects: { charm: 1, health: 5 }, partner: true, result: 'แม้จะไม่ใช่รักแรกพบ แต่ความอบอุ่นค่อยๆ เติบโตขึ้นในบ้านหลังเล็ก' },
        { label: 'ขอใช้ชีวิตอิสระต่อไป', effects: { luck: 1 }, set: ['free_spirit'], result: 'คุณปฏิเสธอย่างสุภาพ ถนนทุกสายยังรอให้คุณเดินทาง' },
      ],
    },
    {
      id: 'adult_love',
      title: 'ความรักและความลับ',
      scene: 'lake',
      minAge: 20,
      maxAge: 50,
      when: { partner: false },
      text: 'คนรักผู้ซื่อสัตย์คนหนึ่งเข้ามาในชีวิต แต่ดูเหมือนเขาจะปิดบังอดีตบางอย่างไว้',
      choices: [
        { label: 'เชื่อใจและอยู่ด้วยกัน', effects: { charm: 2, health: 5, reputation: 1 }, partner: true, result: 'ความอบอุ่นนั้นทำให้ชีวิตของคุณมั่นคงขึ้น อดีตของเขาไม่สำคัญอีกต่อไป' },
        {
          label: 'สืบหาความจริงให้รู้แน่',
          check: {
            stat: 'wisdom',
            dc: 10,
            pass: { result: 'คุณพบว่าเขาเคยเป็นโจรที่กลับใจ คุณเลือกให้อภัยและแต่งงานกัน', effects: { wisdom: 2 }, partner: true },
            fail: { result: 'ความลับนั้นทำให้คุณเสียใจจนนอนไม่หลับหลายคืน', effects: { health: -10 } },
          },
        },
      ],
    },
    {
      id: 'child_born',
      title: 'สมาชิกใหม่ของครอบครัว',
      scene: 'village',
      minAge: 21,
      maxAge: 45,
      weight: 2,
      repeatable: true,
      cooldown: 3,
      when: { partner: true, maxChildren: 2 },
      text: 'เสียงร้องไห้ของทารกดังขึ้นในบ้าน ครอบครัวของคุณมีสมาชิกใหม่',
      choices: [
        { label: 'อุ้มลูกน้อยด้วยความยินดี', effects: { charm: 1, health: 3, gold: -10 }, children: 1, result: 'มือเล็กๆ กำนิ้วของคุณไว้แน่น โลกทั้งใบดูเปลี่ยนไปในพริบตา' },
        { label: 'ตั้งชื่อตามวีรบุรุษในตำนาน', effects: { reputation: 1, gold: -10 }, children: 1, result: 'คุณหวังว่าลูกจะเติบโตอย่างกล้าหาญเหมือนชื่อที่ได้รับ' },
      ],
    },
    {
      id: 'child_grows',
      title: 'ลูกอยากออกเดินทาง',
      scene: 'road',
      minAge: 38,
      maxAge: 65,
      weight: 2,
      when: { minChildren: 1 },
      text: 'ลูกของคุณโตเป็นผู้ใหญ่ และขออนุญาตออกไปผจญภัยในโลกกว้าง',
      choices: [
        { label: 'มอบเสบียงและอวยพร', effects: { gold: -30, reputation: 2, charm: 1 }, set: ['proud_parent'], result: 'หลายปีต่อมา จดหมายจากลูกเล่าถึงการผจญภัยที่ทำให้คุณภูมิใจ' },
        { label: 'ห้ามไว้เพราะเป็นห่วง', effects: { charm: -1, health: 2 }, result: 'ลูกยอมอยู่บ้าน แต่แววตาของเขาไม่สดใสเหมือนเดิม' },
      ],
    },
    {
      id: 'partner_sick',
      title: 'คู่ชีวิตล้มป่วย',
      scene: 'rain_village',
      minAge: 35,
      maxAge: 75,
      when: { partner: true },
      text: 'คู่ชีวิตของคุณล้มป่วยหนัก หมอในหมู่บ้านส่ายหน้า',
      choices: [
        { label: 'จ้างหมอหลวงมารักษา', need: { gold: 60 }, effects: { gold: -60 }, result: 'หมอหลวงรักษาจนหายดี คุณกุมมือกันแน่นกว่าที่เคย' },
        {
          label: 'ดูแลเองด้วยสมุนไพร',
          check: {
            stat: 'wisdom',
            dc: 11,
            pass: { result: 'ยาของคุณได้ผล คู่ชีวิตค่อยๆ ฟื้นตัวในอ้อมกอดของคุณ', effects: { wisdom: 1 } },
            fail: { result: 'คุณเฝ้าไข้ทั้งคืนจนรุ่งสาง แต่ลมหายใจที่คุ้นเคยก็จางหายไป', effects: { health: -10, charm: -1 }, partner: false, set: ['widowed'] },
          },
        },
      ],
    },

    // ---------- เส้นทางทหารและบัลลังก์ ----------
    {
      id: 'soldier_battle',
      title: 'สงครามชายแดน',
      scene: 'battlefield',
      minAge: 18,
      maxAge: 40,
      weight: 3,
      when: { career: 'soldier' },
      text: 'กองทัพศัตรูบุกข้ามแม่น้ำ แม่ทัพสั่งให้ทุกกองเตรียมรบ',
      choices: [
        {
          label: 'บุกแนวหน้า',
          check: {
            stat: 'strength',
            dc: 11,
            pass: { result: 'คุณฝ่าแนวข้าศึกจนกองทัพชนะ ชื่อของคุณถูกประกาศเป็นวีรชนสงคราม', effects: { reputation: 6, strength: 1, gold: 40 }, set: ['war_hero'] },
            fail: { result: 'คมดาบข้าศึกฝากแผลใหญ่ไว้ที่อก คุณรอดมาอย่างหวุดหวิด', effects: { health: -30 } },
          },
        },
        { label: 'คุ้มกันเสบียงด้านหลัง', effects: { gold: 20, health: -5 }, result: 'งานไม่หวือหวา แต่คุณกลับบ้านพร้อมเงินและแขนขาครบ' },
        { label: 'หนีทัพกลางดึก', effects: { reputation: -6, luck: 1 }, career: null, set: ['deserter'], result: 'คุณหนีออกจากค่ายท่ามกลางความมืด ไม่มีวันได้กลับไปอีก' },
      ],
    },
    {
      id: 'war_call',
      title: 'หมายเกณฑ์ทัพ',
      scene: 'battlefield',
      minAge: 25,
      maxAge: 55,
      when: { notCareer: ['soldier', 'knight', 'king', 'dragonrider'] },
      text: 'สงครามใหญ่ปะทุ ราชสำนักออกหมายเกณฑ์ผู้ใหญ่ทุกคนไปรบ',
      choices: [
        {
          label: 'ออกรบเพื่อแผ่นดิน',
          check: {
            stat: 'strength',
            dc: 10,
            pass: { result: 'คุณรอดจากสงครามพร้อมเหรียญกล้าหาญ', effects: { reputation: 5, strength: 1 }, set: ['war_hero'] },
            fail: { result: 'คุณกลับมาพร้อมขาที่เดินกะเผลกไปตลอดชีวิต', effects: { health: -25, strength: -1 } },
          },
        },
        { label: 'จ่ายเงินจ้างคนไปแทน', need: { gold: 50 }, effects: { gold: -50, reputation: -1 }, result: 'คุณอยู่บ้านอย่างปลอดภัย แต่เพื่อนบ้านบางคนมองคุณด้วยสายตาแปลกๆ' },
        { label: 'หลบซ่อนในป่า', effects: { reputation: -4, health: -5 }, result: 'คุณซ่อนตัวในป่าจนสงครามสงบ ไม่มีใครลืมว่าคุณหายไปไหน' },
      ],
    },
    {
      id: 'adult_knight_offer',
      title: 'ตำแหน่งอัศวิน',
      scene: 'fortress',
      minAge: 22,
      maxAge: 50,
      weight: 3,
      when: { anyFlags: ['war_hero', 'dragon_slayer', 'monster_slayer'], notCareer: ['king', 'knight', 'outlaw'] },
      text: 'วีรกรรมของคุณไปถึงพระกรรณ กษัตริย์ทรงเชิญคุณเข้ารับการแต่งตั้งเป็นอัศวิน',
      choices: [
        { label: 'คุกเข่ารับดาบแต่งตั้ง', effects: { reputation: 6, gold: 50 }, career: 'knight', set: ['knight'], result: 'ดาบของกษัตริย์แตะไหล่ทั้งสองข้าง นับจากนี้คุณคืออัศวินแห่งอาณาจักร' },
        { label: 'ปฏิเสธอย่างสุภาพ', effects: { charm: 1, luck: 1 }, result: 'คุณขอใช้ชีวิตอิสระต่อไป กษัตริย์ทรงเคารพการตัดสินใจนั้น' },
      ],
    },
    {
      id: 'knight_coup',
      title: 'แผนการในเงามืด',
      scene: 'royal',
      minAge: 30,
      maxAge: 65,
      weight: 3,
      when: { career: 'knight' },
      text: 'กษัตริย์องค์ใหม่กดขี่ราษฎรอย่างหนัก เหล่าขุนนางลอบมาชวนคุณก่อการโค่นบัลลังก์',
      choices: [
        {
          label: 'นำทัพยึดพระราชวัง',
          check: {
            stat: 'strength',
            dc: 14,
            pass: { result: 'ประตูวังแตก ทรราชหนีไปในยามวิกาล ขุนนางทั้งหลายยกมงกุฎให้คุณ', effects: { reputation: 15, gold: 200 }, career: 'king', set: ['king'] },
            fail: { result: 'แผนรั่วไหล คุณถูกจับได้คาพระราชวัง', die: { cause: 'คุณถูกประหารกลางลานเมืองในข้อหากบฏ', tag: 'executed' } },
          },
        },
        { label: 'ภักดีต่อบัลลังก์', effects: { reputation: 3, gold: 40 }, set: ['loyal'], result: 'คุณเลือกรักษาคำสัตย์ แม้ในใจจะหนักอึ้ง' },
        {
          label: 'เปิดโปงแผนต่อกษัตริย์',
          check: {
            stat: 'charm',
            dc: 10,
            pass: { result: 'กษัตริย์ทรงพอพระทัย พระราชทานที่ดินผืนใหญ่ให้คุณ', effects: { gold: 120, reputation: -2 }, set: ['loyal'] },
            fail: { result: 'กษัตริย์หวาดระแวงคุณไปด้วย และสั่งเฆี่ยนเพื่อสอบสวน', effects: { health: -20 } },
          },
        },
      ],
    },
    {
      id: 'king_rule',
      title: 'ราษฎรอดอยาก',
      scene: 'royal',
      minAge: 30,
      maxAge: 95,
      weight: 4,
      when: { career: 'king' },
      text: 'ภัยแล้งทำให้ราษฎรอดอยาก ขุนคลังทูลถามว่าจะทำอย่างไรกับท้องพระคลัง',
      choices: [
        { label: 'เปิดคลังหลวงแจกจ่ายราษฎร', need: { gold: 100 }, effects: { gold: -100, reputation: 12 }, set: ['good_king'], result: 'ราษฎรทั่วแผ่นดินถวายพระพรให้คุณ เสียงสรรเสริญดังไปถึงเมืองไกล' },
        { label: 'ขึ้นภาษีเพื่อสร้างพระราชวังใหม่', effects: { gold: 250, reputation: -12 }, set: ['tyrant'], result: 'พระราชวังหินอ่อนงามตระการ แต่ราษฎรต่างสาปแช่งชื่อของคุณ' },
      ],
    },
    {
      id: 'king_assassin',
      title: 'มือสังหารในห้องบรรทม',
      scene: 'royal',
      minAge: 35,
      maxAge: 95,
      weight: 2,
      when: { career: 'king' },
      text: 'กลางดึก เงาดำคนหนึ่งลอบเข้ามาในห้องบรรทมพร้อมมีดอาบยาพิษ',
      choices: [
        {
          label: 'คว้าดาบข้างเตียงสู้',
          check: {
            stat: 'strength',
            dc: 12,
            pass: { result: 'คุณปลดอาวุธมือสังหารได้ และสืบจนพบผู้บงการ', effects: { reputation: 3 } },
            fail: { result: 'คมมีดเฉือนผ่านลำคอ', die: { cause: 'คุณถูกลอบปลงพระชนม์กลางดึก', tag: 'assassinated' } },
          },
        },
        {
          label: 'ร้องเรียกองครักษ์',
          check: {
            stat: 'luck',
            dc: 9,
            pass: { result: 'องครักษ์พังประตูเข้ามาทันเวลา', effects: {} },
            fail: { result: 'องครักษ์มาช้าไปนิด มีดอาบยาพิษเฉียดแขนคุณ', effects: { health: -25 } },
          },
        },
      ],
    },

    // ---------- เส้นทางเวทมนตร์ ----------
    {
      id: 'adult_wizard_school',
      title: 'หอคอยเปิดประตู',
      scene: 'tower',
      minAge: 18,
      maxAge: 40,
      when: { notCareer: ['mage', 'king'] },
      text: 'หอคอยเวทมนตร์เปิดรับนักเรียนผู้ใหญ่ที่สนใจศาสตร์ลึกลับ',
      choices: [
        { label: 'จ่ายค่าเล่าเรียนและสมัคร', need: { gold: 40 }, effects: { wisdom: 4, gold: -40 }, career: 'mage', result: 'คุณสวมเสื้อคลุมจอมเวทย์เป็นครั้งแรก คาถาขั้นสูงรอคุณอยู่' },
        { label: 'ไม่สนใจ ไปฝึกดาบแทน', effects: { strength: 2 }, result: 'คุณเลือกเดินเส้นทางของนักรบ' },
      ],
    },
    {
      id: 'mage_forbidden',
      title: 'คัมภีร์ต้องห้าม',
      scene: 'tower',
      minAge: 28,
      maxAge: 65,
      weight: 3,
      when: { career: 'mage' },
      text: 'ในห้องใต้ดินของหอคอย คุณพบคัมภีร์ต้องห้ามว่าด้วยการมีชีวิตนิรันดร์',
      choices: [
        { label: 'ศึกษามันอย่างลับๆ', effects: { wisdom: 4, health: -10 }, set: ['forbidden'], result: 'อักษรในคัมภีร์ลุกเป็นไฟในหัวของคุณ ความลับแห่งความตายเริ่มเผยตัว' },
        { label: 'เผาคัมภีร์ทิ้ง', effects: { reputation: 3, wisdom: 1 }, result: 'ไฟสีม่วงเผาผลาญหน้ากระดาษ คุณรู้สึกโล่งใจอย่างประหลาด' },
      ],
    },
    {
      id: 'mage_tower_master',
      title: 'สภาจอมเวทย์',
      scene: 'tower',
      minAge: 40,
      maxAge: 75,
      weight: 3,
      when: { career: 'mage', stats: { wisdom: 12 } },
      text: 'สภาจอมเวทย์ลงมติเชิญคุณขึ้นเป็นเจ้าหอคอยคนใหม่',
      choices: [
        { label: 'รับตำแหน่งเจ้าหอคอย', effects: { reputation: 8, wisdom: 2 }, set: ['archmage'], result: 'คุณยืนบนยอดหอคอยสูงสุด แสงดาวทุกดวงตอบรับเสียงเรียกของคุณ' },
        { label: 'ขอเป็นเพียงผู้ค้นคว้า', effects: { wisdom: 3 }, result: 'คุณปฏิเสธอำนาจ และจมลงในห้องสมุดอย่างมีความสุข' },
      ],
    },
    {
      id: 'mage_ascend',
      title: 'พิธีแห่งนิรันดร์',
      scene: 'portal',
      minAge: 58,
      maxAge: 95,
      weight: 5,
      when: { flags: ['forbidden'] },
      text: 'ร่างกายของคุณเริ่มร่วงโรย คัมภีร์ต้องห้ามกระซิบว่าถึงเวลาประกอบพิธีแห่งความเป็นอมตะแล้ว',
      choices: [
        {
          label: 'ประกอบพิธีกรรม',
          check: {
            stat: 'wisdom',
            dc: 15,
            pass: { result: 'วงเวทย์ลุกโชน หัวใจของคุณหยุดเต้น แต่ดวงตายังลืมอยู่ คุณจะไม่มีวันตายอีกแล้ว', ending: 'lich' },
            fail: { result: 'คาถาย้อนกลับเข้าหาตัว', die: { cause: 'พิธีล้มเหลว ร่างของคุณสลายกลายเป็นเถ้าสีม่วง', tag: 'ritual' } },
          },
        },
        { label: 'ยอมรับความตายตามธรรมชาติ', effects: { wisdom: 2, health: 5 }, unset: ['forbidden'], set: ['serene'], result: 'คุณปิดคัมภีร์ลงอย่างสงบ ชีวิตมีค่าเพราะมันมีวันสิ้นสุด' },
      ],
    },

    // ---------- เส้นทางพ่อค้า ----------
    {
      id: 'merchant_start',
      title: 'แผงเล็กในตลาด',
      scene: 'city',
      minAge: 18,
      maxAge: 35,
      weight: 2,
      when: { career: null },
      text: 'มีแผงว่างในตลาดใหญ่ให้เช่า ทำเลดีเยี่ยมใกล้ท่าเรือ',
      choices: [
        { label: 'เช่าแผงเปิดร้าน', need: { gold: 40 }, effects: { gold: -40, charm: 1 }, career: 'merchant', result: 'ป้ายร้านเล็กๆ ถูกแขวนขึ้น นับจากนี้คุณคือพ่อค้า' },
        { label: 'ยังไม่อยากเสี่ยง', effects: {}, result: 'คุณเดินผ่านแผงนั้นไป มีคนอื่นเช่าในวันรุ่งขึ้น' },
      ],
    },
    {
      id: 'adult_investment',
      title: 'หอการค้าแห่งใหม่',
      scene: 'harbor',
      minAge: 20,
      maxAge: 50,
      text: 'เพื่อนเก่าชวนลงทุนในหอการค้าใหม่ที่บอกว่าจะทำกำไรมหาศาล',
      choices: [
        {
          label: 'ลงทุน 30 ทอง',
          need: { gold: 30 },
          effects: { gold: -30 },
          check: {
            stat: 'luck',
            dc: 12,
            pass: { result: 'กิจการรุ่งเรือง เงินของคุณงอกเงยหลายเท่า', effects: { gold: 120, reputation: 2 } },
            fail: { result: 'หอการค้าล้มละลาย เงินของคุณหายไปกับมัน', effects: {} },
          },
        },
        { label: 'ไม่ลงทุน', effects: { wisdom: 1 }, result: 'คุณเลือกเก็บเงินไว้กับตัว' },
      ],
    },
    {
      id: 'merchant_fleet',
      title: 'เรือสินค้าลำแรก',
      scene: 'harbor',
      minAge: 28,
      maxAge: 60,
      weight: 3,
      when: { career: 'merchant' },
      text: 'มีเรือสินค้ามือสองประกาศขาย ถ้าได้มา ร้านของคุณจะค้าขายข้ามทะเลได้',
      choices: [
        {
          label: 'ซื้อเรือแล้วออกค้าขาย',
          need: { gold: 120 },
          effects: { gold: -120 },
          check: {
            stat: 'luck',
            dc: 10,
            pass: { result: 'เรือกลับมาพร้อมเครื่องเทศและผ้าไหมเต็มลำ คุณร่ำรวยในชั่วข้ามคืน', effects: { gold: 320, reputation: 4 }, set: ['trade_prince'] },
            fail: { result: 'พายุกลืนเรือของคุณหายไปในทะเล', effects: { luck: 1 } },
          },
        },
        { label: 'ค้าขายทางบกต่อไป', effects: { gold: 30 }, result: 'คุณเลือกความมั่นคง ร้านเล็กยังทำกำไรได้ดี' },
      ],
    },
    {
      id: 'merchant_guild_master',
      title: 'ประธานสมาคมพ่อค้า',
      scene: 'city',
      minAge: 35,
      maxAge: 75,
      weight: 3,
      when: { flags: ['trade_prince'] },
      text: 'สมาคมพ่อค้าทั่วทวีปลงมติให้คุณเป็นประธานคนใหม่',
      choices: [
        { label: 'รับตำแหน่งประธาน', effects: { reputation: 8, gold: 80 }, set: ['guild_master'], result: 'เส้นทางการค้าทุกสายในทวีปต้องผ่านมือคุณ' },
        { label: 'ปฏิเสธเพื่อใช้ชีวิตเรียบง่าย', effects: { health: 5, luck: 2 }, result: 'คุณเลือกเวลากับคนที่รักมากกว่าอำนาจ' },
      ],
    },
    {
      id: 'adult_guild',
      title: 'สมาคมช่างฝีมือ',
      scene: 'city',
      minAge: 30,
      maxAge: 60,
      when: { notCareer: ['king', 'outlaw'] },
      text: 'สมาคมช่างฝีมือเชิญคุณเข้าร่วมเป็นสมาชิกเต็มตัว',
      choices: [
        { label: 'จ่ายค่าสมาชิกแล้วเข้าร่วม', need: { gold: 25 }, effects: { gold: -25, reputation: 4, charm: 1 }, result: 'คุณได้รับการยอมรับในวงการช่างฝีมือ' },
        { label: 'ทำงานอิสระต่อไป', effects: { luck: 1, strength: 1 }, result: 'คุณยังคงทำงานตามลำพัง และได้ฝีมือที่แกร่งขึ้น' },
      ],
    },
    {
      id: 'adult_tax',
      title: 'ผู้เก็บภาษี',
      scene: 'city',
      minAge: 25,
      maxAge: 60,
      when: { notCareer: ['king'] },
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
      id: 'adult_dinner',
      title: 'งานเลี้ยงของขุนนาง',
      scene: 'city',
      minAge: 20,
      maxAge: 45,
      text: 'ขุนนางผู้มีอิทธิพลเชิญคุณไปร่วมงานเลี้ยงค่ำในคฤหาสน์',
      choices: [
        { label: 'ตอบรับและแสดงตัวให้ดี', effects: { charm: 2, reputation: 3, gold: 20 }, result: 'งานเลี้ยงนั้นทำให้คุณมีเพื่อนในวงสังคมชั้นสูง' },
        { label: 'ขอตัวไปหาความสงบในป่า', effects: { luck: 2, charm: -1 }, result: 'คุณได้พบความสงบ แต่โอกาสทางสังคมก็หายไป' },
      ],
    },

    // ---------- เส้นทางโจร ----------
    {
      id: 'adult_bandit',
      title: 'ข้อเสนอของโจรป่า',
      scene: 'camp',
      minAge: 22,
      maxAge: 55,
      weight: 1,
      when: { notCareer: ['king', 'knight', 'outlaw', 'dragonrider'] },
      text: 'หัวหน้าโจรป่ามองคุณข้ามกองไฟ แล้วเสนอที่นั่งในก๊กโจรของเขา',
      choices: [
        {
          label: 'ร่วมปล้นขบวนพ่อค้าใหญ่',
          check: {
            stat: 'luck',
            dc: 11,
            pass: { result: 'แผนสำเร็จ คุณได้ทองกองโตและที่นั่งในก๊กโจร', effects: { gold: 100, reputation: -8 }, career: 'outlaw', set: ['outlaw'] },
            fail: { result: 'ทหารรักษาการณ์มาถึงก่อน คุณถูกจับโยนเข้าคุกใต้ดิน', effects: { health: -15, reputation: -8 }, set: ['prisoner'] },
          },
        },
        { label: 'ปฏิเสธและแจ้งทหาร', effects: { reputation: 5 }, result: 'ทหารยกย่องความซื่อสัตย์ของคุณ' },
      ],
    },
    {
      id: 'outlaw_heist',
      title: 'ปล้นคลังหลวง',
      scene: 'city',
      minAge: 25,
      maxAge: 60,
      weight: 3,
      when: { career: 'outlaw' },
      text: 'สายลับในวังกระซิบว่าคืนพระจันทร์ดับ คลังหลวงจะเฝ้ายามเพียงสองคน',
      choices: [
        {
          label: 'ลงมือปล้นคลังหลวง',
          check: {
            stat: 'luck',
            dc: 13,
            pass: { result: 'คุณขนทองออกมาได้จนเกวียนแทบหัก ชื่อของคุณกลายเป็นตำนานของโจรทุกคน', effects: { gold: 300, reputation: -5 }, set: ['bandit_king'] },
            fail: { result: 'ยามมีมากกว่าที่คิด คุณถูกล้อมจับ', effects: { health: -15 }, set: ['prisoner'] },
          },
        },
        { label: 'ปล้นแค่ขบวนพ่อค้าเล็กๆ', effects: { gold: 60, reputation: -3 }, result: 'ได้ไม่มาก แต่ปลอดภัย' },
        { label: 'วางมือจากวงการโจร', effects: { reputation: 3 }, career: null, set: ['redeemed'], result: 'คุณฝังดาบไว้ใต้ต้นไม้ แล้วเริ่มต้นชีวิตใหม่' },
      ],
    },
    {
      id: 'prison',
      title: 'คุกใต้ดิน',
      scene: 'prison',
      minAge: 15,
      maxAge: 95,
      weight: 8,
      when: { flags: ['prisoner'] },
      text: 'คุณตื่นขึ้นในห้องขังชื้นแฉะ แสงจันทร์ลอดผ่านลูกกรงเหล็กเพียงช่องเดียว',
      choices: [
        {
          label: 'ขุดอุโมงค์หลบหนี',
          check: {
            stat: 'strength',
            dc: 12,
            pass: { result: 'หลังหลายเดือนของการขุด คุณคลานออกสู่อิสรภาพใต้แสงดาว', effects: { strength: 1 }, unset: ['prisoner'], set: ['escaped'] },
            fail: { result: 'ผู้คุมพบอุโมงค์ของคุณ', die: { cause: 'คุณถูกทิ้งไว้ในคุกมืดจนสิ้นใจโดยไม่มีใครจดจำ', tag: 'prison' } },
          },
        },
        { label: 'รับโทษอย่างสงบและกลับตัว', effects: { health: -15, reputation: 3, wisdom: 1 }, career: null, unset: ['prisoner'], set: ['redeemed'], result: 'หลายปีในคุกสอนคุณมากกว่าตำราเล่มไหน คุณออกมาเป็นคนใหม่' },
      ],
    },
    {
      id: 'bounty_hunter',
      title: 'นักล่าค่าหัว',
      scene: 'camp',
      minAge: 25,
      maxAge: 70,
      weight: 2,
      when: { anyFlags: ['outlaw', 'escaped', 'bandit_king', 'deserter'] },
      text: 'นักล่าค่าหัวสวมหน้ากากเหล็กตามรอยคุณมาถึงที่ซ่อน',
      choices: [
        {
          label: 'ชักดาบสู้',
          check: {
            stat: 'strength',
            dc: 12,
            pass: { result: 'คุณล้มนักล่าค่าหัวได้ และยึดดาบของเขามาเป็นถ้วยรางวัล', effects: { reputation: 2, strength: 1 } },
            fail: { result: 'นักล่าค่าหัวแทงคุณทะลุไหล่ก่อนจะหนีไปได้', effects: { health: -30 } },
          },
        },
        { label: 'จ่ายเงินให้เขาเลิกตาม', need: { gold: 100 }, effects: { gold: -100 }, result: 'เขานับเหรียญอย่างพอใจ แล้วหายไปในหมอก' },
        { label: 'หนีข้ามแดน', effects: { gold: -20, luck: -1, health: -5 }, result: 'คุณหนีข้ามภูเขาไปเริ่มต้นใหม่ในแดนไกล' },
      ],
    },

    // ---------- เส้นทางนักผจญภัย ----------
    {
      id: 'adult_relic_quest',
      title: 'อาวุธแห่งเทพ',
      scene: 'ruins',
      minAge: 20,
      maxAge: 50,
      when: { notCareer: ['king', 'knight', 'mage', 'merchant'] },
      text: 'มีผู้ชักชวนให้ร่วมขบวนไปค้นหาอาวุธของเทพในซากปรักหักพังกลางทะเลทราย',
      choices: [
        { label: 'ออกเดินทางร่วมขบวน', effects: { strength: 2, wisdom: 1, health: -12 }, career: 'adventurer', set: ['relic_seen'], result: 'คุณไม่พบอาวุธ แต่พบประตูหินแกะสลักที่ส่องแสงอ่อนๆ ในซากวิหาร และกลายเป็นนักผจญภัยเต็มตัว' },
        { label: 'ปฏิเสธและอยู่บ้าน', effects: {}, result: 'คุณไม่มีวันรู้เลยว่าในซากปรักนั้นมีอะไร' },
      ],
    },
    {
      id: 'adventurer_hydra',
      title: 'ล่าไฮดรา',
      scene: 'cave',
      minAge: 22,
      maxAge: 55,
      weight: 3,
      when: { career: 'adventurer' },
      text: 'กิลด์นักผจญภัยประกาศค่าหัวไฮดราเก้าหัวที่ซ่อนตัวในถ้ำคริสตัล',
      choices: [
        {
          label: 'บุกเข้าไปล่าซึ่งหน้า',
          check: {
            stat: 'strength',
            dc: 13,
            pass: { result: 'หัวสุดท้ายของไฮดราร่วงลง คุณกลับมาพร้อมเงินรางวัลและชื่อเสียง', effects: { gold: 150, reputation: 8 }, set: ['monster_slayer'] },
            fail: { result: 'ไฮดราพุ่งเข้าหาคุณจากทุกทิศ', die: { cause: 'ไฮดราเก้าหัวฉีกร่างของคุณกลางถ้ำคริสตัล', tag: 'monster' } },
          },
        },
        {
          label: 'วางกับดักอย่างรอบคอบ',
          check: {
            stat: 'wisdom',
            dc: 12,
            pass: { result: 'ไฮดราติดกับดักของคุณ งานนี้ใช้สมองมากกว่าดาบ', effects: { gold: 120, reputation: 6 }, set: ['monster_slayer'] },
            fail: { result: 'กับดักพังก่อนเวลา คุณหนีออกจากถ้ำมาได้พร้อมแผลไฟลวก', effects: { health: -25 } },
          },
        },
        { label: 'ปล่อยให้คนอื่นไปล่า', effects: {}, result: 'คุณนั่งดื่มในโรงเตี๊ยม ฟังข่าวการล่าจากปากคนอื่น' },
      ],
    },
    {
      id: 'adventurer_portal',
      title: 'ประตูมิติ',
      scene: 'portal',
      minAge: 30,
      maxAge: 80,
      weight: 1.5,
      when: { flags: ['relic_seen'] },
      text: 'คุณกลับมายังซากวิหารอีกครั้ง ประตูหินที่เคยเห็นตอนนี้หมุนวนด้วยแสงสีม่วง เสียงจากอีกฟากเรียกชื่อคุณ',
      choices: [
        { label: 'ก้าวผ่านประตูไป', ending: 'vanished', result: 'คุณก้าวเข้าไปในแสงโดยไม่หันหลังกลับ ประตูปิดลงตามหลัง และไม่มีใครเห็นคุณอีกเลย' },
        { label: 'ปิดผนึกประตูไว้', effects: { reputation: 6, wisdom: 2 }, unset: ['relic_seen'], result: 'คุณจารึกคาถาผนึกไว้รอบประตู โลกนี้ปลอดภัยไปอีกนาน' },
      ],
    },

    // ---------- เส้นทางมังกร ----------
    {
      id: 'dragon_return',
      title: 'มังกรกลับมา',
      scene: 'dragon_sky',
      minAge: 20,
      maxAge: 55,
      weight: 4,
      when: { flags: ['dragon_friend'] },
      text: 'เงาปีกมหึมาบดบังดวงอาทิตย์ มังกรน้อยที่คุณเคยช่วยไว้ บัดนี้เติบโตเต็มวัยและบินลงมาหาคุณ',
      choices: [
        { label: 'ขึ้นขี่หลังมัน', effects: { reputation: 6, strength: 1 }, career: 'dragonrider', set: ['dragon_rider'], result: 'ลมหนาวตีหน้าขณะทะยานขึ้นเหนือเมฆ คุณกลายเป็นผู้ขี่มังกรคนแรกในรอบพันปี' },
        { label: 'ขอเกล็ดทองเป็นที่ระลึก', effects: { gold: 120, luck: 1 }, unset: ['dragon_friend'], result: 'มังกรสะบัดเกล็ดทองให้กองหนึ่ง ก่อนบินจากไปตลอดกาล' },
      ],
    },
    {
      id: 'dragon_war',
      title: 'ศึกเหนือเมฆา',
      scene: 'battlefield',
      minAge: 28,
      maxAge: 75,
      weight: 4,
      when: { flags: ['dragon_rider'] },
      text: 'กองทัพอสูรบุกจากแดนเหนือ ทั้งอาณาจักรเงยหน้ามองหาผู้ขี่มังกร',
      choices: [
        {
          label: 'นำมังกรออกรบ',
          check: {
            stat: 'strength',
            dc: 12,
            pass: { result: 'เปลวไฟมังกรกวาดกองทัพอสูรสิ้นซาก คุณและมังกรบินขึ้นสู่ฟ้าแล้วไม่เคยกลับลงมาอีก กลายเป็นตำนาน', ending: 'dragon_legend' },
            fail: { result: 'ธนูอสูรนับพันพุ่งขึ้นฟ้า', die: { cause: 'คุณร่วงจากหลังมังกรกลางสนามรบ', tag: 'battle' } },
          },
        },
        { label: 'พามังกรหลบไปซ่อน', effects: { reputation: -8, health: 5 }, result: 'อาณาจักรรอดมาได้อย่างยากลำบาก แต่ไม่มีใครลืมว่าผู้ขี่มังกรหายไปไหน' },
      ],
    },
    {
      id: 'dragon_revenge',
      title: 'แม่มังกรทวงแค้น',
      scene: 'fortress',
      minAge: 18,
      maxAge: 60,
      weight: 4,
      when: { flags: ['dragon_thief'] },
      text: 'แม่มังกรที่คุณเคยขโมยไข่ตามกลิ่นมาจนพบ เปลวไฟพวยพุ่งเหนือหลังคาหมู่บ้าน',
      choices: [
        {
          label: 'คว้าหอกออกไปสู้',
          check: {
            stat: 'strength',
            dc: 14,
            pass: { result: 'หอกของคุณแทงทะลุหัวใจมังกร ทั้งแผ่นดินเรียกคุณว่าผู้สังหารมังกร', effects: { reputation: 12, gold: 80 }, unset: ['dragon_thief'], set: ['dragon_slayer'] },
            fail: { result: 'แม่มังกรอ้าปากกว้าง', die: { cause: 'เปลวไฟของแม่มังกรแผดเผาคุณจนเป็นเถ้า', tag: 'monster' } },
          },
        },
        { label: 'ยอมคืนทองและขอขมา', need: { gold: 50 }, effects: { gold: -50, wisdom: 1 }, unset: ['dragon_thief'], result: 'แม่มังกรจ้องคุณนาน ก่อนรับทองแล้วบินจากไป' },
        { label: 'ทิ้งบ้านหนีไปเมืองอื่น', effects: { gold: -30, luck: -1 }, unset: ['dragon_thief'], result: 'บ้านเก่าของคุณกลายเป็นเถ้าถ่าน แต่คุณรอดมาได้' },
      ],
    },

    // ---------- คำสาปและการรักษา ----------
    {
      id: 'cursed_ring',
      title: 'เสียงกระซิบจากแหวน',
      scene: 'graveyard',
      minAge: 22,
      maxAge: 65,
      weight: 3,
      when: { flags: ['dark_ring'] },
      text: 'แหวนดำจากสุสานเริ่มกระซิบในความฝันทุกคืน มันสัญญาว่าจะมอบพลังให้ถ้าคุณยอมรับมัน',
      choices: [
        {
          label: 'ยอมรับพลังของแหวน',
          check: {
            stat: 'wisdom',
            dc: 12,
            pass: { result: 'คุณควบคุมวิญญาณในแหวนได้ พลังลึกลับไหลเวียนในกาย', effects: { wisdom: 4, strength: 2 }, unset: ['dark_ring'], set: ['ring_master'] },
            fail: { result: 'เสียงกระซิบดังขึ้นจนกลบเสียงของคุณเอง', die: { cause: 'วิญญาณในแหวนกลืนกินร่างของคุณ', tag: 'curse' } },
          },
        },
        { label: 'โยนแหวนลงแม่น้ำ', effects: { luck: 2, health: 5 }, unset: ['dark_ring'], result: 'แหวนจมหายไปในสายน้ำ คืนนั้นคุณหลับสนิทเป็นครั้งแรกในรอบหลายปี' },
      ],
    },
    {
      id: 'adult_fever',
      title: 'ไข้ป่าระบาด',
      scene: 'rain_village',
      minAge: 18,
      maxAge: 60,
      text: 'คุณล้มป่วยด้วยไข้ป่าที่กำลังระบาดในหมู่บ้าน',
      choices: [
        { label: 'ไปหาหมอแห่งหอคอย', need: { gold: 30 }, effects: { gold: -30, health: 25 }, result: 'หมอรักษาจนหายดี แม้ค่ารักษาจะแพงไม่น้อย' },
        {
          label: 'รักษาเองด้วยสมุนไพร',
          check: {
            stat: 'wisdom',
            dc: 9,
            pass: { result: 'คุณปรุงยาได้สำเร็จ และค้นพบว่าตัวเองมีฝีมือด้านสมุนไพร', effects: { health: 15, wisdom: 1 }, set: ['herbalist'] },
            fail: { result: 'ยาไม่ได้ผล อาการทรุดลงอีกนิด', effects: { health: -12 } },
          },
        },
      ],
    },
    {
      id: 'healer_path',
      title: 'หมอประจำหมู่บ้าน',
      scene: 'village',
      minAge: 20,
      maxAge: 55,
      weight: 3,
      when: { flags: ['herbalist'], notCareer: ['king', 'healer'] },
      text: 'ข่าวเรื่องฝีมือปรุงยาของคุณแพร่ไป ชาวบ้านขอให้คุณเป็นหมอประจำหมู่บ้าน',
      choices: [
        { label: 'รับเป็นหมอยา', effects: { reputation: 3, charm: 1 }, career: 'healer', result: 'บ้านของคุณมีกลิ่นสมุนไพรอบอวลตลอดวัน และมีคนมาขอบคุณไม่ขาดสาย' },
        { label: 'ปฏิเสธ', effects: {}, result: 'คุณเก็บความรู้นั้นไว้ใช้กับคนในบ้านเท่านั้น' },
      ],
    },
    {
      id: 'plague',
      title: 'โรคระบาดดำ',
      scene: 'rain_village',
      minAge: 28,
      maxAge: 70,
      weight: 0.6,
      text: 'โรคระบาดดำกวาดเมือง ศพเรียงรายตามท้องถนน ผู้คนต่างหนีขึ้นเขา',
      choices: [
        {
          label: 'อยู่ช่วยรักษาผู้ป่วย',
          check: {
            stat: 'wisdom',
            dc: 12,
            pass: { result: 'คุณค้นพบตำรับยาที่หยุดโรคระบาดได้ ชาวเมืองเรียกคุณว่านักบุญ', effects: { reputation: 14 }, set: ['saint'] },
            fail: { result: 'คุณรักษาคนได้นับร้อย แต่โรคร้ายก็มาถึงตัวคุณในที่สุด', die: { cause: 'คุณติดโรคระบาดขณะดูแลผู้ป่วยคนสุดท้าย', tag: 'plague' } },
          },
        },
        { label: 'อพยพครอบครัวขึ้นเขา', effects: { health: 2, reputation: -1 }, result: 'คุณพาครอบครัวรอดมาได้ ทุกคนปลอดภัย' },
        { label: 'ขายยาเถื่อนราคาแพง', effects: { gold: 120, reputation: -10 }, result: 'คุณร่ำรวยขึ้นมากในฤดูแห่งความตาย และหลายคนจะไม่มีวันให้อภัย' },
      ],
    },
    {
      id: 'hermit_call',
      title: 'เสียงเรียกจากขุนเขา',
      scene: 'dragon_vale',
      minAge: 45,
      maxAge: 80,
      weight: 0.6,
      when: { partner: false, notCareer: ['king', 'hermit'] },
      text: 'คุณรู้สึกเบื่อหน่ายความวุ่นวายของโลก ยอดเขาหิมะที่อยู่ไกลออกไปเหมือนกำลังเรียกหา',
      choices: [
        { label: 'ละทิ้งทุกอย่างขึ้นไปบำเพ็ญบนเขา', effects: { wisdom: 3, health: 5, gold: -20 }, career: 'hermit', set: ['hermit'], result: 'คุณสร้างกระท่อมหินบนยอดเขา มีเพียงลมและเมฆเป็นเพื่อน' },
        { label: 'ยังมีสิ่งที่ต้องทำในโลกนี้', effects: { charm: 1 }, result: 'คุณมองยอดเขาครู่หนึ่ง แล้วกลับไปใช้ชีวิตตามเดิม' },
      ],
    },

    // ---------- เหตุการณ์ทั่วไปที่เกิดซ้ำได้ ----------
    {
      id: 'market_fair',
      title: 'ตลาดนัดประจำปี',
      scene: 'city',
      minAge: 16,
      maxAge: 90,
      weight: 0.8,
      repeatable: true,
      cooldown: 6,
      text: 'ตลาดนัดประจำปีเต็มไปด้วยพ่อค้าเร่จากทั่วทวีป',
      choices: [
        { label: 'ซื้อยาอายุวัฒนะ', need: { gold: 30 }, effects: { gold: -30, health: 15 }, result: 'ยาขมปี๋ แต่คุณรู้สึกสดชื่นขึ้นจริงๆ' },
        { label: 'ซื้อตำราเก่า', need: { gold: 20 }, effects: { gold: -20, wisdom: 1 }, result: 'ตำราเล่มนั้นมีบันทึกของนักปราชญ์ที่คุณไม่เคยรู้จัก' },
        { label: 'เดินชมเฉยๆ', effects: { charm: 1 }, result: 'คุณได้คุยกับผู้คนมากมาย สนุกไปอีกแบบ' },
      ],
    },
    {
      id: 'tavern_dice',
      title: 'วงพนันในโรงเตี๊ยม',
      scene: 'festival',
      minAge: 18,
      maxAge: 80,
      weight: 0.7,
      repeatable: true,
      cooldown: 7,
      text: 'ในโรงเตี๊ยมมีวงพนันลูกเต๋า เสียงเหรียญกระทบโต๊ะดังไม่ขาดสาย',
      choices: [
        {
          label: 'ลงพนัน 30 ทอง',
          need: { gold: 30 },
          effects: { gold: -30 },
          check: {
            stat: 'luck',
            dc: 11,
            pass: { result: 'ลูกเต๋าเข้าข้างคุณ คุณกวาดเงินทั้งโต๊ะ', effects: { gold: 75 } },
            fail: { result: 'ลูกเต๋าไม่เข้าข้าง เงินของคุณหายไปกับเสียงหัวเราะ', effects: {} },
          },
        },
        { label: 'ดื่มสักแก้วแล้วกลับบ้าน', effects: { charm: 1, health: -2 }, result: 'คุณได้เพื่อนดื่มใหม่สองสามคน' },
      ],
    },
    {
      id: 'bard_song',
      title: 'กวีพเนจร',
      scene: 'road',
      minAge: 10,
      maxAge: 90,
      weight: 0.6,
      repeatable: true,
      cooldown: 9,
      text: 'กวีพเนจรหยุดพักที่หมู่บ้าน เสียงพิณของเขาเล่าตำนานจากแดนไกล',
      choices: [
        { label: 'นั่งฟังจนจบเพลง', effects: { charm: 1, wisdom: 1 }, result: 'บทเพลงทำให้คุณใฝ่ฝันถึงโลกกว้าง' },
        { label: 'เล่าเรื่องของคุณให้เขาแต่งเพลง', need: { stats: { reputation: 6 } }, effects: { reputation: 3 }, result: 'ไม่กี่ปีต่อมา เพลงเกี่ยวกับคุณถูกร้องไปทั่วโรงเตี๊ยม' },
      ],
    },
    {
      id: 'adult_mine',
      title: 'เหมืองแร่เรืองแสง',
      scene: 'cave',
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

    // ---------- วัยชรา ----------
    {
      id: 'elder_chronicle',
      title: 'ตำนานของผู้เฒ่า',
      scene: 'elder_home',
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
      title: 'ร่างกายที่ร่วงโรย',
      scene: 'elder_home',
      minAge: 60,
      maxAge: 90,
      text: 'ข้อต่อของคุณเริ่มปวดจนเดินลำบาก',
      choices: [
        { label: 'ไปหาหมอผู้เชี่ยวชาญ', need: { gold: 40 }, effects: { gold: -40, health: 15 }, result: 'อาการดีขึ้นมาก' },
        { label: 'ทนรอให้หายเอง', effects: { health: -8 }, result: 'อาการไม่ดีขึ้นเลย' },
      ],
    },
    {
      id: 'elder_blessing',
      title: 'คำอวยพรสุดท้าย',
      scene: 'village',
      minAge: 60,
      maxAge: 95,
      text: 'เด็กหนุ่มคนหนึ่งขอให้คุณให้พรก่อนเดินทางไปเมืองหลวง',
      choices: [
        { label: 'ให้พรด้วยความเมตตา', effects: { charm: 2, reputation: 3, luck: 1 }, result: 'เด็กคนนั้นจดจำคำอวยพรของคุณไปตลอดชีวิต' },
        { label: 'บอกว่าไม่มีเวลา', effects: { reputation: -1 }, result: 'เขาเดินจากไปอย่างผิดหวัง' },
      ],
    },
    {
      id: 'elder_grandchildren',
      title: 'เสียงหัวเราะของหลาน',
      scene: 'elder_home',
      minAge: 58,
      maxAge: 95,
      weight: 3,
      when: { minChildren: 1 },
      text: 'หลานๆ วิ่งเล่นรอบตัวคุณใต้ต้นไม้ใหญ่ แล้วรบเร้าขอฟังนิทาน',
      choices: [
        { label: 'เล่านิทานเรื่องชีวิตของตัวเอง', effects: { health: 5, charm: 1 }, set: ['grandparent'], result: 'ดวงตาของหลานเป็นประกาย เรื่องของคุณจะถูกเล่าต่อไปอีกหลายรุ่น' },
        { label: 'สอนวิชาที่ตัวเองถนัดให้', effects: { wisdom: 1, health: 3 }, set: ['grandparent'], result: 'มือเล็กๆ ที่จับดาบไม้ ทำให้คุณนึกถึงตัวเองเมื่อนานมาแล้ว' },
      ],
    },
    {
      id: 'elder_last_journey',
      title: 'การเดินทางครั้งสุดท้าย',
      scene: 'road',
      minAge: 66,
      maxAge: 95,
      text: 'คุณฝันถึงถนนสายที่ไม่เคยเดิน และอยากออกเดินทางอีกสักครั้งก่อนสิ้นลม',
      choices: [
        {
          label: 'แบกย่ามออกเดินทาง',
          check: {
            stat: 'luck',
            dc: 10,
            pass: { result: 'คุณได้เห็นทะเลทางทิศใต้เป็นครั้งแรก และกลับบ้านพร้อมรอยยิ้ม', effects: { reputation: 3, wisdom: 2 }, set: ['last_journey'] },
            fail: { result: 'คืนหนึ่งใต้ฟ้าเต็มไปด้วยดาว', die: { cause: 'คุณหลับไปอย่างสงบระหว่างทาง ใต้ดวงดาวนับล้าน', tag: 'journey' } },
          },
        },
        { label: 'อยู่บ้านกับความทรงจำ', effects: { health: 3 }, result: 'คุณนั่งมองถนนจากหน้าต่าง แล้วยิ้มให้กับทุกเส้นทางที่ผ่านมา' },
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

  // ตอนจบเรียงตามลำดับความสำคัญ ตัวแรกที่เงื่อนไขเป็นจริงจะถูกเลือก
  // ตอนจบที่มี forced จะเกิดได้เฉพาะเมื่อเหตุการณ์สั่ง ending เท่านั้น
  const has = (l, f) => !!l.flags[f];
  const ENDINGS = [
    { id: 'lich', forced: true, title: 'จอมเวทย์อมตะ', scene: 'portal', hint: 'ผู้ที่ไม่ยอมแพ้ต่อความตาย', text: '{name} ไม่เคยตาย ร่างกายกลายเป็นเงาแห่งเวทมนตร์ที่เฝ้าหอคอยอยู่ชั่วนิรันดร์ ผู้คนยังเห็นแสงไฟในหน้าต่างบนสุดทุกคืน' },
    { id: 'vanished', forced: true, title: 'ผู้ก้าวข้ามมิติ', scene: 'portal', hint: 'บางประตูเปิดไปสู่ที่ที่ไม่มีทางกลับ', text: 'ไม่มีใครรู้ว่า {name} ไปอยู่ที่ใด บางคนว่ากลายเป็นราชาในโลกอื่น บางคนว่ายังเดินทางอยู่ระหว่างดวงดาว' },
    { id: 'dragon_legend', forced: true, title: 'ตำนานผู้ขี่มังกร', scene: 'dragon_sky', hint: 'มิตรภาพที่เริ่มจากกับดักเหล็กในวัยเด็ก', text: 'ทุกครั้งที่ฟ้าร้องเหนือขุนเขา ผู้คนเชื่อว่าเป็นเสียงปีกมังกรของ {name} ที่ยังบินลาดตระเวนปกป้องอาณาจักร' },

    { id: 'executed', title: 'กบฏผู้พ่ายแพ้', scene: 'prison', hint: 'บัลลังก์ที่เอื้อมไม่ถึง', test: (l) => l.deathTag === 'executed', text: 'ศีรษะของ {name} ถูกแขวนไว้ที่ประตูเมือง แต่ราษฎรบางคนยังแอบวางดอกไม้ให้ในยามค่ำคืน' },
    { id: 'assassinated', title: 'กษัตริย์ผู้ถูกลอบสังหาร', scene: 'royal', hint: 'มงกุฎหนักกว่าที่คิด', test: (l) => l.deathTag === 'assassinated', text: 'รัชสมัยของ {name} จบลงด้วยคมมีดในความมืด บัลลังก์ว่างลงอีกครั้งท่ามกลางเสียงกระซิบ' },
    { id: 'prison', title: 'นักโทษผู้ถูกลืม', scene: 'prison', hint: 'ลูกกรงเหล็กกับแสงจันทร์ช่องเดียว', test: (l) => l.deathTag === 'prison', text: 'ชื่อของ {name} ถูกขีดเขียนไว้บนผนังคุกเท่านั้น ไม่มีหลุมศพ ไม่มีผู้ไว้อาลัย' },
    { id: 'fallen_hero', title: 'วีรชนผู้สละชีพ', scene: 'battlefield', hint: 'ล้มลงกลางสมรภูมิ', test: (l) => l.deathTag === 'battle', text: '{name} ล้มลงกลางสนามรบ ธงของอาณาจักรถูกห่มร่างไว้ และเพลงสรรเสริญยังถูกขับร้องทุกปี' },
    { id: 'monster_prey', title: 'เหยื่อแห่งอสูร', scene: 'cave', hint: 'บางสิ่งไม่ควรท้าทาย', test: (l) => l.deathTag === 'monster', text: 'ไม่มีใครพบร่างของ {name} มีเพียงอาวุธที่หักสะบั้นวางอยู่ปากถ้ำ เป็นคำเตือนแก่ผู้มาเยือน' },
    { id: 'plague_martyr', title: 'ผู้พลีชีพในโรคระบาด', scene: 'rain_village', hint: 'อยู่ช่วยคนอื่นเมื่อทุกคนหนี', test: (l) => l.deathTag === 'plague', text: '{name} ช่วยชีวิตคนได้นับร้อยก่อนจะจากไป ทุกบ้านในเมืองจุดเทียนให้ในคืนที่ฝนตก' },
    { id: 'cursed', title: 'ร่างที่ถูกสาปสิง', scene: 'graveyard', hint: 'ของจากสุสานควรอยู่ในสุสาน', test: (l) => l.deathTag === 'curse', text: 'ร่างของ {name} ยังเดินไปมาในสุสานทุกคืนเดือนมืด แต่สิ่งที่อยู่ข้างในไม่ใช่ {name} อีกต่อไป' },
    { id: 'failed_ritual', title: 'จอมเวทย์ผู้พลาดพลั้ง', scene: 'portal', hint: 'ความเป็นอมตะมีราคาแพง', test: (l) => l.deathTag === 'ritual', text: 'เถ้าสีม่วงของ {name} ปลิวไปตามลม คัมภีร์ต้องห้ามถูกฝังไว้กับห้องที่ไม่มีใครกล้าเปิดอีก' },
    { id: 'last_journey', title: 'ผู้เดินทางจนลมหายใจสุดท้าย', scene: 'road', hint: 'ออกเดินทางแม้ในวัยชรา', test: (l) => l.deathTag === 'journey', text: '{name} ไม่เคยหยุดเดินทาง แม้ในวันสุดท้ายก็ยังมองไปยังขอบฟ้าที่ยังไม่เคยไป' },
    { id: 'died_young', title: 'ดวงดาวที่ดับเร็วเกินไป', scene: 'graveyard', hint: 'จากไปก่อนอายุ 30', test: (l) => l.age < 30, text: 'ชีวิตของ {name} สั้นเกินกว่าจะเป็นตำนาน แต่ผู้ที่รู้จักยังจดจำรอยยิ้มนั้นได้ไม่ลืม' },

    { id: 'tyrant', title: 'ทรราชบนบัลลังก์ทอง', scene: 'royal', hint: 'กษัตริย์ที่เลือกพระราชวังมากกว่าราษฎร', test: (l) => has(l, 'king') && has(l, 'tyrant'), text: 'ราษฎรเฉลิมฉลองในวันที่ {name} สิ้นพระชนม์ พระราชวังหินอ่อนยังตั้งตระหง่าน เย็นชาเหมือนผู้สร้าง' },
    { id: 'good_king', title: 'กษัตริย์ผู้เป็นที่รัก', scene: 'royal', hint: 'จากอัศวินสู่บัลลังก์', test: (l) => has(l, 'king'), text: 'ทั้งแผ่นดินไว้ทุกข์ให้ {name} นานหนึ่งปีเต็ม รัชสมัยนั้นถูกจารึกว่าเป็นยุคทองของอาณาจักร' },
    { id: 'bandit_king', title: 'ราชาแห่งโจรป่า', scene: 'camp', hint: 'ปล้นสิ่งที่ไม่มีใครกล้าปล้น', test: (l) => has(l, 'bandit_king'), text: 'โจรทุกก๊กยังดื่มอวยพรให้ {name} รอบกองไฟ ทองจากคลังหลวงที่หายไปยังไม่มีใครหาเจอ' },
    { id: 'archmage', title: 'เจ้าแห่งหอคอยสูงสุด', scene: 'tower', hint: 'ไต่ขึ้นสู่ยอดของศาสตร์เวทมนตร์', test: (l) => has(l, 'archmage'), text: 'ตำราที่ {name} เขียนไว้ยังถูกใช้สอนในหอคอยทุกแห่ง ดาวดวงหนึ่งบนฟ้าถูกตั้งชื่อตาม {name}' },
    { id: 'trade_prince', title: 'เจ้าชายแห่งการค้า', scene: 'harbor', hint: 'เรือสินค้าและสมาคมพ่อค้า', test: (l) => has(l, 'guild_master') || has(l, 'trade_prince'), text: 'เรือที่ติดธงของ {name} ยังแล่นอยู่ทั่วทะเล ทุกเมืองท่ามีถนนที่ตั้งชื่อตามพ่อค้าผู้ยิ่งใหญ่คนนี้' },
    { id: 'saint', title: 'นักบุญแห่งโรคระบาด', scene: 'village', hint: 'หยุดโรคร้ายด้วยความรู้', test: (l) => has(l, 'saint'), text: 'รูปปั้นของ {name} ตั้งอยู่กลางเมือง แม่ๆ ยังพาลูกมาขอพรให้แข็งแรงทุกเช้า' },
    { id: 'dragon_slayer', title: 'ผู้สังหารมังกร', scene: 'fortress', hint: 'ชดใช้บาปในวัยเด็กด้วยหอก', test: (l) => has(l, 'dragon_slayer'), text: 'กะโหลกมังกรที่ {name} สังหารถูกแขวนไว้ในห้องโถงพระราชวัง เป็นเครื่องเตือนใจถึงความกล้าและความผิดในอดีต' },
    { id: 'monster_slayer', title: 'นักล่าอสูรในตำนาน', scene: 'ruins', hint: 'ไฮดราเก้าหัวในถ้ำคริสตัล', test: (l) => has(l, 'monster_slayer'), text: 'กิลด์นักผจญภัยแขวนภาพของ {name} ไว้เหนือเคาน์เตอร์ นักผจญภัยรุ่นใหม่ทุกคนต้องคารวะก่อนรับงาน' },
    { id: 'ring_master', title: 'ผู้ครองวิญญาณ', scene: 'graveyard', hint: 'เอาชนะเสียงกระซิบจากแหวนดำ', test: (l) => has(l, 'ring_master'), text: '{name} จากไปพร้อมแหวนดำที่นิ้ว ว่ากันว่าวิญญาณในแหวนยังเฝ้าหลุมศพนั้นอย่างซื่อสัตย์' },
    { id: 'hermit', title: 'ฤๅษีแห่งขุนเขา', scene: 'dragon_vale', hint: 'ละทิ้งโลกเพื่อความสงบ', test: (l) => has(l, 'hermit'), text: 'ผู้ที่ปีนขึ้นไปถึงกระท่อมหินของ {name} เล่าว่า ที่นั่นเงียบสงบจนได้ยินเสียงเมฆเคลื่อนผ่าน' },

    { id: 'family', title: 'ร่มโพธิ์ร่มไทรของครอบครัว', scene: 'elder_home', hint: 'ได้เห็นหลานเติบโต', test: (l) => has(l, 'grandparent') || (l.partner && l.children >= 2 && l.age >= 55), text: 'ลูกหลานของ {name} มารวมตัวกันใต้ต้นไม้ใหญ่ เล่าเรื่องราวของผู้ที่สร้างครอบครัวนี้ขึ้นมาด้วยความรัก' },
    { id: 'true_love', title: 'รักแรกจนวันสุดท้าย', scene: 'lake', hint: 'ดอกไม้ป่าริมทะเลสาบ', test: (l) => has(l, 'true_love') && l.partner, text: '{name} จากไปโดยมีมือของรักแรกกุมไว้ ริมทะเลสาบแห่งนั้นยังมีดอกไม้ป่าบานทุกปี' },
    { id: 'lonely_road', title: 'ผู้เดินทางลำพัง', scene: 'road', hint: 'เลือกอิสระมากกว่าพันธะ', test: (l) => has(l, 'free_spirit') && !l.partner && l.age >= 50, text: '{name} ใช้ชีวิตอย่างอิสระจนวันสุดท้าย ไม่มีพันธะ ไม่มีบ้าน มีเพียงถนนที่ทอดยาวไม่สิ้นสุด' },
    { id: 'war_hero', title: 'วีรชนผู้ผ่านศึก', scene: 'fortress', hint: 'รอดกลับมาจากสงคราม', test: (l) => has(l, 'war_hero') || l.career === 'knight', text: 'เหรียญกล้าหาญของ {name} ถูกวางไว้บนหลุมศพ ทหารผ่านศึกรุ่นเดียวกันมายืนตรงคารวะเป็นครั้งสุดท้าย' },
    { id: 'redeemed', title: 'ผู้กลับใจ', scene: 'village', hint: 'วางดาบโจรแล้วเริ่มใหม่', test: (l) => has(l, 'redeemed'), text: 'ในวันสุดท้าย {name} ไม่ใช่โจรอีกแล้ว แต่เป็นเพื่อนบ้านใจดีที่ทุกคนจะคิดถึง' },
    { id: 'rich', title: 'เศรษฐีแห่งเมืองท่า', scene: 'harbor', hint: 'สะสมทองให้ถึง 300', test: (l) => l.stats.gold >= 300, text: 'ทรัพย์สมบัติของ {name} ถูกแบ่งให้ลูกหลานและวัดวาอาราม ร่ำลือกันว่ายังมีหีบทองซ่อนอยู่อีกหลายใบ' },
    { id: 'famous', title: 'ผู้กล้าที่ชาวบ้านจดจำ', scene: 'city', hint: 'มีชื่อเสียง 25 ขึ้นไป', test: (l) => l.stats.reputation >= 25, text: 'ชื่อของ {name} ถูกขับขานในบทเพลงของกวีพเนจร จากหมู่บ้านเล็กๆ ไปจนถึงเมืองหลวง' },
    { id: 'sage', title: 'ปราชญ์ผู้รอบรู้', scene: 'tower', hint: 'มีปัญญา 17 ขึ้นไป', test: (l) => l.stats.wisdom >= 17, text: 'ผู้คนยังเดินทางมาไกลเพื่ออ่านบันทึกที่ {name} ทิ้งไว้ ทุกหน้ามีคำตอบที่โลกกำลังตามหา' },
    { id: 'strongman', title: 'นักรบผู้ไม่เคยก้มหัว', scene: 'fortress', hint: 'มีกำลัง 15 ขึ้นไป', test: (l) => l.stats.strength >= 15, text: 'ดาบของ {name} ถูกปักไว้บนเนินหน้าหมู่บ้าน ไม่มีใครดึงออกได้อีกเลยนับจากวันนั้น' },
    { id: 'beloved', title: 'กวีผู้เป็นที่รัก', scene: 'lake', hint: 'มีเสน่ห์ 15 ขึ้นไป', test: (l) => l.stats.charm >= 15, text: 'งานศพของ {name} มีผู้คนมาร่วมมากที่สุดในประวัติศาสตร์หมู่บ้าน ทุกคนมีเรื่องดีๆ จะเล่า' },
    { id: 'lucky', title: 'ผู้โชคดีแห่งทวีป', scene: 'festival', hint: 'มีโชค 13 ขึ้นไป', test: (l) => l.stats.luck >= 13, text: 'ตลอดชีวิต {name} รอดพ้นภัยมานับครั้งไม่ถ้วน เหรียญนำโชคของ {name} ยังถูกส่งต่อกันในหมู่นักพนัน' },
    { id: 'villager', title: 'ชาวบ้านผู้ซื่อสัตย์', scene: 'ending', hint: 'ชีวิตเรียบง่ายที่ไม่มีอะไรโดดเด่น', test: () => true, text: '{name} ใช้ชีวิตอย่างเรียบง่ายและซื่อตรง ไม่มีบทเพลงใดขับขาน แต่ต้นไม้ที่ปลูกไว้ยังให้ร่มเงาแก่ผู้คน' },
  ];

  return { ORIGINS, CAREERS, EVENTS, QUIET_YEARS, ENDINGS };
});
