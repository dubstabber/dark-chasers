class_name EnemyDefinition
extends Resource

## Typed resource for static-image enemy configuration.
## Replaces dictionary-based EnemyDb entries with editor-friendly resources.

@export var enemy_name: String
@export var image: Texture2D
@export var music: AudioStream
@export var music_playlist: Array[AudioStream]


func has_music() -> bool:
	return music != null


func has_playlist() -> bool:
	return music_playlist.size() > 0


func get_random_music() -> AudioStream:
	if music_playlist.size() > 0:
		return music_playlist.pick_random()
	return music
