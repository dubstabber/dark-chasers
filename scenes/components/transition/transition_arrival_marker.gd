@tool
class_name TransitionArrivalMarker
extends Marker3D

## Inspector-facing config for marker-based arrival facing.

@export_enum("KEEP_CURRENT", "MATCH_MARKER_YAW", "MATCH_MARKER_FULL") var arrival_rotation_mode: int = TransitionArrival.RotationMode.KEEP_CURRENT
