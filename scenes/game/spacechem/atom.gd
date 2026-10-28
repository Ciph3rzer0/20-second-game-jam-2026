class_name Atom
extends CharacterBody2D

@export var speed := 100.0

@onready var number_label: Label = $NumberLabel

func set_number(num: int):
	number_label.text = str(num)

func _physics_process(delta: float) -> void:
	velocity = global_transform.x.normalized() * speed
	move_and_slide()
