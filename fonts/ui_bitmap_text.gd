extends HBoxContainer


var white_font_images := {
	"0": preload("uid://berleh354tn6p"),
	"1": preload("uid://dic02hagqtsxl"),
	"2": preload("uid://qv3ajcxgtbj2"),
	"3": preload("uid://chm4dt1blag01"),
	"4": preload("uid://brgb80snrygm3"),
	"5": preload("uid://bosy875ua5cee"),
	"6": preload("uid://bx6he2dphqw5n"),
	"7": preload("uid://5uwvpnuah1j3"),
	"8": preload("uid://dpw5o6jubi8su"),
	"9": preload("uid://qlhm3njom5au")
}

var font_scale := 0.4


func _ready() -> void:
	set_value_with_aooni_font(919) # test - remove later


func set_value_with_aooni_font(value: int) -> void:
	for node in get_children():
		remove_child(node)
		node.queue_free()
	
	var value_text := str(value)
	
	for digit: String in value_text:
		var digit_texture = TextureRect.new()
		digit_texture.texture = white_font_images[digit]
		digit_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		digit_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(digit_texture)
