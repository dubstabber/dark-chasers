extends Node3D

signal triggered(triggering_player: CharacterBody3D)

@export var event_type_id: StringName = &""
@export var prerequisite_door: Door
@export var completion_door: Door
@export var require_player_for_completion := true
@export var one_shot := true

var _armed := false
var _has_fired := false


func _ready() -> void:
	Services.event_bus.subscribe(GameEventTypes.DOOR_OPENED, _on_door_opened)


func _exit_tree() -> void:
	if Services and Services.event_bus:
		Services.event_bus.unsubscribe(GameEventTypes.DOOR_OPENED, _on_door_opened)


func _on_door_opened(event: RefCounted) -> void:
	if event == null:
		return

	var opened_door := event.source as Door
	if opened_door == null:
		return

	if opened_door == prerequisite_door:
		_armed = true

	if opened_door != completion_door:
		return
	if not _armed:
		return
	if one_shot and _has_fired:
		return

	var triggering_player := event.payload.get("triggering_player") as CharacterBody3D
	if require_player_for_completion and not (triggering_player is Player):
		return

	_has_fired = true
	triggered.emit(triggering_player)
	if event_type_id != &"":
		Services.event_bus.emit(event_type_id, {
			"triggering_player": triggering_player
		}, self)


func reset_state() -> void:
	_armed = false
	_has_fired = false
