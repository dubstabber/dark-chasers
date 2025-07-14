extends AnimatedSprite3D


func _physics_process(delta: float) -> void:
    position.y += 0.6 * delta
