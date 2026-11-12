class_name Player
extends CharacterBody3D
## Top-down, camera-relative, strict 8-way movement controller.
##
## Movement directions are snapped to the 8 screen-space directions (also for
## analog sticks), derived from the camera's yaw so they stay screen-aligned at
## any camera angle. Includes jump (coyote time, buffering, variable height),
## a steerable/cancelable sprint-dash, slope handling, stair stepping, an
## interact hook, and gravity zones (Area3D gravity overrides).
##
## Interaction contract: anything overlapping [member interact_area] that has an
## `interact(player: Player)` method gets it called on pc_interact.
## [signal interact_pressed] always fires, with the target or null.
##
## Gravity zones: add an Area3D child as [member field_detector]. Entering an
## Area3D with a gravity override swaps [member gravity_vector]. Zones are
## assumed not to overlap.

signal jumped
signal landed
signal dash_started
signal dash_ended
signal interact_pressed(target: Node)

const DIRECTION_COUNT := 8

@export_group("References")
## Camera whose yaw defines screen "up". Falls back to the viewport's current camera.
@export var camera: Camera3D
## Optional area (usually a child in front of the player) used to pick an interact target.
@export var interact_area: Area3D
## Area3D child (capsule roughly matching the body) that detects gravity zones.
## Its collision_mask must include the zones' layer.
@export var field_detector: Area3D

@export_group("Movement")
@export var move_speed: float = 6.0
@export var ground_acceleration: float = 80.0
@export var ground_deceleration: float = 100.0
@export var air_acceleration: float = 30.0
@export var air_deceleration: float = 10.0
## Applied to the combined stick vector before 8-way snapping.
@export_range(0.0, 0.95) var stick_deadzone: float = 0.35
## Exponential turn rate (1/s). ~20 reaches the target yaw in about 0.15 s.
@export var turn_sharpness: float = 20.0

@export_group("Jump")
## Peak height of a full (held) jump, in meters.
@export var jump_height: float = 1.4
## Multiplier on the project's default 3D gravity.
@export var gravity_scale: float = 2.0
@export var fall_gravity_multiplier: float = 1.5
## Upward velocity is multiplied by this when jump is released early.
@export_range(0.0, 1.0) var jump_cut: float = 0.5
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.12
@export var max_fall_speed: float = 30.0

@export_group("Dash")
@export var dash_speed: float = 12.0
@export var dash_duration: float = 0.35
## Starts counting when the dash ends (timeout, cancel, or jump).
@export var dash_cooldown: float = 0.4
@export var dash_in_air: bool = false
## A jump started mid-dash keeps dash speed as its air speed until landing.
@export var dash_jump_keeps_speed: bool = true

@export_group("Floor")
@export_range(0.0, 1.0) var step_height: float = 0.35
@export_range(0.0, 89.0) var max_slope_degrees: float = 46.0

@export_group("Gravity Zones")
## Drag on sideways drift from gravity zones, 1/s.
## Terminal drift speed = sideways gravity / this.
@export var field_drift_drag: float = 4.0

## World-space, 8-way snapped input direction. Unit length or zero.
var move_direction := Vector3.ZERO
## Last non-zero intended facing (snapped). Use for aiming abilities.
var facing_direction := Vector3.FORWARD
var is_dashing := false
## Active gravity acceleration (world space). Set automatically by gravity zones.
var gravity_vector := Vector3.DOWN * 9.8

