extends SubViewportContainer

const PLAYER_SCENE = preload("res://scenes/game/player/player.tscn")
const TRAVEL_PERIOD := 10.0
const HOP_RATE := 2.0
const EDGE_MARGIN := 0.8

@onready var _camera: Camera3D = $Viewport/Camera3D

var _model: Node3D
var _material: ShaderMaterial
var _elapsed := 0.0


func _ready() -> void:
	# Reuse the gameplay visuals without adding its player controller to the tree.
	var player := PLAYER_SCENE.instantiate() as Player
	_model = player.get_node("Model")
	var slime := _model.get_node("slime") as MeshInstance3D
	_material = slime.get_active_material(0).duplicate() as ShaderMaterial
	slime.material_override = _material
	var bounds := slime.mesh.get_aabb()
	_material.set_shader_parameter("lean_base_y", bounds.position.y)
	_material.set_shader_parameter("lean_height", bounds.size.y)
	player.remove_child(_model)
	player.free()
	$Viewport.add_child(_model)
	_camera.look_at(Vector3(0, 0.1, 0))


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_elapsed = fposmod(_elapsed + delta, TRAVEL_PERIOD)
	var phase := TAU * _elapsed / TRAVEL_PERIOD
	var hop := sin(PI * fposmod(_elapsed * HOP_RATE, 1.0))
	var half_width := _camera.size * size.x / maxf(size.y, 1.0) * 0.5
	_model.position.x = sin(phase) * maxf(half_width - EDGE_MARGIN, 0.0)
	_model.position.y = 0.5 + 0.16 * hop
	_material.set_shader_parameter("squish", lerpf(0.15, -0.12, hop))
	_material.set_shader_parameter("lean", Vector2(0.12 * cos(phase), 0))
