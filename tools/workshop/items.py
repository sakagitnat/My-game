"""The Salvora art set: every piece one set (e.g. "Modern") needs, with the file name the game loads it by.
folder is under assets/td/. w, h are pixels at 128 px per cell (the game shows them at 64 px)."""
# id, folder, file name, w, h, category, Thai label, hint, flags
ITEMS = [
    # floors (opaque, seamless)
    ("tile_floor_a", "tiles", "tile_floor_01", 128, 128, "พื้น", "พื้นร้านหลัก A", "tile", "tile"),
    ("tile_floor_b", "tiles", "tile_floor_02", 128, 128, "พื้น", "พื้นร้าน B (สลับ A)", "tile", "tile"),
    ("tile_floor_kitchen", "tiles", "tile_floor_03", 128, 128, "พื้น", "พื้นครัว", "tile", "tile"),
    ("tile_pavement", "tiles", "tile_pavement_01", 128, 128, "พื้น", "ลานหน้าร้าน", "tile", "tile"),
    # walls
    ("wall_plain", "walls", "wall_plain_01", 128, 256, "ผนัง", "ผนังหลัง (สูง 2 ช่อง)", "wallplain", "flush"),
    ("wall_low", "walls", "wall_low_01", 128, 64, "ผนัง", "ผนังเตี้ย / ราว", "walllow", "flush"),
    ("wall_side", "walls", "wall_side_01", 32, 256, "ผนัง", "ผนังข้าง (แถบบาง)", "wallside", ""),
    # things hung on or set into a wall
    ("wdeco_window", "walls", "wdeco_window_01", 128, 128, "ของติดผนัง", "หน้าต่าง", "window", ""),
    ("wdeco_door", "walls", "wdeco_door_01", 128, 256, "ของติดผนัง", "ประตู (ปิด)", "door", ""),
    ("wdeco_door_open", "walls", "wdeco_door_open_01", 128, 256, "ของติดผนัง", "ประตู (เปิด)", "dooropen", ""),
    ("wdeco_lamp", "walls", "wdeco_lamp_01", 128, 128, "ของติดผนัง", "โคมไฟติดผนัง", "lamp", ""),
    ("wdeco_painting", "walls", "wdeco_painting_01", 128, 128, "ของติดผนัง", "ภาพวาด", "painting", ""),
    ("wdeco_hood", "walls", "wdeco_hood_01", 128, 128, "ของติดผนัง", "ฮู้ดเหนือเตา", "hood", ""),
    # kitchen modules (join left-right without a seam)
    ("mod_counter", "modular", "mod_modern_counter_01", 128, 128, "ครัว", "เคาน์เตอร์ตรง", "module", "flush"),
    ("mod_sink", "modular", "mod_modern_sink_01", 128, 128, "ครัว", "อ่างล้างจาน", "module", "flush"),
    ("mod_stove", "modular", "mod_modern_stove_01", 128, 128, "ครัว", "เตา", "module", "flush"),
    ("mod_oven", "modular", "mod_modern_oven_01", 128, 128, "ครัว", "เตาอบ", "module", "flush"),
    ("mod_cap_left", "modular", "mod_modern_cap_left_01", 128, 128, "ครัว", "ปิดปลายแถวด้านซ้าย", "module", "flushr"),
    ("mod_cap_right", "modular", "mod_modern_cap_right_01", 128, 128, "ครัว", "ปิดปลายแถวด้านขวา", "module", "flushl"),
    ("mod_fridge", "modular", "mod_modern_fridge_01", 128, 256, "ครัว", "ตู้เย็น", "fridge", ""),
    ("mod_prep", "modular", "mod_modern_prep_table_01", 256, 128, "ครัว", "โต๊ะเตรียม (เกาะกลาง)", "module", "flush"),
    # customer area
    ("rest_table_small", "furniture", "rest_table_small_01", 128, 128, "โซนลูกค้า", "โต๊ะเล็ก", "table", ""),
    ("rest_table_long", "furniture", "rest_table_long_01", 256, 128, "โซนลูกค้า", "โต๊ะยาว", "table", ""),
    ("rest_chair_up", "furniture", "rest_chair_up_01", 128, 128, "โซนลูกค้า", "เก้าอี้หันขึ้น (ใต้โต๊ะ)", "chair", ""),
    ("rest_chair_down", "furniture", "rest_chair_down_01", 128, 128, "โซนลูกค้า", "เก้าอี้หันลง (เหนือโต๊ะ)", "chair", ""),
    ("rest_chair_left", "furniture", "rest_chair_left_01", 128, 128, "โซนลูกค้า", "เก้าอี้หันซ้าย", "chair", ""),
    ("rest_chair_right", "furniture", "rest_chair_right_01", 128, 128, "โซนลูกค้า", "เก้าอี้หันขวา", "chair", ""),
    ("rest_stool", "furniture", "rest_stool_01", 128, 128, "โซนลูกค้า", "สตูล", "stool", ""),
    ("rest_bench", "furniture", "rest_bench_01", 256, 128, "โซนลูกค้า", "ม้านั่งยาว", "table", ""),
    ("rest_register", "furniture", "rest_register_01", 128, 128, "โซนลูกค้า", "เครื่องคิดเงิน", "register", ""),
    ("rest_shelf", "furniture", "rest_shelf_01", 128, 256, "โซนลูกค้า", "ชั้นวางของ", "shelf", ""),
    ("rest_menu_sign", "furniture", "rest_menu_sign_01", 128, 128, "โซนลูกค้า", "ป้ายเมนูตั้งพื้น", "sign", ""),
    # decoration
    ("deco_plant", "deco", "deco_plant_pot_01", 128, 128, "ตกแต่ง", "กระถางต้นไม้", "plant", ""),
    ("deco_rug", "deco", "deco_rug_01", 256, 256, "ตกแต่ง", "พรม (ภาพแบนบนพื้น)", "rug", "flat"),
    ("deco_lamp_floor", "deco", "deco_lamp_floor_01", 128, 256, "ตกแต่ง", "โคมไฟตั้งพื้น", "floorlamp", ""),
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
]
CATEGORIES = ["พื้น", "ผนัง", "ของติดผนัง", "ครัว", "โซนลูกค้า", "ตกแต่ง", "ของเล็ก"]
def anchor(w, h):
    """Base line of the object: 24 px above the bottom of a 128 px canvas (12 px for the 64 px small things)."""
    return (w // 2, h - (12 if w <= 64 and h <= 64 else 24))
