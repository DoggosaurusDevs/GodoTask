extends Node

const SETTINGS_PATH := "user://godotask_settings.json"

static var server_url: String = "http://192.168.1.1"
static var token: String = "YOUR_LONG_LIVED_ACCESS_TOKEN_HA"
static var is_remote: bool = false
static var current_language

func _ready() -> void:
	load_settings()

func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null: return
	f.store_string(JSON.stringify({
		"server_url": server_url,
		"token": token,
		"is_remote": is_remote,
		"current_language": current_language,
	}, "  "))
	f.close()

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH): return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null: return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		server_url = str(parsed.get("server_url", server_url))
		token = str(parsed.get("token", token))
		is_remote = bool(parsed.get("is_remote", is_remote))
		current_language = str(parsed.get("current_language", current_language))
	TranslationServer.set_locale(Settings.current_language if Settings.current_language else TranslationServer.get_locale())
