extends Camera3D

@onready var gun_base: Node2D = $LegacyGunBase2D
@onready var crosshair_rect: TextureRect = $CrosshairRect


func _physics_process(_delta: float) -> void:
	var current_camera = get_viewport().get_camera_3d()
	if self != current_camera:
		if gun_base.visible: gun_base.hide()
		if crosshair_rect.visible: crosshair_rect.hide()
	else:
		if not gun_base.visible: gun_base.show()
		if not crosshair_rect.visible: crosshair_rect.show()
