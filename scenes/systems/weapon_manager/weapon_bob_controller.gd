class_name WeaponBobController
extends RefCounted

# Bob tuning values (optimized for 3D weapons)
const WEAPON_BOB_SMOOTHING: float = 8.0
const WEAPON_BOB_MAX_OFFSET: float = 0.8
const WEAPON_BOB_HORIZONTAL_RANGE: float = 0.31
const WEAPON_BOB_VERTICAL_RANGE: float = 0.31
const WEAPON_BOB_SPEED: float = 2.4
const WEAPON_BOB_SPEED_REFERENCE: float = 5.0
const WEAPON_BOB_MIN_SPEED_MULT: float = 0.5
const WEAPON_BOB_MAX_SPEED_MULT: float = 2.5
const WEAPON_BOB_IDLE_SPEED_MULT: float = 0.4

var bob_time := 0.0
var smooth_movement_speed := 0.0
var movement_speed_smoothing := 5.0
var weapon_bob_amount: Vector3 = Vector3.ZERO
var enabled := true


func update_speed(velocity: Vector3, delta: float) -> void:
	var speed: float = velocity.length()
	smooth_movement_speed = lerp(smooth_movement_speed, speed, delta * movement_speed_smoothing)


func update_bob(delta: float, is_shooting: bool, is_auto_hitting: bool) -> void:
	# If bobbing is disabled, lerp weapon_bob_amount to zero
	if not enabled:
		weapon_bob_amount = weapon_bob_amount.lerp(Vector3.ZERO, delta * WEAPON_BOB_SMOOTHING)
		return
	
	# If shooting, immediately reset to initial position
	if is_shooting or is_auto_hitting:
		weapon_bob_amount = Vector3.ZERO
		return

	var intensity: float = clamp(smooth_movement_speed / WEAPON_BOB_SPEED_REFERENCE, 0.0, 1.0)

	var time_scale: float = WEAPON_BOB_IDLE_SPEED_MULT
	if smooth_movement_speed > 0.1:
		time_scale = clamp(smooth_movement_speed / WEAPON_BOB_SPEED_REFERENCE,
			WEAPON_BOB_MIN_SPEED_MULT,
			WEAPON_BOB_MAX_SPEED_MULT)

	bob_time += delta * time_scale

	# Horizontal sway (X-axis for 3D weapons)
	var h: float = sin(bob_time * WEAPON_BOB_SPEED) * WEAPON_BOB_HORIZONTAL_RANGE
	var curve: float = pow(abs(h) / WEAPON_BOB_HORIZONTAL_RANGE, 4)
	# Vertical bob (Y-axis for 3D weapons) 
	var v: float = - (1.0 - curve) * WEAPON_BOB_VERTICAL_RANGE
	# Forward/backward subtle movement (Z-axis for 3D weapons)
	var z: float = sin(bob_time * WEAPON_BOB_SPEED * 0.5) * (WEAPON_BOB_HORIZONTAL_RANGE * 0.2)

	var target: Vector3 = Vector3(h, v, z) * intensity
	weapon_bob_amount = weapon_bob_amount.lerp(target, delta * WEAPON_BOB_SMOOTHING)
	weapon_bob_amount.x = clamp(weapon_bob_amount.x, -WEAPON_BOB_MAX_OFFSET, WEAPON_BOB_MAX_OFFSET)
	weapon_bob_amount.y = clamp(weapon_bob_amount.y, -WEAPON_BOB_MAX_OFFSET, WEAPON_BOB_MAX_OFFSET)
	weapon_bob_amount.z = clamp(weapon_bob_amount.z, -WEAPON_BOB_MAX_OFFSET * 0.2, WEAPON_BOB_MAX_OFFSET * 0.2)


func get_offset() -> Vector3:
	return weapon_bob_amount


func disable() -> void:
	enabled = false
	smooth_movement_speed = 0.0


func enable() -> void:
	enabled = true
