extends CanvasLayer
## HUD, Touch-Joystick, Werbe-Popups, Doomscroll-Feed und Ergebnis-Screen.
## Alle Elemente werden im Code erzeugt.

## Schwebender Joystick: irgendwo antippen = schieben, ziehen = lenken.
class Joystick extends Control:
	const RADIUS := 90.0
	var hud
	var active := false
	var origin := Vector2.ZERO
	var knob := Vector2.ZERO

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		var mm := event as InputEventMouseMotion
		if mb and mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				active = true
				origin = mb.position
				knob = origin
				hud.on_screen_press()
			else:
				active = false
			queue_redraw()
		elif mm and active:
			knob = origin + (mm.position - origin).limit_length(RADIUS)
			queue_redraw()

	## Halten allein schiebt schon nach vorne – so geht es ohne Erklärung.
	func vector() -> Vector2:
		if not active:
			return Vector2.ZERO
		var d := (knob - origin) / RADIUS
		return Vector2(d.x, clampf(-d.y + 0.6, -1.0, 1.0))

	func release() -> void:
		active = false
		queue_redraw()

	func _draw() -> void:
		if not active:
			return
		draw_circle(origin, RADIUS, Color(1, 1, 1, 0.10))
		draw_arc(origin, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
		draw_circle(knob, 36.0, Color(1, 1, 1, 0.45))


const AD_TEXTS := [
	["GLÜCKWUNSCH!", "Du bist der 1.000.000ste Besucher!"],
	["NUR HEUTE -70%", "Die Sneaker, die alle haben. Nur noch 2 Stück!"],
	["3 NEUE NACHRICHTEN", "Jemand hat über dich geschrieben ..."],
	["DEIN FOTO GEHT VIRAL", "1.284 Leute haben es schon gesehen."],
	["JETZT LIVE", "Du verpasst gerade alles!"],
	["UPDATE VERFÜGBAR", "Jetzt neu starten?"],
	["DU WURDEST MARKIERT", "Sieh dir an, was sie gepostet haben."],
	["GRATIS-GESCHENK", "Nur noch 00:59 einlösbar!"],
]
const AD_COLORS := ["ff3b6b", "ffb800", "7c4dff", "00a8ff", "ff6d00", "16c784"]
const NOISE_TEXTS := ["99+", "NEU!", "PING", "!!", "@du", "LIVE", "SALE", "+1", "HEY", "JETZT", "TRENDING", "OMG", "DM", "-50%"]
const FEED_USERS := ["@lena.xo", "@gamer_max", "@daily.memes", "@foodie", "@travelgram", "@news24", "@fitfam", "@catcontent", "@hype.kicks", "@lol.clips"]
const FEED_CAPTIONS := ["unglaublich, schau bis zum Ende", "das musst du sehen", "POV: du solltest eigentlich was anderes tun", "Teil 7 von 12", "niemand redet darüber ...", "ich kann nicht mehr", "Tag 143 von 365"]
const CARD_H := 300.0
const CARD_GAP := 12.0
const CARD_COUNT := 15
const DOOM_EXIT_TIME := 2.5

var game
var root: Control
var joy: Joystick
var noise_layer: Control
var popup_layer: Control
var hud_box: Control
var height_label: Label
var score_label: Label
var mult_label: Label
var focus_bar: ProgressBar
var focus_fill: StyleBoxFlat
var attract_box: Control
var attract_pulse: Label
var attract_best: Label
var doom: Control
var doom_feed: VBoxContainer
var doom_bar: ProgressBar
var doom_offset := 0.0
var doom_vel := 0.0
var doom_pressed := false
var doom_drag := 0.0
var doom_idle := 0.0
var results: Control
var results_title: Label
var results_lines: Label
var results_rank: Label
var results_hint: Label
var noise_items: Array = []
var overstim := 0.0
var time := 0.0


func _ready() -> void:
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	noise_layer = _full(Control.new())
	root.add_child(noise_layer)

	joy = Joystick.new()
	joy.hud = self
	joy.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(joy)
	joy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_build_hud()
	popup_layer = _full(Control.new())
	root.add_child(popup_layer)
	_build_attract()
	_build_results()
	_build_doom()


func _full(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


func _label(text: String, size: int, color := Color.WHITE, outline := 8) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	return l


func _flat(color: Color, radius := 18) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	return sb


func _centered(child: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	_full(cc)
	cc.add_child(child)
	return cc


# --- Aufbau ------------------------------------------------------------------

func _build_hud() -> void:
	hud_box = _full(Control.new())
	root.add_child(hud_box)
	height_label = _label("0 m", 46)
	height_label.position = Vector2(28, 14)
	hud_box.add_child(height_label)

	score_label = _label("0", 46)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_box.add_child(score_label)
	score_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	score_label.offset_left = -420
	score_label.offset_right = -28
	score_label.offset_top = 14

	mult_label = _label("x2", 36, Color("ffd54f"))
	mult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_box.add_child(mult_label)
	mult_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mult_label.offset_left = -420
	mult_label.offset_right = -28
	mult_label.offset_top = 70

	focus_bar = ProgressBar.new()
	focus_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_bar.show_percentage = false
	focus_bar.max_value = 100.0
	focus_bar.value = 100.0
	focus_bar.add_theme_stylebox_override("background", _flat(Color(0, 0, 0, 0.35), 10))
	focus_fill = _flat(Color("37d6ff"), 10)
	focus_bar.add_theme_stylebox_override("fill", focus_fill)
	hud_box.add_child(focus_bar)
	focus_bar.anchor_left = 0.5
	focus_bar.anchor_right = 0.5
	focus_bar.offset_left = -220
	focus_bar.offset_right = 220
	focus_bar.offset_top = 30
	focus_bar.offset_bottom = 52
	var fl := _label("FOKUS", 18, Color(1, 1, 1, 0.8), 4)
	fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_box.add_child(fl)
	fl.anchor_left = 0.5
	fl.anchor_right = 0.5
	fl.offset_left = -100
	fl.offset_right = 100
	fl.offset_top = 54


func _build_attract() -> void:
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 18)
	var title := _label("FOKUS", 130, Color.WHITE, 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := _label("Bring deine Aufmerksamkeit so weit nach oben wie möglich.", 30, Color.WHITE, 8)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	attract_pulse = _label("BILDSCHIRM BERÜHREN", 44, Color("ffd54f"), 10)
	attract_pulse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(attract_pulse)
	attract_best = _label("", 28, Color.WHITE, 6)
	attract_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(attract_best)
	attract_box = _centered(vb)
	root.add_child(attract_box)


func _build_results() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := _flat(Color(0.05, 0.06, 0.1, 0.9), 24)
	sb.set_content_margin_all(40)
	panel.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	results_title = _label("", 50, Color("ffd54f"), 0)
	results_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(results_title)
	results_lines = _label("", 26, Color.WHITE, 0)
	vb.add_child(results_lines)
	results_rank = _label("", 26, Color("9be7ff"), 0)
	vb.add_child(results_rank)
	results_hint = _label("Tippen für eine neue Runde", 30, Color("ffd54f"), 0)
	results_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(results_hint)
	results = _centered(panel)
	results.visible = false
	root.add_child(results)


func _build_doom() -> void:
	doom = Control.new()
	doom.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(doom)
	doom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	doom.gui_input.connect(_on_doom_input)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	doom.add_child(_full(bg))

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 14)
	var phone := Panel.new()
	phone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone.custom_minimum_size = Vector2(340, 560)
	phone.clip_contents = true
	var psb := _flat(Color("111318"), 32)
	psb.border_color = Color("3a3f4b")
	psb.set_border_width_all(6)
	phone.add_theme_stylebox_override("panel", psb)
	vb.add_child(phone)
	doom_feed = VBoxContainer.new()
	doom_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	doom_feed.add_theme_constant_override("separation", int(CARD_GAP))
	doom_feed.position = Vector2(12, 0)
	doom_feed.size = Vector2(316, 0)
	phone.add_child(doom_feed)
	var specs: Array = []
	for i in CARD_COUNT:
		specs.append([FEED_USERS.pick_random(), FEED_CAPTIONS.pick_random(), Color.from_hsv(randf(), 0.55, 0.85), randi_range(120, 98000)])
	for rep in 2:  # zweimal -> nahtlos endlos scrollbar
		for sp in specs:
			doom_feed.add_child(_feed_card(sp))

	doom_bar = ProgressBar.new()
	doom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	doom_bar.show_percentage = false
	doom_bar.custom_minimum_size = Vector2(340, 14)
	doom_bar.add_theme_stylebox_override("background", _flat(Color(1, 1, 1, 0.15), 7))
	doom_bar.add_theme_stylebox_override("fill", _flat(Color("37d6ff"), 7))
	vb.add_child(doom_bar)
	var hint := _label("Handy weglegen", 24, Color(1, 1, 1, 0.7), 0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)
	doom.add_child(_centered(vb))
	doom.visible = false


func _feed_card(sp: Array) -> Control:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(316, CARD_H)
	var sb := _flat(Color("1d2027"), 16)
	sb.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vb)
	vb.add_child(_label("%s  ·  vor %d Min" % [sp[0], randi_range(1, 59)], 18, Color(1, 1, 1, 0.85), 0))
	var img := ColorRect.new()
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.color = sp[2]
	img.custom_minimum_size = Vector2(0, 190)
	vb.add_child(img)
	vb.add_child(_label(sp[1], 18, Color.WHITE, 0))
	vb.add_child(_label("%d Likes" % sp[3], 16, Color(1, 1, 1, 0.6), 0))
	return card


# --- API für main.gd -----------------------------------------------------------

func joy_vector() -> Vector2:
	return joy.vector()


func on_screen_press() -> void:
	game.on_screen_press()


func set_mode(mode: String, info: int) -> void:
	attract_box.visible = mode == "attract"
	hud_box.visible = mode == "run"
	results.visible = false
	if mode == "attract":
		attract_best.text = ("Bester Punktestand heute: %d" % info) if info > 0 else ""
	if mode == "run":
		update_hud(0, 0, 1, 100.0)


func update_hud(h: int, pts: int, mult: int, att: float) -> void:
	height_label.text = "%d m" % h
	score_label.text = str(pts)
	mult_label.text = "FOKUS x%d" % mult
	mult_label.visible = mult > 1
	focus_bar.value = att
	focus_fill.bg_color = Color("ff4d4d").lerp(Color("37d6ff"), att / 100.0)


func set_overstim(v: float) -> void:
	overstim = v


func popup_count() -> int:
	var n := 0
	for c in popup_layer.get_children():
		if not c.is_queued_for_deletion():
			n += 1
	return n


func clear_popups() -> void:
	for c in popup_layer.get_children():
		c.queue_free()


func show_doom(on: bool) -> void:
	doom.visible = on
	joy.release()
	doom_idle = 0.0
	doom_pressed = false
	doom_vel = 0.0


func show_results(title: String, lines: Array, rank: int, top: Array) -> void:
	hud_box.visible = false
	results.visible = true
	results_title.text = title
	results_lines.text = "\n".join(PackedStringArray(lines))
	var top_txt := "Platz %d heute" % rank
	var n := mini(5, top.size())
	if n > 0:
		top_txt += "      Top heute: "
		var parts: PackedStringArray = []
		for i in n:
			parts.append(str(int(top[i]["score"])))
		top_txt += "  ·  ".join(parts)
	results_rank.text = top_txt


# --- Werbung -----------------------------------------------------------------

func spawn_popup() -> void:
	var vp := root.get_viewport_rect().size
	var w := clampf(vp.x * 0.42, 320.0, 560.0)
	var h := w * 0.6
	var ad: Array = AD_TEXTS.pick_random()
	var col := Color(AD_COLORS.pick_random() as String)

	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.size = Vector2(w, h)
	panel.position = Vector2(randf_range(20.0, vp.x - w - 20.0), randf_range(90.0, maxf(vp.y - h - 20.0, 91.0)))
	var sb := _flat(col, 20)
	sb.border_color = Color.WHITE
	sb.set_border_width_all(5)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 18
	panel.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.position = Vector2(24, 36)
	vb.size = Vector2(w - 48, h - 56)
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var tl := _label(ad[0], 34, Color.WHITE, 6)
	vb.add_child(tl)
	var bl := _label(ad[1], 22, Color.WHITE, 4)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(bl)
	var cta := Button.new()
	cta.text = "JETZT ANSEHEN"
	cta.custom_minimum_size = Vector2(0, 62)
	cta.add_theme_font_size_override("font_size", 28)
	cta.add_theme_color_override("font_color", col.darkened(0.3))
	cta.add_theme_color_override("font_hover_color", col.darkened(0.3))
	cta.add_theme_color_override("font_pressed_color", col.darkened(0.5))
	for st in ["normal", "hover", "pressed", "focus"]:
		cta.add_theme_stylebox_override(st, _flat(Color.WHITE, 14))
	vb.add_child(cta)

	# winziges, kontrastarmes X – das springt manchmal weg (Dark Pattern)
	var xb := Button.new()
	xb.text = "x"
	xb.flat = true
	xb.size = Vector2(26, 26)
	xb.position = Vector2(w - 32, 6)
	xb.add_theme_font_size_override("font_size", 15)
	xb.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	panel.add_child(xb)

	var info := {"jumped": false}
	cta.pressed.connect(func(): _ad_tapped(panel))
	panel.gui_input.connect(func(ev: InputEvent):
		var mb := ev as InputEventMouseButton
		if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_ad_tapped(panel))
	xb.pressed.connect(func():
		if not info["jumped"] and randf() < 0.5:
			info["jumped"] = true
			xb.position = Vector2(6, h - 32)
			game.touch()
		else:
			game.on_ad_closed()
			panel.queue_free())

	popup_layer.add_child(panel)
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.7, 0.7)
	create_tween().tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _ad_tapped(panel: Panel) -> void:
	if panel.is_queued_for_deletion():
		return
	game.on_ad_tap()
	panel.queue_free()


