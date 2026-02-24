@tool
class_name ParticleTextureSetEntry
extends Resource

@export var id: StringName = &""
@export var textures: Array[Texture2D] = []

## Optional per-texture weights for weighted random selection.
## If empty or size != textures.size(), ParticleCatalog will treat all weights as 1.
@export var weights: Array[int] = []
