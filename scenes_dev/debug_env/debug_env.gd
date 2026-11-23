extends Node

func _ready() -> void:
	# Disable subscene camera and lighting if not the main scene.
	if get_tree().current_scene == owner:
		$DirectionalLight3D.visible = true
	else:
		queue_free()
