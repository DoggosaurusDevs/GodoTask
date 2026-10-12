extends Node

signal projects_changed
signal tickets_changed
signal data_saved(path: String)
signal data_loaded(path: String)
signal data_changed_for_sync

const STORAGE_PATH := "user://godotask_data.json"

enum TicketType { BUG, TASK, STORY, EPIC, SUGGESTION }
enum TicketPriority { LOW, MEDIUM, HIGH, CRITICAL }
enum TicketStatus { TO_DO, IN_PROGRESS, IN_REVIEW, DONE }

var TYPE_NAMES := []
var PRIORITY_NAMES := []
var STATUS_NAMES := []

var projects: Array[Dictionary] = []
var tickets: Array[Dictionary] = []

var selected_project_id: String = ""
var selected_ticket_id: String = ""

func _ready() -> void:
	TYPE_NAMES = [
				tr("LBLBug"),
				tr("LBLTask"),
				tr("LBLStory"),
				tr("LBLEpic"),
				tr("LBLSuggestion")
				]
	PRIORITY_NAMES = [
				tr("LBLLow"),
				tr("LBLMedium"),
				tr("LBLHigh"),
				tr("LBLCritical")
				]

	STATUS_NAMES = [
				tr("LBLToDo"),
				tr("LBLInProgress"),
				tr("LBLInReview"),
				tr("LBLDone")
				]
	if not Settings.is_remote:
		load_data()

func select_project(id: String) -> void:
	selected_project_id = id
	selected_ticket_id = ""

func select_ticket(id: String) -> void:
	selected_ticket_id = id

func create_project(project_name: String, description: String = "", key: String = "") -> Dictionary:
	if key.is_empty():
		key = project_name.left(4).to_upper()
		
	var p := {
		"id": _uid(),
		"key": key,
		"name": project_name,
		"description": description,
		"ticket_sequence": 0,
		"created": Time.get_datetime_string_from_system(true),
		"updated_at": Time.get_unix_time_from_system()
	}
	projects.append(p)
	selected_project_id = str(p["id"])
	save_data()
	projects_changed.emit()
	return p

func remove_project(id: String) -> void:
	var i := _find_project_index(id)
	if i == -1: return
	projects.remove_at(i)
	
	var i_tick := tickets.size() - 1
	while i_tick >= 0:
		if str(tickets[i_tick].get("project_id", "")) == id:
			tickets.remove_at(i_tick)
		i_tick -= 1
		
	if selected_project_id == id:
		selected_project_id = str(projects[0]["id"]) if not projects.is_empty() else ""
		selected_ticket_id = ""
		
	save_data()
	projects_changed.emit()
	tickets_changed.emit()

func get_project(id: String) -> Dictionary:
	for p in projects:
		if str(p.get("id", "")) == id: return p
	return {}

func create_ticket(project_id: String, type: int, title: String, description: String,
		priority: int, assignee: String, labels: Array, sprint: String, attachments: Array = []) -> Dictionary:
	var prj_idx := _find_project_index(project_id)
	var seq := 1
	if prj_idx != -1:
		seq = int(projects[prj_idx].get("ticket_sequence", 0)) + 1
		projects[prj_idx]["ticket_sequence"] = seq

	var now_unix := Time.get_unix_time_from_system()
	var t := {
		"id": _uid(),
		"key": "%s-%d" % [_project_key(project_id), seq],
		"project_id": str(project_id),
		"type": int(type),
		"title": str(title),
		"description": str(description),
		"priority": int(priority),
		"assignee": str(assignee),
		"labels": labels,
		"sprint": str(sprint),
		"attachments": attachments,
		"status": TicketStatus.TO_DO,
		"created_by": "admin",
		"created": Time.get_datetime_string_from_system(true),
		"updated": Time.get_datetime_string_from_system(true),
		"updated_at": now_unix,
		"comments": [],
		"history": [],
	}
	tickets.append(t)
	save_data()
	tickets_changed.emit()
	ExperienceManager.reward_action("ticket_created")
	return t

func update_ticket(id: String, field: String, value: Variant) -> void:
	var t := get_ticket_by_id(id)
	if t.is_empty(): return
	var old_val = t.get(field, "")
	if old_val == value: return
	
	t[field] = value
	t["updated"] = Time.get_datetime_string_from_system(true)
	t["updated_at"] = Time.get_unix_time_from_system()
	_history(t, field, old_val, value)
	save_data()
	if field == "status":
		if int(value) == TicketStatus.DONE:
			ExperienceManager.reward_action("ticket_resolved")
		else:
			ExperienceManager.reward_action("status_advanced")
	tickets_changed.emit()

