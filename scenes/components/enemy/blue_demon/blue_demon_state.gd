class_name BlueDemonState
extends RefCounted

## Base class for the Ao Oni's behaviour states — a port of the `u823.IAooniState`
## interface (`Init` / `Update` / `Finished`).
##
## The original stores exactly one live state on `Aooni.currentState` and swaps it with
## `Aooni.SetState(newState)`, which calls `Finished` on the outgoing state and `Init`
## on the incoming one. States are plain objects, not nodes, so they are cheap to
## allocate and hold no scene state of their own.

## Called once when this state becomes current.
func init(_demon: BlueDemon) -> void:
	pass

## Called every frame while this state is current.
func update(_demon: BlueDemon, _delta: float) -> void:
	pass

## Called once when this state is replaced.
func finished(_demon: BlueDemon) -> void:
	pass

## Human-readable name for debugging overlays.
func get_state_name() -> String:
	return "BlueDemonState"

## DST: the body was teleported; every stored position is void.
func on_teleported(_demon: BlueDemon) -> void:  # DST W10 / C9: teleport hook, no SRC counterpart (overridden by Wandering and Chase)
	pass
