class_name EnemyBrain
extends Node

signal state_changed(old_state: StringName, new_state: StringName)
signal ability_started(ability: EnemyAbility)
signal ability_ended(ability: EnemyAbility)

@export var abilities: Array[EnemyAbility] = []
@export var enabled: bool = true

var current_state_name: StringName = &"idle"
var active_ability: EnemyAbility = null
var time_since_last_ability: float = INF

var _owner_enemy: CharacterBody3D = null
var _ai_component: EnemyAIComponent = null
var _health_component: HealthComponent = null


func _ready() -> void:
	_owner_enemy = owner as CharacterBody3D
	if _owner_enemy:
		_ai_component = _owner_enemy.get_node_or_null("EnemyAIComponent")
		_health_component = _owner_enemy.get_node_or_null("HealthComponent")
	_duplicate_abilities()


func _physics_process(delta: float) -> void:
	if not enabled or not _owner_enemy:
		return
	
	time_since_last_ability += delta
	
	if active_ability == null:
		_try_activate_ability()
	
	if active_ability:
		_process_active_ability(delta)


func _try_activate_ability() -> void:
	var context := _build_context()
	for ability in abilities:
		if ability.can_activate(context):
			_start_ability(ability)
			break


func _start_ability(ability: EnemyAbility) -> void:
	active_ability = ability
	time_since_last_ability = 0.0
	ability.activate(_owner_enemy)
	ability_started.emit(ability)


func _process_active_ability(delta: float) -> void:
	var status := active_ability.process(_owner_enemy, delta)
	if status != EnemyAbility.AbilityStatus.RUNNING:
		_end_ability()


func _end_ability() -> void:
	if active_ability:
		active_ability.deactivate(_owner_enemy)
		ability_ended.emit(active_ability)
		active_ability = null


func _build_context() -> EnemyAbilityContext:
	var ctx := EnemyAbilityContext.build(_owner_enemy, _ai_component, _health_component)
	ctx.time_since_last_ability = time_since_last_ability
	return ctx


func is_ability_active() -> bool:
	return active_ability != null


func get_active_ability() -> EnemyAbility:
	return active_ability


func cancel_ability() -> void:
	if active_ability:
		_end_ability()


func change_state(new_state: StringName) -> void:
	var old_state := current_state_name
	current_state_name = new_state
	state_changed.emit(old_state, new_state)


func _duplicate_abilities() -> void:
	var duplicated: Array[EnemyAbility] = []
	for ability in abilities:
		if ability:
			duplicated.append(ability.duplicate())
	abilities = duplicated
