@tool
class_name Pickup
extends Area3D

const PickupAnimation = preload("res://scripts/pickup.gd")
const OUTLINE = preload("res://scenes/game/pickup_outline.tres")
const HOVER_HEIGHT := 0.1
const HOVER_FREQUENCY := 0.4

@export var upgrade: PlayerUpgrade:
	set(value):
		if upgrade and upgrade.changed.is_connected(_update_model):
			upgrade.changed.disconnect(_update_model)
		upgrade = value
		if upgrade:
			upgrade.changed.connect(_update_model)
		_update_model()

@onready var _visual: Node3D = $Visual
@onready var _hover_origin_y := _visual.position.y
var _hover_phase := 0.0
var _absorbing := false


func _ready() -> void:
	_update_model()
	if Engine.is_editor_hint():
		set_process(false)
		return
	monitoring = monitoring and is_visible_in_tree()
	body_entered.connect(_on_body_entered)


func _update_model() -> void:
	if not is_node_ready() or _absorbing:
		return
	for child in _visual.get_children():
		_visual.remove_child(child)
		child.queue_free()
	if upgrade and upgrade.pickup_model:
		var model := upgrade.pickup_model.instantiate() as Node3D
		model.transform = upgrade.pickup_model_transform
		if model is MeshInstance3D:
			model.material_overlay = OUTLINE
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			mesh.material_overlay = OUTLINE
		_visual.add_child(model)


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_visual.rotate_y(PickupAnimation.SPIN_SPEED * delta)
		_hover_phase = fposmod(_hover_phase + TAU * HOVER_FREQUENCY * delta, TAU)
		_visual.position.y = _hover_origin_y + HOVER_HEIGHT * sin(_hover_phase)


func _on_body_entered(body: Node3D) -> void:
	if _absorbing or not upgrade or not is_visible_in_tree() or not body is Player:
		return
	_absorbing = true
	set_process(false)
	_absorb.call_deferred(body)


func _absorb(player: Player) -> void:
	if is_instance_valid(player) and not player.is_queued_for_deletion():
		if not upgrade.animate_pickup:
			player.play_sound(PickupAnimation.ABSORB_SOUND)
		upgrade.apply(player)
		if upgrade.animate_pickup:
			PickupAnimation.animate_absorption(_visual, player.slime, player.play_sound)
	queue_free()
