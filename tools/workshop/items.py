"""The Salvora art set: every piece one set (e.g. "Modern") needs, with the file name the game loads it by.
folder is under assets/td/. w, h are pixels at 128 px per cell (the game shows them at 64 px)."""
# id, folder, file name, w, h, category, Thai label, hint, flags
ITEMS = [
    # floors (opaque, seamless)
    ("tile_floor_a", "tiles", "tile_floor_01", 128, 128, "พื้น", "พื้นร้านหลัก A", "tile", "tile"),
    ("tile_floor_b", "tiles", "tile_floor_02", 128, 128, "พื้น", "พื้นร้าน B (สลับ A)", "tile", "tile"),
    ("tile_floor_kitchen", "tiles", "tile_floor_03", 128, 128, "พื้น", "พื้นครัว (เกมยังไม่ใช้ ทำไว้ล่วงหน้า)", "tile", "tile"),
    ("tile_pavement", "tiles", "tile_pavement_01", 128, 128, "พื้น", "ลานหน้าร้าน", "tile", "tile"),
    # walls
    ("wall_plain", "walls", "wall_plain_01", 128, 384, "ผนัง", "ผนังหลัง (สูง 3 บล็อก)", "wallplain", "flush"),
    ("wall_low", "walls", "wall_low_01", 128, 64, "ผนัง", "ผนังเตี้ย / ราว", "walllow", "flush"),
    ("wall_side", "walls", "wall_side_01", 32, 384, "ผนัง", "ผนังข้าง (แถบเรียบ ไม่มีบัวหรือเส้นขวาง)", "wallside", ""),
    # things hung on or set into a wall
    ("wdeco_window", "walls", "wdeco_window_01", 128, 128, "ของติดผนัง", "หน้าต่าง", "window", ""),
    ("wdeco_door", "walls", "wdeco_door_01", 128, 280, "ของติดผนัง", "ประตู (ปิด)", "door", ""),
    ("wdeco_door_open", "walls", "wdeco_door_open_01", 128, 280, "ของติดผนัง", "ประตู (เปิด) (เกมยังไม่ใช้)", "dooropen", ""),
    ("wdeco_lamp", "walls", "wdeco_lamp_01", 128, 128, "ของติดผนัง", "โคมไฟติดผนัง (เกมยังไม่ใช้)", "lamp", ""),
    ("wdeco_painting", "walls", "wdeco_painting_01", 128, 128, "ของติดผนัง", "ภาพวาด (เกมยังไม่ใช้)", "painting", ""),
    ("wdeco_hood", "walls", "wdeco_hood_01", 128, 128, "ของติดผนัง", "ฮู้ดเหนือเตา (เกมยังไม่ใช้)", "hood", ""),
    # kitchen modules (join left-right without a seam)
    ("mod_counter", "modular", "mod_modern_counter_01", 128, 192, "ครัว", "เคาน์เตอร์ตรง", "module", "flush"),
    ("mod_sink", "modular", "mod_modern_sink_01", 128, 192, "ครัว", "อ่างล้างจาน", "module", "flush"),
    ("mod_stove", "modular", "mod_modern_stove_01", 128, 192, "ครัว", "เตา", "module", "flush"),
    ("mod_oven", "modular", "mod_modern_oven_01", 128, 192, "ครัว", "เตาอบ", "module", "flush"),
    ("mod_cap_left", "modular", "mod_modern_cap_left_01", 128, 192, "ครัว", "ปิดปลายแถวด้านซ้าย", "module", "flushr"),
    ("mod_cap_right", "modular", "mod_modern_cap_right_01", 128, 192, "ครัว", "ปิดปลายแถวด้านขวา", "module", "flushl"),
    ("mod_fridge", "modular", "mod_modern_fridge_01", 128, 320, "ครัว", "ตู้เย็น", "fridge", ""),
    ("mod_prep", "modular", "mod_modern_prep_table_01", 256, 192, "ครัว", "โต๊ะเตรียม (เกาะกลาง)", "module", "flush"),
    # customer area
    ("rest_table_long", "furniture", "rest_table_long_01", 256, 192, "โซนลูกค้า", "โต๊ะยาว (2x1 ช่อง สูง 1 บล็อก)", "tablelong", ""),
    ("rest_chair_up", "furniture", "rest_chair_up_01", 128, 192, "โซนลูกค้า", "เก้าอี้หันขึ้น (ใต้โต๊ะ)", "chair", ""),
    ("rest_chair_down", "furniture", "rest_chair_down_01", 128, 192, "โซนลูกค้า", "เก้าอี้หันลง (เหนือโต๊ะ)", "chair", ""),
    ("rest_chair_side", "furniture", "rest_chair_side_01", 128, 192, "โซนลูกค้า", "เก้าอี้หันข้าง (วาดหันซ้าย)", "chair", ""),
    ("rest_stool", "furniture", "rest_stool_01", 128, 128, "โซนลูกค้า", "สตูล", "stool", ""),
    ("rest_bench", "furniture", "rest_bench_01", 256, 128, "โซนลูกค้า", "ม้านั่งยาว", "table", ""),
    ("rest_register", "furniture", "rest_register_01", 128, 192, "โซนลูกค้า", "เครื่องคิดเงิน", "register", ""),
    ("rest_shelf", "furniture", "rest_shelf_01", 128, 320, "โซนลูกค้า", "ชั้นวางของ", "shelf", ""),
    ("rest_menu_sign", "furniture", "rest_menu_sign_01", 128, 192, "โซนลูกค้า", "ป้ายเมนูตั้งพื้น", "sign", ""),
    # decoration
    ("deco_plant", "deco", "deco_plant_pot_01", 128, 256, "ตกแต่ง", "กระถางต้นไม้", "plant", ""),
    ("deco_rug", "deco", "deco_rug_01", 256, 256, "ตกแต่ง", "พรม (ภาพแบนบนพื้น)", "rug", "flat"),
    ("deco_lamp_floor", "deco", "deco_lamp_floor_01", 128, 320, "ตกแต่ง", "โคมไฟตั้งพื้น", "floorlamp", ""),
    ("deco_bin", "deco", "deco_trash_bin_01", 128, 128, "ตกแต่ง", "ถังขยะ", "bin", ""),
    ("deco_crate", "deco", "deco_crate_01", 128, 128, "ตกแต่ง", "ลังไม้", "crate", ""),
    # small things on tables and counters (half a cell)
    ("prop_plate", "props", "prop_plate_01", 64, 64, "ของเล็ก", "จาน", "prop", ""),
    ("prop_bowl", "props", "prop_bowl_01", 64, 64, "ของเล็ก", "ชาม", "prop", ""),
    ("prop_cup", "props", "prop_cup_01", 64, 64, "ของเล็ก", "ถ้วย", "prop", ""),
    ("prop_pot", "props", "prop_pot_01", 64, 64, "ของเล็ก", "หม้อ", "prop", ""),
    ("prop_pan", "props", "prop_pan_01", 64, 64, "ของเล็ก", "กระทะ", "prop", ""),
    ("prop_knife", "props", "prop_knife_01", 64, 64, "ของเล็ก", "มีด", "prop", ""),
    ("prop_board", "props", "prop_cutting_board_01", 64, 64, "ของเล็ก", "เขียง", "prop", ""),
    ("prop_vase", "props", "prop_vase_01", 64, 64, "ของเล็ก", "แจกัน", "prop", ""),
    ("prop_bottle", "props", "prop_bottle_01", 64, 64, "ของเล็ก", "ขวด", "prop", ""),
    # outdoor ground: the base tiles, and the soft edges that join one ground to another (docs/ART_TOPDOWN.md)
    ("tile_grass", "tiles", "tile_grass_01", 128, 128, "พื้นกลางแจ้ง", "หญ้า (ต่อซ้ำได้ทุกทิศ)", "tile", "tile"),
    ("tile_sand", "tiles", "tile_sand_01", 128, 128, "พื้นกลางแจ้ง", "ทราย (ต่อซ้ำได้ทุกทิศ)", "tile", "tile"),
    ("tile_dirt", "tiles", "tile_dirt_01", 128, 128, "พื้นกลางแจ้ง", "ดิน (ต่อซ้ำได้ทุกทิศ)", "tile", "tile"),
    ("tile_road", "tiles", "tile_road_dirt_01", 128, 128, "พื้นกลางแจ้ง", "ถนนดิน (ต่อซ้ำได้ทุกทิศ)", "tile", "tile"),
    # trees, rocks and bushes the player clears (the base of the trunk / rock sits on the bottom edge of the cell)
    ("obs_tree", "obstacles", "obs_tree_01", 256, 512, "ต้นไม้ หิน พุ่ม", "ต้นไม้ใหญ่ (ยอดสูงกว่าตัวคน)", "tree", ""),
    ("obs_tree_small", "obstacles", "obs_tree_02", 128, 256, "ต้นไม้ หิน พุ่ม", "ต้นไม้เล็ก (สูงเท่าตัวคน)", "treesmall", ""),
    ("obs_bush", "obstacles", "obs_bush_01", 128, 128, "ต้นไม้ หิน พุ่ม", "พุ่มไม้ (สูง 1 บล็อก)", "bush", ""),
    ("obs_rock", "obstacles", "obs_rock_01", 128, 96, "ต้นไม้ หิน พุ่ม", "ก้อนหิน (สูงครึ่งบล็อก)", "rock", ""),
    # farm plot (2 x 2 cells), what grows on it, and the farm things
    ("tile_soil_dry", "farm", "tile_soil_dry_01", 256, 256, "แปลงปลูก", "ดินแปลง สีอ่อน (แห้ง ดินล้วน ห้ามมีพืช)", "soil", "flat"),
    ("tile_soil_wet", "farm", "tile_soil_wet_01", 256, 256, "แปลงปลูก", "ดินแปลง สีเข้ม (เปียก ดินล้วน ห้ามมีพืช)", "soil", "flat"),
]
for _crop, _clabel in (("wheat", "ข้าวสาลี"), ("tomato", "มะเขือเทศ"), ("cabbage", "กะหล่ำปลี")):
    for _stage, _slabel in ((1, "ต้นอ่อน"), (2, "กำลังโต"), (3, "ใกล้สุก"), (4, "สุก เก็บเกี่ยวได้")):
        ITEMS.append((f"crop_{_crop}_s{_stage}", "farm", f"crop_{_crop}_s{_stage}", 256, 256, "พืช", f"{_clabel} {_slabel} (พื้นโปร่งใส ไม่มีดิน)", f"crop{_stage}", ""))
