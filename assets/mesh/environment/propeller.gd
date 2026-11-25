@tool
extends Node3D

@export var rotation_speed: float = 20.0 # Radians per second

func _process(delta: float) -> void:
	rotate_y(rotation_speed * delta)
