extends Resource

class_name FootstepMaterialLibrary

@export var footstep_material_library : Array[FootstepMaterialProfile] = []

func get_footstep_profile_by_material_name(material_name : String) -> AudioStreamRandomizer:
	for footstep_material_profile in footstep_material_library:
		for m_name in footstep_material_profile.material_names:
			if m_name == material_name:
				return footstep_material_profile.footstep_profile
	return null

#func get_footstep_profile_by_material(material : Material) -> AudioStreamRandomizer:
	#for footstep_material_profile in footstep_material_library:
		#if material == footstep_material_profile.material:
			#return footstep_material_profile.footstep_profile
	#return null

