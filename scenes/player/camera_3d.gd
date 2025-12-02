extends Camera3D

@onready var crosshair_rect: TextureRect = $CrosshairRect


func _physics_process(_delta: float) -> void:
	var current_camera = get_viewport().get_camera_3d()
	if self != current_camera:
		if crosshair_rect.visible: crosshair_rect.hide()
	else:
		if not crosshair_rect.visible: crosshair_rect.show()