# --- Doomscroll ------------------------------------------------------------------

func _on_doom_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	var mm := event as InputEventMouseMotion
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		doom_pressed = mb.pressed
		doom_idle = 0.0
		if mb.pressed:
			doom_drag = 0.0
		elif absf(doom_drag) > 50.0:
			game.on_swipe()
	elif mm and doom_pressed:
		doom_offset -= mm.relative.y
		doom_drag += mm.relative.y
		doom_vel = -mm.relative.y * 40.0
		doom_idle = 0.0


func _process(delta: float) -> void:
	time += delta
	attract_pulse.modulate.a = 0.55 + 0.45 * sin(time * 3.0)
	results_hint.modulate.a = 0.55 + 0.45 * sin(time * 3.0)

	if doom.visible:
		if not doom_pressed:
			doom_offset += doom_vel * delta
			doom_vel = lerpf(doom_vel, 0.0, clampf(delta * 3.0, 0.0, 1.0))
			doom_idle += delta
		doom_bar.value = doom_idle / DOOM_EXIT_TIME * 100.0
		doom_feed.position.y = -fposmod(doom_offset, CARD_COUNT * (CARD_H + CARD_GAP))
		if doom_idle >= DOOM_EXIT_TIME:
			game.end_doomscroll()

	_update_noise(delta)


## Reizüberflutung: herumfliegende Schnipsel. Sanft ein-/ausgeblendet, kein Flackern.
func _update_noise(delta: float) -> void:
	var vp := root.get_viewport_rect().size
	var target := int(overstim * 16.0)
	if noise_items.size() < target and randf() < 0.15:
		var l := _label(NOISE_TEXTS.pick_random(), randi_range(22, 54), Color.from_hsv(randf(), 0.7, 1.0), 6)
		l.position = Vector2(randf() * vp.x, randf() * vp.y)
		l.rotation = randf_range(-0.3, 0.3)
		l.modulate.a = 0.0
		noise_layer.add_child(l)
		noise_items.append({"label": l, "vel": Vector2.from_angle(randf() * TAU) * randf_range(40.0, 140.0), "age": 0.0, "life": randf_range(3.0, 5.0)})
	var keep: Array = []
	for it in noise_items:
		var l: Label = it["label"]
		it["age"] += delta
		var age: float = it["age"]
		var life: float = it["life"]
		l.position += it["vel"] * delta
		l.modulate.a = clampf(minf(age, life - age), 0.0, 1.0) * 0.85
		if age >= life:
			l.queue_free()
		else:
			keep.append(it)
	noise_items = keep
