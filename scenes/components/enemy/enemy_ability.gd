@abstract
class_name EnemyAbility
extends Resource

enum AbilityStatus {RUNNING, COMPLETED, CANCELLED}

@export var ability_name: String = ""
@export var cooldown: float = 5.0


func can_activate(context: EnemyAbilityContext) -> bool:
	return context.time_since_last_ability >= cooldown


@abstract
func activate(_enemy: CharacterBody3D) -> void


@abstract
func process(_enemy: CharacterBody3D, _delta: float) -> AbilityStatus


@abstract
func deactivate(_enemy: CharacterBody3D) -> void
