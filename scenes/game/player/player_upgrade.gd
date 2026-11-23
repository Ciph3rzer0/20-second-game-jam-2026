class_name PlayerUpgrade
extends Resource

var host: Player

@export var upgrade_icon: Texture2D
@export var pickup_model: PackedScene
@export var pickup_model_transform := Transform3D.IDENTITY
@export var apply_on_arrival := false
@export var upgrade_name : String
@export var upgrade_message : String
@export var upgrade_effects : Array[PlayerEffect]

func apply(player: Player):
	for effect in upgrade_effects:
		effect.apply_effect(player)
