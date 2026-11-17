extends Node3D


@export var millis_offset := 0
@export var steps_per_turn := 4
@export var spinner : Node3D
@export var activation_period := 1.0
@export var clockwise := true
@export_exp_easing var rotation_ease: float = -2.0 

# Tracks total elapsed game time.
var total_time := 0.0

func _physics_process(delta: float) -> void:
	total_time += delta
	
	var period_time := fmod(
		total_time + millis_offset / 1000.0,
		activation_period * steps_per_turn
	)
	
	var t := period_time / activation_period          # 0..4 (steps_per_turn)
	var full_quarters := floorf(t)
	var partial_quarter := t - full_quarters   # 0..1
	var angle := (full_quarters + ease(partial_quarter, rotation_ease)) * PI * 2 / steps_per_turn
	spinner.rotation.y = -angle if clockwise else angle
