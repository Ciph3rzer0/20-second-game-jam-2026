extends Area3D

@export var nodes_to_hide: Array[Node3D]
var _meshes: Array[GeometryInstance3D] = []


func _ready() -> void:
	for node in nodes_to_hide:
		for c in node.find_children("*", "GeometryInstance3D", true, false):
			_meshes.append(c)
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D):
	_set_hidden(true)

func _on_body_exited(body: Node3D):
	_set_hidden(false)

func _set_hidden(val: bool) -> void:
	for mesh in _meshes:
		if val:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		else:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
