class_name Pickup
extends Area3D

@export var upgrade: PlayerUpgrade

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D):
	print(body.name)
	
	assert(body is Player)
	upgrade.apply(body)
	queue_free()
