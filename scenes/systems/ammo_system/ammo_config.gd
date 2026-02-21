class_name AmmoConfig extends Node

## Ammo Configuration Class
##
## This class holds shared ammo type configurations that are used by all players.
## It replaces the singleton AmmoManager with a configuration-only approach that
## supports multiplayer by providing ammo type definitions without managing state.

# Default ammo type configurations shared across all players
var _default_ammo_configs: Dictionary = {
	"pistol_ammo": {"max": 100, "default": 68},
	"lighter_fuel": {"max": 2000, "default": 50},
	"shotgun_shells": {"max": 100, "default": 10},
	"rifle_rounds": {"max": 300, "default": 100},
	"energy_cells": {"max": 400, "default": 50}
}


func get_default_ammo_configs() -> Dictionary:
	## Get the default ammo configurations.
	return _default_ammo_configs.duplicate()


func get_ammo_config(ammo_type: String) -> Dictionary:
	## Get configuration for a specific ammo type.
	return _default_ammo_configs.get(ammo_type, {})


func register_ammo_type(ammo_type: String, max_amount: int, default_amount: int = 0) -> void:
	## Register a new ammo type configuration.
	_default_ammo_configs[ammo_type] = {
		"max": max_amount,
		"default": default_amount
	}


func has_ammo_type(ammo_type: String) -> bool:
	## Check if an ammo type is registered.
	return _default_ammo_configs.has(ammo_type)


func get_all_ammo_types() -> Array[String]:
	## Get list of all registered ammo types.
	var types: Array[String] = []
	for ammo_type in _default_ammo_configs.keys():
		types.append(ammo_type)
	return types


func get_max_ammo_for_type(ammo_type: String) -> int:
	## Get maximum ammo for a specific type.
	var config = get_ammo_config(ammo_type)
	return config.get("max", 0)


func get_default_ammo_for_type(ammo_type: String) -> int:
	## Get default starting ammo for a specific type.
	var config = get_ammo_config(ammo_type)
	return config.get("default", 0)
