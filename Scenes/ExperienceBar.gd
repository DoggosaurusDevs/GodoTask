extends ProgressBar

@export var color_speed: float = 2.0
@export var is_rainbow_active: bool = true
@onready var level_up_audio: AudioStreamPlayer = $LevelUpAudio

var _stylebox_fill: StyleBoxFlat
@onready var experience_label: Label = get_parent().get_node("ExperienceLabel")

var leveltext: String = tr("LBLLevel")

func _ready() -> void:
	show_percentage = false
	
	_stylebox_fill = StyleBoxFlat.new()
	_stylebox_fill.corner_radius_top_left = 6
	_stylebox_fill.corner_radius_top_right = 6
	_stylebox_fill.corner_radius_bottom_left = 6
	_stylebox_fill.corner_radius_bottom_right = 6
	add_theme_stylebox_override("fill", _stylebox_fill)

	ExperienceManager.xp_gained.connect(_on_xp_gained)
	ExperienceManager.level_up.connect(_on_level_up)
	max_value = ExperienceManager.max_xp
	value = ExperienceManager.current_xp
	experience_label.text = str(tr("LBLLevel"), ExperienceManager.level)

func _process(_delta: float) -> void:
	if is_rainbow_active:
		var time_sec := Time.get_ticks_msec() / 1000.0
		var hue := fmod(time_sec * color_speed * 0.1, 1.0)
		_stylebox_fill.bg_color = Color.from_hsv(hue, 0.85, 0.95)

func _on_xp_gained(_amount: int, current_xp: int, max_xp_val: int) -> void:
	max_value = max_xp_val
	
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "value", float(current_xp), 0.4)
	
	var scale_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(self, "scale", Vector2(1.05, 1.1), 0.1)
	scale_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)

func _on_level_up(new_level: int) -> void:
	var flash_tween := create_tween()
	flash_tween.tween_property(_stylebox_fill, "bg_color", Color.WHITE, 0.1)
	
	_spawn_floating_text("LEVEL UP! %d" % new_level, Color.GOLD)
	experience_label.text = str(leveltext, ExperienceManager.level)
	level_up_audio.play()

func _spawn_floating_text(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.add_theme_font_size_override("font_size", 20)
	label.position = global_position + Vector2(size.x / 2.0 - 40, -25)
	%RemoteSync.get_parent().add_child(label)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 140, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(label.queue_free)
