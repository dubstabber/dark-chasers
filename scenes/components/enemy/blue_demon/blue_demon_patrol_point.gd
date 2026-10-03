@tool
class_name BlueDemonPatrolPoint
extends Node3D

## One node of the Ao Oni's patrol graph — a port of `u823.AooniFloorPoint` +
## `u823.AooniFloorPointData` from Absolute Fear -AOONI-.
##
## The wandering state walks this directed graph: it moves to a point, waits
## [member thinking_time] seconds while optionally swinging its head, then picks one of
## [member next_points] at random. In the original the position and rotation were copied
## off the transform in Awake(); here the node's own transform is the source of truth.
##
## DST: one node of the blue demon's patrol graph. The node's transform is the data:
## position = destination (put it on the floor), local -Z = the facing the demon turns to
## while it dwells. Edits against SRC `aooni_floor_point.gd` are tagged `# DST P<n>`:
## P1 room, P2 static registry instead of the group, P3 source_id dropped, P4 export
## setters refresh the editor view, P5 arrival ring, P6 red cross-room edges, P7 warnings.
## `# DST R<n>` are review fixes: R1 successors outside the tree, R5 incoming edges follow a move.

## Declaration order taken from the reconstructed `u823.AooniFloorPointType`. The IL2CPP
## metadata dump lists enum members alphabetically, which is a different order and will
## mislabel every point if used by mistake.
enum PointType {
	## An ordinary patrol destination — what most of the shipped graph is.
	NORMAL = 0,
	## Valid both as a starting point and as a patrol destination.
	START = 1,
	## Only ever used as a starting point, never walked to during patrol.
	ONLY_START = 2,
	## Only reachable when the demon is summoned here by a CallAooniTrigger.
	ONLY_CALL = 3,
	NONE = 4,
}

## Room id this point belongs to (the same strings as Enemy.current_room). Empty = usable from any room.
@export var room: String = "": set = _set_room  # DST P1: rooms

## `Normal`, matching the C# field default — a hand-placed point has to be a spawn
## candidate, and `None` would quietly exclude it.
@export var type: PointType = PointType.NORMAL: set = _set_type  # DST P4: editor refresh

## Metres per second while travelling towards this point. The shipped graph uses
## 1.0 - 2.5; compare InGameConst.AOONI_WANDERING_SPEED = 1.0.
## DST: SRC-scale m/s while travelling TO this point; multiplied by the demon's speed_scale (1.4).
## 2.0 stroll, 2.5-3.0 brisk, 5.0 rush (= 2.8 / 3.5-4.2 / 7.0 m/s in game).
@export var moving_speed: float = 1.0

## Seconds to idle at this point before choosing the next one.
@export var thinking_time: float = 0.0

## Stay here until a CallAooniTrigger summons the demon onwards.
## DST: stay until BlueDemon.call_to() moves the demon on.
@export var wait_until_call: bool = false

## Ignore the player entirely until summoned — used to keep the demon docile in
## scripted sections.
## DST: only together with wait_until_call: no senses at all while waiting.
@export var ignore_player_until_call: bool = false

## Ignore the player until this point is reached.
## DST: no senses during the leg TO this point.
@export var ignore_player_until_touch_here: bool = false

## Arriving here forces the chase state regardless of whether the player was seen.
## DST: arriving here starts a forced chase (the dwell is its delay).
@export var force_chase_when_touch_here: bool = false

## Face the direction of travel while moving.
## DST: what the flag does in the wandering state: turn to this node's -Z while dwelling.
@export var head_to_forward: bool = true

## Sweep the head left/right while idling here, widening the effective search cone.
## DST: centre / right / left, every 3 s.
@export var swing_head: bool = false

## Successors in the patrol graph. Empty means this is a sink: the demon stays put.
## DST: several successors = random choice; from a sink the demon walks on to the nearest
## other point of its room. Successors must be in the same room.
@export var next_points: Array[BlueDemonPatrolPoint] = []: set = _set_next_points  # DST P4: editor refresh

# DST P3: SRC `source_id` (the Unity fileID an extracted point came from) is not ported.


