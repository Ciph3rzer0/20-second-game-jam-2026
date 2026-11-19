extends Node3D

@export var flipper : Node3D
@export_range(1.0, 30.0, 0.1) var tip_speed := 10.0
@export var reset_duration := 2.0

@export_range(0, 90, 0.5) var target_degrees: float = 45

## TRANS_CUBIC + EASE_IN is angle = target * (t / duration)^3, which ends
## turning at 3 * target / duration. Change this if you change the transition
## (QUAD = 2, QUART = 4, QUINT = 5).
const EASE_END_SLOPE := 3.0

var _tween: Tween
var _reset_angle: float
var _arm_length: float

func _ready() -> void:
	_reset_angle = flipper.rotation.z
	_arm_length = abs(flipper.position.x)

func flip() -> void:
	if _tween and _tween.is_running():
		return  # ignore signals mid-flip (or kill() it and start the next one)

	var angle := deg_to_rad(target_degrees)
	var flip_duration := EASE_END_SLOPE * angle * _arm_length / tip_speed

	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(flipper, "rotation:z", _reset_angle + angle, flip_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(flipper, "rotation:z", _reset_angle, reset_duration)
