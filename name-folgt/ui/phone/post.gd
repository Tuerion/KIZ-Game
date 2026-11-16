extends PanelContainer

@export var saturation := 0.3
@export var brightness := 0.55

@onready var _avatar: Panel = $Content/Header/Avatar
@onready var _image: Panel = $Content/Image


func _ready() -> void:
	_tint(_avatar, randf())
	_tint(_image, randf())


func _tint(panel: Panel, hue: float) -> void:
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
	style.bg_color = Color.from_hsv(hue, saturation, brightness)