func update_ticket_details(id: String, title: String, description: String, priority: int, assignee: String, type: int, attachments: Array = []) -> void:
	var t := get_ticket_by_id(id)
	if t.is_empty(): return
	
	_history(t, "title", t.get("title", ""), title)
	_history(t, "description", t.get("description", ""), description)
	_history(t, "priority", t.get("priority", 0), priority)
	_history(t, "assignee", t.get("assignee", ""), assignee)
	_history(t, "type", t.get("type", 0), type)

	t["title"] = str(title)
	t["description"] = str(description)
	t["priority"] = int(priority)
	t["assignee"] = str(assignee)
	t["type"] = int(type)
	if not attachments.is_empty():
		t["attachments"] = attachments
	t["updated"] = Time.get_datetime_string_from_system(true)
	t["updated_at"] = Time.get_unix_time_from_system()
	
	save_data()
	tickets_changed.emit()

func add_comment(id: String, author: String, text: String) -> void:
	var t := get_ticket_by_id(id)
	if t.is_empty(): return
	if not t.has("comments"):
		t["comments"] = []
	t["comments"].append({"id": _uid(), "author": author, "text": text, "date": Time.get_datetime_string_from_system(true)})
	t["updated"] = Time.get_datetime_string_from_system(true)
	t["updated_at"] = Time.get_unix_time_from_system()
	save_data()
	ExperienceManager.reward_action("comment_added")
	tickets_changed.emit()

func delete_comment(ticket_id: String, comment_index: int) -> void:
	var t := get_ticket_by_id(ticket_id)
	if t.is_empty() or not t.has("comments"): return
	var comments: Array = t["comments"]
	if comment_index >= 0 and comment_index < comments.size():
		comments.remove_at(comment_index)
		t["updated"] = Time.get_datetime_string_from_system(true)
		t["updated_at"] = Time.get_unix_time_from_system()
		save_data()
		tickets_changed.emit()

func delete_ticket(id: String) -> void:
	var i := _find_ticket_index(id)
	if i == -1: return
	tickets.remove_at(i)
	if selected_ticket_id == id:
		selected_ticket_id = ""
	save_data()
	tickets_changed.emit()

func tickets_for_project(project_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t in tickets:
		if str(t.get("project_id", "")) == project_id:
			out.append(t)
	return out

func tickets_in_current_project() -> Array[Dictionary]:
	return tickets_for_project(selected_project_id)

func get_ticket_by_id(id: String) -> Dictionary:
	for t in tickets:
		if str(t.get("id", "")) == id: return t
	return {}

func _find_ticket_index(id: String) -> int:
	for i in tickets.size():
		if str(tickets[i].get("id", "")) == id: return i
	return -1

func _find_project_index(id: String) -> int:
	for i in projects.size():
		if str(projects[i].get("id", "")) == id: return i
	return -1

func _project_key(project_id: String) -> String:
	var p := get_project(project_id)
	return str(p.get("key", "PRJ"))

func _history(t: Dictionary, field: String, old_val: Variant, new_val: Variant) -> void:
	if not t.has("history"):
		t["history"] = []
	t["history"].append({
		"field": field, 
		"old_value": str(old_val), 
		"new_value": str(new_val), 
		"date": Time.get_datetime_string_from_system(true)
	})

func save_data(path: String = STORAGE_PATH) -> bool:
	if Settings.is_remote:
		data_changed_for_sync.emit()
		return true

	var payload := {
		"version": 1,
		"saved_at": Time.get_datetime_string_from_system(true),
		"projects": projects,
		"tickets": tickets,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(payload, "  "))
	f.close()
	data_saved.emit(path)
	return true

func load_data(path: String = STORAGE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		save_data(path)
		return true
		
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
		
	var text: String = f.get_as_text()
	f.close()
	
	if text.strip_edges().is_empty():
		save_data(path)
		return true

	var parsed_data = JSON.parse_string(text)
	if parsed_data == null or not (parsed_data is Dictionary):
		projects.clear()
		tickets.clear()
		save_data(path)
		data_loaded.emit(path)
		return false

	projects.assign(parsed_data.get("projects", []))
	tickets.assign(parsed_data.get("tickets", []))
	
	if not projects.is_empty() and selected_project_id.is_empty():
		selected_project_id = str(projects[0]["id"])
			
	data_loaded.emit(path)
	return true

func _uid() -> String:
	var crypto := Crypto.new()
	return str(crypto.generate_random_bytes(8)) + "-" + str(Time.get_ticks_msec())

func reorder_ticket(from_index: int, to_index: int) -> void:
	if from_index < 0 or from_index >= tickets.size(): return
	if to_index < 0 or to_index >= tickets.size(): return
	var item = tickets.pop_at(from_index)
	tickets.insert(to_index, item)
	save_data()
	tickets_changed.emit()
