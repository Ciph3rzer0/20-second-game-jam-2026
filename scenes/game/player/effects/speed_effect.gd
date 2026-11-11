class_name SpeedEffect
extends PlayerEffect

@export_range(1, 4, 0.25, "or_greater")
var speed_multiplier := 2

func apply_effect(player: Player):
	player.move_speed *= speed_multiplier
