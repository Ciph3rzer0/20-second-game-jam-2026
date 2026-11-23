class_name Teleporter
extends Area3D

const GROUP := &"level_teleporters"
const ARRIVAL_OFFSET := Vector3(0, 0.45, 0)
const TELEPORT_SOUND = preload("res://assets/audio/sfx/squelch_05.wav")
const COLORS := [
	Color(0.85, 0.06, 0.08),
	Color(0.12, 0.78, 0.22),
	Color(0.10, 0.36, 0.95),
	Color(0.96, 0.79, 0.08),
]

# The player can enter only one pad per physics step, including on arrival.
static var _locked_pad: Teleporter
var _channel := 0
var _channel_material: StandardMaterial3D

@onready var button_area: Area3D = $ButtonArea


func _ready() -> void:
	_channel_material = $base.get_active_material(0).duplicate() as StandardMaterial3D
	$base.material_override = _channel_material
	$box/button.material_override = _channel_material


static func find_button(player: Player) -> Teleporter:
	var nearest: Teleporter
	var nearest_distance := INF
	for pad: Teleporter in player.get_tree().get_nodes_in_group(GROUP):
		if pad.is_queued_for_deletion() or not pad.button_area or not pad.button_area.overlaps_body(player):
			continue
		var distance := player.global_position.distance_squared_to(pad.button_area.global_position)
		if distance < nearest_distance:
			nearest = pad
			nearest_distance = distance
	return nearest


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pc_interact"):
		return
	var player := Player.instance
	if not is_instance_valid(player) or find_button(player) != self:
		return
	get_viewport().set_input_as_handled()
	_channel = (_channel % (COLORS.size() - 1)) + 1
	_channel_material.albedo_color = COLORS[_channel]
	_channel_material.emission = COLORS[_channel]


func _exit_tree() -> void:
	if _locked_pad == self:
		_locked_pad = null


func _on_body_entered(body: Node3D) -> void:
	if _channel == 0 or not body is Player or is_instance_valid(_locked_pad):
		return

	var pads := get_tree().get_nodes_in_group(GROUP).filter(
		func(pad: Teleporter) -> bool:
			return pad._channel == _channel and pad.monitoring and not pad.is_queued_for_deletion()
	)
	if pads.size() < 2:
		return

	var destination: Teleporter = pads[(pads.find(self) + 1) % pads.size()]
	_locked_pad = self
	# Move the player after the physics query that emitted body_entered.
	_teleport.call_deferred(body, destination)


func _teleport(player: Player, destination: Teleporter) -> void:
	if not is_instance_valid(player) or not is_instance_valid(destination) or not destination.is_inside_tree():
		_locked_pad = null
		return

	_locked_pad = destination
	player.global_position = destination.to_global(ARRIVAL_OFFSET)
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	player.play_sound(TELEPORT_SOUND)


func _on_body_exited(body: Node3D) -> void:
	if body is Player and _locked_pad == self:
		_locked_pad = null
