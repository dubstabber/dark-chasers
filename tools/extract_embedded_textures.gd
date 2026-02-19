@tool
extends EditorScript

## Tool script to analyze embedded textures in mansion_1.tscn and provide fix guidance.
##
## ANALYSIS RESULT (from external tooling):
## - mansion_1.tscn is 35MB with 15128 lines
## - 31.53 MB (90%) is PortableCompressedTexture2D (144 instances)
## - These textures came from mansion1.glb import with embedded_image_handling=2
##
## HOW TO FIX:
## 1. The import setting has been changed to embedded_image_handling=1
## 2. In Godot: Select models/mansion1/mansion1.glb in FileSystem
## 3. Go to Import dock > Reimport
## 4. This will extract textures to models/mansion1/ as PNG files
## 5. Open mansion_1.tscn
## 6. Delete the "Map" node under NavigationRegion3D
## 7. Re-instance mansion1.glb into the scene (drag from FileSystem)
## 8. Rename to "Map" and parent under NavigationRegion3D
## 9. Save the scene - it should now be ~3MB instead of 35MB
##
## Usage: Open this script in Godot editor and run via Script > Run (Ctrl+Shift+X)

const TARGET_SCENE_PATH := "res://scenes/rooms/mansion_1.tscn"

func _run() -> void:
	print("")
	print("============================================")
	print("  MANSION_1.TSCN SIZE ANALYSIS")
	print("============================================")
	print("")
	print("Current state:")
	print("  - Scene size: ~35 MB")
	print("  - Embedded PortableCompressedTexture2D: 31.53 MB (144 textures)")
	print("  - Embedded ArrayMesh: 1.67 MB (430 meshes)")
	print("  - Embedded ConcavePolygonShape3D: 1.13 MB (264 shapes)")
	print("  - NavigationMesh: 0.07 MB (not the problem)")
	print("")
	print("Root cause:")
	print("  mansion1.glb was imported with embedded_image_handling=2")
	print("  which embeds textures as PortableCompressedTexture2D.")
	print("  When Map nodes were copied into the scene, textures were duplicated.")
	print("")
	print("============================================")
	print("  FIX INSTRUCTIONS")
	print("============================================")
	print("")
	print("Step 1: Reimport the GLB")
	print("  - Import setting already changed to embedded_image_handling=1")
	print("  - Select: models/mansion1/mansion1.glb in FileSystem")
	print("  - Click 'Reimport' in the Import dock")
	print("  - Textures will be extracted to models/mansion1/*.png")
	print("")
	print("Step 2: Update the scene")
	print("  - Open: scenes/rooms/mansion_1.tscn")
	print("  - Find: NavigationRegion3D/Map (contains all mesh instances)")
	print("  - Delete the Map node")
	print("  - Drag mansion1.glb from FileSystem into NavigationRegion3D")
	print("  - Rename the new node to 'Map'")
	print("  - Save the scene")
	print("")
	print("Expected result:")
	print("  - Scene size: ~3 MB (was 35 MB)")
	print("  - Textures stored as external PNG files")
	print("  - Faster load times, easier VCS diffs")
	print("")
	print("============================================")
	
	# Verify current state
	var file := FileAccess.open(TARGET_SCENE_PATH, FileAccess.READ)
	if file:
		var size_mb := file.get_length() / 1024.0 / 1024.0
		file.close()
		print("")
		print("Current scene file size: %.2f MB" % size_mb)
		if size_mb > 10:
			print("Status: NEEDS FIX (follow instructions above)")
		else:
			print("Status: OK (already optimized or fix applied)")
	else:
		print("Could not read scene file to verify size.")
