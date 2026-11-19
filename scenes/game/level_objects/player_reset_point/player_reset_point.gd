@tool
extends Node3D
## Spawns a player when the scene containing this point is run on its own (F6)
## and has no player yet. Otherwise it removes itself.
## In the editor it shows a preview player (no owner, so it's never saved).

const player_scene := preload("uid://rxe83v08frni")

@onready var spawn_point: Marker3D = $SpawnPoint

func _ready() -> void:
	if Engine.is_editor_hint():
		var root := get_tree().edited_scene_root
		if root != null and owner == root:
			var preview := player_scene.instantiate()
			add_child(preview)
			preview.global_position = spawn_point.global_position
		return
	# Deferred so every node, including a real player, has run _ready first.
	_spawn_if_needed.call_deferred()

func _spawn_if_needed() -> void:
	var scene := get_tree().current_scene
	if Player.instance == null and scene == owner:
		var player: Player = player_scene.instantiate()
		scene.add_child(player)
		player.global_position = spawn_point.global_position
	else:
		visible = false
		queue_free()
