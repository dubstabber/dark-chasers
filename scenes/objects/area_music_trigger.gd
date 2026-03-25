class_name AreaMusicTrigger
extends Area3D

@export var sound_id: StringName = &""
@export var music_player: AudioStreamPlayer
@export var volume_db: float = -15.0
@export var trigger_once: bool = false

var _triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if trigger_once and _triggered:
		return
	if sound_id == &"":
		push_warning("AreaMusicTrigger: sound_id is empty on '%s'" % name)
		return
	if not music_player:
		push_warning("AreaMusicTrigger: music_player is not assigned on '%s'" % name)
		return

	var sound: AudioStream = Services.get_sfx_catalog().get_sound(sound_id)
	if not sound:
		push_warning("AreaMusicTrigger: sound id '%s' was not found in SfxCatalog" % String(sound_id))
		return

	# Avoid restarting from the beginning if this track is already playing on the target player.
	if music_player.stream == sound and music_player.playing:
		if trigger_once:
			_triggered = true
		return

	_triggered = true
	music_player.stream = sound
	music_player.volume_db = volume_db
	music_player.play()
