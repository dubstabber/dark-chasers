extends SceneTree
## Blue demon, source-text gates S1-S7 (plan section 11.3).
##
## Reads source text only: it needs neither the ripped assets nor a refreshed class cache, so it
## runs on a clean clone. Exit code 1 on any failure; the last line on success is the OK banner.
##
##   godot --headless --path . --script res://tests/test_blue_demon_static.gd
##
## S3 and S4 test CODE ONLY: everything from the first '#' on a line is removed first, so the SRC
## header comments, the LOCKER comment and the "# DST <id> ... (aooni.gd:NNN)" provenance comments
## stay legal. S1 tests whole lines, comments included, because that is how the lint reads them.

const OK_BANNER := "=== BLUE DEMON STATIC OK ==="

const ROOT_SCRIPT := "res://scenes/enemies/blue_demon.gd"
const PREY_SCRIPT := "res://scenes/interfaces/blue_demon_prey.gd"
const COMPONENT_DIR := "res://scenes/components/enemy/blue_demon/"
const DEMON_SCENE := "res://scenes/enemies/blue_demon.tscn"
const SCENE_CATALOG := "res://scenes/resources/scene_catalog.tres"

const COMPONENT_SCRIPTS: Array[String] = [
	"blue_demon_tuning.gd",
	"blue_demon_state.gd",
	"blue_demon_wandering_state.gd",
	"blue_demon_chase_state.gd",
	"blue_demon_sleeping_state.gd",
	"blue_demon_patrol_point.gd",
	"blue_demon_patrol_point_data.gd",
	"blue_demon_travel.gd",
	"blue_demon_senses.gd",
	"blue_demon_body.gd",
	"blue_demon_foot.gd",
	"blue_demon_se.gd",
]

## S3: the three state files, body, foot, travel and senses.
const PORTED_CODE_SCRIPTS: Array[String] = [
	"blue_demon_wandering_state.gd",
	"blue_demon_chase_state.gd",
	"blue_demon_sleeping_state.gd",
	"blue_demon_body.gd",
	"blue_demon_foot.gd",
	"blue_demon_travel.gd",
	"blue_demon_senses.gd",
]

const TEST_SCRIPTS: Array[String] = [
	"res://tests/test_blue_demon_static.gd",
	"res://tests/blue_demon_test_arena.gd",
	"res://tests/test_blue_demon.gd",
	"res://tests/test_blue_demon_extended.gd",
	"res://tests/test_blue_demon_map.gd",
]

## The three substrings the architecture lint rejects on any line of a scanned script.
const LINT_BANNED: Array[String] = ["get_nodes_in_group(", "get_first_node_in_group(", ".make_current("]
const DUCK_TYPING_CALL := "has_method("
const LENGTH_FLAG := 300

var _failed := false
var _check := ""


func _init() -> void:
	print("=".repeat(60))
	print("BLUE DEMON STATIC GATES (S1-S7)")
	print("=".repeat(60))

	var scripts := _demon_scripts()
	_s1_scripts_exist_and_pass_the_lint_rules(scripts)
	_s2_no_in_operator_duck_typing_in_the_root()
	_s3_port_hygiene()
	_s4_locker_is_not_ported()
	_s5_scene_text()
	_s6_registered_in_the_scene_catalog()
	_s7_report_line_counts(scripts)

	print("")
	if _failed:
		print("=== BLUE DEMON STATIC FAILED ===")
	else:
		print(OK_BANNER)
	quit(1 if _failed else 0)


## The 14 new scripts under scenes/.
func _demon_scripts() -> Array[String]:
	var scripts: Array[String] = [ROOT_SCRIPT, PREY_SCRIPT]
	for file_name in COMPONENT_SCRIPTS:
		scripts.append(COMPONENT_DIR + file_name)
	return scripts


# --- S1 ----------------------------------------------------------------------------------------

func _s1_scripts_exist_and_pass_the_lint_rules(scripts: Array[String]) -> void:
	_begin("S1")
	_assert(scripts.size() == 14, "14 new scripts under scenes/ are checked (%d)" % scripts.size())
	for path in scripts:
		var exists := FileAccess.file_exists(path)
		_assert(exists, "%s exists" % path)
		if not exists:
			continue
		var lines := _read(path).split("\n")
		var banned_hits: PackedStringArray = []
		var duck_hits: PackedStringArray = []
		for i in lines.size():
			for banned in LINT_BANNED:
				if lines[i].contains(banned):
					banned_hits.append("%d: %s" % [i + 1, banned])
			if lines[i].contains(DUCK_TYPING_CALL):
				duck_hits.append(str(i + 1))
		_assert(banned_hits.is_empty(), "%s: no get_nodes_in_group( / get_first_node_in_group( / .make_current( on any line, comments included%s" % [
			path.get_file(), _hits_text(banned_hits)])
		if path != PREY_SCRIPT:
			_assert(duck_hits.is_empty(), "%s: no has_method( (it may appear only in scenes/interfaces/blue_demon_prey.gd)%s" % [
				path.get_file(), _hits_text(duck_hits)])


