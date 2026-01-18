class_name EnemyStats
extends Resource

## Reusable configuration resource for enemy movement and physics stats.
## Create .tres files to share configurations across enemy variants.

@export_group("Movement")
@export var speed: float = 7.0
@export var accel: float = 10.0
@export var jump_velocity: float = 12.0

@export_group("Behavior")
@export var chase_player: bool = true
@export var can_open_door: bool = true
@export var is_wandering: bool = false

@export_group("Combat")
@export var death_message: String = ""
