@tool
class_name SfxCatalog
extends Resource

## Resource-based catalog for game sound effects.
## Decouples sound playback from hardcoded res:// paths in Preloads.

@export_group("Item Sounds")
@export var key_collected: AudioStream
@export var water_splash: AudioStream

@export_group("Combat Sounds")
@export var kill_player: AudioStream

@export_group("Event Sounds")
@export var event_trigger: AudioStream
@export var spawn: AudioStream
@export var bar_shake: AudioStream
@export var wall_cut: AudioStream

@export_group("Music/Ambience")
@export var creep_ambience: AudioStream
@export var ao_see: AudioStream
@export var d_running: AudioStream
