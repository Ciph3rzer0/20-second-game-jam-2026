extends Node2D

var atoms : Array[Atom]

func _ready() -> void:
	var count := 0
	for child in get_children():
		if child is Atom:
			count += 1
			child.set_number(count)
			atoms.append(child)
			remove_child(child)
	seed(778)
	atoms.shuffle()

func spawn_atom():
	var atom = atoms.pop_front()
	if atom is Atom:
		var parent := get_parent()
		var layer :int = atom.collision_layer
		var mask :int = atom.collision_mask
		atom.collision_layer = 0
		atom.collision_mask = 0
		atom.position = parent.to_local(global_position)
		parent.add_child(atom)
		atom.global_position = parent.to_global(atom.position)
		PhysicsServer2D.body_set_state(atom.get_rid(),
			PhysicsServer2D.BODY_STATE_TRANSFORM, atom.global_transform)
		await get_tree().physics_frame
		atom.collision_layer = layer
		atom.collision_mask = mask
