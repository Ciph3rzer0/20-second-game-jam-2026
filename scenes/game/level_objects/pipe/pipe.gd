@tool
class_name Pipe
extends Path3D
## Sucks the player in at the start of the curve and carries them along it to
## the end. Edit the route with the Path3D curve tools; the tube mesh and the
## end areas follow (also in the editor).

## Travel speed inside the pipe, in metres per second.
@export var speed := 8.0
## Speed the player shoots out of the end at, along the pipe's direction.
@export var exit_speed := 6.0
## Time to pull the player into the mouth before travelling.
@export var suck_time := 0.2
## Also suck the player in at the last marker and carry them back to the first.
@export var two_way := false
## The player's origin is at their feet; this lifts the route to their middle.
@export var player_center_height := 0.4

@export_group("Shape")
@export var radius := 0.7
@export var wall_thickness := 0.1

@onready var entrance: Area3D = $Entrance
@onready var exit: Area3D = $Exit
@onready var mesh: CSGPolygon3D = $Mesh

var _rider: Player
var _forward := true
var _distance := 0.0
var _built_signature: Array


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	set_process(false)
	set_physics_process(false)
	exit.monitoring = two_way
	entrance.body_entered.connect(_on_body_entered.bind(true))
	exit.body_entered.connect(_on_body_entered.bind(false))


func _process(_delta: float) -> void:
	# Editor only: keep the tube and end areas in step with the curve.
	_rebuild()


# --- Travel ----------------------------------------------------------------

func _on_body_entered(body: Node3D, forward: bool) -> void:
	if _rider or body is not Player or body.in_pipe:
		return
	var length := curve.get_baked_length()
	if length < 0.01:
		return
	_rider = body
	_forward = forward
	_distance = 0.0 if forward else length
	_rider.enter_pipe()

	# Suck them into the mouth, then start travelling.
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(_rider, "global_position", _rider_position(_distance), suck_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(set_physics_process.bind(true))


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_rider):
		_rider = null
		set_physics_process(false)
		return

	var length := curve.get_baked_length()
	var end := length if _forward else 0.0
	_distance = move_toward(_distance, end, speed * delta)
	_rider.global_position = _rider_position(_distance)

	if is_equal_approx(_distance, end):
		var before := end - 0.1 if _forward else end + 0.1
		var dir := curve.sample_baked(end, true) - curve.sample_baked(before, true)
		_rider.exit_pipe((global_basis * dir).normalized() * exit_speed)
		_rider = null
		set_physics_process(false)


func _rider_position(distance: float) -> Vector3:
	return to_global(curve.sample_baked(distance, true)) - Vector3.UP * player_center_height


# --- Building ----------------------------------------------------------------

func _rebuild() -> void:
	if curve == null:
		curve = Curve3D.new()
	var n := curve.point_count
	var first := curve.get_point_position(0) if n > 0 else Vector3.ZERO
	var last := curve.get_point_position(n - 1) if n > 0 else Vector3.ZERO

	var signature := [first, last, radius, wall_thickness]
	if signature == _built_signature:
		return
	_built_signature = signature

	mesh.polygon = _ring(radius, wall_thickness)
	entrance.position = first
	exit.position = last
	for area: Area3D in [entrance, exit]:
		var shape := (area.get_child(0) as CollisionShape3D).shape as SphereShape3D
		shape.radius = radius


## A ring cross-section as one polygon: the outer circle one way, the inner
## circle back, joined by a hairline slit so the tube comes out hollow.
static func _ring(outer: float, wall: float, segments := 24) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var gap := 0.002
	for i in segments + 1:
		polygon.append(Vector2.from_angle(lerpf(gap, TAU - gap, float(i) / segments)) * outer)
	for i in segments + 1:
		polygon.append(Vector2.from_angle(lerpf(TAU - gap, gap, float(i) / segments)) * (outer - wall))
	return polygon
