extends Node

func _ready() -> void:
	# Disable subscene camera and lighting if not the main scene.
	if not get_tree().current_scene == owner:
		queue_free()