# --- S2 ----------------------------------------------------------------------------------------

func _s2_no_in_operator_duck_typing_in_the_root() -> void:
	_begin("S2")
	if not _require(ROOT_SCRIPT):
		return
	# The lint's own regex (tests/test_architecture_enforcement.gd); the root is not in an exempt directory.
	var pattern := RegEx.new()
	pattern.compile('["\'][a-z_]+["\']\\s+in\\s+[a-z_]')
	var hits: PackedStringArray = []
	var lines := _read(ROOT_SCRIPT).split("\n")
	for i in lines.size():
		if lines[i].strip_edges().begins_with("#"):
			continue
		if pattern.search(lines[i]) != null:
			hits.append(str(i + 1))
	_assert(hits.is_empty(), "blue_demon.gd: no non-comment line matches [\"'][a-z_]+[\"']\\s+in\\s+[a-z_]%s" % _hits_text(hits))


# --- S3 ----------------------------------------------------------------------------------------

func _s3_port_hygiene() -> void:
	_begin("S3")
	var demon_speed := RegEx.new()
	demon_speed.compile("\\bdemon\\.speed\\b")
	var src_identifier := RegEx.new()
	src_identifier.compile("\\baooni\\b")
	for file_name in PORTED_CODE_SCRIPTS:
		var path := COMPONENT_DIR + file_name
		if not _require(path):
			continue
		var speed_hits: PackedStringArray = []
		var identifier_hits: PackedStringArray = []
		var preload_hits: PackedStringArray = []
		var code_lines := _code_only(_read(path)).split("\n")
		for i in code_lines.size():
			if demon_speed.search(code_lines[i]) != null:
				speed_hits.append(str(i + 1))
			if src_identifier.search(code_lines[i]) != null:
				identifier_hits.append(str(i + 1))
			if code_lines[i].contains("preload("):
				preload_hits.append(str(i + 1))
		_assert(speed_hits.is_empty(), "%s: code has no demon.speed (Enemy.speed is getter-only; states write desired_speed)%s" % [file_name, _hits_text(speed_hits)])
		_assert(identifier_hits.is_empty(), "%s: code has no 'aooni' identifier%s" % [file_name, _hits_text(identifier_hits)])
		_assert(preload_hits.is_empty(), "%s: code has no preload(%s" % [file_name, _hits_text(preload_hits)])


# --- S4 ----------------------------------------------------------------------------------------

func _s4_locker_is_not_ported() -> void:
	_begin("S4")
	var path := COMPONENT_DIR + "blue_demon_chase_state.gd"
	if not _require(path):
		return
	var raw := _read(path)
	_assert(raw.contains("LOCKER is not ported"), "the chase state's raw text contains 'LOCKER is not ported' (the comment at the code site)")
	var code := _code_only(raw)
	for token: String in ["_update_locker", "set_locker", "_locker_front", "State.LOCKER", "LOCKER_"]:
		_assert(not code.contains(token), "the chase state's code does not contain '%s'%s" % [token, _hits_text(_lines_with(code, token))])


# --- S5 ----------------------------------------------------------------------------------------

