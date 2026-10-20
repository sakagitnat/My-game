// ภาพประกอบเป็น SVG ทั้งหมด ไม่ต้องใช้ไฟล์ภาพ ทุกภาพเป็นค่าคงที่ที่เขียนในโค้ดนี้เอง
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  } else {
    root.LifeArt = api;
  }
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  // ช่วงวัยของชีวิต ใช้เลือกฉากประกอบ
  function stageOf(age) {
    if (age < 13) return 'child';
    if (age < 18) return 'youth';
    if (age < 60) return 'adult';
    return 'elder';
  }

  const STAGE_TITLES = {
    child: 'วัยเยาว์',
    youth: 'วัยหนุ่มสาว',
    adult: 'วัยทำงาน',
    elder: 'วัยชรา',
  };

  const SCENES = {
    child: `
      <defs>
        <linearGradient id="sky-child" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stop-color="#7fb8d8"/><stop offset="1" stop-color="#f6e3b4"/>
        </linearGradient>
      </defs>
      <rect width="400" height="200" fill="url(#sky-child)"/>
      <circle cx="320" cy="58" r="22" fill="#fff3c4" opacity=".9"/>
      <path d="M0 150 Q90 110 180 145 T400 135 V200 H0Z" fill="#7ea86a"/>
      <path d="M0 175 Q140 150 260 172 T400 165 V200 H0Z" fill="#5d8a4f"/>
      <rect x="95" y="112" width="48" height="36" fill="#c98f5c"/>
      <path d="M88 114 L119 88 L150 114Z" fill="#8b4b35"/>
      <rect x="112" y="128" width="12" height="20" fill="#5a3322"/>
      <rect x="62" y="132" width="5" height="18" fill="#5a3322"/>
      <circle cx="64" cy="128" r="12" fill="#3f6b3c"/>
      <circle cx="300" cy="140" r="16" fill="#3f6b3c"/>
      <rect x="296" y="150" width="8" height="16" fill="#5a3322"/>`,
    youth: `
      <defs>
        <linearGradient id="sky-youth" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stop-color="#4f6f95"/><stop offset="1" stop-color="#f1c58a"/>
        </linearGradient>
      </defs>
      <rect width="400" height="200" fill="url(#sky-youth)"/>
      <path d="M0 130 L70 70 L120 115 L190 55 L260 118 L330 80 L400 125 V200 H0Z" fill="#5b5770"/>
      <path d="M0 150 L60 110 L130 150 L200 105 L300 155 L400 115 V200 H0Z" fill="#3e5a4a"/>
      <g fill="#2d2a3a">
        <rect x="235" y="98" width="72" height="62"/>
        <rect x="225" y="82" width="16" height="78"/><rect x="299" y="82" width="16" height="78"/>
        <path d="M225 82 L233 66 L241 82Z M299 82 L307 66 L315 82Z"/>
        <path d="M262 108 V140 h16 V108 Z"/>
      </g>
      <path d="M0 176 Q200 160 400 178 V200 H0Z" fill="#2f4638"/>`,
    adult: `
      <defs>
        <linearGradient id="sky-adult" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stop-color="#1d1a2e"/><stop offset="1" stop-color="#6a4c6e"/>
        </linearGradient>
      </defs>
      <rect width="400" height="200" fill="url(#sky-adult)"/>
      <circle cx="80" cy="46" r="18" fill="#f3ecd2"/>
      <g fill="#f3ecd2" opacity=".8"><circle cx="150" cy="30" r="1.5"/><circle cx="210" cy="60" r="1"/><circle cx="350" cy="28" r="1.5"/></g>
      <path d="M0 140 H60 V112 H90 V140 H140 V100 H170 V140 H230 V118 H260 V140 H400 V200 H0Z" fill="#3a3550"/>
      <rect x="296" y="60" width="40" height="92" fill="#2c2840"/>
      <path d="M292 60 L316 30 L340 60Z" fill="#2c2840"/>
      <g fill="#f5c76b"><rect x="306" y="82" width="6" height="8"/><rect x="306" y="110" width="6" height="8"/><rect x="306" y="136" width="6" height="8"/></g>
      <path d="M0 170 Q200 150 400 172 V200 H0Z" fill="#23203a"/>`,
    elder: `
      <defs>
        <linearGradient id="sky-elder" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stop-color="#3b3f6b"/><stop offset=".6" stop-color="#e88f6a"/><stop offset="1" stop-color="#f7c978"/>
        </linearGradient>
      </defs>
      <rect width="400" height="200" fill="url(#sky-elder)"/>
      <circle cx="200" cy="150" r="36" fill="#ffd98a" opacity=".95"/>
      <g fill="#fff6d8"><circle cx="50" cy="40" r="1.5"/><circle cx="110" cy="22" r="1"/><circle cx="350" cy="40" r="1.5"/></g>
      <path d="M0 150 Q100 128 200 148 T400 140 V200 H0Z" fill="#6b5b82"/>
      <path d="M0 170 Q180 158 400 172 V200 H0Z" fill="#43395e"/>
      <rect x="250" y="122" width="54" height="36" fill="#7a4b3a"/>
      <path d="M244 124 L277 96 L310 124Z" fill="#4a2e2a"/>
      <rect x="268" y="138" width="12" height="20" fill="#ffd98a"/>
      <path d="M96 176 V120" stroke="#3a2b2a" stroke-width="5"/>
      <circle cx="96" cy="108" r="22" fill="#3d4f3a"/>`,
  };

  function sceneSvg(stage) {
    const body = SCENES[stage] || SCENES.adult;
    return `<svg viewBox="0 0 400 200" preserveAspectRatio="xMidYMid slice" role="img" aria-label="${STAGE_TITLES[stage]}">${body}</svg>`;
  }

  // ไอคอนอาชีพ 48x48
  const ORIGIN_ICONS = {
    warrior: `<path d="M24 4 L40 10 V24 C40 34 33 41 24 44 C15 41 8 34 8 24 V10Z" fill="#8c6a3f" stroke="#e7c27d" stroke-width="2"/>
      <path d="M24 12 V36 M16 20 H32" stroke="#f3e0b0" stroke-width="3" stroke-linecap="round"/>`,
    mage: `<path d="M24 14 V44" stroke="#8b5a3c" stroke-width="4" stroke-linecap="round"/>
      <circle cx="24" cy="11" r="8" fill="#7fb4ff" stroke="#e5f1ff" stroke-width="2"/>
      <circle cx="21" cy="8" r="2" fill="#fff"/>`,
    merchant: `<ellipse cx="24" cy="18" rx="14" ry="6" fill="#d9b26a" stroke="#8a6420" stroke-width="2"/>
      <path d="M10 18 V30 C10 34 38 34 38 30 V18" fill="#c99a4c" stroke="#8a6420" stroke-width="2"/>
      <path d="M10 26 C10 30 38 30 38 26" fill="none" stroke="#8a6420" stroke-width="2"/>
      <circle cx="24" cy="18" r="3" fill="#fff0bf"/>`,
    wanderer: `<circle cx="24" cy="24" r="18" fill="#2f3b48" stroke="#9fb4c7" stroke-width="2"/>
      <path d="M24 10 L29 24 L24 38 L19 24Z" fill="#c96a5a"/>
      <path d="M24 10 L29 24 H19Z" fill="#f3e0b0"/>`,
  };

  function originIcon(id) {
    const body = ORIGIN_ICONS[id] || ORIGIN_ICONS.warrior;
    return `<svg viewBox="0 0 48 48" aria-hidden="true">${body}</svg>`;
  }

  // ไอคอนค่าสถานะ 24x24
  const STAT_ICONS = {
    health: `<path d="M12 21 C3 14 3 7 8 5 C10 4 12 5 12 7 C12 5 14 4 16 5 C21 7 21 14 12 21Z" fill="#e0695b"/>`,
    gold: `<circle cx="12" cy="12" r="9" fill="#e8bf5c" stroke="#8a6420" stroke-width="1.5"/><circle cx="12" cy="12" r="4" fill="none" stroke="#8a6420" stroke-width="1.5"/>`,
    reputation: `<path d="M12 2 L14.9 8.6 L22 9.2 L16.6 13.9 L18.2 21 L12 17.3 L5.8 21 L7.4 13.9 L2 9.2 L9.1 8.6Z" fill="#f2d27a" stroke="#8a6420" stroke-width="1"/>`,
    strength: `<path d="M5 19 L15 9 M13 5 L19 11 M4 20 L8 16" stroke="#b9c6d6" stroke-width="2.5" stroke-linecap="round" fill="none"/>`,
    wisdom: `<path d="M3 5 Q8 3 12 6 Q16 3 21 5 V19 Q16 17 12 20 Q8 17 3 19Z" fill="#8fb3e8" stroke="#3b5f94" stroke-width="1"/>`,
    charm: `<path d="M12 3 L13.8 9.2 L20 11 L13.8 12.8 L12 19 L10.2 12.8 L4 11 L10.2 9.2Z" fill="#f29ac2"/>`,
    luck: `<circle cx="12" cy="8" r="4.5" fill="#7fc98c"/><circle cx="8" cy="13" r="4.5" fill="#7fc98c"/><circle cx="16" cy="13" r="4.5" fill="#7fc98c"/><path d="M12 14 V22" stroke="#3f7360" stroke-width="2"/>`,
  };

  function statIcon(key) {
    const body = STAT_ICONS[key];
    return body ? `<svg viewBox="0 0 24 24" aria-hidden="true">${body}</svg>` : '';
  }

  // ลูกเต๋า d20 แบบเรียบง่าย ใช้แสดงตอนทอย
  function diceSvg() {
    return `<svg viewBox="0 0 48 48" aria-hidden="true" class="die">
      <polygon points="24,3 44,15 44,35 24,45 4,35 4,15" fill="#2c2533" stroke="#d9b26a" stroke-width="2"/>
      <polygon points="24,3 44,15 24,24 4,15" fill="#3b3346"/>
      <line x1="24" y1="24" x2="24" y2="45" stroke="#d9b26a" stroke-width="1" opacity=".6"/>
      <line x1="4" y1="15" x2="24" y2="24" stroke="#d9b26a" stroke-width="1" opacity=".6"/>
      <line x1="44" y1="15" x2="24" y2="24" stroke="#d9b26a" stroke-width="1" opacity=".6"/>
    </svg>`;
  }

  // กรอบมุมประดับ
  const ORNAMENT = `<svg viewBox="0 0 160 14" aria-hidden="true" class="ornament"><path d="M0 7 H60 M100 7 H160" stroke="#d9b26a" stroke-width="1"/><path d="M80 1 L86 7 L80 13 L74 7Z" fill="#d9b26a"/></svg>`;

  return {
    stageOf,
    STAGE_TITLES,
    sceneSvg,
    originIcon,
    statIcon,
    diceSvg,
    ORNAMENT,
  };
});
