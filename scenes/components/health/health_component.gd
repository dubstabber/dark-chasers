class_name HealthComponent
extends Node

## A reusable health component that can be added to any entity
## Provides health management, damage handling, and death events

signal health_changed(current_health: int, max_health: int)
signal damage_taken(amount: int, current_health: int)
signal healed(amount: int, current_health: int)
signal died()
signal health_depleted()

@export_group("Health Settings")
@export var max_health: int = 100: set = set_max_health
@export var current_health: int = 100: set = set_current_health
@export var can_overheal: bool = false
@export var overheal_limit: int = 150

@export_group("Death Settings")
@export var destroy_on_death: bool = false
@export var death_delay: float = 0.0

@export_group("Damage Settings")
@export var invulnerable: bool = false
@export var invulnerability_duration: float = 0.0

@export_group("Audio")
@export var damage_sound: AudioStream
@export var heal_sound: AudioStream
@export var death_sound: AudioStream

var is_dead: bool = false
var invulnerability_timer: float = 0.0

func _ready():
	# Initialize health if not set
	if current_health <= 0:
		current_health = max_health
	
	# Connect to parent if it has relevant methods
	_connect_to_parent()

func _process(delta):
	# Handle invulnerability timer
	if invulnerability_timer > 0.0:
		invulnerability_timer -= delta

func set_max_health(value: int):
	max_health = max(1, value)
	# Adjust current health if it exceeds new max (unless overhealing is allowed)
	if not can_overheal and current_health > max_health:
		current_health = max_health
	health_changed.emit(current_health, max_health)

func set_current_health(value: int):
	var old_health = current_health
	current_health = clamp(value, 0, overheal_limit if can_overheal else max_health)
	
	if current_health != old_health:
		health_changed.emit(current_health, max_health)
		
		# Check for death
		if current_health <= 0 and not is_dead:
			_handle_death()

func take_damage(amount: int) -> bool:
	if is_dead or invulnerable or invulnerability_timer > 0.0:
		return false

	if amount <= 0:
		return false

	# Check for ArmorComponent and process damage reduction
	var final_damage = amount
	var armor_component = _get_armor_component()
	if armor_component and armor_component.has_method("process_damage"):
		final_damage = armor_component.process_damage(amount)

	# Apply remaining damage to health
	var _old_health = current_health
	current_health = max(0, current_health - final_damage)

	# Play damage sound (only if health damage was taken)
	if final_damage > 0 and damage_sound:
		_play_sound(damage_sound)

	# Emit signals (use original damage amount for damage_taken signal)
	damage_taken.emit(amount, current_health)
	health_changed.emit(current_health, max_health)

	# Start invulnerability if configured
	if invulnerability_duration > 0.0:
		invulnerability_timer = invulnerability_duration

	# Check for death
	if current_health <= 0 and not is_dead:
		_handle_death()
		return true

	return true

func heal(amount: int) -> bool:
	if is_dead or amount <= 0:
		return false
	
	var old_health = current_health
	var max_allowed = overheal_limit if can_overheal else max_health
	current_health = min(max_allowed, current_health + amount)
	
	if current_health != old_health:
		# Play heal sound
		if heal_sound:
			_play_sound(heal_sound)
		
		# Emit signals
		healed.emit(amount, current_health)
		health_changed.emit(current_health, max_health)
		return true
	
	return false

func set_health(value: int):
	"""Set health directly without triggering damage/heal effects"""
	current_health = clamp(value, 0, overheal_limit if can_overheal else max_health)
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0 and not is_dead:
		_handle_death()

func get_health_percentage() -> float:
	return float(current_health) / float(max_health)

func is_at_full_health() -> bool:
	return current_health >= max_health

func is_alive() -> bool:
	return not is_dead and current_health > 0

func kill():
	"""Instantly kill the entity"""
	if is_dead:
		return
	
	current_health = 0
	_handle_death()

func revive(health_amount: int = -1):
	"""Revive the entity with specified health (or max health if -1)"""
	if not is_dead:
		return
	
	is_dead = false
	var new_health = health_amount if health_amount > 0 else max_health
	current_health = min(new_health, max_health)
	health_changed.emit(current_health, max_health)

func _handle_death():
	if is_dead:
		return
	
	is_dead = true
	
	# Play death sound
	if death_sound:
		_play_sound(death_sound)
	
	# Emit death signals
	died.emit()
	health_depleted.emit()
	
	# Handle destruction if configured
	if destroy_on_death:
		if death_delay > 0.0:
			await get_tree().create_timer(death_delay).timeout
		
		if is_instance_valid(get_parent()):
			get_parent().queue_free()

func _get_armor_component():
	"""Get the ArmorComponent from the same parent node"""
	var parent = get_parent()
	if not parent:
		return null

	# Look for ArmorComponent as a sibling node
	for child in parent.get_children():
		if child.get_script() and child.get_script().get_global_name() == "ArmorComponent":
			return child

	return null

func _connect_to_parent():
	"""Connect to parent node if it has compatible methods"""
	var parent = get_parent()
	if not parent:
		return

	# If parent has a take_damage method, we can override it
	if parent.has_method("take_damage"):
		# Note: This would require the parent to delegate to this component
		pass

func _play_sound(sound: AudioStream):
	"""Play a sound effect"""
	if not sound:
		return
	
	# Try to find an AudioStreamPlayer in the parent
	var parent = get_parent()
	if not parent:
		return
	
	var audio_player = parent.get_node_or_null("AudioStreamPlayer3D")
	if not audio_player:
		audio_player = parent.get_node_or_null("AudioStreamPlayer")
	
	if audio_player and audio_player is AudioStreamPlayer3D:
		audio_player.stream = sound
		audio_player.play()
	elif audio_player and audio_player is AudioStreamPlayer:
		audio_player.stream = sound
		audio_player.play()
	else:
		# Create a temporary audio player
		var pos = Vector3.ZERO
		if parent.has_method("get_global_position"):
			pos = parent.get_global_position()
		elif "global_position" in parent:
			pos = parent.global_position
		Utils.play_sound(sound, get_tree().root, pos)

# Convenience methods for common use cases
func damage(amount: int) -> bool:
	return take_damage(amount)

func restore_health(amount: int) -> bool:
	return heal(amount)

func get_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health
