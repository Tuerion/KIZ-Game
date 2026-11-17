extends PanelContainer

@export var saturation := 0.3
@export var brightness := 0.55


func _ready() -> void:
	_tint($Content/Header/Avatar)
	_tint($Content/Image)


func _tint(panel: Panel) -> void:
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
	style.bg_color = Color.from_hsv(randf(), saturation, brightness)
