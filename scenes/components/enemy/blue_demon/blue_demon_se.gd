class_name BlueDemonSe
extends AudioStreamPlayer

## The blue demon's sting player — port of the demon half of `u823.AudioController`
## (SRC `GameAudioController.play_aooni_se` / `stop_aooni_se` / `_is_same_clip` / `_with_loop`,
## audio_controller.gd:109-154,200-227, and the `GameAudioTuning.AOONI_SE` table).
##
## The SE source is **not** fire-and-forget. `AooniSE` assigns a clip, sets a volume and
## pitch, and for `Chase` sets `loop = true`, so the chase sting keeps running until
## [method stop_se] takes it away — which is why [BlueDemon] emits both `se_requested` and
## `se_stopped`.
##
## | `SeType` | clip | volume | loops |
## |---|---|---|---|
## | `FIND` | `ホラータイトル表示音` (horror title) | 0.30 | no |
## | `LOOK` | `恐怖` (dread) | 0.15 | no |
## | `CHASE` | `バイオリン恐怖音1` (violin) | 0.25 | yes, pitch 0.92 |
## | `NONE` | — | — | stops |
##
## DST: SRC's level owned one 2-D player on the `BGM` bus and wired it to the demon
## (`attach_aooni`, audio_controller.gd:68-76). dark-chasers has no level audio controller, so
## the demon owns the player (the `SePlayer` child, bus `Music`) and `BlueDemon._ready`
## connects its own `se_requested` / `se_stopped` to it. This script *is* the player: SRC's
## `aooni_se_player` is `self`. The `GAME_OVER` variant belongs to the kill cutscene and is
## not ported (porting decision 2).

## [linear volume, pitch (0 = the branch writes none), loops], indexed by BlueDemon.SeType.
## SRC GameAudioTuning.AOONI_SE rows 0-2 (the GAME_OVER row belongs to the kill cutscene).
##
## Two things here are worth not tidying up. The looping entry keeps playing until
## `AooniSE(None)` stops it, which is what the demon's `se_stopped` signal is for. And
## **only the chase branch touches the pitch**, so once a chase has happened the source
## stays at 0.92 and every later Find and Look sting plays 8 % slow.
##
## DST: SRC's rows start with a clip index into `aooni_se_clips`; here the three clips are
## the three exports below, so that column is gone.
const SE_TABLE := [
	[0.30, 0.0, false],   # FIND  — horror_title.wav
	[0.15, 0.0, false],   # LOOK  — fear_drone.wav
	[0.25, 0.92, true],   # CHASE — violin_horror_1.wav
]

@export var find_stream: AudioStream
@export var look_stream: AudioStream
@export var chase_stream: AudioStream


## Port of `AudioController.AooniSE(AooniSeType)`.
func play_se(se_type: int) -> void:
	if se_type == BlueDemon.SeType.NONE:
		stop()
		return
	if se_type < 0 or se_type >= SE_TABLE.size():  # DST: SRC bounds-checked the clip index instead
		return
	var entry: Array = SE_TABLE[se_type]
	var volume: float = entry[0]
	var pitch: float = entry[1]
	var loops: bool = entry[2]
	var clips: Array[AudioStream] = [find_stream, look_stream, chase_stream]  # DST: SRC `aooni_se_clips`
	var clip := clips[se_type]
	if clip == null:
		return

	# Two re-entry guards, which the port used to be missing. `Find` is dropped outright if
	# anything at all is already playing, and `Look` is dropped if the drone is playing
	# already — but `Chase` really does restart unconditionally. Without the first one the
	# `Find` that fires on entering a chase cuts off a running violin
	# [disasm 0x1806B8858 get_isPlaying -> jne epilogue; 0x1806B87ED op_Equality against
	# clips[1] then 0x1806B8805 get_isPlaying].
	if se_type == BlueDemon.SeType.FIND and playing:
		return
	if (
		se_type == BlueDemon.SeType.LOOK
		and playing
		and _is_same_clip(stream, clip)
	):
		return

	# Looping is a property of the stream in Godot and of the source in Unity, so a
	# looping SE needs its own stream instance rather than the shared resource.
	stream = _with_loop(clip, loops)
	volume_db = linear_to_db(volume)
	# A zero in the table means that branch of the original never writes a pitch, so the
	# source keeps whatever the previous SE left on it — which is why `Find` and `Look`
	# inherit the chase sting's 0.92 once a chase has happened. Assigning the zero is not
	# an option: Godot rejects a non-positive `pitch_scale` outright.
	if pitch > 0.0:
		pitch_scale = pitch
	play()


## Port of `AudioController.AooniSE(None)`.
func stop_se() -> void:
	stop()


## The playing stream may be a private looping duplicate of the clip rather than the clip
## itself, so identity is not enough.
func _is_same_clip(playing_stream: AudioStream, clip: AudioStream) -> bool:  # DST: SRC's parameter `playing` would shadow AudioStreamPlayer.playing here
	if playing_stream == null or clip == null:
		return false
	if playing_stream == clip:
		return true
	return (
		not playing_stream.resource_path.is_empty()
		and playing_stream.resource_path == clip.resource_path
	)


## Godot expresses looping on the stream, Unity on the source, so a looping SE gets a
## private duplicate — otherwise setting `loop` here would silently make every other user
## of that clip loop too.
func _with_loop(clip: AudioStream, should_loop: bool) -> AudioStream:
	if not (clip is AudioStreamWAV):
		return clip
	var wav := clip as AudioStreamWAV
	var wants := AudioStreamWAV.LOOP_FORWARD if should_loop else AudioStreamWAV.LOOP_DISABLED
	if wav.loop_mode == wants:
		return wav
	var copy := wav.duplicate() as AudioStreamWAV
	copy.loop_mode = wants
	copy.loop_begin = 0
	# The loop end must be the last frame, not zero. Godot wraps the play head when it
	# passes `loop_end`, so `loop_begin = loop_end = 0` is a zero-length loop: the sample
	# sticks on frame one and the sting is silent. `data.size()` cannot be used to count
	# frames because the importer may have compressed the stream (these arrive as QOA), so
	# the length is taken from the stream itself.
	copy.loop_end = int(round(wav.get_length() * float(wav.mix_rate)))
	return copy
