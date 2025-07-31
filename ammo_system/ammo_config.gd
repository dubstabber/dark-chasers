class_name AmmoConfig extends RefCounted

## Ammo Configuration Class
##
## This class holds shared ammo type configurations that are used by all players.
## It replaces the singleton AmmoManager with a configuration-only approach that
## supports multiplayer by providing ammo type definitions without managing state.

# Singleton instance for global access
static var _instance: AmmoConfig

# Default ammo type configurations shared across all players
var _default_ammo_configs: Dictionary = {
	"pistol_ammo": {"max": 100, "default": 68},
	"lighter_fuel": {"max": 2000, "default": 50},
	"shotgun_shells": {"max": 100, "default": 10},
	"rifle_rounds": {"max": 300, "default": 100},
	"energy_cells": {"max": 400, "default": 50}
}


static func get_instance() -> AmmoConfig:
	"""Get the singleton instance of AmmoConfig
	
	Returns:
		AmmoConfig: The singleton instance
	"""
	if not _instance:
		_instance = AmmoConfig.new()
	return _instance


func get_default_ammo_configs() -> Dictionary:
	"""Get the default ammo configurations
	
	Returns:
		Dictionary: Ammo type configurations with max and default values
	"""
	return _default_ammo_configs.duplicate()


func get_ammo_config(ammo_type: String) -> Dictionary:
	"""Get configuration for a specific ammo type
	
	Args:
		ammo_type: The ammo type to get config for
		
	Returns:
		Dictionary: Config with max and default values, or empty if not found
	"""
	return _default_ammo_configs.get(ammo_type, {})


func register_ammo_type(ammo_type: String, max_amount: int, default_amount: int = 0) -> void:
	"""Register a new ammo type configuration
	
	Args:
		ammo_type: Name of the ammo type
		max_amount: Maximum amount for this type
		default_amount: Default starting amount
	"""
	_default_ammo_configs[ammo_type] = {
		"max": max_amount,
		"default": default_amount
	}


func has_ammo_type(ammo_type: String) -> bool:
	"""Check if an ammo type is registered
	
	Args:
		ammo_type: The ammo type to check
		
	Returns:
		bool: True if the ammo type is registered
	"""
	return _default_ammo_configs.has(ammo_type)


func get_all_ammo_types() -> Array[String]:
	"""Get list of all registered ammo types
	
	Returns:
		Array[String]: List of all ammo type names
	"""
	var types: Array[String] = []
	for ammo_type in _default_ammo_configs.keys():
		types.append(ammo_type)
	return types


func get_max_ammo_for_type(ammo_type: String) -> int:
	"""Get maximum ammo for a specific type
	
	Args:
		ammo_type: The ammo type to check
		
	Returns:
		int: Maximum ammo amount, 0 if type doesn't exist
	"""
	var config = get_ammo_config(ammo_type)
	return config.get("max", 0)


func get_default_ammo_for_type(ammo_type: String) -> int:
	"""Get default starting ammo for a specific type
	
	Args:
		ammo_type: The ammo type to check
		
	Returns:
		int: Default ammo amount, 0 if type doesn't exist
	"""
	var config = get_ammo_config(ammo_type)
	return config.get("default", 0)
