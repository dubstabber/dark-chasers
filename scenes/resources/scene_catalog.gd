@tool
class_name SceneCatalog
extends Resource

## Resource-based catalog for core game scenes (player, HUD, enemies).
## Decouples scene instantiation from hardcoded res:// paths in Preloads.

@export_group("Core Scenes")
@export var player_scene: PackedScene
@export var hud_scene: PackedScene

@export_group("Enemy Scenes")
@export var aooni_scene: PackedScene
@export var ilopulu_scene: PackedScene
@export var whiteface_scene: PackedScene
@export var image_enemy_scene: PackedScene
