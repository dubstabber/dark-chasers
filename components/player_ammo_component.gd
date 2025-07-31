class_name PlayerAmmoComponent extends Node

## Per-Player Ammo Management Component
##
## This component manages ammo for a single player, allowing:
## - Weapon-independent ammo pickup (collect ammo for weapons you don't own yet)
## - Shared ammo pools between multiple weapons of the same type
## - Per-player ammo isolation (multiplayer ready)
## - Centralized ammo tracking and persistence per player

signal ammo_changed(ammo_type: String, current_amount: int, max_amount: int)

# Dictionary storing current ammo amounts by type for this player
var _ammo_pools: Dictionary = {}

# Dictionary storing maximum ammo amounts by type for this player
var _max_ammo_pools: Dictionary = {}

# Reference to ammo configuration (shared across all players)
var _ammo_config: AmmoConfig


func _ready() -> void:
	# Get ammo configuration from the global config
	_ammo_config = AmmoConfig.get_instance()
	
	# Initialize default ammo pools for this player
	_initialize_default_pools()


func _initialize_default_pools() -> void:
	"""Initialize ammo pools with default values for this player"""
	var configs = _ammo_config.get_default_ammo_configs()
	for ammo_type in configs:
		var config = configs[ammo_type]
		_max_ammo_pools[ammo_type] = config.max
		_ammo_pools[ammo_type] = config.default


## Public API Methods

func get_ammo(ammo_type: String) -> int:
	"""Get current ammo amount for a specific type
	
	Args:
		ammo_type: The ammo type to check (e.g., "pistol_ammo")
		
	Returns:
		int: Current ammo amount, 0 if type doesn't exist
	"""
	return _ammo_pools.get(ammo_type, 0)


func get_max_ammo(ammo_type: String) -> int:
	"""Get maximum ammo amount for a specific type
	
	Args:
		ammo_type: The ammo type to check
		
	Returns:
		int: Maximum ammo amount, 0 if type doesn't exist
	"""
	return _max_ammo_pools.get(ammo_type, 0)


func has_ammo(ammo_type: String, amount: int = 1) -> bool:
	"""Check if there's enough ammo of a specific type
	
	Args:
		ammo_type: The ammo type to check
		amount: Amount needed (default: 1)
		
	Returns:
		bool: True if enough ammo is available
	"""
	return get_ammo(ammo_type) >= amount


func consume_ammo(ammo_type: String, amount: int = 1) -> bool:
	"""Consume ammo of a specific type
	
	Args:
		ammo_type: The ammo type to consume
		amount: Amount to consume (default: 1)
		
	Returns:
		bool: True if ammo was consumed, False if insufficient ammo
	"""
	if not has_ammo(ammo_type, amount):
		return false
	
	_ammo_pools[ammo_type] -= amount
	ammo_changed.emit(ammo_type, get_ammo(ammo_type), get_max_ammo(ammo_type))
	return true


func add_ammo(ammo_type: String, amount: int) -> bool:
	"""Add ammo of a specific type
	
	Args:
		ammo_type: The ammo type to add
		amount: Amount to add
		
	Returns:
		bool: True if ammo was added, False if already at maximum or invalid
	"""
	if amount <= 0:
		return false
	
	# Ensure the ammo type exists
	if not _ammo_pools.has(ammo_type):
		_register_ammo_type(ammo_type)
	
	var current = get_ammo(ammo_type)
	var max_amount = get_max_ammo(ammo_type)
	
	if current >= max_amount:
		return false
	
	var old_amount = current
	_ammo_pools[ammo_type] = min(max_amount, current + amount)
	
	if _ammo_pools[ammo_type] != old_amount:
		ammo_changed.emit(ammo_type, get_ammo(ammo_type), get_max_ammo(ammo_type))
		return true
	
	return false


func set_max_ammo(ammo_type: String, max_amount: int) -> void:
	"""Set maximum ammo for a specific type
	
	Args:
		ammo_type: The ammo type
		max_amount: New maximum amount
	"""
	if max_amount < 0:
		return
	
	_max_ammo_pools[ammo_type] = max_amount
	
	# Clamp current ammo to new maximum
	if _ammo_pools.has(ammo_type):
		var old_amount = _ammo_pools[ammo_type]
		_ammo_pools[ammo_type] = min(_ammo_pools[ammo_type], max_amount)
		
		if _ammo_pools[ammo_type] != old_amount:
			ammo_changed.emit(ammo_type, get_ammo(ammo_type), get_max_ammo(ammo_type))


func get_ammo_percentage(ammo_type: String) -> float:
	"""Get current ammo as a percentage of maximum
	
	Args:
		ammo_type: The ammo type to check
		
	Returns:
		float: Ammo percentage (0.0 to 1.0)
	"""
	var max_amount = get_max_ammo(ammo_type)
	if max_amount <= 0:
		return 1.0
	return float(get_ammo(ammo_type)) / float(max_amount)


func get_all_ammo_types() -> Array[String]:
	"""Get list of all registered ammo types for this player
	
	Returns:
		Array[String]: List of ammo type names
	"""
	var types: Array[String] = []
	for ammo_type in _ammo_pools.keys():
		types.append(ammo_type)
	return types


func _register_ammo_type(ammo_type: String, max_amount: int = 100, initial_amount: int = 0) -> void:
	"""Register a new ammo type for this player
	
	Args:
		ammo_type: Name of the ammo type
		max_amount: Maximum amount for this type
		initial_amount: Initial amount to set
	"""
	if not _ammo_pools.has(ammo_type):
		_max_ammo_pools[ammo_type] = max_amount
		_ammo_pools[ammo_type] = initial_amount


## Debug and Utility Methods

func debug_print_ammo_status() -> void:
	"""Print current ammo status for all types (debug only)"""
	print("=== Player Ammo Status ===")
	for ammo_type in get_all_ammo_types():
		var current = get_ammo(ammo_type)
		var max_amount = get_max_ammo(ammo_type)
		var percentage = get_ammo_percentage(ammo_type)
		print("%s: %d/%d (%.1f%%)" % [ammo_type, current, max_amount, percentage * 100])


func reset_all_ammo() -> void:
	"""Reset all ammo to default values (useful for testing/debugging)"""
	_ammo_pools.clear()
	_max_ammo_pools.clear()
	_initialize_default_pools()
	
	# Emit signals for all types
	for ammo_type in get_all_ammo_types():
		ammo_changed.emit(ammo_type, get_ammo(ammo_type), get_max_ammo(ammo_type))


## Multiplayer Support Methods

func get_ammo_state() -> Dictionary:
	"""Get complete ammo state for saving/networking
	
	Returns:
		Dictionary: Complete ammo state with current and max values
	"""
	return {
		"ammo_pools": _ammo_pools.duplicate(),
		"max_ammo_pools": _max_ammo_pools.duplicate()
	}


func set_ammo_state(state: Dictionary) -> void:
	"""Set complete ammo state from save/network data
	
	Args:
		state: Dictionary containing ammo_pools and max_ammo_pools
	"""
	if state.has("ammo_pools"):
		_ammo_pools = state.ammo_pools.duplicate()
	if state.has("max_ammo_pools"):
		_max_ammo_pools = state.max_ammo_pools.duplicate()
	
	# Emit signals for all changed types
	for ammo_type in get_all_ammo_types():
		ammo_changed.emit(ammo_type, get_ammo(ammo_type), get_max_ammo(ammo_type))
