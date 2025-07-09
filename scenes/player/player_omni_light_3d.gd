extends OmniLight3D


@export var lighter_source: Node


func _ready() -> void:
	if lighter_source:
		lighter_source.lighter_on.connect(light_lighter)
		lighter_source.lighter_off.connect(extinguish_lighter)


func light_lighter() -> void:
	light_energy = 0.6
	light_color = Color.YELLOW


func extinguish_lighter() -> void:
	light_energy = 0.06
	light_color = Color.WHITE