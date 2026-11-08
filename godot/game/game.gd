## Autoload "Game": loaded content, the current run, settings and saving.
## Screens read and change `run` only through the engine (RunState, Combat, Edits).
extends Node

signal changed

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"

var db: Dictionary
var run: Dictionary = {}
var settings := {"seen_tutorial": false, "screen_shake": true}


func _ready() -> void:
	db = Db.load_all()
	_load_settings()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func new_run() -> void:
	run = RunState.new_run(db)
	save()


func load_run() -> bool:
	if not has_save():
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("deck"):
		return false
	run = Db.ints(parsed)
	# rebuild the fields JSON cannot hold faithfully
	if run.get("combat") is Dictionary:
		run.combat.events = []
	return true


func save() -> void:
	if run.is_empty():
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(run, "", false))


func clear_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if parsed is Dictionary:
		for k in parsed:
			settings[k] = parsed[k]
