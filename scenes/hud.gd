extends CanvasLayer

@onready var label = $MarginContainer/Label

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func _on_player_mode_changed(mode, value):
	match mode:
		'clip_mode':
			if value:
				label.text = 'Clip mode enabled'
			else:
				label.text = ''
