class_name EnemyKillZoneComponent
extends Area3D

signal player_killed(player: Node3D)

@export var death_message: String = ""
@export var enabled: bool = true

var _owner_enemy: Enemy = null


func _ready() -> void:
	_owner_enemy = owner
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not enabled:
		return

	# Prevent duplicate death/events if the player stays inside the kill zone.
	if not Mortal.is_alive(body):
		return
	
	if body.is_in_group("player"):
		var msg = ""
		if death_message != "":
			msg = body.name + " " + death_message
		
		# Use Mortal interface to kill the player
		Mortal.kill(body, global_position, msg)

		# Map scripts can react to typed events via Services.event_bus.
		Services.event_bus.emit(
			&"enemy_killed_player",
			{
				"body": body,
				"enemy": _owner_enemy,
			},
			_owner_enemy
		)
		
		player_killed.emit(body)
		
		if _owner_enemy:
			_owner_enemy.current_target = null
			_owner_enemy.velocity = Vector3.ZERO


func set_death_message_value(msg: String) -> void:
	death_message = msg
