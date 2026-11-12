class_name PancakeEffect
extends PlayerEffect

@export_range(0.1, 1, 0.05)
var shrink_multiplier := 0.25

@export_range(0.1, 1, 0.05)
var speed_multiplier := 0.25

@export_range(0.1, 1, 0.05)
var jump_multiplier := 0.25

func apply_effect(player: Player):
	player.scale.y *= shrink_multiplier
	player.move_speed *= speed_multiplier
	player.jump_height *= jump_multiplier
