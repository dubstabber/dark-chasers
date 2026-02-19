class_name WeaponSoundController
extends RefCounted

## Handles weapon sound effects (draw, holster, hit, lighter).
## Extracted from WeaponManager to enforce SRP.

var _hit_sound_player: AudioStreamPlayer3D
var _weapon_sound_player: AudioStreamPlayer3D


func setup(hit_sound_player: AudioStreamPlayer3D, weapon_sound_player: AudioStreamPlayer3D) -> void:
	_hit_sound_player = hit_sound_player
	_weapon_sound_player = weapon_sound_player


func play_draw_sound(weapon: WeaponResource, animation_player: AnimationPlayer) -> void:
	if not weapon or not _weapon_sound_player:
		return
	
	var sound_to_play: AudioStream = null
	var is_playing_backwards: bool = animation_player.get_playing_speed() < 0.0

	if is_playing_backwards:
		sound_to_play = weapon.holster_sound
	else:
		sound_to_play = weapon.draw_sound
	
	if sound_to_play:
		_weapon_sound_player.stream = sound_to_play
		_weapon_sound_player.play()


func play_holster_sound(weapon: WeaponResource, animation_player: AnimationPlayer) -> void:
	if not weapon or not _weapon_sound_player:
		return
	
	var sound_to_play: AudioStream = null
	var is_playing_backwards: bool = animation_player.get_playing_speed() < 0.0

	if is_playing_backwards:
		sound_to_play = weapon.draw_sound
	else:
		sound_to_play = weapon.holster_sound
	
	if sound_to_play:
		_weapon_sound_player.stream = sound_to_play
		_weapon_sound_player.play()


func play_hit_sound(weapon: WeaponResource) -> void:
	if not weapon or not _hit_sound_player:
		return
	
	if weapon.hit_sound:
		_hit_sound_player.stream = weapon.hit_sound
		_hit_sound_player.play()


func set_hit_sound_stream(weapon: WeaponResource) -> void:
	"""Set the hit sound player's stream without playing (for weapon equip)."""
	if _hit_sound_player:
		_hit_sound_player.stream = weapon.hit_sound if weapon and weapon.hit_sound else null
