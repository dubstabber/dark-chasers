extends Decal


func _ready() -> void:
	var catalog: ParticleCatalog = Services.get_particle_catalog()
	texture_albedo = catalog.get_random_doom_decal()
