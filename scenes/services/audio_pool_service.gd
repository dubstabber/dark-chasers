extends Node

## Audio pooling service to reduce churn from short-lived audio nodes.
## Maintains a pool of reusable AudioStreamPlayer3D nodes with concurrency limits.

signal pool_exhausted(requested_stream: AudioStream)

@export var pool_size: int = 16
@export var max_concurrent_per_sound: int = 4

var _pool: Array[AudioStreamPlayer3D] = []
var _active_count: Dictionary = {} # stream_path -> count


func _ready() -> void:
	_initialize_pool()


func _initialize_pool() -> void:
	for i in range(pool_size):
		var player = AudioStreamPlayer3D.new()
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
		add_child(player)
		player.finished.connect(_on_player_finished.bind(player))
		_pool.append(player)


func _on_player_finished(player: AudioStreamPlayer3D) -> void:
	# Decrement active count for this stream
	if player.stream:
		var path = player.stream.resource_path
		if path in _active_count:
			_active_count[path] = max(0, _active_count[path] - 1)
	
	# Reset and return to pool
	player.stream = null
	player.global_position = Vector3.ZERO
	player.pitch_scale = 1.0


func _get_available_player() -> AudioStreamPlayer3D:
	for player in _pool:
		if not player.playing:
			return player
	return null


func play_sound_3d(stream: AudioStream, position: Vector3, volume_db: float = -25.0) -> AudioStreamPlayer3D:
	if not stream:
		return null
	
	# Check concurrency limit
	var path = stream.resource_path
	if path and path in _active_count and _active_count[path] >= max_concurrent_per_sound:
		return null
	
	var player = _get_available_player()
	if not player:
		pool_exhausted.emit(stream)
		return null
	
	# Track active count
	if path:
		_active_count[path] = _active_count.get(path, 0) + 1
	
	player.stream = stream
	player.global_position = position
	player.volume_db = volume_db
	player.play()
	
	return player


func play_footstep(stream: AudioStream, position: Vector3, volume_db: float = -20.0) -> AudioStreamPlayer3D:
	return play_sound_3d(stream, position, volume_db)


func get_pool_stats() -> Dictionary:
	var active := 0
	for player in _pool:
		if player.playing:
			active += 1
	return {
		"pool_size": pool_size,
		"active": active,
		"available": pool_size - active
	}
