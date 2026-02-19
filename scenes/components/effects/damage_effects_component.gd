class_name DamageEffectsComponent
extends Node

## Handles visual damage feedback effects (screen blink, overlays)

@export_group("Blink Effect")
@export var blink_color: Color = Color(1.0, 0.0, 0.0, 0.3)
@export var fade_in_time: float = 0.1
@export var hold_time: float = 0.15
@export var fade_out_time: float = 0.8

@export_group("Death Overlay")
@export var death_overlay_color: Color = Color(1.0, 0.0, 0.0, 0.7)

@export_group("Node References")
@export var color_rect: ColorRect
@export var health_component: HealthComponent:
	get:
		return _health_component
	set(value):
		# Disconnect from old health component
		if _health_component and _health_component.damage_taken.is_connected(_on_damage_taken):
			_health_component.damage_taken.disconnect(_on_damage_taken)
			_health_component.died.disconnect(_on_died)
		
		_health_component = value

		# Connect to new health component
		if _health_component:
			_health_component.damage_taken.connect(_on_damage_taken)
			_health_component.died.connect(_on_died)

var _health_component: HealthComponent
var original_modulate: Color = Color(1.0, 1.0, 1.0, 0.0)
var damage_blink_tween: Tween


func _ready():
	if color_rect:
		original_modulate = color_rect.modulate
	
	_validate_node_references()


func _validate_node_references() -> void:
	"""Validate that required node references are set and log warnings for missing ones.
	Only warns if both references are missing (component is essentially non-functional)."""
	if not color_rect and not health_component:
		push_warning("DamageEffectsComponent: No references set. Component is non-functional - consider removing it.")


func _on_damage_taken(_amount: int, _current_health: int) -> void:
	play_damage_blink()


func _on_died() -> void:
	apply_death_overlay()


func play_damage_blink() -> void:
	if not color_rect:
		return
	
	# Don't play blink if dead (death overlay takes priority)
	if health_component and health_component.is_dead:
		return
	
	# Stop any existing blink tween
	if damage_blink_tween:
		damage_blink_tween.kill()
	
	# Create new tween for the blink effect
	damage_blink_tween = create_tween()
	
	# 1. Fade in to damage color
	damage_blink_tween.tween_property(color_rect, "modulate", blink_color, fade_in_time)
	
	# 2. Hold at damage color
	damage_blink_tween.tween_interval(hold_time)
	
	# 3. Fade out to transparent
	damage_blink_tween.tween_property(color_rect, "modulate", original_modulate, fade_out_time)
	
	# 4. Ensure we end up in the correct state
	damage_blink_tween.tween_callback(func():
		if health_component and not health_component.is_dead:
			color_rect.modulate = original_modulate
	)


func apply_death_overlay() -> void:
	if not color_rect:
		return
	
	# Stop any damage blink tween
	if damage_blink_tween:
		damage_blink_tween.kill()
		damage_blink_tween = null
	
	# Apply persistent death overlay
	color_rect.modulate = death_overlay_color


func clear_death_overlay() -> void:
	if not color_rect:
		return
	
	# Stop any tweens
	if damage_blink_tween:
		damage_blink_tween.kill()
		damage_blink_tween = null
	
	# Reset to original state
	color_rect.modulate = original_modulate


func reset() -> void:
	clear_death_overlay()
