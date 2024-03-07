extends Node

var ENEMIES = [
	{
		"name": "swag hacker",
		"image": load("res://images/enemies/static-images/swag_hacker.jpg"),
	},
	{
		"name": "botanicula onion",
		"image": load("res://images/enemies/static-images/botanicula_onion.png"),
	},
	{
		"name": "giga chad",
		"image": load("res://images/enemies/static-images/gigachad.webp"),
		"music": load("res://sounds/music/gigachad.mp3"),
	},
	{
		"name": "obunga",
		"image": load("res://images/enemies/static-images/obunga.webp"),
	},
	{
		"name": "angry german kid",
		"image": load("res://images/enemies/static-images/angry-german-kid.png"),
		"musics": load_musics("res://sounds/music/angrygermankid/angry-german-kid-", 25, ".ogg")
	},
]


func load_musics(prefix, numberOfFiles, type):
	var musics := []
	for i in range(1, numberOfFiles):
		var music: Resource
		if i < 10:
			music = load(prefix + "0" + str(i) + type)
		else:
			music = load(prefix + str(i) + type)
		musics.push_front(music)
	return musics
