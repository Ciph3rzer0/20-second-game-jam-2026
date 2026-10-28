@tool
extends EditorPlugin

var btn: Button

func _enter_tree() -> void:
	btn = Button.new()
	btn.text = "Toggle Edge"
	btn.flat = true
	btn.visible = false
	btn.pressed.connect(_toggle_edge)
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, btn)
	EditorInterface.get_selection().selection_changed.connect(_on_selection_changed)
	_on_selection_changed()

func _exit_tree() -> void:
	EditorInterface.get_selection().selection_changed.disconnect(_on_selection_changed)
	remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, btn)
	btn.queue_free()

func _selected_map_nodes() -> Array:
	return EditorInterface.get_selection().get_selected_nodes().filter(
		func(n): return n is MapNode)

func _on_selection_changed() -> void:
	var count := _selected_map_nodes().size()
	btn.visible = count > 0
	btn.disabled = count != 2
	btn.tooltip_text = "" if count == 2 else "Select exactly two MapNodes"

func _toggle_edge() -> void:
	var sel := EditorInterface.get_selection().get_selected_nodes().filter(
		func(n): return n is MapNode)
	if sel.size() != 2:
		push_warning("Select exactly two MapNodes")
		return
	var a: MapNode = sel[0]
	var b: MapNode = sel[1]
	var ur := get_undo_redo()
	ur.create_action("Toggle edge")
	if b in a.connections:
		_set_conns(ur, a, b, false)
	elif a in b.connections:
		_set_conns(ur, b, a, false)
	else:
		_set_conns(ur, a, b, true)
	ur.commit_action()

func _set_conns(ur: EditorUndoRedoManager, node: MapNode, other: MapNode, add: bool) -> void:
	var c := node.connections.duplicate()  # keeps the Array[MapNode] type
	if add: c.append(other)
	else: c.erase(other)
	ur.add_do_property(node, "connections", c)
	ur.add_undo_property(node, "connections", node.connections)
