extends SceneTree

## Architecture enforcement tests
## Scans source files for banned patterns as defined in PLANNING.md
##
## Banned patterns:
## 1. Direct Camera3D.make_current() outside CameraManager
## 2. String-based "match event:" routing in room scripts
## 3. has_method() duck-typing in gameplay code (with exceptions)
## 4. get_nodes_in_group() as primary wiring (with exceptions)

const SCAN_DIRS := [
	"res://scenes/",
	"res://weapon_manager/",
	"res://ammo_system/",
]

const EXCLUDE_DIRS := [
	"res://egb281/",
	"res://addons/",
	"res://tests/",
]

const EXCLUDE_FILES := [
	"res://scenes/services/camera_manager.gd", # CameraManager is allowed to call make_current
]

var violations := []
var scanned_files := 0

func _init():
	print("=".repeat(60))
	print("ARCHITECTURE ENFORCEMENT TESTS")
	print("=".repeat(60))
	
	scan_all_files()
	print_results()
	
	quit(0 if violations.is_empty() else 1)


func scan_all_files():
	for dir_path in SCAN_DIRS:
		scan_directory(dir_path)


func scan_directory(path: String):
	var dir := DirAccess.open(path)
	if not dir:
		push_warning("Could not open directory: " + path)
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		var full_path := path.path_join(file_name)
		
		if dir.current_is_dir():
			if not is_excluded_dir(full_path):
				scan_directory(full_path)
		elif file_name.ends_with(".gd"):
			if not is_excluded_file(full_path):
				scan_file(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()


func is_excluded_dir(path: String) -> bool:
	for excluded in EXCLUDE_DIRS:
		if path.begins_with(excluded):
			return true
	return false


func is_excluded_file(path: String) -> bool:
	return path in EXCLUDE_FILES


func scan_file(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("Could not open file: " + path)
		return
	
	scanned_files += 1
	var content := file.get_as_text()
	var lines := content.split("\n")
	
	for i in lines.size():
		var line := lines[i]
		var line_num := i + 1
		
		check_make_current(path, line, line_num)
		check_match_event(path, line, line_num)
		check_has_method(path, line, line_num)
		check_group_wiring(path, line, line_num)


func check_make_current(path: String, line: String, line_num: int):
	# Ban: .make_current() outside CameraManager
	if ".make_current(" in line:
		add_violation(
			"CAMERA_MAKE_CURRENT",
			path,
			line_num,
			"Direct .make_current() call. Use CameraManager instead.",
			line.strip_edges()
		)


func check_match_event(path: String, line: String, line_num: int):
	# Ban: match event: string routing in room scripts
	if "rooms/" in path:
		# Look for patterns like: match event: or match some_event:
		var stripped := line.strip_edges()
		if stripped.begins_with("match ") and "event" in stripped.to_lower() and stripped.ends_with(":"):
			add_violation(
				"STRING_EVENT_ROUTING",
				path,
				line_num,
				"String-based event routing in room script. Use typed events + GameEventBus.",
				stripped
			)


func check_has_method(path: String, line: String, line_num: int):
	# Ban: has_method() duck-typing in gameplay code
	# Exception: interface check implementations, migration adapters
	if ".has_method(" in line or "has_method(" in line:
		# Check if it's in an interface file (allowed)
		if "interfaces/" in path:
			return
		# Check if it's a comment
		if line.strip_edges().begins_with("#"):
			return
		
		add_violation(
			"DUCK_TYPING_HAS_METHOD",
			path,
			line_num,
			"Duck-typing via has_method(). Use typed capability interfaces.",
			line.strip_edges()
		)


func check_group_wiring(path: String, line: String, line_num: int):
	# Ban: get_nodes_in_group / get_first_node_in_group as primary wiring
	# Exception: context services (EnemyContext, WorldContext), debug tools
	if "get_nodes_in_group(" in line or "get_first_node_in_group(" in line:
		# Check if it's in a context/service file (allowed as centralized fallback)
		if "context" in path.to_lower() or "services/" in path:
			return
		# Check if it's a comment
		if line.strip_edges().begins_with("#"):
			return
		
		add_violation(
			"GROUP_WIRING",
			path,
			line_num,
			"Group-based discovery for wiring. Use explicit references or context registration.",
			line.strip_edges()
		)


func add_violation(rule: String, path: String, line_num: int, message: String, code: String):
	violations.append({
		"rule": rule,
		"path": path,
		"line": line_num,
		"message": message,
		"code": code
	})


func print_results():
	print("\n📁 Scanned %d files" % scanned_files)
	
	if violations.is_empty():
		print("\n✅ No architecture violations found!")
		print("=".repeat(60))
		return
	
	print("\n❌ Found %d architecture violations:\n" % violations.size())
	
	# Group by rule
	var by_rule := {}
	for v in violations:
		if not v.rule in by_rule:
			by_rule[v.rule] = []
		by_rule[v.rule].append(v)
	
	for rule in by_rule:
		var items: Array = by_rule[rule]
		print("--- %s (%d) ---" % [rule, items.size()])
		for v in items:
			print("  %s:%d" % [v.path, v.line])
			print("    %s" % v.message)
			print("    Code: %s" % v.code)
			print("")
	
	print("=".repeat(60))
	print("VIOLATIONS SUMMARY:")
	for rule in by_rule:
		print("  %s: %d" % [rule, by_rule[rule].size()])
	print("=".repeat(60))
