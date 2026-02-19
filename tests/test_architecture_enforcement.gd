extends SceneTree

## Architecture enforcement tests
## Scans source files for banned patterns as defined in PLANNING.md
##
## Banned patterns:
## 1. Direct Camera3D.make_current() outside CameraManager
## 2. String-based "match event:" routing in room scripts
## 3. has_method() duck-typing in gameplay code (with exceptions)
## 4. get_nodes_in_group() as primary wiring (with exceptions)
## 5. "prop" in node duck-typing outside interfaces/adapters
## 6. App-level input polling (menu/fullscreen) in room scripts (use InputRouter)
##
## Warnings (non-blocking):
## - Scripts exceeding 500 LOC (SRP pressure)

const SCAN_DIRS := [
	"res://scenes/",
	"res://scenes/systems/weapon_manager/",
	"res://scenes/systems/ammo_system/",
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
var warnings := []
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
		check_in_operator_duck_typing(path, line, line_num)
		check_app_input_in_rooms(path, line, line_num)
	
	# Check file length (warning only)
	check_file_length(path, lines.size())


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
				"String-based event routing in room script. Use typed events + Services.event_bus.",
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
	# Exception: context services (EnemyContext, WorldContext), player.gd (debug-gated fallback)
	if "get_nodes_in_group(" in line or "get_first_node_in_group(" in line:
		# Check if it's in a context/service file (allowed as centralized fallback)
		if "context" in path.to_lower() or "services/" in path:
			return
		# Check if it's in player.gd (allowed - debug-gated fallback with warning)
		if path.ends_with("player.gd"):
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


func check_in_operator_duck_typing(path: String, line: String, line_num: int):
	# Ban: "prop" in node duck-typing outside interfaces/adapters/components
	# Pattern: if "property_name" in some_node or "method" in object
	var stripped := line.strip_edges()
	
	# Skip comments
	if stripped.begins_with("#"):
		return
	
	# Allow in interface files (adapter zones)
	if "interfaces/" in path:
		return
	
	# Allow in component files (need flexibility for various owner types)
	if "components/" in path:
		return
	
	# Allow in services (pool services, etc. need property checks)
	if "services/" in path:
		return
	
	# Allow in test files (already excluded, but be safe)
	if "tests/" in path:
		return
	
	# Regex-like check for pattern: "string" in variable (duck-typing)
	# Look for: "some_prop" in node_var or 'some_prop' in node_var
	var in_pattern := RegEx.new()
	in_pattern.compile('["\'][a-z_]+["\']\\s+in\\s+[a-z_]')
	if in_pattern.search(line):
		add_violation(
			"IN_OPERATOR_DUCK_TYPING",
			path,
			line_num,
			"Duck-typing via 'prop' in node. Use typed capability interfaces.",
			stripped
		)


func check_app_input_in_rooms(path: String, line: String, line_num: int):
	# Ban: app-level input polling in room scripts (handled by InputRouter autoload)
	if "rooms/" not in path:
		return
	var stripped := line.strip_edges()
	if stripped.begins_with("#"):
		return
	# Check for quit/fullscreen input actions that should be in InputRouter
	if "is_action" in line and ("menu" in line or "toggle-window-mode" in line or "quit" in line):
		add_violation(
			"APP_INPUT_IN_ROOM",
			path,
			line_num,
			"App-level input polling in room script. Use InputRouter autoload.",
			stripped
		)


func check_file_length(path: String, line_count: int):
	const MAX_LOC := 500
	if line_count > MAX_LOC:
		warnings.append({
			"type": "FILE_TOO_LONG",
			"path": path,
			"message": "Script has %d lines (>%d). Consider splitting for SRP." % [line_count, MAX_LOC]
		})


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
	
	# Print warnings (non-blocking)
	if not warnings.is_empty():
		print("\n⚠️  %d warnings (non-blocking):" % warnings.size())
		for w in warnings:
			print("  %s: %s" % [w.path, w.message])
	
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
