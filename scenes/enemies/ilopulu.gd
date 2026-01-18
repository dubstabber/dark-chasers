extends Enemy

@onready var animation_component: EnemyAnimationComponent = $EnemyAnimationComponent


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if animation_component:
		animation_component.update_animation_state()