## Editor-only visualisation. These nodes carry nothing but data, so without this the
## patrol scenes are a list of invisible Node3Ds and the graph cannot be read at a
## glance. The gizmo is an unowned child, so it is never saved into the scene.
const _GIZMO_NAME := &"_graph_gizmo"

const _TYPE_COLOURS := {
	PointType.NORMAL: Color(0.35, 0.8, 1.0),
	PointType.START: Color(0.4, 1.0, 0.45),
	PointType.ONLY_START: Color(1.0, 0.85, 0.3),
	PointType.ONLY_CALL: Color(1.0, 0.4, 0.9),
	PointType.NONE: Color(0.6, 0.6, 0.6),
}

## Radius of the ring drawn on the floor: the demon's horizontal arrival radius.
const GIZMO_ARRIVE_RADIUS := 0.5  # DST P5: BlueDemon.arrive_radius

var _gizmo: MeshInstance3D

## Editor only: the points whose gizmo draws an edge to this one. Filled by their
## _rebuild_gizmo(). Untyped, not exported: never saved, and holds no reference at runtime.
## Read it through _predecessors() only: when the editor hot-reloads this script under an
## open scene, a member added by the reload is null on the points that were already alive.
var _gizmo_predecessors = null  # DST R5

## Every point that is inside the tree of a running game (never filled in the editor).
static var _registry: Array[BlueDemonPatrolPoint] = []  # DST P2: replaces the SRC group "aooni_floor_point"


func _enter_tree() -> void:  # DST P2: static registry (SRC: add_to_group in _ready, aooni_floor_point.gd:87-88)
	# Self-registering, as in SRC: no producer has to remember to list a point, so the
	# registry is complete by construction. It empties itself again on level change.
	if not Engine.is_editor_hint() and not _registry.has(self):
		_registry.append(self)


func _exit_tree() -> void:  # DST P2
	_registry.erase(self)


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_gizmo()
		set_notify_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		_rebuild_gizmo()
		_rebuild_incoming_edges()  # DST R5


func _set_room(value: String) -> void:  # DST P4
	room = value
	if Engine.is_editor_hint():
		_rebuild_gizmo()
		update_configuration_warnings()


func _set_type(value: PointType) -> void:  # DST P4
	type = value
	if Engine.is_editor_hint():
		_rebuild_gizmo()
		update_configuration_warnings()


func _set_next_points(value: Array[BlueDemonPatrolPoint]) -> void:  # DST P4
	next_points = value
	if Engine.is_editor_hint():
		_rebuild_gizmo()
		update_configuration_warnings()


## DST R5: the edge that ends at this point belongs to the gizmo of its predecessor, so a
## moved point has those gizmos rebuilt too. Editor only, and only on a transform change:
## nothing runs per frame. An entry is dropped once its point is freed or no longer lists
## this one; a point that merely left the tree (a delete that can be undone) is kept.
func _rebuild_incoming_edges() -> void:  # DST R5
	var predecessors := _predecessors()
	for i in range(predecessors.size() - 1, -1, -1):
		var entry: Variant = predecessors[i]  # untyped on purpose: a freed object cannot be cast
		var predecessor := entry as BlueDemonPatrolPoint if is_instance_valid(entry) else null
		if predecessor == null or not predecessor.next_points.has(self):
			predecessors.remove_at(i)
		elif predecessor != self:
			predecessor._rebuild_gizmo()


func _predecessors() -> Array:  # DST R5: lazily created, see _gizmo_predecessors
	if not _gizmo_predecessors is Array:
		_gizmo_predecessors = []
	return _gizmo_predecessors


