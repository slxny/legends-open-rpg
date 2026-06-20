extends Node

## Sidecar save adapter for the revamp slice. Persists revamp-specific state
## (equipped item, HP / charges, unlocked checkpoint) to user://revamp_save.json
## so it doesn't conflict with the main game's savegame.json schema.

const SAVE_PATH := "user://revamp_save.json"

var _player: Node
var _data: Dictionary = {}


func bind(p: Node) -> void:
	_player = p
	if _player and _player.has_signal("equipment_changed"):
		_player.equipment_changed.connect(_on_equipment_changed)


func try_load() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var text: String = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return false
	_data = parsed
	_apply_to_player()
	return true


func save() -> void:
	if not is_instance_valid(_player):
		return
	_data["equipped_item_id"] = String(_player.get("equipped_item_id"))
	_data["hp"] = float(_player.get("current_hp"))
	_data["max_hp"] = float(_player.get("max_hp"))
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_data, "\t"))
		f.close()


func _apply_to_player() -> void:
	if not is_instance_valid(_player):
		return
	var item_id: String = String(_data.get("equipped_item_id", ""))
	if item_id != "" and _player.has_method("equip_item_by_id"):
		_player.equip_item_by_id(item_id)


func _on_equipment_changed(_item_id: String) -> void:
	save()
