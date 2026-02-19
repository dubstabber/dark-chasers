class_name EnemyDisappearZoneComponent
extends Node

## Manages disappear zones for an enemy. When the enemy enters a disappear zone,
## it is freed. Includes a throttled overlap check as fallback for cases where
## body_entered doesn't fire (e.g., enemy already inside zone at connection time).
##
## Zones are added at runtime via add_zone() — typically called from enemy.gd
## which has the @export var disappear_zones that level designers wire up.

var disappear_zones: Array[Area3D] = []

var _owner_enemy: CharacterBody3D = null
var _check_timer: float = 0.0
const CHECK_INTERVAL: float = 0.5


func _ready() -> void:
	_owner_enemy = owner as CharacterBody3D
	for zone in disappear_zones:
		if is_instance_valid(zone):
			zone.body_entered.connect(_on_disappear_area)


func update(delta: float) -> void:
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = CHECK_INTERVAL
		_check_overlap()


func add_zone(area: Area3D) -> void:
	disappear_zones.append(area)
	area.body_entered.connect(_on_disappear_area)


func has_zones() -> bool:
	return not disappear_zones.is_empty()


func check_overlap_immediate() -> bool:
	for zone in disappear_zones:
		if is_instance_valid(zone) and zone.overlaps_body(_owner_enemy):
			_owner_enemy.queue_free()
			return true
	return false


func _on_disappear_area(body: Node3D) -> void:
	if body == _owner_enemy:
		_owner_enemy.queue_free()


func _check_overlap() -> void:
	for zone in disappear_zones:
		if is_instance_valid(zone) and zone.overlaps_body(_owner_enemy):
			Services.utils.debug_log("Enemy: detected overlap with %s, calling queue_free" % zone.name)
			_owner_enemy.queue_free()
			return
