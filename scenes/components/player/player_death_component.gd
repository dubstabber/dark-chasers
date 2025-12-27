class_name PlayerDeathComponent
extends Node

## Handles player death animation, collision changes, respawn, and corpse spawning

signal death_animation_started()
signal death_animation_finished()
signal respawn_started()
signal respawn_completed()

@export_group("Death Animation")
@export var death_throw_speed: float = 7.0
@export var dead_lerp_speed: float = 3.0
@export var camera_death_depth_multiplier: float = 1.7

@export_group("Node References")
@export var player: CharacterBody3D
@export var head: Node3D
@export var camera: Node # PlayerCamera
@export var standing_collision: CollisionShape3D
@export var crouching_collision: CollisionShape3D
@export var health_component: HealthComponent
# Note: Death handling is currently managed by player.gd directly
# This component provides utility functions but doesn't auto-connect to died signal
# to avoid duplicate death animation handling
@export var weapon_manager: WeaponManager
@export var directional_sprite: Sprite3D
@export var corpse_sprite: Sprite3D
@export var sprite_animation_player: AnimationPlayer
@export var damage_effects: DamageEffectsComponent
@export var auto_discover: bool = true

@export_group("Crouch Settings")
@export var crouching_depth: float = -0.5

var death_throw: float = 0.0
var killed_pos: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.ZERO
var is_dead: bool = false


func _ready():
	if auto_discover:
		_auto_discover_dependencies()


func _auto_discover_dependencies() -> void:
	"""Auto-discover player and related nodes from parent if not set"""
	var parent = get_parent()
	if not parent:
		return
	
	# Auto-discover player (parent if it's a CharacterBody3D)
	if not player and parent is CharacterBody3D:
		player = parent
	
	if not player:
		return
	
	# Auto-discover nodes from player
	if not head:
		head = player.get_node_or_null("nek/head")
	if not camera:
		camera = player.get_node_or_null("nek/head/eyes/Camera3D")
	if not standing_collision:
		standing_collision = player.get_node_or_null("StandingCollisionShape")
	if not crouching_collision:
		crouching_collision = player.get_node_or_null("CrouchingCollisionShape")
	if not directional_sprite:
		directional_sprite = player.get_node_or_null("DirectionalSprite3D")
	if not corpse_sprite:
		corpse_sprite = player.get_node_or_null("Corpse3D")
	if not sprite_animation_player:
		sprite_animation_player = player.get_node_or_null("SpriteAnimationPlayer")
	
	# Auto-discover sibling components
	for sibling in parent.get_children():
		if not health_component and sibling is HealthComponent:
			health_component = sibling
		if not weapon_manager and sibling is WeaponManager:
			weapon_manager = sibling
		if not damage_effects and sibling is DamageEffectsComponent:
			damage_effects = sibling


func _physics_process(delta: float):
	if not is_dead or not player:
		return
	
	_process_death_animation(delta)


func _on_health_died() -> void:
	if is_dead:
		return
	
	is_dead = true
	death_throw = death_throw_speed
	death_animation_started.emit()
	
	_handle_weapon_death()
	_setup_death_camera()
	_configure_death_collision()
	
	if damage_effects:
		damage_effects.apply_death_overlay()
	
	if sprite_animation_player and sprite_animation_player.has_animation("death"):
		sprite_animation_player.play("death")
	
	if directional_sprite:
		directional_sprite.visible = false
	
	if corpse_sprite:
		corpse_sprite.visible = true


func kill_with_direction(enemy_pos: Vector3, _death_message: String = "") -> void:
	if is_dead:
		return
	
	# Set direction for death throw
	direction = (enemy_pos - player.position).normalized()
	direction.y = 0
	killed_pos = enemy_pos
	
	# Health component will trigger _on_health_died
	if health_component:
		health_component.kill()


