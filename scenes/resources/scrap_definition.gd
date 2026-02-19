class_name ScrapDefinition
extends Resource

## Defines a single type of scrap to spawn when a destructible object is destroyed.

@export var scrap_type: String = ""
@export var count: int = 1
@export var count_variation: Array[int] = [] ## If non-empty, picks random from this array instead of using count
@export var horizontal_velocity: float = 5.0
@export var vertical_velocity: float = 5.0
@export var position_offset: Vector3 = Vector3.ZERO
