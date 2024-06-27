extends MeshInstance3D

var walls_material

func _ready():
	walls_material = get_surface_override_material(0)

func _process(_delta):
	walls_material.set_shader_parameter("volume_position", global_transform.origin)
	walls_material.set_shader_parameter("volume_scale", global_transform.basis.get_scale())

