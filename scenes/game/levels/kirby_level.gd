extends "level.gd"


func _on_win_area_3d_body_entered(_body: Node3D) -> void:
	level_won.emit(next_level_path)

func _on_game_timer_timeout() -> void:
	print(level_lost)
	level_lost.emit()
