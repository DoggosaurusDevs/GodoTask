class_name ProjectsPanel
extends PanelContainer

signal project_selected(project_id: String)
signal delete_requested(project_id: String)

@onready var _list: VBoxContainer = %ProjectList
@onready var _modal: Window = %NewProjectModal
@onready var _name_input: LineEdit = %ProjectNameInput
@onready var _desc_input: TextEdit = %ProjectDescInput

func _ready() -> void:
	%NewProjectBtn.pressed.connect(func(): _modal.popup_centered())

func refresh() -> void:
	for c in _list.get_children(): c.queue_free()
	for p in DataModel.projects:
		var pid := str(p.get("id", ""))
		var pname := str(p.get("name", "Senza nome"))
		var is_sel := pid == DataModel.selected_project_id
		
		var hb := HBoxContainer.new()
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var btn := Button.new()
		btn.text = pname
		btn.flat = not is_sel
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_sel: btn.add_theme_color_override("font_color", UiTheme.ACCENT)
		btn.pressed.connect(func():
			DataModel.select_project(pid)
			project_selected.emit(pid)
			refresh()
		)
		
		var del_btn := Button.new()
		del_btn.text = "✕"
		del_btn.flat = true
		del_btn.pressed.connect(func(): delete_requested.emit(pid))
		
		hb.add_child(btn)
		hb.add_child(del_btn)
		_list.add_child(hb)

func _on_modal_confirmed() -> void:
	var n := _name_input.text.strip_edges()
	var d := _desc_input.text.strip_edges()
	if not n.is_empty():
		var prj := DataModel.create_project(n, d)
		var new_id := str(prj.get("id", ""))
		if not new_id.is_empty():
			DataModel.select_project(new_id)
			project_selected.emit(new_id)
		refresh()
	_name_input.clear()
	_desc_input.clear()
	_modal.hide()
