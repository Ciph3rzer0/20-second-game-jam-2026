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

signal started_moving
var _has_moved

signal win
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
## While cotton_candy floats in a zone this close to the floor, use ground control.
@export var float_control_height: float = 0.6
## How fast (m/s²) upward speed above a zone's float_velocity bleeds off, e.g. after jumping in.
@export var float_overspeed_decay: float = 6.0
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
@export var dash_in_air: bool = true
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

## When true, gravity zones push the opposite way (low-gravity updrafts lift the player).
var can_float := false
var can_stick := false
var can_dash := false
var can_push := false
var can_grapple := false

var _gravity := 9.8  # base gravity magnitude, also used for the jump impulse
var _default_gravity := Vector3.DOWN * 9.8
var _zone: Area3D
var _drift := Vector3.ZERO  # sideways velocity from gravity zones, added on top of input
var _last_platform_velocity := Vector3.ZERO
var _had_support := false
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _dash_direction := Vector3.FORWARD
var _air_speed := 0.0
var _jumping := false
var _was_on_floor := false
var _maintain_momentum := false

@export_group("Slime")
@export var jump_sound: AudioStream

@export var stiffness := 26.0
@export var damping := 7.0

@export var lean_response := 1.0
@export var lean_stiffness := 55.0
@export var lean_damping := 10.0
@export var max_lean := 0.18

@export var slime: MeshInstance3D
@export var buff_slime_mesh: Mesh

var material: ShaderMaterial

var squish := 0.0
var squish_velocity := 0.0

var lean := Vector2.ZERO
var lean_velocity := Vector2.ZERO
var previous_horizontal_velocity := Vector2.ZERO

static var instance: Player

func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		if instance == null:
			instance = self
		else:
			queue_free()
			set_process(false)
			set_physics_process(false)
	

func _exit_tree() -> void:
	if instance == self:
		instance = null

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
	platform_on_leave = PLATFORM_ON_LEAVE_DO_NOTHING  # handled in _launch_off_platform
	floor_snap_length = maxf(floor_snap_length, step_height + 0.05)
	facing_direction = -global_basis.z
	_air_speed = move_speed
	_was_on_floor = is_on_floor()

	# Slime Ready
	if material == null:
		material = slime.get_active_material(0) as ShaderMaterial

	if material == null:
		push_error("Slime requires a ShaderMaterial on its mesh or in the material export.")
		return

	material = material.duplicate() as ShaderMaterial
	slime.material_override = material

	var bounds := slime.mesh.get_aabb()
	material.set_shader_parameter("lean_base_y", bounds.position.y)
	material.set_shader_parameter("lean_height", bounds.size.y)

var held_item : Node3D

func pickup_item(node: Node3D) -> void:
	if (not can_push): return
	assert(not held_item)
	print(" :: Picking up item ", node.name)
	
	if node is RigidBody3D:
		held_item = node
		(held_item as RigidBody3D).freeze = true
		(held_item.find_child("CollisionShape3D") as CollisionShape3D).disabled = true
		$PickupAreaCollision.disabled = false
		held_item.reparent($PickupArea)
		held_item.position = Vector3.ZERO

func drop_item() -> void:
	if (not can_push): return
	assert(held_item)
	print(" :: Dropping item ", held_item.name)
	if held_item is RigidBody3D:
		(held_item as RigidBody3D).freeze = false
		(held_item.find_child("CollisionShape3D") as CollisionShape3D).disabled = false
		$PickupAreaCollision.disabled = true
		held_item.reparent(get_parent())
		held_item.linear_velocity = velocity * 0.6
		held_item = null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pc_interact"):
		
		if held_item:
			print(" Dropping item ")
			drop_item()
		else:
			var target := _find_pickup_target()
			if target:
				pickup_item(target)

func get_pickup_prompt() -> String:
	if not can_push:
		return ""
	if held_item:
		return "Press E to drop block"
	if _find_pickup_target():
		return "Press E to pick up block"
	return ""


