@tool
extends Node3D

const player_scene = preload("uid://rxe83v08frni")

func _ready() -> void:
	if Engine.is_editor_hint():
		var root := get_tree().edited_scene_root
		if root != null and self == root:
			try_spawn()
	else:
		try_spawn()
 
func try_spawn():
	if not Player.instance:
		var player = player_scene.instantiate()
		player.top_level = true
		add_child(player)
