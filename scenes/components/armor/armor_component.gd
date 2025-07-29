class_name ArmorComponent
extends Node

## A reusable armor component that provides damage reduction
## Works alongside HealthComponent to reduce incoming damage before it affects health

signal armor_changed(current_armor: int, max_armor: int)
signal armor_gained(amount: int, current_armor: int)
signal armor_lost(amount: int, current_armor: int)
signal armor_depleted()
signal armor_broken()

@export_group("Armor Settings")
@export var max_armor: int = 100: set = set_max_armor
@export var current_armor: int = 0: set = set_current_armor
@export var can_overshield: bool = false
@export var overshield_limit: int = 150

@export_group("Damage Reduction")
@export var damage_reduction_type: DamageReductionType = DamageReductionType.DOOM_GREEN
@export var damage_reduction_percentage: float = 0.0 # For percentage-based reduction (0.0 to 1.0)

@export_group("Audio")
@export var armor_gain_sound: AudioStream
@export var armor_break_sound: AudioStream
@export var armor_hit_sound: AudioStream

enum DamageReductionType {
	DOOM_GREEN, # DOOM-style green armor: 1/3 damage reduction, 1:2 absorption ratio
	DOOM_BLUE, # DOOM-style blue armor: 1/2 damage reduction, 1:2 absorption ratio
	ABSORPTION # Armor absorbs damage completely until depleted (classic shield)
}

var is_broken: bool = false


func _ready():
	# Initialize armor if not set
	if current_armor < 0:
		current_armor = 0
	
	# Connect to parent if it has relevant methods
	_connect_to_parent()


func set_max_armor(value: int):
	max_armor = max(0, value)
	# Adjust current armor if it exceeds new max (unless overshielding is allowed)
	if not can_overshield and current_armor > max_armor:
		current_armor = max_armor
	armor_changed.emit(current_armor, max_armor)


func set_current_armor(value: int):
	var old_armor = current_armor
	current_armor = clamp(value, 0, overshield_limit if can_overshield else max_armor)
	
	if current_armor != old_armor:
		armor_changed.emit(current_armor, max_armor)
		
		# Check for armor depletion
		if current_armor <= 0 and old_armor > 0:
			is_broken = true
			_handle_armor_depletion()


func process_damage(incoming_damage: int) -> int:
	"""Process incoming damage through the armor system
	
	Args:
		incoming_damage: The amount of damage to process
		
	Returns:
		int: The amount of damage that should be applied to health after armor reduction
	"""
	if incoming_damage <= 0 or current_armor <= 0:
		return incoming_damage
	
	var damage_to_health = incoming_damage
	var armor_damage = 0
	
	match damage_reduction_type:
		DamageReductionType.DOOM_GREEN:
			# DOOM Green Armor: 1/3 damage reduction, 1:2 absorption ratio
			# Armor absorbs 1/3 of damage, health takes 2/3 of damage
			# Armor loses 1 point for every 2 points of damage absorbed
			var damage_to_armor = int(incoming_damage / 3.0) # 1/3 goes to armor
			damage_to_health = incoming_damage - damage_to_armor # 2/3 goes to health
			armor_damage = int(damage_to_armor / 2.0) # Armor loses 1 point per 2 absorbed

		DamageReductionType.DOOM_BLUE:
			# DOOM Blue Armor: 1/2 damage reduction, 1:2 absorption ratio
			# Armor absorbs 1/2 of damage, health takes 1/2 of damage
			# Armor loses 1 point for every 2 points of damage absorbed
			var damage_to_armor = int(incoming_damage / 2.0) # 1/2 goes to armor
			damage_to_health = incoming_damage - damage_to_armor # 1/2 goes to health
			armor_damage = int(damage_to_armor / 2.0) # Armor loses 1 point per 2 absorbed

		DamageReductionType.ABSORPTION:
			# Classic shield behavior - absorbs damage completely until depleted
			armor_damage = min(incoming_damage, current_armor)
			damage_to_health = incoming_damage - armor_damage
	
	# Apply armor damage if any
	if armor_damage > 0:
		_take_armor_damage(armor_damage)
	
	return damage_to_health

func add_armor(amount: int) -> bool:
	"""Add armor to the current amount
	
	Args:
		amount: Amount of armor to add
		
	Returns:
		bool: True if armor was added, False if at maximum or invalid amount
	"""
	if amount <= 0:
		return false
	
	var old_armor = current_armor
	var max_allowed = overshield_limit if can_overshield else max_armor
	current_armor = min(max_allowed, current_armor + amount)
	
	if current_armor != old_armor:
		# Reset broken state if armor is restored
		if is_broken and current_armor > 0:
			is_broken = false
		
		# Play armor gain sound
		if armor_gain_sound:
			_play_sound(armor_gain_sound)
		
		# Emit signals
		armor_gained.emit(amount, current_armor)
		armor_changed.emit(current_armor, max_armor)
		return true
	
	return false

func set_armor(value: int):
	"""Set armor directly without triggering gain/loss effects"""
	current_armor = clamp(value, 0, overshield_limit if can_overshield else max_armor)
	armor_changed.emit(current_armor, max_armor)
	
	# Update broken state
	is_broken = current_armor <= 0

func get_armor_percentage() -> float:
	if max_armor <= 0:
		return 0.0
	return float(current_armor) / float(max_armor)

func has_armor() -> bool:
	return current_armor > 0 and not is_broken

func is_at_max_armor() -> bool:
	return current_armor >= max_armor

func get_armor() -> int:
	return current_armor

func get_max_armor() -> int:
	return max_armor

func _take_armor_damage(amount: int):
	"""Internal method to apply damage to armor"""
	if amount <= 0:
		return
	
	var old_armor = current_armor
	current_armor = max(0, current_armor - amount)
	
	# Play armor hit sound
	if armor_hit_sound:
		_play_sound(armor_hit_sound)
	
	# Emit signals
	armor_lost.emit(amount, current_armor)
	armor_changed.emit(current_armor, max_armor)
	
	# Check for armor depletion
	if current_armor <= 0 and old_armor > 0:
		is_broken = true
		_handle_armor_depletion()

func _handle_armor_depletion():
	"""Handle when armor is completely depleted"""
	# Play armor break sound
	if armor_break_sound:
		_play_sound(armor_break_sound)
	
	# Emit depletion signals
	armor_depleted.emit()
	armor_broken.emit()

func _connect_to_parent():
	"""Connect to parent node if it has compatible methods"""
	var parent = get_parent()
	if not parent:
		return
	
	# If parent has armor-related methods, we can integrate with them
	# This allows for custom armor handling per entity type

func _play_sound(sound: AudioStream):
	"""Play an audio stream using the game's audio system"""
	if sound:
		# Use the same audio system as HealthComponent
		var audio_player = AudioStreamPlayer.new()
		get_tree().current_scene.add_child(audio_player)
		audio_player.stream = sound
		audio_player.play()
		
		# Clean up after playing
		audio_player.finished.connect(func(): audio_player.queue_free())

# Convenience methods for common use cases
func gain_armor(amount: int) -> bool:
	return add_armor(amount)

func lose_armor(amount: int):
	_take_armor_damage(amount)
