class_name VfxCatalog
extends Resource

## Resource-based catalog for VFX PackedScene effects.
## For scrap textures and sounds, use ParticleCatalog instead.

@export_group("Blood Effects")
@export var red_blood_particle: PackedScene
@export var blue_blood_particle: PackedScene
@export var blood_splat_decal: PackedScene

@export_group("Scrap")
@export var scrap_scene: PackedScene
