@tool
class_name Door extends Node3D

const GameEventTypesScript = preload("res://scenes/resources/game_event_types.gd")

signal door_locked(text, triggering_player)

@export var time_to_close := 1.2
@export var open_only := false
@export var key_needed: String
@export var locked_message: String
@export var open_sound: AudioStream
@export var close_sound: AudioStream
@export var stop_sound: AudioStream
@export var locked_sound: AudioStream
@export var can_interrupt := true

@export_group("Side selection")
@export var allow_front: bool = true: set = _set_allow_front
@export var allow_back: bool = true: set = _set_allow_back
@export var allow_left: bool = false: set = _set_allow_left
@export var allow_right: bool = false: set = _set_allow_right
@export var allow_top: bool = false: set = _set_allow_top
@export var allow_bottom: bool = false: set = _set_allow_bottom

@export_group("Debug Visualization")
@export var show_debug_faces: bool = false: set = _set_show_debug_faces

var _is_open := false
var _playing_forward := true
var _has_reversed_due_block := false
var _triggering_player: CharacterBody3D = null

var _audio_component: DoorAudioComponent
var _blocking_component: DoorBlockingComponent
var _debug_visualization: DoorDebugVisualization

@onready var _body = $"AnimatableBody3D"
@onready var _anim: AnimationPlayer = $"AnimationPlayer"
@onready var _meshes: Array[MeshInstance3D] = []

func _ready() -> void:
	if not is_in_group("door"):
		add_to_group("door")

	if _anim:
		_anim.connect("animation_finished", _on_animation_finished)

	if _body:
		_meshes.clear()
		for child in _body.get_children():
			if child is MeshInstance3D:
				_meshes.append(child)

	_setup_components()

	if Engine.is_editor_hint():
		_update_debug_visualization()
	
	# Disable physics processing until door is closing (blocking check not needed when idle)
	set_physics_process(false)


func _setup_components() -> void:
	_audio_component = DoorAudioComponent.new()
	_audio_component.open_sound = open_sound
	_audio_component.close_sound = close_sound
	_audio_component.stop_sound = stop_sound
	_audio_component.locked_sound = locked_sound
	_audio_component.setup(self)
	add_child(_audio_component)

	_blocking_component = DoorBlockingComponent.new()
	_blocking_component.setup(_body, _meshes, is_side_allowed)
	add_child(_blocking_component)

	if Engine.is_editor_hint():
		_debug_visualization = DoorDebugVisualization.new()
		_debug_visualization.setup(_body, _meshes)
		_sync_debug_side_states()
		add_child(_debug_visualization)


func _exit_tree() -> void:
	if Engine.is_editor_hint() and _debug_visualization:
		_debug_visualization.cleanup()


func _toggle_door(force := false) -> void:
	var is_unlocked := true
	if not force and key_needed and not Services.world_context.has_key(key_needed):
		is_unlocked = false

	if not is_unlocked:
		door_locked.emit(locked_message, _triggering_player)
		if not Engine.is_editor_hint():
			Services.event_bus.emit(GameEventTypesScript.DOOR_LOCKED, {
				"text": locked_message,
				"triggering_player": _triggering_player,
				"door": self
			}, self)
		if _audio_component:
			_audio_component.play_locked_sound()
		return

	if not _anim:
		push_warning("AnimationPlayer not found under door node, cannot animate")
		return

	if _anim.is_playing():
		if not can_interrupt:
			return

		if _anim.current_animation == "Open" and _anim.speed_scale < 0:
			_anim.speed_scale = abs(_anim.speed_scale)
			_playing_forward = true
			_has_reversed_due_block = true
			if _audio_component:
				_audio_component.play_open_sound()
		elif _playing_forward:
			_anim.play_backwards("Open")
			_playing_forward = false
			_has_reversed_due_block = false
			set_physics_process(true) # Enable blocking check during close
			if _audio_component:
				_audio_component.play_close_sound()
		else:
			_anim.play("Open")
			_playing_forward = true
			if _audio_component:
				_audio_component.play_open_sound()
		return

	if _is_open:
		if (not can_interrupt) and not force:
			return
		_anim.play_backwards("Open")
		_playing_forward = false
		_has_reversed_due_block = false
		set_physics_process(true) # Enable blocking check during close
		if _audio_component:
			_audio_component.play_close_sound()
	else:
		_anim.play("Open")
		_playing_forward = true
		if _audio_component:
			_audio_component.play_open_sound()


