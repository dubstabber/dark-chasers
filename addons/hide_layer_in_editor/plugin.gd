@tool
extends EditorPlugin

# Editor-only hidden layer index (1-based as in the UI). Layer 3 == bit 2 (value 4).
const HIDDEN_LAYER_INDEX := 3

func _enter_tree():
	# Delay one frame so the editor viewport exists.
	set_input_event_forwarding_always_enabled()
	call_deferred("_apply_culling_mask_to_all")

func _exit_tree():
	# Restore default editor camera mask when plugin is disabled.
	_restore_culling_mask_on_all()

func _apply_culling_mask_to_all():
	for viewport: SubViewport in _get_editor_viewports_3d():
		var cam: Camera3D = viewport.get_camera_3d()
		if cam and not _is_preview_camera(cam):
			# Disable the specified layer only for editor cameras.
			cam.set_cull_mask_value(HIDDEN_LAYER_INDEX, false)

func _restore_culling_mask_on_all():
	for viewport: SubViewport in _get_editor_viewports_3d():
		var cam: Camera3D = viewport.get_camera_3d()
		if cam and not _is_preview_camera(cam):
			# Re-enable the layer when plugin is disabled.
			cam.set_cull_mask_value(HIDDEN_LAYER_INDEX, true)

func _get_editor_viewports_3d() -> Array[SubViewport]:
	# Return all available 3D editor SubViewports (supports split view up to 4).
	var vps: Array[SubViewport] = []
	var ei := get_editor_interface()
	for i in 4:
		var vp := ei.get_editor_viewport_3d(i)
		if vp:
			vps.append(vp)
	return vps

func _is_preview_camera(cam: Camera3D) -> bool:
	# A preview camera is a Camera3D from the edited scene (user's Camera3D with "Preview" enabled).
	var root: Node = get_editor_interface().get_edited_scene_root()
	if root and cam.is_inside_tree():
		return root.is_ancestor_of(cam)
	return false

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	# Enforce mask for editor cameras during viewport interaction; skip scene preview cameras.
	if camera and not _is_preview_camera(camera):
		camera.set_cull_mask_value(HIDDEN_LAYER_INDEX, false)
	return EditorPlugin.AFTER_GUI_INPUT_PASS
