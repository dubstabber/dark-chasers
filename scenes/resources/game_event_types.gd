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
