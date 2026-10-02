extends Node

signal changed

const LANGS: Array[String] = ["en", "th"]
const STRINGS_PATH := "res://data/strings.json"
const FONT_PATH := "res://assets/fonts/NotoSansThai_400Regular.ttf"

func _ready() -> void:
	_load_strings()
	_apply_font()
	var lang: String = GameState.language
	if not LANGS.has(lang):
		lang = "th" if OS.get_locale_language() == "th" else "en"
	TranslationServer.set_locale(lang)

func _load_strings() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(STRINGS_PATH))
	if not (parsed is Dictionary):
		push_error("strings.json missing or invalid")
		return
	for lang in LANGS:
		var t := Translation.new()
		t.locale = lang
		for key in parsed:
			t.add_message(key, str(parsed[key].get(lang, "")))
		TranslationServer.add_translation(t)

func _apply_font() -> void:
	var font := load(FONT_PATH) as FontFile
	if font == null:
		push_error("UI font failed to load")
		return
	ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = 22

func current() -> String:
	return TranslationServer.get_locale()

func toggle() -> void:
	set_language("th" if current() == "en" else "en")

func set_language(code: String) -> void:
	if not LANGS.has(code):
		return
	TranslationServer.set_locale(code)
	GameState.set_language(code)
	changed.emit()

func t(key: String) -> String:
	return TranslationServer.translate(key)