## Closest body in PickupArea that we can see
func _find_pickup_target() -> Node3D:
	var space := get_world_3d().direct_space_state
	var from: Vector3 = ($CollisionShape3D as Node3D).global_position
	var best: Node3D = null
	var best_dist := INF
	for body: Node3D in $PickupArea.get_overlapping_bodies():
		var query := PhysicsRayQueryParameters3D.create(from, body.global_position, collision_mask, [get_rid()])
		var hit := space.intersect_ray(query)
		# Blocked if the ray hits something other than the item itself.
		if not hit.is_empty() and hit.collider != body:
			continue
		var d := from.distance_squared_to(body.global_position)
		if d < best_dist:
			best_dist = d
			best = body
	return best



func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()

	# Reset momentum gained from being launched (flippy thing)
	if on_floor:
		_maintain_momentum = false

	_update_timers(delta, on_floor)
	_update_gravity(delta)

	if _maintain_momentum:
		move_direction = Vector3.ZERO
	else:
		move_direction = _read_move_direction()

	if not _maintain_momentum:
		if Input.is_action_just_pressed("pc_jump"):
			_jump_buffer_timer = jump_buffer_time
		if Input.is_action_just_pressed("pc_dash") and can_dash:
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
	var falling_speed := velocity.y  # before move_and_slide zeroes it on landing
	_move(delta, on_floor)
	_slime_physics_process(delta, on_floor, falling_speed)
	_update_floor_transition()


func _slime_physics_process(delta: float, was_on_floor: bool, falling_speed: float):
	# Horizontal velocity changes give the lean spring an impulse.
	var actual_velocity := get_real_velocity()
	var horizontal_velocity := Vector2(actual_velocity.x, actual_velocity.z)
	var velocity_change := horizontal_velocity - previous_horizontal_velocity
	previous_horizontal_velocity = horizontal_velocity
	lean_velocity -= velocity_change * lean_response

	var lean_acceleration := -lean_stiffness * lean - lean_damping * lean_velocity
	lean_velocity += lean_acceleration * delta
	lean += lean_velocity * delta
	lean = lean.limit_length(max_lean)

	# Landing generates a deformation impulse
	if not was_on_floor and is_on_floor():

		if falling_speed < 0.0:
			squish_velocity += min(
				-falling_speed * 0.16,
				1.8
			)

	# spring
	var acceleration := (
		-stiffness * squish
		-damping * squish_velocity
	)

	squish_velocity += acceleration * delta
	squish += squish_velocity * delta

	squish = clamp(squish, -0.5, 0.75)

	# Send parameters to shader.
	if material == null:
		return

	# spring uses world space; shader vertices use mesh-local space
	var local_lean := slime.global_basis.inverse() * Vector3(lean.x, 0.0, lean.y)
	material.set_shader_parameter("lean", Vector2(local_lean.x, local_lean.z))

	material.set_shader_parameter(
		"squish",
		squish
	)

	var horizontal_speed := Vector2(
		velocity.x,
		velocity.z
	).length()

	material.set_shader_parameter(
		"motion",
		clamp(horizontal_speed / move_speed, 0.5, 1.0)
	)


# --- Input -----------------------------------------------------------------

func _read_move_direction() -> Vector3:
	var input := Input.get_vector(&"pc_move_left", &"pc_move_right", &"pc_move_up", &"pc_move_down", stick_deadzone)
	if input == Vector2.ZERO:
		return Vector3.ZERO
	input = Vector2.from_angle(snappedf(input.angle(), TAU / DIRECTION_COUNT))

	if not _has_moved:
		started_moving.emit()
		_has_moved = true

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
		var zone_gravity := dir * _zone.gravity * gravity_scale
		if can_float:
			zone_gravity = -zone_gravity / 3.0
		gravity_vector = zone_gravity
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
	var prior := velocity.y
	velocity.y = clampf(prior - g * mult * delta, -max_fall_speed, max_fall_speed)

	# Cotton candy: updrafts cap upward speed at the zone's float_velocity.
	if can_float and _zone:
		var cap: Variant = _zone.get(&"float_velocity")
		if cap != null:
			var limit := float(cap)
			if prior > limit:
				# Entered faster than the cap (e.g. jumped in): keep the
				# momentum and ease it down instead of clamping.
				velocity.y = move_toward(prior, limit, float_overspeed_decay * delta)
			else:
				velocity.y = minf(velocity.y, limit)


