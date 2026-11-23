extends "level.gd"

signal restart_requested

@onready var player: Player = $Player
@onready var interaction_prompt: Label = $CanvasLayer/Control/InteractionPrompt

var _restart_queued := false


func _physics_process(_delta: float) -> void:
	var prompt := player.get_pickup_prompt()
	interaction_prompt.text = prompt
	interaction_prompt.visible = not prompt.is_empty()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"dev_reload_scene"):
		get_viewport().set_input_as_handled()
		_queue_restart()


func _on_kill_floor_body_entered(body: Node3D) -> void:
	if body == player:
		_queue_restart()


func _queue_restart() -> void:
	if _restart_queued:
		return
	_restart_queued = true
	_restart.call_deferred()


func _restart() -> void:
	if get_tree().current_scene == self:
		get_tree().reload_current_scene()
	else:
		restart_requested.emit()


func _on_player_win() -> void:
	level_won.emit(next_level_path)

func _on_game_timer_timeout() -> void:
	print(level_lost)
	level_lost.emit()
