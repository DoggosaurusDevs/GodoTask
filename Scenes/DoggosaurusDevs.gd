extends Control

@onready var godotLogo: Sprite2D = $Control/GodotLogo
@onready var doggosaurusLabelsContainer: HBoxContainer = $Control/HBoxContainer/VBoxContainer/doggosaurusLabelsContainer
@onready var devsLabelsContainer: HBoxContainer = $Control/HBoxContainer/VBoxContainer/devsLabelsContainer
@onready var h_box_container: HBoxContainer = $Control/HBoxContainer

var doggo_labels: Array[Label] = []
var devs_labels: Array[Label] = []

func _ready() -> void:
	if "theme_override_constants" in doggosaurusLabelsContainer:
		doggosaurusLabelsContainer.theme_override_constants.spacing = 0
	if "theme_override_constants" in devsLabelsContainer:
		devsLabelsContainer.theme_override_constants.spacing = 0
	
	h_box_container.modulate.a = 0
	devsLabelsContainer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	await get_tree().create_timer(0.5).timeout
	start_animation_sequence()

func start_animation_sequence() -> void:
	var logo_tween = create_tween()
	logo_tween.tween_property(godotLogo, "modulate:a", 0.0, 1.5)
	
	await logo_tween.finished
	
	var hbox_tween = create_tween()
	hbox_tween.tween_property(h_box_container, "modulate:a", 1.0, 1.0)
	
	create_labels_dynamically("doggosaurus", doggosaurusLabelsContainer, doggo_labels)
	create_labels_dynamically("Devs", devsLabelsContainer, devs_labels)
	
	await get_tree().create_timer(0.1).timeout
	
	var last_tween: Tween = null
	
	for label in doggo_labels:
		last_tween = animate_letter(label)
		await get_tree().create_timer(0.1).timeout 
		
	for label in devs_labels:
		last_tween = animate_letter(label)
		await get_tree().create_timer(0.1).timeout

	if last_tween:
		await last_tween.finished
	
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")

func create_labels_dynamically(text: String, container: HBoxContainer, array_to_fill: Array[Label]):
	for character in text:
		var new_label = Label.new()
		new_label.text = character
		new_label.modulate.a = 0.0
		new_label.autowrap_mode = 0
		
		new_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		new_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		container.add_child(new_label)
		array_to_fill.append(new_label)

		new_label.custom_minimum_size.x = 0
		var grow_tween = create_tween()
		grow_tween.tween_property(new_label, "custom_minimum_size:x", 20, 0.3)

func animate_letter(label: Label) -> Tween:
	var tween = create_tween()
	
	label.position.y = 10
	
	tween.tween_property(label, "position:y", 0, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 1.0, 0.8)
	
	return tween
