class_name PancakeEffect
extends PlayerEffect

@export_range(0.1, 1, 0.05)
var shrink_multiplier := 0.25

@export_range(1, 2, 0.1)
var widen_multiplier := 2

@export_range(0.1, 1, 0.05)
var speed_multiplier := 0.25

@export_range(0.1, 1, 0.05)
var jump_multiplier := 0.25

func apply_effect(player: Player):
	player.modify_scale(shrink_multiplier, widen_multiplier)
	player.move_speed *= speed_multiplier
	player.jump_height *= jump_multiplier
