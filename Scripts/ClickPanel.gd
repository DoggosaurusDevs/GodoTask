class_name ClickPanel
extends Panel

var data: Dictionary = {}
var on_click: Callable

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if on_click.is_valid():
			on_click.call(data)