var _gravity := 9.8  # base gravity magnitude, also used for the jump impulse
var _default_gravity := Vector3.DOWN * 9.8
var _zone: Area3D
var _drift := Vector3.ZERO  # sideways velocity from gravity zones, added on top of input
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _dash_direction := Vector3.FORWARD
var _air_speed := 0.0
var _jumping := false
var _was_on_floor := false


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity")) * gravity_scale
	_default_gravity = Vector3.DOWN * _gravity
	gravity_vector = _default_gravity
	if field_detector:
		field_detector.area_entered.connect(_on_zone_entered)
		field_detector.area_exited.connect(_on_zone_exited)
	floor_max_angle = deg_to_rad(max_slope_degrees)
	floor_constant_speed = true
	floor_stop_on_slope = true
	floor_snap_length = maxf(floor_snap_length, step_height + 0.05)
	facing_direction = -global_basis.z
	_air_speed = move_speed
	_was_on_floor = is_on_floor()


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	_update_timers(delta, on_floor)
	_update_gravity(delta)
	move_direction = _read_move_direction()

	if Input.is_action_just_pressed("pc_jump"):
		_jump_buffer_timer = jump_buffer_time
	if Input.is_action_just_pressed("pc_dash"):
		if is_dashing:
			_end_dash()
		elif _dash_cooldown_timer <= 0.0 and (on_floor or dash_in_air):
			_start_dash()
	if Input.is_action_just_pressed("pc_interact"):
		_interact()

	_apply_gravity(delta, on_floor)
	_try_jump()
	if _jumping and velocity.y > 0.0 and Input.is_action_just_released("pc_jump"):
		velocity.y *= jump_cut
	_apply_horizontal(delta, on_floor)
	_update_facing(delta)
	_move(delta, on_floor)
	_update_floor_transition()


# --- Input -----------------------------------------------------------------

func _read_move_direction() -> Vector3:
	var input := Input.get_vector(&"pc_move_left", &"pc_move_right", &"pc_move_up", &"pc_move_down", stick_deadzone)
	if input == Vector2.ZERO:
		return Vector3.ZERO
	input = Vector2.from_angle(snappedf(input.angle(), TAU / DIRECTION_COUNT))

	# Build axes from the camera's right vector only, so a camera looking
	# straight down still yields a valid forward.
	var right := Vector3.RIGHT
	var cam := camera if camera else get_viewport().get_camera_3d()
	if cam:
		right = Vector3(cam.global_basis.x.x, 0.0, cam.global_basis.x.z).normalized()
	var forward := Vector3.UP.cross(right)
	return (right * input.x - forward * input.y).normalized()


# --- Gravity zones ---------------------------------------------------------

func _on_zone_entered(area: Area3D) -> void:
	if area.gravity_space_override != Area3D.SPACE_OVERRIDE_DISABLED:
		_zone = area


func _on_zone_exited(area: Area3D) -> void:
	if area == _zone:
		_zone = null


func _update_gravity(delta: float) -> void:
	if _zone:
		var dir: Vector3
		if _zone.gravity_point:
			dir = (_zone.to_global(_zone.gravity_point_center) - global_position).normalized()
		else:
			dir = _zone.gravity_direction.normalized()
		gravity_vector = dir * _zone.gravity * gravity_scale
		# Only COMBINE adds to the default gravity. The other modes replace it.
		if _zone.gravity_space_override == Area3D.SPACE_OVERRIDE_COMBINE:
			gravity_vector += _default_gravity
	else:
		gravity_vector = _default_gravity

	var sideways := Vector3(gravity_vector.x, 0.0, gravity_vector.z)
	_drift += (sideways - _drift * field_drift_drag) * delta


# --- Vertical --------------------------------------------------------------

func _apply_gravity(delta: float, on_floor: bool) -> void:
	var g := -gravity_vector.y  # positive = down
	if on_floor and velocity.y <= 0.0 and g > 0.0:
		velocity.y = 0.0
		return
	var mult := fall_gravity_multiplier if (velocity.y < 0.0 and g > 0.0) else 1.0
	velocity.y = clampf(velocity.y - g * mult * delta, -max_fall_speed, max_fall_speed)


func _try_jump() -> void:
	if _jump_buffer_timer <= 0.0 or _coyote_timer <= 0.0:
		return
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_jumping = true
	velocity.y = sqrt(2.0 * _gravity * jump_height)
	if is_dashing:
		_air_speed = dash_speed if dash_jump_keeps_speed else move_speed
		_end_dash()
	else:
		_air_speed = maxf(move_speed, Vector2(velocity.x, velocity.z).length())
	jumped.emit()


# --- Horizontal ------------------------------------------------------------

func _apply_horizontal(delta: float, on_floor: bool) -> void:
	var dir := move_direction
	var speed := move_speed if on_floor else _air_speed
	if is_dashing:
		if dir != Vector3.ZERO:
			_dash_direction = dir
		dir = _dash_direction
		speed = dash_speed

	var target := dir * speed
	var rate: float
	if on_floor or is_dashing:
		rate = ground_acceleration if dir != Vector3.ZERO else ground_deceleration
	else:
		rate = air_acceleration if dir != Vector3.ZERO else air_deceleration

	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _update_facing(delta: float) -> void:
	var dir := _dash_direction if is_dashing else move_direction
	if dir == Vector3.ZERO:
		return
	facing_direction = dir
	var yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-turn_sharpness * delta))


