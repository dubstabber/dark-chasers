class_name WeaponAnimationStateController
extends RefCounted

var _is_shooting := false


func reset() -> void:
	_is_shooting = false


func is_shooting() -> bool:
	return _is_shooting


func on_animation_started(anim_name: String, current_weapon: WeaponResource, fire_controller: WeaponFireController) -> void:
	if not current_weapon or fire_controller == null:
		return
	if fire_controller.is_shooting_animation(anim_name, current_weapon):
		_is_shooting = true


func on_animation_finished(anim_name: String, current_weapon: WeaponResource, fire_controller: WeaponFireController) -> void:
	if not current_weapon or fire_controller == null:
		return
	if fire_controller.is_shooting_animation(anim_name, current_weapon):
		_is_shooting = false
