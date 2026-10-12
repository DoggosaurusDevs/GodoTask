class_name TicketModal
extends ConfirmationDialog

var _editing_ticket_id := ""
var _attached_files: Array = []

@onready var title_input: LineEdit = %TitleInput
@onready var desc_input: TextEdit = %DescInput
@onready var type_opt: OptionButton = %TypeOpt
@onready var prio_opt: OptionButton = %PrioOpt
@onready var assignee_input: LineEdit = %AssigneeInput
@onready var attach_lbl: Label = %AttachLbl
@onready var file_dialog: FileDialog = %FileDialog

func _ready() -> void:
	type_opt.clear()
	for t in DataModel.TYPE_NAMES: type_opt.add_item(t)
	prio_opt.clear()
	for p in DataModel.PRIORITY_NAMES: prio_opt.add_item(p)
	
	%AttachBtn.pressed.connect(func(): file_dialog.popup_centered(Vector2i(600, 400)))
	file_dialog.file_selected.connect(_on_file_selected)
	get_tree().root.files_dropped.connect(_on_files_dropped)

func open_create() -> void:
	_editing_ticket_id = ""
	_attached_files.clear()
	title_input.clear()
	desc_input.clear()
	assignee_input.clear()
	type_opt.selected = 0
	prio_opt.selected = 0
	_update_attach_label()
	title = tr("LBLCreateNewTicket")
	popup_centered(Vector2i(480, 620))

func open_edit(t: Dictionary) -> void:
	_editing_ticket_id = str(t.get("id", ""))
	_attached_files = t.get("attachments", []).duplicate(true)
	title_input.text = str(t.get("title", ""))
	desc_input.text = str(t.get("description", ""))
	assignee_input.text = str(t.get("assignee", ""))
	type_opt.selected = clampi(int(t.get("type", 0)), 0, DataModel.TYPE_NAMES.size() - 1)
	prio_opt.selected = clampi(int(t.get("priority", 0)), 0, DataModel.PRIORITY_NAMES.size() - 1)
	_update_attach_label()
	title = tr("LBLModifyTicket")
	popup_centered(Vector2i(480, 500))

func _on_files_dropped(files: PackedStringArray) -> void:
	if not visible: return
	for f in files:
		_process_and_add_file(f)
	_update_attach_label()

func _on_file_selected(path: String) -> void:
	_process_and_add_file(path)
	_update_attach_label()

func _process_and_add_file(path: String) -> void:
	if not FileAccess.file_exists(path): return
	
	var fname := path.get_file()
	for att in _attached_files:
		if att is Dictionary and att.get("file_name", "") == fname:
			return
			
	var f := FileAccess.open(path, FileAccess.READ)
	if f:
		var buf := f.get_buffer(f.get_length())
		f.close()
		var b64 := Marshalls.raw_to_base64(buf)
		_attached_files.append({
			"id": str(fname.hash()),
			"file_name": fname,
			"file_data": b64,
			"path": path
		})

func _update_attach_label() -> void:
	if _attached_files.is_empty():
		attach_lbl.text = tr("LBLNoFileSelected")
	else:
		var count = _attached_files.size()
		var translation_key = "LBLFileAttachedSingular" if count == 1 else "LBLFileAttachedPlural"
		attach_lbl.text = tr(translation_key) % count

func _on_confirmed() -> void:
	var tt := title_input.text.strip_edges()
	if tt.is_empty(): return
	if _editing_ticket_id.is_empty():
		DataModel.create_ticket(
			DataModel.selected_project_id, type_opt.selected, tt,
			desc_input.text.strip_edges(), prio_opt.selected,
			assignee_input.text.strip_edges(), [], "", _attached_files
		)
	else:
		DataModel.update_ticket_details(
			_editing_ticket_id, tt, desc_input.text.strip_edges(),
			prio_opt.selected, assignee_input.text.strip_edges(), type_opt.selected,
			_attached_files
		)
