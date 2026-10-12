class_name TicketDetailPanel
extends Panel

signal request_edit(ticket: Dictionary)
signal ticket_deleted

@onready var vbox: VBoxContainer = %DetailVBox

func display(t: Dictionary) -> void:
	for c in vbox.get_children():
		c.queue_free()
		
	if t.is_empty():
		var empty_lbl := UiTheme.make_label(tr("LBLNoTicketSelected"), 13, UiTheme.TEXT_DIM)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(empty_lbl)
		return
		
	var top_hb := HBoxContainer.new()
	top_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var key_lbl := UiTheme.make_label(str(t.get("key", "")), 13, UiTheme.ACCENT)
	key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hb.add_child(key_lbl)
	
	var edit_btn := Button.new()
	edit_btn.text = tr("LBLModify")
	edit_btn.flat = true
	edit_btn.pressed.connect(func(): request_edit.emit(t))
	top_hb.add_child(edit_btn)
	vbox.add_child(top_hb)
	
	var title_lbl := UiTheme.make_label(str(t.get("title", "")), 16, UiTheme.TEXT)
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(title_lbl)

	vbox.add_child(UiTheme.make_label(tr("LBLStatus"), 11, UiTheme.TEXT_DIM))
	var status_opt := OptionButton.new()
	status_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s_name in DataModel.STATUS_NAMES: status_opt.add_item(s_name)
	status_opt.selected = clampi(int(t.get("status", 0)), 0, DataModel.STATUS_NAMES.size() - 1)
	status_opt.item_selected.connect(func(idx): DataModel.update_ticket(str(t["id"]), "status", idx))
	vbox.add_child(status_opt)

	var type_idx: int = clampi(int(t.get("type", 0)), 0, DataModel.TYPE_NAMES.size() - 1)
	var prio_idx: int = clampi(int(t.get("priority", 0)), 0, DataModel.PRIORITY_NAMES.size() - 1)
	vbox.add_child(UiTheme.make_label(tr("LBLType") + DataModel.TYPE_NAMES[type_idx], 12, UiTheme.TEXT))
	vbox.add_child(UiTheme.make_label(tr("LBLPriority") + DataModel.PRIORITY_NAMES[prio_idx], 12, UiTheme.TEXT))
	
	var ass_lbl := UiTheme.make_label(tr("LBLAssignee") + str(t.get("assignee", tr("LBLNotAssigned"))), 12, UiTheme.TEXT)
	ass_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(ass_lbl)

	vbox.add_child(UiTheme.make_label(tr("LBLDescription"), 11, UiTheme.TEXT_DIM))
	var desc_rt := RichTextLabel.new()
	desc_rt.bbcode_enabled = true
	desc_rt.text = str(t.get("description", tr("LBLNoDescription")))
	desc_rt.fit_content = true
	desc_rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_rt.custom_minimum_size.y = 40
	desc_rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_rt)

	var attachments: Array = t.get("attachments", [])
	
	if attachments.size() > 0:
		vbox.add_child(UiTheme.make_label(tr("LBLAttachmentList"), 11, UiTheme.TEXT_DIM))
		
		for att_idx in attachments.size():
			var att_item = attachments[att_idx]
			var local_path := ""
			var filename := ""
			var b64_data := ""
			
			if att_item is Dictionary:
				for k in ["path", "file_path", "filePath"]:
					if att_item.has(k) and not str(att_item[k]).is_empty():
						local_path = str(att_item[k])
						break
						
				for k in ["file_name", "filename", "name", "fileName"]:
					if att_item.has(k) and not str(att_item[k]).is_empty():
						filename = str(att_item[k])
						break
						
				for k in ["file_data", "data", "content", "base64", "fileData"]:
					if att_item.has(k) and not str(att_item[k]).strip_edges().is_empty():
						b64_data = str(att_item[k]).strip_edges()
						break
						
				if b64_data.is_empty():
					for k in att_item.keys():
						var val_str := str(att_item[k]).strip_edges()
						if val_str.length() > 100:
							b64_data = val_str
							break
							
			elif att_item is String:
				local_path = str(att_item)
				
			if filename.is_empty() and not local_path.is_empty():
				filename = local_path.get_file()
			if filename.is_empty():
				filename = "Attachment_" + str(att_idx + 1)

			var ext := filename.get_extension().to_lower()

			if ext in ["png", "jpg", "jpeg", "webp"]:
				var img: Image = null
				if not local_path.is_empty() and FileAccess.file_exists(local_path):
					img = Image.load_from_file(local_path)
				elif not b64_data.is_empty():
					var raw_buf := Marshalls.base64_to_raw(b64_data)
					if not raw_buf.is_empty():
						img = Image.new()
						if ext == "png": img.load_png_from_buffer(raw_buf)
						elif ext in ["jpg", "jpeg"]: img.load_jpg_from_buffer(raw_buf)
						elif ext == "webp": img.load_webp_from_buffer(raw_buf)

				if img:
					var texrect := TextureRect.new()
					texrect.texture = ImageTexture.create_from_image(img)
					texrect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					texrect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					texrect.custom_minimum_size = Vector2(0, 120)
					texrect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					vbox.add_child(texrect)

			var btn_file := Button.new()
			btn_file.text = "📎 " + filename
			btn_file.flat = true
			btn_file.clip_text = true
			btn_file.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn_file.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_file.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn_file.add_theme_color_override("font_color", UiTheme.ACCENT)
			
			btn_file.pressed.connect(func():
				if not local_path.is_empty() and FileAccess.file_exists(local_path):
					var open_path := local_path
					if open_path.begins_with("user://") or open_path.begins_with("res://"):
						open_path = ProjectSettings.globalize_path(open_path)
					
					var _err := OS.shell_open(open_path)
					if _err == OK:
						return

				if not b64_data.is_empty():
					var cache_dir := "user://attachments"
					if not DirAccess.dir_exists_absolute(cache_dir):
						DirAccess.make_dir_recursive_absolute(cache_dir)
						
					var safe_filename := filename.get_file()
					if safe_filename.is_empty():
						safe_filename = "allegato_temp." + (ext if not ext.is_empty() else "bin")
						
					var save_path := cache_dir.path_join(safe_filename)
					var raw_bytes := Marshalls.base64_to_raw(b64_data)
					
					if raw_bytes.is_empty():
						return

					var f := FileAccess.open(save_path, FileAccess.WRITE)
					if f:
						f.store_buffer(raw_bytes)
						f.close()
						
						var global_save_path := ProjectSettings.globalize_path(save_path)
						var _err := OS.shell_open(global_save_path)
			)
			vbox.add_child(btn_file)

	vbox.add_child(HSeparator.new())
	vbox.add_child(UiTheme.make_label(tr("LBLComments"), 13, UiTheme.TEXT))
	
	var comments: Array = t.get("comments", [])
	for idx in comments.size():
		var c = comments[idx]
		var c_box := VBoxContainer.new()
		c_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var c_hb := HBoxContainer.new()
		c_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var c_header := UiTheme.make_label("%s (%s)" % [c.get("author", tr("LBLAnonymous")), str(c.get("date", "")).left(10)], 10, UiTheme.TEXT_DIM)
		c_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c_header.clip_text = true
		var del_c_btn := Button.new()
		del_c_btn.text = "✕"
		del_c_btn.flat = true
		del_c_btn.pressed.connect(func(): DataModel.delete_comment(str(t["id"]), idx))
		c_hb.add_child(c_header)
		c_hb.add_child(del_c_btn)
		
		var c_text := UiTheme.make_label(str(c.get("text", "")), 11, UiTheme.TEXT)
		c_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		c_box.add_child(c_hb)
		c_box.add_child(c_text)
		vbox.add_child(c_box)

	var add_comment_hb := HBoxContainer.new()
	add_comment_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var comment_input := LineEdit.new()
	comment_input.placeholder_text = tr("LBLCommentPlaceholder")
	comment_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var send_comment_btn := Button.new()
	send_comment_btn.text = tr("LBLSave")
	send_comment_btn.pressed.connect(func():
		var txt := comment_input.text.strip_edges()
		if not txt.is_empty(): DataModel.add_comment(str(t["id"]), "User", txt)
	)
	add_comment_hb.add_child(comment_input)
	add_comment_hb.add_child(send_comment_btn)
	vbox.add_child(add_comment_hb)

	vbox.add_child(HSeparator.new())
	var del_btn := UiTheme.make_button(tr("LBLDeleteTicket"), func():
		DataModel.delete_ticket(str(t["id"]))
		ticket_deleted.emit()
	)
	del_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	del_btn.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))
	vbox.add_child(del_btn)