func _on_animation_finished(anim_name: String) -> void:
	if anim_name != "Open":
		return

	_is_open = _playing_forward
	set_physics_process(false) # Disable blocking check when animation done

	if _audio_component:
		_audio_component.stop_looping_sounds()
		_audio_component.play_stop_sound()

	if _is_open and not open_only:
		await get_tree().create_timer(time_to_close).timeout
		if _is_open and not _anim.is_playing():
			_anim.play_backwards("Open")
			_playing_forward = false
			_has_reversed_due_block = false
			set_physics_process(true) # Enable blocking check during auto-close
			if _audio_component:
				_audio_component.play_close_sound()


func is_side_allowed(side_name: String) -> bool:
	match side_name:
		"FrontSide": return allow_front
		"BackSide": return allow_back
		"LeftSide": return allow_left
		"RightSide": return allow_right
		"TopSide": return allow_top
		"BottomSide": return allow_bottom
		_: return false


func open():
	_toggle_door(true)


func open_with_point(hit_pos: Vector3, triggering_player: CharacterBody3D = null) -> void:
	_triggering_player = triggering_player
	var local_p: Vector3 = _body.to_local(hit_pos)

	var side: String = _blocking_component._get_side_from_local_point(local_p) if _blocking_component else ""

	if is_side_allowed(side):
		_toggle_door()
	else:
		if _audio_component:
			_audio_component.play_locked_sound()
		door_locked.emit(locked_message, _triggering_player)
		if not Engine.is_editor_hint():
			Services.event_bus.emit(GameEventTypesScript.DOOR_LOCKED, {
				"text": locked_message,
				"triggering_player": _triggering_player,
				"door": self
			}, self)


func _physics_process(_delta: float) -> void:
	if _anim and _anim.is_playing() and not _playing_forward and can_interrupt and not _has_reversed_due_block:
		if _blocking_component and _blocking_component.is_blocked():
			_toggle_door()


func _set_allow_front(value: bool) -> void:
	allow_front = value
	_update_debug_visualization()

func _set_allow_back(value: bool) -> void:
	allow_back = value
	_update_debug_visualization()

func _set_allow_left(value: bool) -> void:
	allow_left = value
	_update_debug_visualization()

func _set_allow_right(value: bool) -> void:
	allow_right = value
	_update_debug_visualization()

func _set_allow_top(value: bool) -> void:
	allow_top = value
	_update_debug_visualization()

func _set_allow_bottom(value: bool) -> void:
	allow_bottom = value
	_update_debug_visualization()

func _set_show_debug_faces(value: bool) -> void:
	show_debug_faces = value
	_update_debug_visualization()

func _sync_debug_side_states() -> void:
	if _debug_visualization:
		_debug_visualization.set_side_allowed("FrontSide", allow_front)
		_debug_visualization.set_side_allowed("BackSide", allow_back)
		_debug_visualization.set_side_allowed("LeftSide", allow_left)
		_debug_visualization.set_side_allowed("RightSide", allow_right)
		_debug_visualization.set_side_allowed("TopSide", allow_top)
		_debug_visualization.set_side_allowed("BottomSide", allow_bottom)

func _update_debug_visualization() -> void:
	if not Engine.is_editor_hint():
		return

	if _debug_visualization:
		_sync_debug_side_states()
		_debug_visualization.set_show_debug_faces(show_debug_faces)