func _try_jump() -> void:
	if _jump_buffer_timer <= 0.0 or _coyote_timer <= 0.0:
		return
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_jumping = true
	velocity.y = sqrt(2.0 * _gravity * jump_height)
	
	# Reduce horizontal speed when jumping
	var h_velocity = velocity * Vector3(1, 0, 1)
	var h_speed = h_velocity.length()
	
	var v_velocity = velocity * Vector3(0, 1, 0)
	var v_speed = v_velocity.length()
	
	var new_h_speed = h_speed - v_speed / 3.0
	velocity = h_velocity.normalized() * new_h_speed
	velocity.y = v_velocity.y
	
	if is_dashing:
		_air_speed = dash_speed if dash_jump_keeps_speed else move_speed
		_end_dash()
	else:
		_air_speed = maxf(move_speed, Vector2(velocity.x, velocity.z).length())
	
	play_sound(jump_sound)
	# Stretch upward when jumping
	squish_velocity -= 2.0

	jumped.emit()


# --- Horizontal ------------------------------------------------------------

func _near_floor() -> bool:
	var params := PhysicsTestMotionParameters3D.new()
	params.from = global_transform
	params.motion = Vector3.DOWN * float_control_height
	return PhysicsServer3D.body_test_motion(get_rid(), params)

func _apply_horizontal(delta: float, on_floor: bool) -> void:
	# Lifted slightly by an updraft counts as grounded for control purposes.
	var grounded: bool = on_floor or (can_float and _zone != null and _near_floor())

	var dir := move_direction
	var speed := move_speed if grounded else _air_speed
	if is_dashing:
		if dir != Vector3.ZERO:
			_dash_direction = dir
		dir = _dash_direction
		speed = dash_speed

	var target := dir * speed
	var rate: float
	if grounded or is_dashing:
		rate = ground_acceleration if dir != Vector3.ZERO else ground_deceleration
	else:
		if not _maintain_momentum:
			rate = air_acceleration if dir != Vector3.ZERO else air_deceleration

	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, rate * delta)

	# Zone drag: exponential damping, read from a horizontal_drag property on the zone.
	if _zone and _zone.linear_damp_space_override != Area3D.SPACE_OVERRIDE_DISABLED:
		horizontal *= exp(-_zone.linear_damp * delta)

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

	# Dash velocity boost
	velocity.y = jump_height * 3

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
		var pre_slide := velocity
		move_and_slide()
		_push_bodies(pre_slide)
		_launch_off_platform(delta)
	velocity -= _drift

## Keeps a moving platform's speed when we leave it. Replaces Godot's
## platform_on_leave (turned off in _ready) so it also works on surfaces too
## steep to count as floor, like a flipper arm partway through its swing.
## Leaving means stepping off, jumping off, or the platform stopping faster than
## gravity would pull us down (a flipper reaching the top), which throws us.
func _launch_off_platform(delta: float) -> void:
	var support := Vector3.ZERO
	var has_support := false
	if is_on_floor():
		support = get_platform_velocity()
		has_support = true
	else:
		# Resting on a slope too steep to stand on: use the velocity of what's under us.
		var best_up := 0.1
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			var up := c.get_normal().dot(up_direction)
			if up > best_up:
				best_up = up
				support = c.get_collider_velocity()
				has_support = true

	var stopped_under_us := has_support \
		and (_last_platform_velocity - support).dot(up_direction) > _gravity * delta
	if _had_support and (stopped_under_us or not has_support):
		velocity += _last_platform_velocity
		# We're airborne now, even if still touching it this frame.
		has_support = false
		support = Vector3.ZERO
	_had_support = has_support
	_last_platform_velocity = support

