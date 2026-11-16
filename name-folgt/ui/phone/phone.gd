class_name Phone
extends CanvasLayer

signal closed

@export var post_scene: PackedScene
@export var post_count := 30
@export var scroll_interval := 1.2
@export var swipe_distance := 140.0
@export var dim_alpha := 0.35

var _can_close := false
var _drag := 0.0
var _feed_start_y: float
var _scroll_tween: Tween

@onready var _dim: ColorRect = $Dim
@onready var _slide: Control = $Slide
@onready var _feed: VBoxContainer = $Slide/Frame/Screen/Feed
@onready var _time_bar: ColorRect = $Slide/Frame/Screen/TimeBar
@onready var _hint: Label = $Slide/Frame/Hint


func _ready() -> void:
	_feed_start_y = _feed.position.y


func _input(event: InputEvent) -> void:
	if not _can_close:
		return

	if event.is_action_pressed("close_phone"):
		close()
	elif event is InputEventScreenDrag:
		_drag = maxf(_drag + event.relative.y, 0.0)
		_slide.position.y = _drag * 0.5
		if _drag >= swipe_distance:
			close()
	elif event is InputEventScreenTouch and not event.pressed:
		_drag = 0.0
		create_tween().tween_property(_slide, "position:y", 0.0, 0.15)


func open(duration: float) -> void:
	_fill_feed()
	_can_close = false
	_drag = 0.0
	_hint.modulate.a = 0.0
	_time_bar.scale.x = 0.0
	show()

	var tween := create_tween().set_parallel()
	tween.tween_property(_dim, "color:a", dim_alpha, 0.3)
	tween.tween_property(_slide, "position:y", 0.0, 0.4).from(_hidden_y()) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_time_bar, "scale:x", 1.0, duration)
	tween.chain().tween_callback(_allow_closing)

	_scroll_tween = create_tween().set_loops()
	_scroll_tween.tween_interval(scroll_interval)
	_scroll_tween.tween_callback(_scroll_to_next_post)


func close() -> void:
	_can_close = false
	_scroll_tween.kill()
	closed.emit()

	var tween := create_tween().set_parallel()
	tween.tween_property(_dim, "color:a", 0.0, 0.25)
	tween.tween_property(_slide, "position:y", _hidden_y(), 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(hide)


func _fill_feed() -> void:
	for post in _feed.get_children():
		post.free()
	_feed.position.y = _feed_start_y
	for i in post_count:
		_feed.add_child(post_scene.instantiate())


func _scroll_to_next_post() -> void:
	var first_post: Control = _feed.get_child(0)
	var step := first_post.size.y + _feed.get_theme_constant("separation")
	create_tween().tween_property(_feed, "position:y", _feed.position.y - step, 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _allow_closing() -> void:
	_can_close = true
	create_tween().tween_property(_hint, "modulate:a", 1.0, 0.3)


func _hidden_y() -> float:
	return get_viewport().get_visible_rect().size.y