func _s5_scene_text() -> void:
	_begin("S5")
	if not _require(DEMON_SCENE):
		return
	var scene := _read(DEMON_SCENE)
	for needle: String in [
		'instance=ExtResource("1_base")',
		"chase_player = false",
		"animation_type = 1",
		'[node name="DummyLookTarget" type="Node3D" parent="Graphics"',
	]:
		_assert(scene.contains(needle), "blue_demon.tscn contains `%s`" % needle)
	var cutoff_count := scene.count("attenuation_filter_cutoff_hz = 20500.0")
	_assert(cutoff_count == 2, "blue_demon.tscn contains `attenuation_filter_cutoff_hz = 20500.0` twice (both feet), found %d" % cutoff_count)
	_assert(not scene.contains("target_desired_distance"), "blue_demon.tscn has no target_desired_distance (written at runtime per command)")

	# No transform on the KillZone node: the kill position stays at the feet (stock death throw, D7).
	var kill_zone_header := '[node name="KillZone" parent="." index="4"]'
	var lines := scene.split("\n")
	var header_line := -1
	for i in lines.size():
		if lines[i].strip_edges() == kill_zone_header:
			header_line = i
			break
	var next_line := lines[header_line + 1].strip_edges() if header_line >= 0 and header_line + 1 < lines.size() else "<missing>"
	_assert(header_line >= 0 and next_line == "visible = false", "the line after `%s` is `visible = false`, got `%s`" % [kill_zone_header, next_line])
	# The KillZone's OWN line: a bare `scene.contains("enabled = false")` is also satisfied by the AI
	# component's `detection_enabled = false` further down.
	var enabled_line := lines[header_line + 2].strip_edges() if header_line >= 0 and header_line + 2 < lines.size() else "<missing>"
	_assert(header_line >= 0 and enabled_line == "enabled = false", "the second line after `%s` is `enabled = false`, got `%s` (the zone is disarmed in the scene and armed at activation)" % [kill_zone_header, enabled_line])


# --- S6 ----------------------------------------------------------------------------------------

## The demon is spawnable by id: Services.get_scene_catalog().get_enemy_scene(&"blue_demon").
func _s6_registered_in_the_scene_catalog() -> void:
	_begin("S6")
	if not _require(SCENE_CATALOG):
		return
	var catalog := _read(SCENE_CATALOG)
	var ext_line := "[ext_resource type=\"PackedScene\" path=\"%s\" id=\"13_blue_demon\"]" % DEMON_SCENE
	_assert(catalog.contains(ext_line), "scene_catalog.tres loads %s as `13_blue_demon`%s" % [DEMON_SCENE, _hits_text(_lines_with(catalog, "blue_demon"))])
	_assert(catalog.contains("id = &\"blue_demon\"\nscene = ExtResource(\"13_blue_demon\")"), "scene_catalog.tres has an entry with id &\"blue_demon\" for that scene%s" % _hits_text(_lines_with(catalog, "blue_demon")))
	var enemy_line := ""
	for line in catalog.split("\n"):
		if line.begins_with("enemy_scenes = "):
			enemy_line = line
	_assert(enemy_line.contains("SubResource(\"Resource_blue_demon\")"), "the entry is listed in enemy_scenes, got `%s`" % enemy_line)


# --- S7 ----------------------------------------------------------------------------------------

## Report only; never fails.
func _s7_report_line_counts(scripts: Array[String]) -> void:
	_begin("S7")
	var all_scripts: Array[String] = []
	all_scripts.append_array(scripts)
	all_scripts.append_array(TEST_SCRIPTS)
	for path in all_scripts:
		if not FileAccess.file_exists(path):
			print("  -    %s: missing" % path)
			continue
		var line_count := _line_count(_read(path))
		var flag := "   <-- over %d lines" % LENGTH_FLAG if line_count > LENGTH_FLAG else ""
		print("  -    %s: %d lines%s" % [path, line_count, flag])


# --- helpers -----------------------------------------------------------------------------------

func _begin(check: String) -> void:
	_check = check
	print("\n--- %s ---" % check)


func _require(path: String) -> bool:
	var exists := FileAccess.file_exists(path)
	if not exists:
		_assert(false, "%s exists" % path)
	return exists


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


## The text with everything from the first '#' on each line removed (line numbers are kept).
func _code_only(text: String) -> String:
	var lines := text.split("\n")
	for i in lines.size():
		var hash_at := lines[i].find("#")
		if hash_at >= 0:
			lines[i] = lines[i].substr(0, hash_at)
	return "\n".join(lines)


func _lines_with(text: String, token: String) -> PackedStringArray:
	var hits: PackedStringArray = []
	var lines := text.split("\n")
	for i in lines.size():
		if lines[i].contains(token):
			hits.append(str(i + 1))
	return hits


func _hits_text(hits: PackedStringArray) -> String:
	if hits.is_empty():
		return ""
	return " (line %s)" % ", ".join(hits)


func _line_count(text: String) -> int:
	if text.is_empty():
		return 0
	var count := text.count("\n")
	if not text.ends_with("\n"):
		count += 1
	return count


func _assert(condition: bool, message: String) -> void:
	var text := "[%s] %s" % [_check, message]
	if condition:
		print("  ok   ", text)
	else:
		_failed = true
		push_error("ASSERT FAILED: " + text)
		print("  FAIL ", text)
