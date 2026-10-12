class_name KanbanColumn
extends PanelContainer

var status_id: int = -1
var main_ref = null
var _cards_vbox: VBoxContainer

func setup(status: int, title: String, color: Color, main_node) -> void:
	status_id = status
	main_ref = main_node
	
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size.x = 150
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.PANEL_DARK
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 6
	sb.content_margin_top = 6
	sb.content_margin_right = 6
	sb.content_margin_bottom = 6
	add_theme_stylebox_override("panel", sb)
	
	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 6)
	main_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge := UiTheme.badge(title.to_upper(), color)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(badge)
	main_vbox.add_child(header)
	
	_cards_vbox = VBoxContainer.new()
	_cards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_vbox.add_theme_constant_override("separation", 6)
	_cards_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	
	main_vbox.add_child(_cards_vbox)
	add_child(main_vbox)

func clear_cards() -> void:
	for c in _cards_vbox.get_children():
		c.queue_free()

func add_card(card_node: Control) -> void:
	_cards_vbox.add_child(card_node)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type") == "ticket_row"

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var dragged_id: String = str(data.get("id", ""))
	if dragged_id.is_empty():
		return

	var original_status: int = int(data.get("status", -1))
	
	var target_index := _calculate_drop_index(at_position)

	if original_status == status_id:
		var current_from_index := DataModel._find_ticket_index(dragged_id)
		var current_to_index := _get_global_target_index(target_index)
		
		if current_from_index != -1 and current_to_index != -1:
			DataModel.reorder_ticket(current_from_index, current_to_index)
	else:
		DataModel.update_ticket(dragged_id, "status", status_id)

func _calculate_drop_index(local_pos: Vector2) -> int:
	var children := _cards_vbox.get_children()
	for i in children.size():
		var child = children[i] as Control
		if child and local_pos.y < child.position.y + (child.size.y / 2.0):
			return i
	return children.size()

func _get_global_target_index(column_local_index: int) -> int:
	var count := 0
	for i in DataModel.tickets.size():
		var t = DataModel.tickets[i]
		if str(t.get("project_id", "")) == DataModel.selected_project_id and int(t.get("status", 0)) == status_id:
			if count == column_local_index:
				return i
			count += 1
	return DataModel.tickets.size() - 1
