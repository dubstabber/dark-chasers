class_name WeaponInputComponent
extends Node

## Handles weapon-related input: fire, auto-fire, weapon switching.
## Extracted from WeaponManager to keep it as pure orchestrator/state.
##
## This component reads input and calls WeaponManager methods,
## enabling AI-controlled weapons or input remapping.

@export var weapon_manager: WeaponManager
@export var player: Player


func _ready() -> void:
	if not weapon_manager:
		push_warning("WeaponInputComponent: 'weapon_manager' is not set.")
	if not player:
		push_warning("WeaponInputComponent: 'player' is not set.")


func _physics_process(_delta: float) -> void:
	if not weapon_manager or not player:
		return
	if player.blocked_movement:
		return
	if player.is_dead():
		return
	
	_process_continuous_fire()


func _unhandled_input(event: InputEvent) -> void:
	if not weapon_manager or not player:
		return
	if player.blocked_movement:
		return
	if player.is_dead():
		return
	
	_process_fire_input(event)
	_process_weapon_switch_input(event)


func _process_continuous_fire() -> void:
	"""Handle continuous fire for single-shot weapons (non-auto)"""
	var current_weapon = weapon_manager.current_weapon
	if not current_weapon:
		return
	
	if Input.is_action_just_pressed("hit") and current_weapon.shoot_anim_name:
		weapon_manager.try_fire()
	
	if weapon_manager.is_auto_hitting and current_weapon.can_fire():
		weapon_manager.try_auto_fire()


func _process_fire_input(event: InputEvent) -> void:
	"""Handle fire button press/release"""
	var current_weapon = weapon_manager.current_weapon
	if not current_weapon:
		return
	
	if event.is_action_pressed("hit"):
		if current_weapon.auto_hit:
			weapon_manager.start_auto_hitting()
		elif current_weapon.shoot_anim_name and not weapon_manager.is_switching_weapon and current_weapon.can_fire():
			weapon_manager.try_fire()
	elif event.is_action_released("hit"):
		if weapon_manager.is_auto_hitting:
			weapon_manager.stop_auto_hitting()


func _process_weapon_switch_input(event: InputEvent) -> void:
	"""Handle weapon switching via number keys"""
	if event is InputEventKey and event.pressed:
		var num: int = event.unicode - KEY_0
		if num > 0 and num < 10:
			weapon_manager.switch_weapon(num)
