class_name EnemyAnimationComponent
extends Node

enum AnimationType {
	ANIMATION_PLAYER,
	ANIMATED_SPRITE_3D,
}

signal animation_changed(animation_name: String)
signal state_changed(new_state: String)

@export_group("Animation Settings")
@export var animation_type: AnimationType = AnimationType.ANIMATION_PLAYER
@export var animation_player: AnimationPlayer
@export var animated_sprite: AnimatedSprite3D

@export_group("Animation Names")
@export var idle_animation: String = "RESET"
@export var move_animation: String = "move"
@export var death_animation: String = "death"

@export_group("Speed Scaling")
@export var scale_speed_with_movement: bool = true
@export var speed_scale_factor: float = 8.0

@export_group("Thresholds")
@export var velocity_threshold: float = 0.1

var current_state: String = "idle"
var is_dead: bool = false

var _owner_enemy: Node = null


func _ready() -> void:
	_owner_enemy = owner
	if _owner_enemy and scale_speed_with_movement:
		_update_speed_scale()


func _update_speed_scale() -> void:
	if not scale_speed_with_movement:
		return
	
	if animation_type == AnimationType.ANIMATION_PLAYER and animation_player:
		var enemy_speed = _get_owner_speed()
		if enemy_speed > 0 and speed_scale_factor > 0:
			animation_player.speed_scale = enemy_speed / speed_scale_factor


func _get_owner_speed() -> float:
	if _owner_enemy and "speed" in _owner_enemy:
		return _owner_enemy.speed
	return 0.0


func _get_owner_velocity() -> Vector3:
	if _owner_enemy and "velocity" in _owner_enemy:
		return _owner_enemy.velocity
	return Vector3.ZERO


func update_animation_state() -> void:
	if is_dead:
		return
	
	var velocity = _get_owner_velocity()
	var is_moving = velocity.length() > velocity_threshold
	
	var new_state = "move" if is_moving else "idle"
	
	if new_state != current_state:
		current_state = new_state
		_play_state_animation()
		state_changed.emit(current_state)
		
		if _owner_enemy and "moving_state" in _owner_enemy:
			_owner_enemy.moving_state = current_state


func _play_state_animation() -> void:
	var anim_name = move_animation if current_state == "move" else idle_animation
	_play_animation(anim_name)


func _play_animation(anim_name: String) -> void:
	match animation_type:
		AnimationType.ANIMATION_PLAYER:
			if animation_player:
				if animation_player.has_animation(anim_name):
					animation_player.play(anim_name)
					animation_changed.emit(anim_name)
				elif animation_player.get_animation_list().has(anim_name):
					animation_player.play(anim_name)
					animation_changed.emit(anim_name)
		AnimationType.ANIMATED_SPRITE_3D:
			if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
				if str(animated_sprite.animation) != anim_name:
					animated_sprite.play(anim_name)
					animation_changed.emit(anim_name)


func play_death_animation() -> void:
	is_dead = true
	current_state = "dead"
	_play_animation(death_animation)
	state_changed.emit(current_state)


func reset() -> void:
	is_dead = false
	current_state = "idle"
	_play_state_animation()


func set_speed_scale(scale: float) -> void:
	if animation_type == AnimationType.ANIMATION_PLAYER and animation_player:
		animation_player.speed_scale = scale
