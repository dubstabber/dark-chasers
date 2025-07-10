class_name WeaponResource extends Resource

enum ShootTypes {
	None,
	HitScan,
	Projectile,
}

var weapon_manager: WeaponManager

@export var shoot_type: ShootTypes

@export var name: String

@export_range(1,9) var slot : int = 1
@export_range(1,10) var slot_priority : int = 1

@export var pullout_anim_name: String
@export var shoot_anim_name: String
@export var repeat_shoot_anim_name: String
@export var auto_hit := false
@export var melee_attack := false
@export var hit_sound: AudioStream
@export var draw_sound: AudioStream
@export var holster_sound: AudioStream
@export var damage_wall_sound: AudioStream
@export var damage_entity_sound: AudioStream
@export var damage := 10
@export var hit_particle: PackedScene


func hit() -> void:
	if shoot_type == ShootTypes.HitScan:
		var collider = weapon_manager.bullet_raycast.get_collider()
		if collider:
			var hit_pos = weapon_manager.bullet_raycast.get_collision_point()
			var hit_normal = weapon_manager.bullet_raycast.get_collision_normal()
			if hit_particle:
				var hit_particle1 = hit_particle.instantiate()
				weapon_manager.get_tree().root.add_child(hit_particle1)
				hit_particle1.global_transform.origin = hit_pos + hit_normal * 0.01
				var rotation_basis = _calculate_sprite_rotation(hit_normal)
				hit_particle1.global_transform.basis = rotation_basis
			
				hit_particle1.connect("animation_finished", hit_particle1.queue_free)

			if collider.is_in_group("entity"):
				if damage_entity_sound:
					Utils.play_sound(damage_entity_sound, weapon_manager.get_tree().root, hit_pos)
			elif damage_wall_sound:
				Utils.play_sound(damage_wall_sound, weapon_manager.get_tree().root, hit_pos)
			if collider.has_method("take_damage"):
				collider.take_damage(damage)
			if collider.is_in_group("destroyable"):
				collider.queue_free()



func _calculate_sprite_rotation(normal: Vector3) -> Basis:
	# Define a default "up" vector (Y-axis)
	var up_vector = Vector3(0, 1, 0)

	# Handle edge cases where the normal is parallel to the up vector
	if abs(normal.dot(up_vector)) > 0.99: # If normal is nearly parallel to up vector
		# Use a different "up" vector (e.g., Z-axis) to avoid singularity
		up_vector = Vector3(0, 0, 1)

	# Calculate the right and up vectors for the sprite
	var right_vector = up_vector.cross(normal).normalized()
	var sprite_up_vector = normal.cross(right_vector).normalized()

	# Construct the rotation basis
	# The Z-axis of the sprite should align with the normal
	# The X and Y axes should lie flat on the surface
	return Basis(right_vector, sprite_up_vector, normal)