func _rebuild_gizmo() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _gizmo == null:
		_gizmo = get_node_or_null(NodePath(_GIZMO_NAME)) as MeshInstance3D
	if _gizmo == null:
		_gizmo = MeshInstance3D.new()
		_gizmo.name = _GIZMO_NAME
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.disable_receive_shadows = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_gizmo.material_override = material
		add_child(_gizmo)  # deliberately unowned: not persisted

	var colour: Color = _TYPE_COLOURS.get(type, Color.WHITE)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	# A marker: vertical post plus a cross, sized so it reads at level scale.
	mesh.surface_set_color(colour)
	for segment in [
		[Vector3.ZERO, Vector3.UP * 1.6],
		[Vector3(-0.3, 0, 0), Vector3(0.3, 0, 0)],
		[Vector3(0, 0, -0.3), Vector3(0, 0, 0.3)],
	]:
		mesh.surface_add_vertex(segment[0])
		mesh.surface_add_vertex(segment[1])

	# DST P5: a 24-segment ring on the floor — where the demon really stops (it arrives
	# within GIZMO_ARRIVE_RADIUS horizontally, not on the post).
	var ring_step := TAU / 24.0
	for i in 24:
		var ring_from := Vector3(cos(ring_step * i), 0, sin(ring_step * i))
		var ring_to := Vector3(cos(ring_step * (i + 1)), 0, sin(ring_step * (i + 1)))
		mesh.surface_add_vertex(ring_from * GIZMO_ARRIVE_RADIUS)
		mesh.surface_add_vertex(ring_to * GIZMO_ARRIVE_RADIUS)

	# Facing arrow — the direction the demon turns to while thinking here.
	mesh.surface_set_color(colour.lightened(0.3))
	var tip := Vector3(0, 1.6, -1.0)
	mesh.surface_add_vertex(Vector3.UP * 1.6)
	mesh.surface_add_vertex(tip)
	for side in [Vector3(0.18, 0, 0.25), Vector3(-0.18, 0, 0.25)]:
		mesh.surface_add_vertex(tip)
		mesh.surface_add_vertex(tip + side)

	# Edges to successors, drawn with a mid-point chevron so direction is visible.
	mesh.surface_set_color(Color(1.0, 0.55, 0.2))
	for point in next_points:
		if point != null and not point._predecessors().has(self):  # DST R5
			point._predecessors().append(self)  # DST R5: this gizmo must follow when `point` moves
		if point == null or not point.is_inside_tree():
			continue
		var cross_room := room != "" and point.room != "" and point.room != room  # DST P6
		mesh.surface_set_color(Color(1.0, 0.15, 0.15) if cross_room else Color(1.0, 0.55, 0.2))  # DST P6: red = edge into another room
		var to := to_local(point.global_position) + Vector3.UP * 0.9
		var from := Vector3.UP * 0.9
		mesh.surface_add_vertex(from)
		mesh.surface_add_vertex(to)
		var mid := from.lerp(to, 0.55)
		var dir := (to - from).normalized()
		var side := dir.cross(Vector3.UP).normalized() * 0.25
		for wing in [side, -side]:
			mesh.surface_add_vertex(mid)
			mesh.surface_add_vertex(mid - dir * 0.5 + wing)

	mesh.surface_end()
	_gizmo.mesh = mesh


func pick_next() -> BlueDemonPatrolPoint:
	var candidates: Array[BlueDemonPatrolPoint] = []
	for point in next_points:
		if point != null and point.is_inside_tree():  # DST R1: as BlueDemonPatrolPointData.pick_next()
			candidates.append(point)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	# DST P7: SRC's "No next_points" warning is dropped — a sink is legal, the demon then
	# walks to the nearest other point.
	for point in next_points:
		if point == null:
			warnings.append("next_points contains an empty slot.")
			break
	for i in next_points.size():  # DST P7: a graph edge must not lead across a teleport
		var successor := next_points[i]
		if not is_instance_valid(successor):
			continue
		if room != "" and successor.room != "" and successor.room != room:
			warnings.append(
				"next_points[%d] is in room '%s' but this point is in room '%s': the demon never patrols across rooms."
				% [i, successor.room, room]
			)
	if moving_speed <= 0.0:  # DST P7
		warnings.append("moving_speed must be > 0.")
	return warnings


## DST P2: the valid points that are inside the tree — what BlueDemon.get_patrol_points()
## filters by patrol_root and room. Replaces the SRC group lookup of the wandering state.
static func get_registered() -> Array[BlueDemonPatrolPoint]:
	var result: Array[BlueDemonPatrolPoint] = []
	for point in _registry:
		if is_instance_valid(point) and point.is_inside_tree():
			result.append(point)
	return result
