extends Control

var letter_images := {
	"0": preload("res://images/fonts/AOMFN048.png"),
	"1": preload("res://images/fonts/AOMFN049.png"),
	"2": preload("res://images/fonts/AOMFN050.png"),
	"3": preload("res://images/fonts/AOMFN051.png"),
	"4": preload("res://images/fonts/AOMFN052.png"),
	"5": preload("res://images/fonts/AOMFN053.png"),
	"6": preload("res://images/fonts/AOMFN054.png"),
	"7": preload("res://images/fonts/AOMFN055.png"),
	"8": preload("res://images/fonts/AOMFN056.png"),
	"9": preload("res://images/fonts/AOMFN057.png"),
	"A": preload("res://images/fonts/AOMFN065.png"),
	"a": preload("res://images/fonts/AOMFN065.png"),
	"B": preload("res://images/fonts/AOMFN066.png"),
	"b": preload("res://images/fonts/AOMFN066.png"),
	"C": preload("res://images/fonts/AOMFN067.png"),
	"c": preload("res://images/fonts/AOMFN067.png"),
	"D": preload("res://images/fonts/AOMFN068.png"),
	"d": preload("res://images/fonts/AOMFN068.png"),
	"E": preload("res://images/fonts/AOMFN069.png"),
	"e": preload("res://images/fonts/AOMFN069.png"),
	"F": preload("res://images/fonts/AOMFN070.png"),
	"f": preload("res://images/fonts/AOMFN070.png"),
	"G": preload("res://images/fonts/AOMFN071.png"),
	"g": preload("res://images/fonts/AOMFN071.png"),
	"H": preload("res://images/fonts/AOMFN072.png"),
	"h": preload("res://images/fonts/AOMFN072.png"),
	"I": preload("res://images/fonts/AOMFN073.png"),
	"i": preload("res://images/fonts/AOMFN073.png"),
	"J": preload("res://images/fonts/AOMFN074.png"),
	"j": preload("res://images/fonts/AOMFN074.png"),
	"K": preload("res://images/fonts/AOMFN075.png"),
	"k": preload("res://images/fonts/AOMFN075.png"),
	"L": preload("res://images/fonts/AOMFN076.png"),
	"l": preload("res://images/fonts/AOMFN076.png"),
	"M": preload("res://images/fonts/AOMFN077.png"),
	"m": preload("res://images/fonts/AOMFN077.png"),
	"N": preload("res://images/fonts/AOMFN078.png"),
	"n": preload("res://images/fonts/AOMFN078.png"),
	"O": preload("res://images/fonts/AOMFN079.png"),
	"o": preload("res://images/fonts/AOMFN079.png"),
	"P": preload("res://images/fonts/AOMFN080.png"),
	"p": preload("res://images/fonts/AOMFN080.png"),
	"Q": preload("res://images/fonts/AOMFN081.png"),
	"q": preload("res://images/fonts/AOMFN081.png"),
	"R": preload("res://images/fonts/AOMFN082.png"),
	"r": preload("res://images/fonts/AOMFN082.png"),
	"S": preload("res://images/fonts/AOMFN083.png"),
	"s": preload("res://images/fonts/AOMFN083.png"),
	"T": preload("res://images/fonts/AOMFN084.png"),
	"t": preload("res://images/fonts/AOMFN084.png"),
	"U": preload("res://images/fonts/AOMFN085.png"),
	"u": preload("res://images/fonts/AOMFN085.png"),
	"V": preload("res://images/fonts/AOMFN086.png"),
	"v": preload("res://images/fonts/AOMFN086.png"),
	"W": preload("res://images/fonts/AOMFN087.png"),
	"w": preload("res://images/fonts/AOMFN087.png"),
	"X": preload("res://images/fonts/AOMFN088.png"),
	"x": preload("res://images/fonts/AOMFN088.png"),
	"Y": preload("res://images/fonts/AOMFN089.png"),
	"y": preload("res://images/fonts/AOMFN089.png"),
	"Z": preload("res://images/fonts/AOMFN090.png"),
	"z": preload("res://images/fonts/AOMFN090.png"),
	".": preload("res://images/fonts/AOMFN043.png"),
	"_": preload("res://images/fonts/AOMFN045.png"),
	"-": preload("res://images/fonts/AOMFN046.png"),
	"'": preload("res://images/fonts/AOMFN039.png"),
	",": preload("res://images/fonts/AOMFN044.png"),
	":": preload("res://images/fonts/AOMFN058.png"),
	"!": preload("res://images/fonts/AOMFN033.png"),
	"?": preload("res://images/fonts/AOMFN063.png"),
}

var font_scale := 0.4
var special_character_offsets: Dictionary


func _ready():
	set_font_scale(font_scale)


func set_font_scale(sc: float):
	font_scale = sc
	special_character_offsets = {
		'.': 30*font_scale, 
		',': 25*font_scale,
		'_': 33*font_scale,
		':': 5*font_scale,
	}


func set_text_with_aooni_font(new_text: String) -> void:
	for node in get_children():
		remove_child(node)
		node.queue_free()
	if not new_text:
		return
	
	var character_spacing = 25 * font_scale
	var character_size = 5
	var current_x = 0
	var y = 0
	var y_offset = 0
	
	for character in new_text:
		if character in letter_images:
			var image_path = letter_images[character]
			var character_sprite = TextureRect.new()
			character_sprite.texture = image_path
			character_sprite.scale = Vector2(font_scale,font_scale/2.0)
			if character in special_character_offsets:
				y_offset = special_character_offsets[character]
			else:
				y_offset = 0
			character_sprite.position.x = current_x
			character_sprite.position.y = y_offset
			
			add_child(character_sprite)
			current_x += character_sprite.texture.get_width() * font_scale
		else:
			current_x += character_spacing
	custom_minimum_size = Vector2(current_x, character_size)
