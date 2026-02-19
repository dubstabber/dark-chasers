extends Node

const GameEventScript = preload("res://scenes/resources/game_event.gd")

## Central event bus for typed game events.
## Replaces string-based event routing with a publish/subscribe pattern.
##
## Usage:
##   - Add as autoload named "GameEventBus" in Project Settings
##   - Emit: Services.event_bus.emit_event(GameEvent.new(&"event_type", {payload}))
##   - Subscribe: Services.event_bus.subscribe(&"event_type", callback)

signal event_emitted(event: RefCounted)

var _subscribers: Dictionary = {} # StringName -> Array[Callable]
var _event_history: Array[RefCounted] = []
var _history_limit: int = 50


func emit_event(event: RefCounted) -> void:
	_record_event(event)
	event_emitted.emit(event)
	
	if event.event_type in _subscribers:
		var callbacks: Array = _subscribers[event.event_type]
		for callback: Callable in callbacks:
			if callback.is_valid():
				callback.call(event)


func emit(event_type: StringName, payload: Dictionary = {}, source: Node = null) -> void:
	var event := GameEventScript.new(event_type, payload, source)
	emit_event(event)


func subscribe(event_type: StringName, callback: Callable) -> void:
	if not event_type in _subscribers:
		_subscribers[event_type] = []
	
	if not callback in _subscribers[event_type]:
		_subscribers[event_type].append(callback)


func unsubscribe(event_type: StringName, callback: Callable) -> void:
	if event_type in _subscribers:
		_subscribers[event_type].erase(callback)


func unsubscribe_all(event_type: StringName) -> void:
	_subscribers.erase(event_type)


func clear_subscriber(callback: Callable) -> void:
	for event_type in _subscribers:
		_subscribers[event_type].erase(callback)


func has_subscribers(event_type: StringName) -> bool:
	return event_type in _subscribers and not _subscribers[event_type].is_empty()


func get_subscriber_count(event_type: StringName) -> int:
	if event_type in _subscribers:
		return _subscribers[event_type].size()
	return 0


func _record_event(event: RefCounted) -> void:
	_event_history.append(event)
	if _event_history.size() > _history_limit:
		_event_history.pop_front()


func get_recent_events(count: int = 10) -> Array:
	var start: int = max(0, _event_history.size() - count)
	var result: Array = []
	for i in range(start, _event_history.size()):
		result.append(_event_history[i])
	return result


func get_events_of_type(event_type: StringName, count: int = 10) -> Array:
	var result: Array = []
	for i in range(_event_history.size() - 1, -1, -1):
		if _event_history[i].event_type == event_type:
			result.append(_event_history[i])
			if result.size() >= count:
				break
	result.reverse()
	return result
