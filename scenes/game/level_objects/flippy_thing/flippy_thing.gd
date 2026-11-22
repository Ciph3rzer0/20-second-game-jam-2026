extends Node3D

@export var flipper : Node3D
## Area3D parented to the flipper, covering its striking surface.
@export var contact_area : Area3D
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

var _flipping := false
var _prev_angle: float

func _ready() -> void:
	_reset_angle = flipper.rotation.z
	_prev_angle = _reset_angle
	_arm_length = abs(flipper.position.x)

func _physics_process(delta: float) -> void:
	var a := flipper.rotation.z
	var omega := (a - _prev_angle) / delta
	_prev_angle = a
	if _flipping:
		_apply_velocity(omega)

func flip() -> void:
	if _tween and _tween.is_running():
		return

	var angle := deg_to_rad(target_degrees)
	var flip_duration := EASE_END_SLOPE * angle * _arm_length / tip_speed

	_flipping = true
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(flipper, "rotation:z", _reset_angle + angle, flip_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_on_flip_end)
	_tween.tween_property(flipper, "rotation:z", _reset_angle, reset_duration)

func _on_flip_end() -> void:
	# Exact end-of-ease angular velocity: 3 * angle / duration == tip_speed / arm_length
	_apply_velocity(tip_speed / _arm_length)
	_flipping = false

func _apply_velocity(omega: float) -> void:
	var axis := flipper.global_basis.z.normalized()  # rotation.z spins about this
	var pivot := flipper.global_position
	var w := axis * omega
	for body in contact_area.get_overlapping_bodies():
		var v := w.cross(body.global_position - pivot)
		if body is RigidBody3D:
			body.linear_velocity = v
		elif body is CharacterBody3D:
			body.velocity = v