ITEMS += [
    ("farm_fence", "farm", "farm_fence_01", 128, 160, "ฟาร์ม", "รั้ว (1 ช่อง ต่อกันเป็นแถว)", "fence", ""),
    ("farm_coop", "farm", "farm_coop_01", 384, 576, "ฟาร์ม", "เล้าไก่ (3x3 ช่อง สูง 3 บล็อก)", "coop", ""),
    # what the shop sells today (sizes follow the game's Catalog: a table and a stove take 2 x 2 cells)
    ("rest_table_small", "furniture", "rest_table_small_01", 256, 256, "ร้าน (ในเกมตอนนี้)", "โต๊ะ (2x2 ช่อง นั่งได้ 2 ที่)", "table2", ""),
    ("rest_stove", "furniture", "rest_stove_01", 256, 256, "ร้าน (ในเกมตอนนี้)", "เตา ด้านหน้า (2x2 ช่อง)", "stove2", ""),
    ("rest_stove_side", "furniture", "rest_stove_side_01", 256, 256, "ร้าน (ในเกมตอนนี้)", "เตา ด้านข้างซ้าย (หมุนแล้ว)", "stove2", ""),
    ("rest_stove_back", "furniture", "rest_stove_back_01", 256, 256, "ร้าน (ในเกมตอนนี้)", "เตา ด้านหลัง (หมุนแล้ว)", "stove2", ""),
    ("rest_vase_small", "furniture", "rest_vase_small_01", 64, 64, "ร้าน (ในเกมตอนนี้)", "แจกันเล็ก (บนโต๊ะ ครึ่งช่อง)", "prop", ""),
    ("rest_vase_large", "furniture", "rest_vase_large_01", 128, 128, "ร้าน (ในเกมตอนนี้)", "แจกันใหญ่ (บนโต๊ะ 1 ช่อง)", "vase", ""),
    # icons (not used by the game yet; one cell, seen straight on)
    ("icon_wood", "icons", "icon_wood_01", 128, 128, "ไอคอน", "ไม้", "icon", ""),
    ("icon_stone", "icons", "icon_stone_01", 128, 128, "ไอคอน", "หิน", "icon", ""),
    ("icon_wheat", "icons", "icon_wheat_01", 128, 128, "ไอคอน", "ข้าวสาลี", "icon", ""),
    ("icon_tomato", "icons", "icon_tomato_01", 128, 128, "ไอคอน", "มะเขือเทศ", "icon", ""),
    ("icon_cabbage", "icons", "icon_cabbage_01", 128, 128, "ไอคอน", "กะหล่ำปลี", "icon", ""),
    ("icon_egg", "icons", "icon_egg_01", 128, 128, "ไอคอน", "ไข่", "icon", ""),
    ("icon_dish_porridge", "icons", "icon_dish_porridge_01", 128, 128, "ไอคอน", "โจ๊กข้าวสาลี", "icon", ""),
    ("icon_dish_omelet", "icons", "icon_dish_omelet_01", 128, 128, "ไอคอน", "ไข่เจียว", "icon", ""),
    ("icon_dish_tomato_soup", "icons", "icon_dish_tomato_soup_01", 128, 128, "ไอคอน", "ซุปมะเขือเทศ", "icon", ""),
    ("icon_dish_salad", "icons", "icon_dish_salad_01", 128, 128, "ไอคอน", "สลัดกะหล่ำ", "icon", ""),
    ("icon_coin", "icons", "icon_coin_01", 128, 128, "ไอคอน", "เหรียญ", "icon", ""),
    # characters (not used by the game yet): one cell wide, two cells (blocks) tall; the right side is the left side mirrored by the game
]

