@tool
class_name Pickup
extends Area3D

@export var upgrade: PlayerUpgrade:
	set(value):
		if upgrade and upgrade.changed.is_connected(_update_sprite):
			upgrade.changed.disconnect(_update_sprite)
		upgrade = value
		if upgrade:
			upgrade.changed.connect(_update_sprite)
		_update_sprite()

func _ready() -> void:
	_update_sprite()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)

func _update_sprite() -> void:
	if not is_node_ready():
		return
	var t: Texture2D = upgrade.upgrade_icon if upgrade else null
	$Sprite3D.texture = t
	($Sprite3D.material_override as ShaderMaterial).set_shader_parameter("tex", t)

func _on_body_entered(body: Node3D) -> void:
	assert(body is Player)
	upgrade.apply(body)
	queue_free()
