class_name BloodConfig
extends Resource

## Reusable configuration resource for blood effect settings.
## Create .tres files to share blood configurations across enemy variants.

@export_group("Appearance")
@export var blood_color: Color = Color(0.6, 0.0, 0.0, 1.0)
@export var splatter_scale: float = 1.0

@export_group("Particles")
@export var splatter_scene: PackedScene
@export var wall_trace_scene: PackedScene

@export_group("Behavior")
@export var enabled: bool = true
@export var wall_trace_enabled: bool = true
@export var max_trace_distance: float = 10.0
