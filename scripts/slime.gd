extends CharacterBody3D

@export var move_speed := 4.0
@export var jump_speed := 6.0
@export var gravity := 18.0

@export var stiffness := 26.0
@export var damping := 7.0

@onready var slime: MeshInstance3D = $slime

@export var material: ShaderMaterial

var squish := 0.0
var squish_velocity := 0.0


#func _ready():
	#material = slime.material_override.duplicate()
	#slime.material_override = material


func _physics_process(delta):

	# Movement
	var direction := Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
        "ui_down"
	)

	velocity.x = direction.x * move_speed
	velocity.z = direction.y * move_speed

	var was_on_floor := is_on_floor()

	if not was_on_floor:
		velocity.y -= gravity * delta

	if was_on_floor and Input.is_action_just_pressed("ui_accept"):
		velocity.y = jump_speed
		print("jumped")

		# Stretch upward when jumping
		squish_velocity -= 2.0

	var falling_speed := velocity.y

	move_and_slide()

	# Landing generates a deformation impulse
	if not was_on_floor and is_on_floor():

		if falling_speed < 0.0:
			squish_velocity += min(
				-falling_speed * 0.16,
				1.8
			)

	# Spring simulation
	var acceleration := (
		-stiffness * squish
		-damping * squish_velocity
	)

	squish_velocity += acceleration * delta
	squish += squish_velocity * delta

	squish = clamp(squish, -0.5, 0.75)

	### Send parameters to shader
	#material.set_shader_parameter(
		#"squish",
		#squish
	#)

	var horizontal_speed := Vector2(
		velocity.x,
		velocity.z
	).length()

	#material.set_shader_parameter(
		#"motion",
		#clamp(horizontal_speed / move_speed, 0.0, 1.0)
	#)