func _push_bodies(pre_slide: Vector3) -> void:
	var pushed: Array[RigidBody3D] = []
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var body := c.get_collider() as RigidBody3D
		if body == null or body in pushed:
			continue
		var normal := c.get_normal()
		# Standing on (or bumping under) the box is not a push.
		if absf(normal.dot(up_direction)) > 0.7:
			continue
		var dir := -normal
		dir -= up_direction * dir.dot(up_direction)
		if dir.length_squared() < 0.01:
			continue
		dir = dir.normalized()
		var push_speed := pre_slide.dot(dir) * push_speed_factor
		if push_speed <= 0.0:
			continue
		pushed.append(body)
		# Bring the box up to push speed along dir (never slow it down).
		var box_speed := body.linear_velocity.dot(dir)
		if box_speed < push_speed:
			body.apply_central_impulse(dir * (push_speed - box_speed) * body.mass)
		# Give back the speed the slide stripped, so we keep walking with the box instead of stutter-stepping.
		var my_speed := velocity.dot(dir)
		if my_speed < push_speed:
			velocity += dir * (push_speed - my_speed)

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


# --- Transformations -------------------------------------------------------

@export_group("Transformations")

func set_slime_mesh(mesh: Mesh) -> void:
	slime.mesh = mesh
	# The lean shader is set up from the mesh bounds in _ready; redo it for the new shape.
	var bounds := mesh.get_aabb()
	material.set_shader_parameter("lean_base_y", bounds.position.y)
	material.set_shader_parameter("lean_height", bounds.size.y)

func modify_scale(height: float, width: float) -> void:
	(($CollisionShape3D as CollisionShape3D).shape as SphereShape3D).radius *= max(height, width)
	$Model.scale.y *= height
	$Model.scale.x *= width
	$Model.scale.z *= width

# Set the effect shader for whole model
func set_material_overlay_recursive(material: Material, node: Node = self) -> void:
	for child in node.get_children():
		print(child.name)
		if child is GeometryInstance3D:
			print(child.name, " is material")
			child.material_overlay = material
		set_material_overlay_recursive(material, child)


# Fraction of the player's speed a pushed rigid body moves at (lower feels heavier).
@export_range(0.0, 1.0, 0.05) var push_speed_factor := 0.3

func become_jello():
	pass



@export_range(1.0, 4.0, 0.25) var hot_tamale_speed_multiplier := 1.3

func become_hot_tamale():
	can_dash = true
	move_speed *= hot_tamale_speed_multiplier



@export_range(0.1, 1.0, 0.05) var pancake_shrink_multiplier := 0.2
@export_range(1.0, 2.0, 0.10) var pancake_widen_multiplier := 2.0
@export_range(0.1, 1.0, 0.05) var pancake_speed_multiplier := 0.8
@export_range(0.1, 1.0, 0.05) var pancake_jump_multiplier := 0.5

func become_pancake():
	modify_scale(pancake_shrink_multiplier, pancake_widen_multiplier)
	move_speed *= pancake_speed_multiplier
	jump_height *= pancake_jump_multiplier



func become_cotton_candy():
	can_float = true
	set_material_overlay_recursive(preload("uid://cfqpg500558gd"))



@export_range(0.0, 1.0, 0.05) var beef_push_speed_factor := 0.8
@export var beef_body_scale := 1.4

func become_beef():
	can_push = true
	push_speed_factor = beef_push_speed_factor
	set_slime_mesh(buff_slime_mesh)
	
	slime.scale *= beef_body_scale * 1/2 # Adust for mesh size
	slime.scale.z = -slime.scale.z
	
	# Double hit-box width
	(($CollisionShape3D as CollisionShape3D).shape as SphereShape3D).radius *= beef_body_scale
	#$"BeefyArms CollisionL".set_deferred("disabled", false)
	#$"BeefyArms CollisionR".set_deferred("disabled", false)


func become_honey():
	can_stick = true



func become_spaghetti():
	can_grapple = true



func play_sound(stream: AudioStream) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
