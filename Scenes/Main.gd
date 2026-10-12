extends Control

var _selected_ticket_id := ""
var _filter_type := -1
var _filter_prio := -1
var _search_filter := ""
var _kanban_columns: Array[KanbanColumn] = []

@onready var _sync: RemoteSync = %RemoteSync
@onready var _sync_label: Label = %SyncLabel
@onready var _projects_panel: ProjectsPanel = %ProjectsPanel
@onready var _detail_panel: TicketDetailPanel = %TicketDetailPanel
@onready var _ticket_modal: TicketModal = %TicketModal
@onready var _sync_modal: SyncSettingsModal = %SyncSettingsModal

@onready var _type_menu: OptionButton = %TypeMenu
@onready var _prio_menu: OptionButton = %PrioMenu
@onready var _search_input: LineEdit = %SearchInput

func _ready() -> void:
	%SyncNowBtn.pressed.connect(func(): _sync.save_to_ha(); _sync_label.text = tr("LBLSyncronizing"))
	%SyncSettingsBtn.pressed.connect(func(): _sync_modal.open())
	_sync.sync_done.connect(func(_ok: bool, msg: String): _sync_label.text = msg)
	
	_projects_panel.project_selected.connect(func(_id): _refresh_tickets())
	_projects_panel.delete_requested.connect(func(pid): DataModel.remove_project(pid))
	
	_detail_panel.request_edit.connect(func(t): _ticket_modal.open_edit(t))
	_detail_panel.ticket_deleted.connect(func(): _selected_ticket_id = ""; _refresh_tickets(); _detail_panel.display({}))
	
	%NewTicketBtn.pressed.connect(func():
		if DataModel.selected_project_id.is_empty():
			return
		_ticket_modal.open_create()
	)
	
	_setup_filters()
	_setup_kanban()

	DataModel.projects_changed.connect(_on_data_changed)
	DataModel.tickets_changed.connect(_on_data_changed)

	if DataModel.projects.size() > 0 and DataModel.selected_project_id.is_empty():
		DataModel.select_project(str(DataModel.projects[0]["id"]))

	_projects_panel.refresh()
	_refresh_tickets()

func _setup_filters() -> void:
	_type_menu.add_item(tr("LBLAllTypes"), -1)
	for i in DataModel.TYPE_NAMES.size(): _type_menu.add_item(DataModel.TYPE_NAMES[i], i)
	_type_menu.item_selected.connect(func(idx): _filter_type = _type_menu.get_item_id(idx); _refresh_tickets())

	_prio_menu.add_item(tr("LBLAllPriorities"), -1)
	for i in DataModel.PRIORITY_NAMES.size(): _prio_menu.add_item(DataModel.PRIORITY_NAMES[i], i)
	_prio_menu.item_selected.connect(func(idx): _filter_prio = _prio_menu.get_item_id(idx); _refresh_tickets())

	_search_input.text_changed.connect(func(t): _search_filter = t; _refresh_tickets())
	%ResetBtn.pressed.connect(func():
		_type_menu.selected = 0
		_prio_menu.selected = 0
		_search_input.clear()
		_filter_type = -1; _filter_prio = -1; _search_filter = ""
		_refresh_tickets()
	)

func _setup_kanban() -> void:
	for i in DataModel.STATUS_NAMES.size():
		var col := KanbanColumn.new()
		col.setup(i, DataModel.STATUS_NAMES[i], UiTheme.STATUS_COLORS[i], self)
		%KanbanBoard.add_child(col)
		_kanban_columns.append(col)

func _on_data_changed() -> void:
	_projects_panel.refresh()
	_refresh_tickets()
	if not _selected_ticket_id.is_empty():
		_detail_panel.display(DataModel.get_ticket_by_id(_selected_ticket_id))

func select_ticket_row(ticket_id: String) -> void:
	_selected_ticket_id = ticket_id
	DataModel.select_ticket(_selected_ticket_id)
	_refresh_tickets()
	_detail_panel.display(DataModel.get_ticket_by_id(_selected_ticket_id))

func _refresh_tickets() -> void:
	for col in _kanban_columns: col.clear_cards()
	for t in _filtered_tickets():
		var status_idx: int = clampi(int(t.get("status", 0)), 0, _kanban_columns.size() - 1)
		var row = TicketDragRow.new()
		row.build_row(t, _selected_ticket_id == str(t.get("id", "")), self)
		_kanban_columns[status_idx].add_card(row)

func _filtered_tickets() -> Array:
	var out: Array = []
	for t in DataModel.tickets_in_current_project():
		if _filter_type >= 0 and int(t.get("type", 0)) != _filter_type: continue
		if _filter_prio >= 0 and int(t.get("priority", 0)) != _filter_prio: continue
		if not _search_filter.is_empty():
			var q := _search_filter.to_lower()
			var hay := (str(t.get("key", "")) + " " + str(t.get("title", "")) + " " + str(t.get("assignee", ""))).to_lower()
			if not hay.contains(q): continue
		out.append(t)
	return out
