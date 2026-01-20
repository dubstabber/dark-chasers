class_name EnemyAbility
extends Resource

enum AbilityStatus {RUNNING, COMPLETED, CANCELLED}

@export var ability_name: String = ""
@export var cooldown: float = 5.0


func can_activate(context: EnemyAbilityContext) -> bool:
	return context.time_since_last_ability >= cooldown


func activate(_enemy: CharacterBody3D) -> void:
	pass


func process(_enemy: CharacterBody3D, _delta: float) -> AbilityStatus:
	return AbilityStatus.COMPLETED


func deactivate(_enemy: CharacterBody3D) -> void:
	pass
