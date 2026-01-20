class_name EnemyAbilityContext
extends RefCounted

var enemy_position: Vector3
var target_position: Vector3
var distance_to_target: float
var enemy_health_percent: float
var time_since_last_ability: float
var is_target_visible: bool
var has_target: bool


static func build(enemy: CharacterBody3D, ai_component: EnemyAIComponent = null, health_component: HealthComponent = null) -> EnemyAbilityContext:
	var ctx := EnemyAbilityContext.new()
	ctx.enemy_position = enemy.global_position
	
	if ai_component and ai_component.has_target():
		ctx.has_target = true
		ctx.target_position = ai_component.get_target_position()
		ctx.distance_to_target = ctx.enemy_position.distance_to(ctx.target_position)
		ctx.is_target_visible = ai_component.check_line_of_sight
	else:
		ctx.has_target = false
		ctx.target_position = Vector3.ZERO
		ctx.distance_to_target = INF
		ctx.is_target_visible = false
	
	if health_component:
		ctx.enemy_health_percent = health_component.get_health_percentage()
	else:
		ctx.enemy_health_percent = 1.0
	
	ctx.time_since_last_ability = INF
	
	return ctx