for _who, _wlabel in (("player", "ผู้เล่น"), ("customer_a", "ลูกค้า A"), ("customer_b", "ลูกค้า B"), ("customer_c", "ลูกค้า C")):
    for _dir, _dlabel in (("front", "หน้า"), ("back", "หลัง"), ("side", "ข้างซ้าย")):
        for _frame, _flabel in (("idle", "ยืน"), ("walk1", "เดิน 1"), ("walk2", "เดิน 2")):
            ITEMS.append((f"char_{_who}_{_dir}_{_frame}", "chars", f"char_{_who}_{_dir}_{_frame}_01", 128, 256, f"ตัวละคร: {_wlabel}", f"{_wlabel} {_dlabel} {_flabel}", "char", ""))
# The template is split into sheets so each one is a size a drawing app (or an image AI) copes with.
# status: "now" = the game loads these pieces today, "next" = to be added to the game's shop, "later" = the game does not use them yet.
SHEETS = [
    {"id": "now_outdoor", "title": "แผ่น 1: พื้นกลางแจ้งและฟาร์ม", "status": "now", "note": "ใช้ในเกมตอนนี้",
     "categories": ["พื้นกลางแจ้ง", "ต้นไม้ หิน พุ่ม", "แปลงปลูก", "พืช", "ฟาร์ม"]},
    {"id": "now_shop", "title": "แผ่น 2: ร้านและผนัง", "status": "now", "note": "ใช้ในเกมตอนนี้",
     "categories": ["พื้น", "ผนัง", "ของติดผนัง", "ร้าน (ในเกมตอนนี้)"]},
    {"id": "next_shop", "title": "แผ่น 3: ชุดตกแต่งร้าน", "status": "next", "note": "จะเพิ่มเข้าร้านค้าของเกมต่อ",
     "categories": ["ครัว", "โซนลูกค้า", "ตกแต่ง", "ของเล็ก"]},
    {"id": "later_icons", "title": "แผ่น 4: ไอคอน", "status": "later", "note": "เกมยังไม่ใช้",
     "categories": ["ไอคอน"]},
    {"id": "later_chars", "title": "แผ่น 5: ตัวละคร", "status": "later", "note": "เกมยังไม่ใช้ (ตัวละครยังไม่เดินในแมพ)",
     "categories": ["ตัวละคร: ผู้เล่น", "ตัวละคร: ลูกค้า A", "ตัวละคร: ลูกค้า B", "ตัวละคร: ลูกค้า C"]},
]
CATEGORIES = [c for sh in SHEETS for c in sh["categories"]]
assert sorted(CATEGORIES) == sorted(set(i[5] for i in ITEMS)), "every item category must be on a sheet"
WALL_DECO = ("window", "door", "dooropen", "lamp", "painting", "hood")
def anchor(w, h, hint=""):
    """Where the piece stands. Things on the floor (furniture, kitchen modules, decoration, small things) stand with the
    bottom edge of the canvas on the bottom edge of the cell(s) they take, so they touch the floor and the wall behind.
    Pieces that hang on a wall keep a base line 24 px above the canvas bottom. Tiles and walls have no anchor of their own."""
    if hint in WALL_DECO:
        return (w // 2, h - 24)
    return (w // 2, h)
