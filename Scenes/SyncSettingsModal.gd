class_name SyncSettingsModal
extends ConfirmationDialog

@onready var url_input: LineEdit = %UrlInput
@onready var token_input: LineEdit = %TokenInput
@onready var language_option: OptionButton = $VBoxContainer/LanguageOption

const LANGUAGES = [
	["English", "en"],
	["Español", "es"],
	["Italiano", "it"],
	["Français", "fr"],
	["Deutsch", "de"]
]

func _ready() -> void:
	$VBoxContainer/CheckButton.button_pressed = Settings.is_remote
	_on_check_button_toggled($VBoxContainer/CheckButton.button_pressed)
	%SyncNowBtn.visible = Settings.is_remote
	handle_language()
	
func open() -> void:
	url_input.text = Settings.server_url
	token_input.text = Settings.token
	popup_centered(Vector2i(400, 260))

func _on_confirmed() -> void:
	Settings.server_url = url_input.text.strip_edges()
	Settings.token = token_input.text.strip_edges()
	Settings.save_settings()

func _on_check_button_toggled(toggled_on: bool) -> void:
	Settings.is_remote = toggled_on
	%SyncNowBtn.visible = toggled_on
	url_input.editable = toggled_on
	token_input.editable = toggled_on

func handle_language() -> void:
	language_option.clear()
	
	var current_locale: String = Settings.current_language if Settings.current_language else TranslationServer.get_locale()
	var selected_index := 0
	for i in range(LANGUAGES.size()):
			var lang_name: String = LANGUAGES[i][0]
			var lang_code: String = LANGUAGES[i][1]
			
			language_option.add_item(lang_name)
			language_option.set_item_metadata(i, lang_code)
			
			if current_locale.begins_with(lang_code):
				selected_index = i
	language_option.select(selected_index)

func _on_language_option_item_selected(index: int) -> void:
	Settings.current_language = language_option.get_item_metadata(index)
	TranslationServer.set_locale(Settings.current_language)
