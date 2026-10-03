class_name BlueDemonPatrolPointData
extends RefCounted

## One patrol-graph node's data — port of `u823.AooniFloorPointData`.
##
## The original keeps this separate from the [BlueDemonPatrolPoint] MonoBehaviour on purpose:
## the chase state manufactures *synthetic* points at runtime that exist nowhere in the
## level, to send the demon somewhere specific and then have it stand around. When it
## gives up a chase, for instance, it builds one at its own position with
## `ThinkingTime = 9`, no successors and `IsSwingHead = true`, so the demon stops and
## looks around before resuming its patrol.
##
## `MovingSpeed` defaults to 1 because the original's constructor writes 1.0 into it.

var type: BlueDemonPatrolPoint.PointType = BlueDemonPatrolPoint.PointType.NORMAL
var moving_speed: float = 1.0
var thinking_time: float = 0.0
var wait_until_call: bool = false
var ignore_player_until_call: bool = false
var ignore_player_until_touch_here: bool = false
var force_chase_when_touch_here: bool = false
var head_to_forward: bool = true
var swing_head: bool = false
var position: Vector3 = Vector3.ZERO
var rotation: Quaternion = Quaternion.IDENTITY

## Successors. Empty for synthetic points, which is what makes the demon stay put.
var next_points: Array[BlueDemonPatrolPoint] = []

## The graph node this was copied from, or null for a transient point. Used to tell
## "where I am" and "where I came from" apart when picking the next destination.
var source_point: BlueDemonPatrolPoint

## Room id copied from the node; "" for transient points.
var room: String = ""  # DST PD1: rooms (BlueDemonPatrolPoint.room)
## Non-empty only for a return-home hop: the gate (room transition) to take on arrival.
var hop_transition: String = ""  # DST PD2: return-home hop
## The room the hop was made in; the gate is only taken while the demon is still there.
var hop_from_room: String = ""  # DST PD2: return-home hop


static func from_point(point: BlueDemonPatrolPoint) -> BlueDemonPatrolPointData:
	var data := BlueDemonPatrolPointData.new()
	data.source_point = point
	data.type = point.type
	data.moving_speed = point.moving_speed
	data.thinking_time = point.thinking_time
	data.wait_until_call = point.wait_until_call
	data.ignore_player_until_call = point.ignore_player_until_call
	data.ignore_player_until_touch_here = point.ignore_player_until_touch_here
	data.force_chase_when_touch_here = point.force_chase_when_touch_here
	data.head_to_forward = point.head_to_forward
	data.swing_head = point.swing_head
	data.position = point.global_position
	data.rotation = point.global_basis.get_rotation_quaternion()
	data.next_points = point.next_points
	data.room = point.room  # DST PD1: rooms
	return data


## The shape the chase state builds when it wants the demon to go somewhere and wait.
static func make_transient(
	at: Vector3, dwell: float, speed: float = 1.0
) -> BlueDemonPatrolPointData:
	var data := BlueDemonPatrolPointData.new()
	data.position = at
	data.thinking_time = dwell
	data.moving_speed = speed
	data.head_to_forward = false
	data.swing_head = true
	data.next_points = []
	return data


## DST PD2: a transient point at a room gate, built for the return-home hop
## (BlueDemonTravel.make_homeward_hop). No dwell, no facing, no head sweep, no successors:
## on arrival (or when blocked at the gate) the wandering state takes the transition.
## [param speed] is in SRC units, like every moving_speed.
static func make_hop(
	at: Vector3, transition_name: String, from_room: String, speed: float
) -> BlueDemonPatrolPointData:
	var data := BlueDemonPatrolPointData.new()
	data.position = at
	data.thinking_time = 0.0
	data.moving_speed = speed
	data.head_to_forward = false
	data.swing_head = false
	data.next_points = []
	data.hop_transition = transition_name
	data.hop_from_room = from_room
	return data


## Did this data come from that node? The original compares `AooniFloorPointData`
## references directly, since each `AooniFloorPoint` owns exactly one; here the data is
## copied out of the node, so identity is tracked through [member source_point].
func matches(point: BlueDemonPatrolPoint) -> bool:
	return point != null and source_point == point


func pick_next() -> BlueDemonPatrolPoint:
	var candidates: Array[BlueDemonPatrolPoint] = []
	for point in next_points:
		if point != null and point.is_inside_tree():  # DST R1: a successor that left the tree has no position (from_point would read the world origin)
			candidates.append(point)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]
