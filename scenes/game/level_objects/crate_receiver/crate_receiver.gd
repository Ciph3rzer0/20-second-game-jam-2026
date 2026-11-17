extends Area3D

@export var target: Node3D
@export var duration := 1.0

var _tween: Tween

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(node: Node3D):
	var body = node as RigidBody3D
	if _tween and _tween.is_running():
		return  # ignore signals mid-flip (or kill() it and start the next one)
	
	body.freeze = true
	var start: Transform3D = body.global_transform
	var step := func(t: float) -> void:
		body.global_transform = start.interpolate_with(target.global_transform, t)
	
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(step, 0.0, 1.0, duration)
	
	monitoring = false
	## not working...
	#await _tween.finished
	#print ("tween finished ")
	#body.freeze = false
