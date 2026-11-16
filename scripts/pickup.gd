extends Node3D

const ABSORB_SOUND = preload("res://assets/audio/sfx/squelch_01.wav")
const DISSOLVE_SOUND = preload("res://assets/audio/sfx/dissolve_02.wav")
const DISAPPEAR_SOUND = preload("res://assets/audio/sfx/squelch_03.wav")
const ABSORB_DURATION := 0.5
const HOLD_DURATION := 0.5

var absorbing := false


func _process(_delta: float) -> void:
	rotate(Vector3(0,1,0), 0.01)


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

	# Tween in mesh-local space so the pickup follows a moving/jumping slime.
	reparent(body.slime, true)
	body.play_sound(ABSORB_SOUND)
	var tween := create_tween()
	tween.tween_property(self, "position", body.slime.mesh.get_aabb().get_center(), ABSORB_DURATION)
	tween.tween_callback(body.play_sound.bind(DISSOLVE_SOUND))
	tween.tween_interval(HOLD_DURATION)
	tween.tween_callback(body.play_sound.bind(DISAPPEAR_SOUND))
	tween.tween_callback(queue_free)
