extends Node3D

@export var flipper : Node3D
@export var flip_duration := 0.4
@export var reset_duration := 2.0

@export var target_degrees: float = 45
@export var flip_curve: Curve

var _tween: Tween
var _reset_angle: float

func _ready() -> void:
	_reset_angle = flipper.rotation.z

func flip() -> void:
	if _tween and _tween.is_running():
		return  # ignore signals mid-flip (or kill() it and start the next one)
	
	var _target_angle = _reset_angle + deg_to_rad(target_degrees)
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(flipper, "rotation:z", _target_angle, flip_duration) \
		.set_custom_interpolator(func(t: float) -> float: return flip_curve.sample_baked(t))
	_tween.tween_property(flipper, "rotation:z", _reset_angle, reset_duration)
	
	await _tween.finished
