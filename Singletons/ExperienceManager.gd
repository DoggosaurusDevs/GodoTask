extends Node

signal xp_gained(amount: int, current_xp: int, max_xp: int)
signal level_up(new_level: int)

var level: int = 1
var current_xp: int = 0
var max_xp: int = 100

const SAVE_PATH := "user://experience_data.cfg"

const XP_VALUES := {
	"ticket_created": 15,
	"status_advanced": 25,
	"ticket_resolved": 100,
	"comment_added": 10,
}

func _ready() -> void:
	load_xp_data()

func add_xp(amount: int) -> void:
	current_xp += amount
	
	var leveled_up := false
	while current_xp >= max_xp:
		current_xp -= max_xp
		level += 1
		max_xp = int(max_xp * 1.3)
		leveled_up = true
	
	save_xp_data()
	
	if leveled_up:
		level_up.emit(level)
		
	xp_gained.emit(amount, current_xp, max_xp)

func reward_action(action_name: String) -> void:
	if XP_VALUES.has(action_name):
		add_xp(XP_VALUES[action_name])

func save_xp_data() -> void:
	var config := ConfigFile.new()
	config.set_value("XP", "level", level)
	config.set_value("XP", "current_xp", current_xp)
	config.set_value("XP", "max_xp", max_xp)

func load_xp_data() -> void:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	
	if err == OK:
		level = config.get_value("XP", "level", 1)
		current_xp = config.get_value("XP", "current_xp", 0)
		max_xp = config.get_value("XP", "max_xp", 100)

func reset_progress() -> void:
	level = 1
	current_xp = 0
	max_xp = 100
	save_xp_data()
	xp_gained.emit(0, current_xp, max_xp)
