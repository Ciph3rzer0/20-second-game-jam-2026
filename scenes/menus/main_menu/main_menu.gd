extends MainMenu

const PREVIEW_GAP := 16.0
const MIN_PREVIEW_HEIGHT := 56.0

@onready var slime_preview: SubViewportContainer = $SlimePreview
@onready var _preview_top_offset := slime_preview.offset_top

func load_game_scene() -> void:
	GameState.start_game()
	super.load_game_scene()

func new_game() -> void:
	GameState.reset()
	load_game_scene()

func _ready() -> void:
	super._ready()
	sub_menu_opened.connect(_refresh_slime_preview)
	sub_menu_closed.connect(_refresh_slime_preview)
	exit_confirmation.visibility_changed.connect(_refresh_slime_preview)
	menu_buttons_box_container.item_rect_changed.connect(_refresh_slime_preview)
	resized.connect(_refresh_slime_preview)
	_refresh_slime_preview.call_deferred()

func _refresh_slime_preview() -> void:
	var button_rect: Rect2 = menu_buttons_box_container.get_global_rect()
	var content_bottom := button_rect.end.y - global_position.y
	var top_offset := maxf(_preview_top_offset, content_bottom + PREVIEW_GAP - size.y)
	slime_preview.offset_top = minf(top_offset, slime_preview.offset_bottom)
	var has_room := slime_preview.offset_bottom - top_offset >= MIN_PREVIEW_HEIGHT
	slime_preview.visible = has_room and sub_menu == null and not exit_confirmation.visible
