class_name DetectionConfig
extends Resource

## Reusable configuration resource for enemy detection and targeting behavior.
## Create .tres files to share detection configurations across enemy variants.

@export_group("Detection")
@export var detection_enabled: bool = true
@export var check_line_of_sight: bool = true

@export_group("Targeting")
@export var chase_player: bool = true
@export var lose_target_on_death: bool = true

@export_group("Debug")
@export var debug_prints: bool = false
