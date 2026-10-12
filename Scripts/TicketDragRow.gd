class_name TicketDragRow
extends PanelContainer

var ticket_data: Dictionary = {}
var main_ref = null

func build_row(data: Dictionary, is_selected: bool, main_node) -> void:
	ticket_data = data
	main_ref = main_node
	
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	var sb := StyleBoxFlat.new()
	var bg_color := UiTheme.PANEL_DARK.lightened(0.15)
	sb.bg_color = UiTheme.ACCENT.darkened(0.6) if is_selected else bg_color
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_top = 8
	sb.content_margin_right = 8
	sb.content_margin_bottom = 8
	if is_selected:
		sb.border_width_left = 3
		sb.border_color = UiTheme.ACCENT
	add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)

	var top_hb := HBoxContainer.new()
	top_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var key_lbl := UiTheme.make_label(str(data.get("key", "")), 11, UiTheme.ACCENT)
	key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_hb.add_child(key_lbl)

	var prio_idx: int = clampi(int(data.get("priority", 0)), 0, UiTheme.PRIORITY_COLORS.size() - 1)
	var prio_badge := UiTheme.badge(DataModel.PRIORITY_NAMES[prio_idx], UiTheme.PRIORITY_COLORS[prio_idx])
	prio_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_hb.add_child(prio_badge)

	vbox.add_child(top_hb)

	var title_lbl := UiTheme.make_label(str(data.get("title", "")), 12, UiTheme.TEXT)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title_lbl)

	var ass_lbl := UiTheme.make_label(str(data.get("assignee", tr("LBLNotAssigned"))), 10, UiTheme.TEXT_DIM)
	ass_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ass_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(ass_lbl)

	add_child(vbox)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if main_ref and main_ref.has_method("select_ticket_row"):
			main_ref.select_ticket_row(str(ticket_data.get("id", "")))

func _get_drag_data(_at_position: Vector2) -> Variant:
	var drag_preview := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.PANEL_DARK.lightened(0.2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_top = 8
	sb.content_margin_right = 8
	sb.content_margin_bottom = 8
	drag_preview.add_theme_stylebox_override("panel", sb)

	var lbl := UiTheme.make_label(str(ticket_data.get("key", "")) + ": " + str(ticket_data.get("title", "")), 12, UiTheme.TEXT)
	drag_preview.add_child(lbl)
	set_drag_preview(drag_preview)

	return {
		"type": "ticket_row",
		"id": str(ticket_data.get("id", "")),
		"status": ticket_data.get("status", -1)
	}
