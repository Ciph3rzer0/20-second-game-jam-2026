class_name Atom
extends CharacterBody2D

@onready var number_label: Label = $NumberLabel

func set_number(num: int):
	number_label.text = str(num)

func _physics_process(delta: float) -> void:
	velocity.x = 100
	move_and_slide()
