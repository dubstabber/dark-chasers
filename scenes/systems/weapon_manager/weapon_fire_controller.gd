class_name WeaponFireController
extends RefCounted


func try_fire(current_weapon: WeaponResource, animation_player: AnimationPlayer, is_switching_weapon: bool) -> bool:
	if not current_weapon or not current_weapon.shoot_anim_name:
		return false
	if not animation_player or animation_player.is_playing() or is_switching_weapon:
		return false
	if not current_weapon.can_fire():
		return false
	animation_player.play(current_weapon.shoot_anim_name)
	return true


func try_auto_fire(current_weapon: WeaponResource, animation_player: AnimationPlayer, is_auto_hitting: bool) -> bool:
	if not current_weapon or not is_auto_hitting:
		return false
	if not animation_player or animation_player.is_playing():
		return false
	if not current_weapon.can_fire():
		return false

	if current_weapon.repeat_shoot_anim_name:
		animation_player.play(current_weapon.repeat_shoot_anim_name)
	elif current_weapon.shoot_anim_name:
		animation_player.play(current_weapon.shoot_anim_name)
	else:
		return false
	return true


func consume_and_execute_hit(current_weapon: WeaponResource, hit_executor: WeaponHitExecutor) -> bool:
	if not current_weapon or not hit_executor:
		return false

	if not current_weapon.melee_attack and not current_weapon.consume_ammo():
		return false

	hit_executor.execute_hit(current_weapon)
	return true


func is_shooting_animation(anim_name: String, current_weapon: WeaponResource) -> bool:
	if not current_weapon:
		return false
	return anim_name == current_weapon.shoot_anim_name or anim_name == current_weapon.repeat_shoot_anim_name
