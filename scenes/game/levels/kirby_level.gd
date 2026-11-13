extends "level.gd"


func _on_player_win() -> void:
	level_won.emit(next_level_path)

func _on_game_timer_timeout() -> void:
	print(level_lost)
	level_lost.emit()
