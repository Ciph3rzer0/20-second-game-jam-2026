extends Timer

@export var progress_bar: Range

func _ready() -> void:
	progress_bar.max_value = wait_time
	progress_bar.value = wait_time
	set_process(false)

func start_countdown() -> void:
	start()
	set_process(true)

func _process(_delta: float) -> void:
	progress_bar.value = time_left
