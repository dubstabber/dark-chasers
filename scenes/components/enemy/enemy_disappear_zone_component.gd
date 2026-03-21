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
var _owner_overlap_area: Area3D = null
var _check_timer: float = 0.0
const CHECK_INTERVAL: float = 1.0 / 60.0


func _ready() -> void:
	_owner_enemy = owner as CharacterBody3D
	if _owner_enemy == null:
		# Fallback for dynamically created nodes where `owner` may not be set.
		_owner_enemy = get_parent() as CharacterBody3D
	_owner_overlap_area = _owner_enemy.get_node_or_null("KillZone") as Area3D if _owner_enemy else null
	if _owner_overlap_area and _owner_enemy:
		_owner_overlap_area.collision_layer |= _owner_enemy.collision_layer
		_owner_overlap_area.monitorable = true
	for zone in disappear_zones:
		_ensure_zone_connected(zone)
	check_overlap_immediate()


func update(delta: float) -> void:
	if _owner_enemy == null or disappear_zones.is_empty():
		return
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = CHECK_INTERVAL
		_check_overlap()


func add_zone(area: Area3D) -> void:
	if not is_instance_valid(area):
		return
	if disappear_zones.has(area):
		return
	disappear_zones.append(area)
	_ensure_zone_connected(area)
	check_overlap_immediate()


## Ensures the component zones reflect the enemy-provided list (typically from `Enemy.disappear_zones`).
## Returns true if already in sync (set-equal, no duplicates), false if it had to repair.
func sync_with_enemy_zones(enemy_zones: Array[Area3D]) -> bool:
	var desired := _unique_valid_zones(enemy_zones)
	var in_sync := _zones_equivalent(disappear_zones, desired)
	if in_sync:
		# Still ensure connections exist (safe no-op if already connected)
		for z in desired:
			_ensure_zone_connected(z)
		check_overlap_immediate()
		return true

	# Disconnect zones that are no longer desired
	var cb := Callable(self, "_on_disappear_area")
	var area_cb := Callable(self, "_on_disappear_overlap_area")
	for old_zone in disappear_zones:
		if is_instance_valid(old_zone) and not desired.has(old_zone):
			if old_zone.body_entered.is_connected(cb):
				old_zone.body_entered.disconnect(cb)
			if old_zone.area_entered.is_connected(area_cb):
				old_zone.area_entered.disconnect(area_cb)

	# Replace list and ensure connections for desired zones
	disappear_zones = desired
	for z in disappear_zones:
		_ensure_zone_connected(z)
	check_overlap_immediate()
	return false


func _ensure_zone_connected(zone: Area3D) -> void:
	if not is_instance_valid(zone):
		return
	var cb := Callable(self, "_on_disappear_area")
	if not zone.body_entered.is_connected(cb):
		zone.body_entered.connect(cb)
	var area_cb := Callable(self, "_on_disappear_overlap_area")
	if not zone.area_entered.is_connected(area_cb):
		zone.area_entered.connect(area_cb)


func _unique_valid_zones(zones: Array[Area3D]) -> Array[Area3D]:
	var unique: Array[Area3D] = []
	for z in zones:
		if is_instance_valid(z) and not unique.has(z):
			unique.append(z)
	return unique


func _zones_equivalent(a: Array[Area3D], b: Array[Area3D]) -> bool:
	# Equivalent iff both represent the same set of valid zones and contain no duplicates.
	var ua := _unique_valid_zones(a)
	var ub := _unique_valid_zones(b)
	if ua.size() != a.size():
		return false
	if ub.size() != b.size():
		return false
	if ua.size() != ub.size():
		return false
	for z in ua:
		if not ub.has(z):
			return false
	return true


func has_zones() -> bool:
	return not disappear_zones.is_empty()


func check_overlap_immediate() -> bool:
	if _owner_enemy == null:
		return false
	for zone in disappear_zones:
		if _zone_overlaps_enemy(zone):
			_owner_enemy.queue_free()
			return true
	return false


func _on_disappear_area(body: Node3D) -> void:
	if body == _owner_enemy:
		_owner_enemy.queue_free()


func _on_disappear_overlap_area(area: Area3D) -> void:
	if area == _owner_overlap_area and _owner_enemy:
		_owner_enemy.queue_free()


func _check_overlap() -> void:
	if _owner_enemy == null:
		return
	for zone in disappear_zones:
		if _zone_overlaps_enemy(zone):
			Services.utils.debug_log("Enemy: detected overlap with %s, calling queue_free" % zone.name)
			_owner_enemy.queue_free()
			return


func _zone_overlaps_enemy(zone: Area3D) -> bool:
	if not is_instance_valid(zone) or _owner_enemy == null:
		return false
	if zone.overlaps_body(_owner_enemy):
		return true
	if _owner_overlap_area and is_instance_valid(_owner_overlap_area) and zone.overlaps_area(_owner_overlap_area):
		return true
	return false
