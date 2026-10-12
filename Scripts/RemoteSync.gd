class_name RemoteSync
extends Node

signal sync_done(ok: bool, message: String)

var _ws := WebSocketPeer.new()
var _connected := false
var _authenticated := false
var _msg_id := 1

func _ready() -> void:
	if not DataModel.data_changed_for_sync.is_connected(save_to_ha):
		DataModel.data_changed_for_sync.connect(save_to_ha)

	if Settings.is_remote:
		connect_websocket()

func _process(_delta: float) -> void:
	if Settings.is_remote:
		_poll_websocket()

func _prepare_tickets_for_sync() -> Array:
	var cleaned_tickets: Array = []
	
	for ticket in DataModel.tickets:
		if not ticket is Dictionary:
			continue
			
		var t_copy: Dictionary = ticket.duplicate(true)
		var raw_attachments = t_copy.get("attachments", [])
		var cleaned_attachments: Array = []
		
		if raw_attachments is Array:
			for att in raw_attachments:
				var att_copy: Dictionary = {}
				if att is Dictionary:
					att_copy = att.duplicate(true)
				elif att is String:
					att_copy = {"path": att}
				else:
					continue

				var file_path: String = ""
				for key in ["path", "file_path", "filepath", "uri", "url"]:
					if att_copy.has(key) and not str(att_copy[key]).is_empty():
						file_path = str(att_copy[key])
						break
				
				var clean_name: String = str(att_copy.get("file_name", att_copy.get("name", "")))
				if clean_name.is_empty() and not file_path.is_empty():
					clean_name = file_path.get_file()
				if clean_name.is_empty():
					clean_name = "file_attachment"
				
				att_copy["file_name"] = clean_name
				
				var att_id: String = str(att_copy.get("id", ""))
				if att_id.is_empty():
					att_id = str(clean_name.hash())
					att_copy["id"] = att_id

				var existing_b64: String = str(att_copy.get("file_data", att_copy.get("data", ""))).strip_edges()
				
				if existing_b64.is_empty() and not file_path.is_empty() and FileAccess.file_exists(file_path):
					var f := FileAccess.open(file_path, FileAccess.READ)
					if f:
						var buf := f.get_buffer(f.get_length())
						f.close()
						existing_b64 = Marshalls.raw_to_base64(buf)
				
				att_copy["file_data"] = existing_b64
				
				cleaned_attachments.append(att_copy)
				
		t_copy["attachments"] = cleaned_attachments
		cleaned_tickets.append(t_copy)
		
	return cleaned_tickets

func save_to_ha() -> void:
	if not Settings.is_remote:
		sync_done.emit(false, "Modalità remota disattivata!")
		return

	var base_url: String = Settings.server_url.trim_suffix("/")
	if base_url.is_empty() or Settings.token.is_empty():
		sync_done.emit(false, "Configurazione incompleta!")
		return

	var cleaned_tickets := _prepare_tickets_for_sync()
	var url := base_url + "/api/services/pyscript/godotask_save_data"
	
	var payload := {
		"projects": DataModel.projects,
		"tickets": cleaned_tickets
	}
	
	var headers := PackedStringArray([
		"Authorization: Bearer " + Settings.token,
		"Content-Type: application/json"
	])
	
	var req := HTTPRequest.new()
	add_child(req)
	
	req.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
		req.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
			sync_done.emit(true, tr("LBLSyncronized"))
		else:
			sync_done.emit(false, tr("LBLHTTPError") % response_code)
	)
	
	req.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))

func fetch_initial_state() -> void:
	if not Settings.is_remote: return

	var base_url: String = Settings.server_url.trim_suffix("/")
	if base_url.is_empty() or Settings.token.is_empty(): return

	var url := base_url + "/api/states/sensor.godotask_database"
	var headers := PackedStringArray([
		"Authorization: Bearer " + Settings.token,
		"Content-Type: application/json"
	])
	
	var req := HTTPRequest.new()
	add_child(req)
	
	req.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		req.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
			var json = JSON.parse_string(body.get_string_from_utf8())
			if json is Dictionary and json.has("attributes"):
				var attr: Dictionary = json.get("attributes", {})
				var remote_projects = attr.get("projects", null)
				var remote_tickets = attr.get("tickets", null)
				
				if remote_projects is Array and remote_tickets is Array:
					DataModel.projects.clear()
					DataModel.projects.assign(remote_projects)
					
					DataModel.tickets.clear()
					DataModel.tickets.assign(remote_tickets)
					
					if not DataModel.projects.is_empty() and DataModel.selected_project_id.is_empty():
						DataModel.selected_project_id = str(DataModel.projects[0].get("id", ""))
					
					DataModel.projects_changed.emit()
					DataModel.tickets_changed.emit()
	)
	req.request(url, headers, HTTPClient.METHOD_GET)

func connect_websocket() -> void:
	if not Settings.is_remote: return

	var base_url: String = Settings.server_url.trim_suffix("/")
	if base_url.is_empty(): return

	var ws_url := base_url.replace("http://", "ws://").replace("https://", "wss://") + "/api/websocket"
	_ws.connect_to_url(ws_url)

func _poll_websocket() -> void:
	_ws.poll()
	var state := _ws.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		while _ws.get_available_packet_count() > 0:
			var packet := _ws.get_packet()
			_handle_ws_message(packet.get_string_from_utf8())
			
	elif state == WebSocketPeer.STATE_CLOSED:
		if _connected:
			_connected = false
			_authenticated = false
			get_tree().create_timer(3.0).timeout.connect(connect_websocket)

func _handle_ws_message(raw_msg: String) -> void:
	var json = JSON.parse_string(raw_msg)
	if not json is Dictionary: return

	var msg_type: String = json.get("type", "")

	if msg_type == "auth_required":
		_ws.send_text(JSON.stringify({
			"type": "auth",
			"access_token": Settings.token
		}))

	elif msg_type == "auth_ok":
		_authenticated = true
		_connected = true
		_msg_id += 1
		_ws.send_text(JSON.stringify({
			"id": _msg_id,
			"type": "subscribe_events",
			"event_type": "state_changed"
		}))
		fetch_initial_state()

	elif msg_type == "event":
		var event_data: Dictionary = json.get("event", {})
		if event_data.get("event_type") == "state_changed":
			var data: Dictionary = event_data.get("data", {})
			if data.get("entity_id") == "sensor.godotask_database":
				fetch_initial_state()
