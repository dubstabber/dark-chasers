class_name GameEventTypes
extends RefCounted

## Centralized event type constants.
## Use these instead of raw strings for type safety and discoverability.

# Key pickup events
const KEY_COLLECTED := &"key_collected"

# Monster events
const SPAWN_MONSTER := &"spawn_monster"
const MONSTER_DISAPPEARED := &"monster_disappeared"

# Player events
const PLAYER_BLOCKED := &"player_blocked"
const PLAYER_UNBLOCKED := &"player_unblocked"

# Area trigger events
const AREA_ENTERED := &"area_entered"
const AREA_EXITED := &"area_exited"

# Button/interaction events
const BUTTON_PRESSED := &"button_pressed"
const INTERACTION_TRIGGERED := &"interaction_triggered"

# Door events
const DOOR_LOCKED := &"door_locked"
const DOOR_OPENED := &"door_opened"

# Camera events
const CAMERA_CUT := &"camera_cut"
const CAMERA_RESTORE := &"camera_restore"

# UI/HUD events
const SHOW_EVENT_TEXT := &"show_event_text"
const HIDE_EVENT_TEXT := &"hide_event_text"

# Music events
const PLAY_MUSIC := &"play_music"
const STOP_MUSIC := &"stop_music"

# Sequence events
const SEQUENCE_STARTED := &"sequence_started"
const SEQUENCE_ENDED := &"sequence_ended"
const SEQUENCE_STEP := &"sequence_step"

# Level events
const LEVEL_LOADED := &"level_loaded"
const LEVEL_TRANSITION := &"level_transition"

# Item events
const ITEM_PICKEDUP := &"item_pickedup"

# === Mansion-specific event IDs ===
# Key events
const KEY_SPAWN_AO_ONI_LIBRARY := &"key_spawn_ao_oni_library"
const KEY_AO_ONI_TRIES_BARS := &"key_ao_oni_tries_bars"
const KEY_TELEPORT_TO_VOID := &"key_teleport_to_void"
const KEY_SPAWN_WHITE_FACE := &"key_spawn_white_face"

# Button events
const BUTTON_CHECK_TV := &"button_check_tv"
const BUTTON_CHECK_MAP := &"button_check_map"
const BUTTON_CHECK_MAP_2 := &"button_check_map_2"
const BUTTON_PLAY_PIANO := &"button_play_piano"
const BUTTON_SHOW_MOVING_BARS := &"button_show_moving_bars"
const BUTTON_SHOW_SECRET_DOOR := &"button_show_secret_door"
const BUTTON_SHOW_OPEN_EXIT := &"button_show_open_exit"

# Area events
const AREA_ENTERED_MANSION_TEXT := &"area_entered_mansion_text"
const AREA_MONSTER_CRAWLS_LIBRARY := &"area_monster_crawls_library"
const AREA_PIANO_ALARM := &"area_piano_alarm"
const AREA_OPEN_AO_ONI_WIDE_DOOR := &"area_open_ao_oni_wide_door"
const AREA_SPAWN_ILOPULU := &"area_spawn_ilopulu"
const AREA_OPEN_AO_MIKA_WARDROBE := &"area_open_ao_mika_wardrobe"
const AREA_UNDERGROUND_SECRET_INFO := &"area_underground_secret_info"
const AREA_CHANGE_TO_NEXT_MAP := &"area_change_to_next_map"
const AREA_KILL_PLAYER := &"area_kill_player"

# Custom/internal events
const CUSTOM_MONSTER_DISAPPEARED := &"custom_monster_disappeared"
const CUSTOM_AO_ONI_GAVE_UP := &"custom_ao_oni_gave_up"
const CUSTOM_AOMIKA_DISAPPEARED := &"custom_aomika_disappeared"