func _process_death_animation(delta: float) -> void:
	if death_throw <= 0:
		return
	
	# Apply gradual camera lowering
	_apply_death_camera_lowering(delta)
	
	# Different movement based on death cause
	if killed_pos != Vector3.ZERO:
		# Enemy-caused death: throw player backward
		player.velocity = - direction * death_throw
		
		# Smooth camera rotation to face enemy
		if camera and camera.has_method("orient_toward_position"):
			camera.orient_toward_position(killed_pos, delta)
	else:
		# Fall damage death: stay in place
		player.velocity = Vector3.ZERO
	
	player.move_and_slide()
	death_throw -= 0.1
	
	if death_throw <= 0:
		death_animation_finished.emit()


func _apply_death_camera_lowering(delta: float) -> void:
	if camera and camera.has_method("apply_death_camera_lowering"):
		camera.apply_death_camera_lowering(delta)
	elif head:
		var death_camera_depth = crouching_depth * camera_death_depth_multiplier
		head.position.y = lerp(head.position.y, death_camera_depth, delta * dead_lerp_speed)


func _handle_weapon_death() -> void:
	if not weapon_manager:
		return
	
	weapon_manager.disable_weapon_bobbing()
	
	if weapon_manager.current_weapon and weapon_manager.current_weapon.pullout_anim_name:
		var weapon_animation_player = weapon_manager.animation_player
		if weapon_animation_player:
			weapon_animation_player.stop()
			weapon_animation_player.play_backwards(weapon_manager.current_weapon.pullout_anim_name)
	
	weapon_manager.is_auto_hitting = false


func _setup_death_camera() -> void:
	if killed_pos == Vector3.ZERO:
		# Fall death: center head pitch
		if camera and camera.has_method("center_pitch"):
			camera.center_pitch()
		elif head:
			head.rotation.x = 0.0


func _configure_death_collision() -> void:
	if standing_collision:
		standing_collision.disabled = true
	if crouching_collision:
		crouching_collision.disabled = false


func respawn(health_amount: int = -1) -> void:
	if not is_dead:
		return
	
	if death_throw > 0:
		return
	
	respawn_started.emit()
	
	# Spawn corpse
	_spawn_corpse()
	
	# Reset sprites
	if corpse_sprite:
		corpse_sprite.visible = false
	if directional_sprite:
		directional_sprite.visible = true
	if sprite_animation_player:
		sprite_animation_player.play("RESET")
	
	# Revive health
	if health_component:
		health_component.revive(health_amount)
	
	# Reset state
	is_dead = false
	killed_pos = Vector3.ZERO
	death_throw = death_throw_speed
	
	# Reset weapon
	_handle_weapon_revival()
	
	# Reset collision
	_enable_revival_collision()
	
	# Reset camera and effects
	_reset_death_effects()
	
	respawn_completed.emit()


func _spawn_corpse() -> void:
	var corpses_parents = player.get_tree().get_nodes_in_group("corpse")
	if corpse_sprite and corpses_parents.size() > 0:
		var corpse_copy = corpse_sprite.duplicate()
		if corpse_copy:
			var corpses_parent = corpses_parents[0]
			corpses_parent.add_child(corpse_copy)
			corpse_copy.global_transform = corpse_sprite.global_transform
			corpse_copy.visible = true
			corpse_copy.layers = 1


func _handle_weapon_revival() -> void:
	if weapon_manager:
		weapon_manager.reset_weapon_on_revival()


func _enable_revival_collision() -> void:
	if standing_collision:
		standing_collision.disabled = false
	if crouching_collision:
		crouching_collision.disabled = true


func _reset_death_effects() -> void:
	if camera and camera.has_method("reset_camera"):
		camera.reset_camera()
	elif head:
		head.position.y = 0.0
	
	if damage_effects:
		damage_effects.clear_death_overlay()


func can_respawn() -> bool:
	return is_dead and death_throw <= 0


func get_death_direction() -> Vector3:
	return direction


func set_death_direction(dir: Vector3) -> void:
	direction = dir
	direction.y = 0


func set_killed_position(pos: Vector3) -> void:
	killed_pos = pos
