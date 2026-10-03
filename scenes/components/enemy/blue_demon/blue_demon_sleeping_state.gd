class_name BlueDemonSleepingState
extends BlueDemonState

## Dormant behaviour — port of `u823.AooniSleepingState`.
## Something external wakes it by calling [method BlueDemon.set_state] (wake, force_chase, call_to).
##
## DST S1: SRC parks the body at (9999, 9999, 0) with the agent off. In dark-chasers the demon is made
## absent IN PLACE instead (BlueDemon.off_nav_mesh: hidden, collision off, KillZone off, coordinator
## not ticked): a parked body would keep a room tag at a bogus position, and nothing else needs it.


func get_state_name() -> String:
	return "Sleeping"


func init(demon: BlueDemon) -> void:
	demon.is_sleeping = true
	demon.is_chase = false
	demon.desired_speed = 0.0
	demon.off_nav_mesh()
	demon.set_look_target(null)


func finished(demon: BlueDemon) -> void:
	demon.is_sleeping = false
	demon.on_nav_mesh()
