extends Node

signal changed

const LANGS: Array[String] = ["en", "th"]
const STRINGS_PATH := "res://data/strings.json"
const FONT_LATIN := "res://assets/fonts/noto-sans-thai-latin-400-normal.woff2"
const FONT_THAI := "res://assets/fonts/noto-sans-thai-thai-400-normal.woff2"

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
	var latin := load(FONT_LATIN) as FontFile
	var thai := load(FONT_THAI) as FontFile
	if latin == null or thai == null:
		push_error("UI fonts failed to load")
		return
	latin.fallbacks = [thai]
	ThemeDB.fallback_font = latin
	var theme := Theme.new()
	theme.default_font = latin
	theme.default_font_size = 22
	get_tree().root.theme = theme

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
