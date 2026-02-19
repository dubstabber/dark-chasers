class_name DoorAudioComponent
extends Node

signal sound_started(sound_player: AudioStreamPlayer3D, is_open_sound: bool)

@export var open_sound: AudioStream
@export var close_sound: AudioStream
@export var stop_sound: AudioStream
@export var locked_sound: AudioStream

var _current_open_sound: AudioStreamPlayer3D
var _current_close_sound: AudioStreamPlayer3D
var _sound_parent: Node3D


func setup(parent: Node3D) -> void:
	_sound_parent = parent


func play_open_sound() -> void:
	if open_sound and _sound_parent:
		var new_sound = Services.utils.play_sound(open_sound, _sound_parent)
		_update_current_sound_reference(new_sound, true)


func play_close_sound() -> void:
	if close_sound and _sound_parent:
		var new_sound = Services.utils.play_sound(close_sound, _sound_parent)
		_update_current_sound_reference(new_sound, false)


func play_stop_sound() -> void:
	if stop_sound and _sound_parent:
		Services.utils.play_sound(stop_sound, _sound_parent)


func play_locked_sound() -> void:
	if locked_sound and _sound_parent:
		Services.utils.play_sound(locked_sound, _sound_parent)


func stop_looping_sounds() -> void:
	if _current_open_sound and is_instance_valid(_current_open_sound):
		if _is_sound_looping(_current_open_sound.stream):
			_current_open_sound.stop()
		_current_open_sound = null

	if _current_close_sound and is_instance_valid(_current_close_sound):
		if _is_sound_looping(_current_close_sound.stream):
			_current_close_sound.stop()
		_current_close_sound = null


func _is_sound_looping(audio_stream: AudioStream) -> bool:
	if audio_stream is AudioStreamOggVorbis:
		return audio_stream.loop
	elif audio_stream is AudioStreamWAV:
		return audio_stream.loop_mode != AudioStreamWAV.LOOP_DISABLED
	elif audio_stream is AudioStreamMP3:
		return audio_stream.loop
	return false


func _update_current_sound_reference(new_sound: AudioStreamPlayer3D, is_open_sound: bool) -> void:
	if is_open_sound:
		if _current_open_sound and is_instance_valid(_current_open_sound):
			if _is_sound_looping(_current_open_sound.stream):
				_current_open_sound.stop()
		_current_open_sound = new_sound
	else:
		if _current_close_sound and is_instance_valid(_current_close_sound):
			if _is_sound_looping(_current_close_sound.stream):
				_current_close_sound.stop()
		_current_close_sound = new_sound
	sound_started.emit(new_sound, is_open_sound)
