@tool
class_name MapGraph
extends Node2D

@export var edge_color := Color.WHITE
@export var edge_width := 3.0

func _draw() -> void:
	for n in get_children():
		if n is MapNode:
			for other in n.connections:
				if other:
					draw_line(n.position, other.position, edge_color, edge_width, true)
