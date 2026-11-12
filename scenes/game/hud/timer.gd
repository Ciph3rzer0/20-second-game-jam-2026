extends Timer

@export var progress_bar: Range

func _ready() -> void:
	progress_bar.max_value = wait_time

func _process(delta: float) -> void:
	progress_bar.value = time_left
