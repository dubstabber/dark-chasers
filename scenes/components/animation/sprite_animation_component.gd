class_name SpriteAnimationComponent
extends Node

## Handles DirectionalSprite3D animation state based on movement and weapon state

@export_group("Node References")
@export var player: CharacterBody3D
@export var sprite_animation_player: AnimationPlayer
@export var weapon_manager: WeaponManager
@export var health_component: HealthComponent

var moving_state: String = "idle"
var shooting_state: String = "idle"
var previous_shooting_state: String = "idle"
var is_playing_shoot_animation: bool = false
var last_weapon_animation: String = ""


func _ready():
	_validate_node_references()


func _validate_node_references() -> void:
	"""Validate that required node references are set and log warnings for missing ones"""
	if not player:
		push_warning("SpriteAnimationComponent: 'player' is not set. Animation updates will be disabled.")
	if not sprite_animation_player:
		push_warning("SpriteAnimationComponent: 'sprite_animation_player' is not set. Animations will be disabled.")
	if not weapon_manager:
		push_warning("SpriteAnimationComponent: 'weapon_manager' is not set. Shooting animations will be disabled.")
	if not health_component:
		push_warning("SpriteAnimationComponent: 'health_component' is not set. Death state check will be disabled.")


func _physics_process(_delta: float):
	if not player or not sprite_animation_player:
		return
	
	# Don't update animations when dead
	if health_component and health_component.is_dead:
		return
	
	_update_animation_state()


func _update_animation_state() -> void:
	# Update movement state
	if player.velocity.length() > 0.1:
		moving_state = "run"
	else:
		moving_state = "idle"
	
	# Update shooting state
	_update_shooting_state()

	# Detect shooting state transition or new shot
	if shooting_state == "shoot" and previous_shooting_state == "idle":
		# New shot started - play shoot animation
		sprite_animation_player.play("shoot")
		is_playing_shoot_animation = true
	elif shooting_state == "shoot" and is_playing_shoot_animation:
		# Still shooting and animation is playing - do nothing
		pass
	elif moving_state == "run":
		# Not shooting, play movement animation
		sprite_animation_player.play("move")
		is_playing_shoot_animation = false
	else:
		# Not shooting, play idle animation
		sprite_animation_player.play(_get_idle_animation_name())
		is_playing_shoot_animation = false
	
	# Update previous state for next frame
	previous_shooting_state = shooting_state


func _update_shooting_state() -> void:
	if weapon_manager and weapon_manager.animation_player and weapon_manager.current_weapon:
		# Check if a shooting animation is currently playing
		var is_shooting = weapon_manager.animation_player.is_playing() and (
			weapon_manager.animation_player.current_animation == weapon_manager.current_weapon.shoot_anim_name or
			weapon_manager.animation_player.current_animation == weapon_manager.current_weapon.repeat_shoot_anim_name
		)
		
		# Track current weapon animation for detecting new shots
		var current_weapon_animation = weapon_manager.animation_player.current_animation if weapon_manager.animation_player.is_playing() else ""

		if is_shooting:
			shooting_state = "shoot"
			# Check if this is a new weapon animation (new shot)
			if current_weapon_animation != last_weapon_animation and current_weapon_animation != "":
				# New shot detected - reset sprite animation flag to allow new animation
				is_playing_shoot_animation = false
		else:
			shooting_state = "idle"
		
		last_weapon_animation = current_weapon_animation
	else:
		shooting_state = "idle"
		last_weapon_animation = ""


func on_animation_finished(anim_name: String) -> void:
	if anim_name == "shoot":
		is_playing_shoot_animation = false


func play_death_animation() -> void:
	if sprite_animation_player and sprite_animation_player.has_animation("death"):
		sprite_animation_player.play("death")


func reset_animation() -> void:
	if sprite_animation_player:
		sprite_animation_player.play(_get_idle_animation_name())
	is_playing_shoot_animation = false
	shooting_state = "idle"
	previous_shooting_state = "idle"
	moving_state = "idle"
	last_weapon_animation = ""


func _get_idle_animation_name() -> String:
	if sprite_animation_player and sprite_animation_player.has_animation("idle"):
		return "idle"
	return "RESET"
