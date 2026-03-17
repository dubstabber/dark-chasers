@tool
class_name TransitionArrivalMarker
extends Marker3D

## Inspector-facing config for marker-based arrival facing.

const TransitionArrival := preload("res://scenes/components/transition/transition_arrival.gd")

@export_enum("KEEP_CURRENT", "MATCH_MARKER_YAW", "MATCH_MARKER_FULL") var arrival_rotation_mode: int = TransitionArrival.RotationMode.KEEP_CURRENT
