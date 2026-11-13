class_name WorldEndEffect
extends PlayerEffect

func apply_effect(player: Player):
	player.win.emit()
