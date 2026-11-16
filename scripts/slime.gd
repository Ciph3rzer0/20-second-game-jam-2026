class_name Slime
extends CharacterBody3D

const JUMP_SOUND = preload("res://assets/audio/sfx/squelch_07.wav")

@export var move_speed := 4.0
@export var jump_speed := 6.0
@export var gravity := 18.0

@export var stiffness := 26.0
@export var damping := 7.0

@export var lean_response := 1.0
@export var lean_stiffness := 55.0
@export var lean_damping := 10.0
@export var max_lean := 0.18

@onready var slime: MeshInstance3D = $slime

@export var material: ShaderMaterial

var squish := 0.0
var squish_velocity := 0.0

var lean := Vector2.ZERO
var lean_velocity := Vector2.ZERO
var previous_horizontal_velocity := Vector2.ZERO


func _ready():
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


func _physics_process(delta):

	# Movement
	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
        "move_backward"
	)

	velocity.x = direction.x * move_speed
	velocity.z = direction.y * move_speed

	var was_on_floor := is_on_floor()

	if not was_on_floor:
		velocity.y -= gravity * delta

	if was_on_floor and Input.is_action_just_pressed("ui_accept"):
		velocity.y = jump_speed
		play_sound(JUMP_SOUND)

		# Stretch upward when jumping
		squish_velocity -= 2.0

	var falling_speed := velocity.y

	move_and_slide()

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
	
	## EATING ANIMATION
	# size increase + slow top tilt in last moveDir?
	
	## JUMPING ANIMATION
	 # remove the mask during jumps? 
	   # lerp removal over ~1s after the jump?

	# Landing generates a deformation impulse
	if not was_on_floor and is_on_floor():

		if falling_speed < 0.0:
			squish_velocity += min(
				-falling_speed * 0.16,
				1.8
			)

	# Spring sim
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

	# spring uses world space, while shader vertices use mesh-local space.
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


func play_sound(stream: AudioStream) -> void:
	# Keep sounds on the slime so removing an absorbed pickup won't cut them off.
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
