@tool
class_name MapNode
extends Node2D

@export var connections: Array[MapNode] = []:
	set(v): connections = v; _notify()

func _ready() -> void:
	set_notify_transform(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_notify()

func _notify() -> void:
	if get_parent() and get_parent().has_method("queue_redraw"):
		get_parent().queue_redraw()
