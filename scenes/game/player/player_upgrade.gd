class_name PlayerUpgrade
extends Resource

var host: Player

@export var upgrade_name : String
@export var upgrade_message : String
@export var upgrade_effects : Array[PlayerEffect]

func apply(player: Player):
	for effect in upgrade_effects:
		effect.apply_effect(player)
