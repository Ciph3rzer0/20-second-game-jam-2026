extends Node

signal hold_progress(action: StringName, ratio: float)

@export var hold_time := 0.4

var _held := {&"dev_quit_game": 0.0, &"dev_reload_scene": 0.0}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	for action in _held:
		if Input.is_action_pressed(action):
			_held[action] += delta
			hold_progress.emit(action, minf(_held[action] / hold_time, 1.0))
			if _held[action] >= hold_time:
				_held[action] = 0.0
				_trigger(action)
		elif _held[action] > 0.0:
			_held[action] = 0.0
			hold_progress.emit(action, 0.0)

func _trigger(action: StringName) -> void:
	match action:
		&"dev_quit_game":
			get_tree().quit()
		&"dev_reload_scene":
			get_tree().reload_current_scene()