# --- Dash ------------------------------------------------------------------

func _start_dash() -> void:
	is_dashing = true
	_dash_timer = dash_duration
	_dash_direction = move_direction if move_direction != Vector3.ZERO else facing_direction
	velocity.x = _dash_direction.x * dash_speed
	velocity.z = _dash_direction.z * dash_speed
	dash_started.emit()


func _end_dash() -> void:
	if not is_dashing:
		return
	is_dashing = false
	_dash_cooldown_timer = dash_cooldown
	dash_ended.emit()


func _update_timers(delta: float, on_floor: bool) -> void:
	if on_floor:
		_coyote_timer = coyote_time
	else:
		_coyote_timer -= delta
	_jump_buffer_timer -= delta
	if is_dashing:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_end_dash()
	else:
		_dash_cooldown_timer -= delta


# --- Collision / floor -----------------------------------------------------

func _move(delta: float, on_floor: bool) -> void:
	# Zone drift is added only for this move so input control stays independent of it.
	velocity += _drift
	if not (on_floor and velocity.y <= 0.0 and _try_step_up(delta)):
		move_and_slide()
	velocity -= _drift


func _update_floor_transition() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		_jumping = false
		_air_speed = move_speed
		landed.emit()
	elif not on_floor and _was_on_floor and not _jumping:
		# Walked (or dashed) off a ledge: keep current speed as the air cap.
		_air_speed = maxf(move_speed, Vector2(velocity.x, velocity.z).length())
	_was_on_floor = on_floor


## Moves up/over/down a ledge no taller than step_height. Returns true if it stepped.
func _try_step_up(delta: float) -> bool:
	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if motion.length_squared() < 1e-8:
		return false

	var params := PhysicsTestMotionParameters3D.new()
	var result := PhysicsTestMotionResult3D.new()
	var xf := global_transform

	# Only step when the straight move would hit something too steep to walk.
	params.from = xf
	params.motion = motion
	if not PhysicsServer3D.body_test_motion(get_rid(), params, result):
		return false
	if result.get_collision_normal().angle_to(up_direction) <= floor_max_angle:
		return false

	# Up.
	params.motion = up_direction * step_height
	var up_travel := params.motion
	if PhysicsServer3D.body_test_motion(get_rid(), params, result):
		up_travel = result.get_travel()
	xf.origin += up_travel

	# Across.
	params.from = xf
	params.motion = motion
	var across := motion
	if PhysicsServer3D.body_test_motion(get_rid(), params, result):
		across = result.get_travel()
	if across.length_squared() < motion.length_squared() * 0.25:
		return false
	xf.origin += across

	# Down onto the step.
	params.from = xf
	params.motion = -up_direction * (up_travel.length() + 0.05)
	if not PhysicsServer3D.body_test_motion(get_rid(), params, result):
		return false
	if result.get_collision_normal().angle_to(up_direction) > floor_max_angle:
		return false
	xf.origin += result.get_travel()
	if (xf.origin - global_position).dot(up_direction) < 0.01:
		return false

	global_position = xf.origin
	# Zero-horizontal slide to refresh floor state without moving again.
	var saved := velocity
	velocity = -up_direction
	move_and_slide()
	velocity = Vector3(saved.x, 0.0, saved.z)
	return true


# --- Interaction -----------------------------------------------------------

func _interact() -> void:
	var target := _find_interact_target()
	interact_pressed.emit(target)
	if target and target.has_method(&"interact"):
		target.call(&"interact", self)


func _find_interact_target() -> Node3D:
	if not interact_area:
		return null
	var best: Node3D = null
	var best_dist := INF
	var candidates: Array[Node3D] = []
	candidates.append_array(interact_area.get_overlapping_bodies())
	candidates.append_array(interact_area.get_overlapping_areas())
	for node in candidates:
		if node == self or not node.has_method(&"interact"):
			continue
		var d := global_position.distance_squared_to(node.global_position)
		if d < best_dist:
			best_dist = d
			best = node
	return best
