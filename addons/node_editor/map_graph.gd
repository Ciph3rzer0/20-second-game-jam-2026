@tool
class_name MapGraph
extends Node2D

@export var edge_color := Color.WHITE
@export var edge_width := 8.0
@export var tile_length := 32.0  # world units per repeat of the pattern

func _draw() -> void:
	for n in get_children():
		if n is MapNode:
			for other in n.connections:
				if other:
					_draw_edge(n.position, other.position)

func _draw_edge(a: Vector2, b: Vector2) -> void:
	var dir := b - a
	var length := dir.length()
	if length == 0.0:
		return
	var side := dir.orthogonal().normalized() * edge_width * 0.5
	var pts := PackedVector2Array([a - side, b - side, b + side, a + side])
	var u := length / tile_length
	var uvs := PackedVector2Array([Vector2(0, 0), Vector2(u, 0), Vector2(u, 1), Vector2(0, 1)])
	draw_polygon(pts, PackedColorArray([edge_color]), uvs)
