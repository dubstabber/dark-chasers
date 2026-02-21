extends Resource

class_name DarkChasersFootstepMaterialLibrary

@export var footstep_material_library: Array[FootstepMaterialProfile] = []

var _material_name_to_profile: Dictionary = {}
var _index_built: bool = false


func _ensure_index():
	if Engine.is_editor_hint():
		_rebuild_index()
		return
	if _index_built:
		return
	_rebuild_index()
	_index_built = true


func _rebuild_index():
	_material_name_to_profile.clear()
	for footstep_material_profile in footstep_material_library:
		if not footstep_material_profile:
			continue
		for m_name in footstep_material_profile.material_names:
			if m_name == "":
				continue
			_material_name_to_profile[m_name] = footstep_material_profile.footstep_profile

func get_footstep_profile_by_material_name(material_name: String) -> AudioStreamRandomizer:
	_ensure_index()
	return _material_name_to_profile.get(material_name, null)
