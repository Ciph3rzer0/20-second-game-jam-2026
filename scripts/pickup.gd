extends Node3D

const ABSORB_SOUND = preload("res://assets/audio/sfx/squelch_01.wav")
const DISSOLVE_SOUND = preload("res://assets/audio/sfx/dissolve_02.wav")
const DISAPPEAR_SOUND = preload("res://assets/audio/sfx/squelch_03.wav")
const SPIN_SPEED := 0.6
const ABSORB_DURATION := 0.5
const HOLD_DURATION := 0.5

var absorbing := false

func _process(delta: float) -> void:
	rotate_y(SPIN_SPEED * delta)

func _on_body_entered(body: Node3D) -> void:
	if absorbing or not body is Slime:
		return

	absorbing = true
	set_process(false)
	$meat/CollectionArea.set_deferred("monitoring", false)
	# Reparent outside the physics query that emitted body_entered.
	_absorb.call_deferred(body)

func _absorb(body: Slime) -> void:
	if not is_instance_valid(body):
		queue_free()
		return

	animate_absorption(self, body.slime, body.play_sound)

static func animate_absorption(
	visual: Node3D, slime_mesh: MeshInstance3D, play_sound: Callable, on_arrival := Callable()
) -> void:
	# Tween in mesh-local space so the pickup follows a moving or jumping slime.
	visual.reparent(slime_mesh, true)
	play_sound.call(ABSORB_SOUND)
	var tween := visual.create_tween()
	tween.tween_property(visual, "position", slime_mesh.mesh.get_aabb().get_center(), ABSORB_DURATION)
	tween.tween_callback(play_sound.bind(DISSOLVE_SOUND))
	if on_arrival.is_valid():
		tween.tween_callback(on_arrival)
	tween.tween_interval(HOLD_DURATION)
	tween.tween_callback(play_sound.bind(DISAPPEAR_SOUND))
	tween.tween_callback(visual.queue_free)
