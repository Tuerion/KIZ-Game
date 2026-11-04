extends Node3D
## Arcade-Prototyp: Aufmerksamkeits-Ball endlos den Berg hinaufrollen.
## Die Welt wird komplett im Code aufgebaut, damit keine Szenen/Assets nötig sind.

# --- Tuning -----------------------------------------------------------------
const SLOPE_DEG := 12.0          # Steigung des Berges
const HALF_WIDTH := 6.5          # halbe Wegbreite
const SEG_LEN := 40.0            # Länge eines Bodensegments
const BALL_R := 0.9
const PLATEAU_EVERY := 200.0     # alle X m entlang des Hangs ein Ruhe-Plateau
const PLATEAU_LEN := 40.0
const PUSH_FORCE := 7.5
const GRAVITY_SLOPE := 2.0       # Ball rollt zurück, wenn man nicht schiebt (Sisyphus)
const GRAVITY_PLATEAU := 0.5
const STEER_SPEED := 5.0
const HIT_DAMAGE := 12.0
const AD_TAP_DAMAGE := 10.0
const IDLE_TIMEOUT := 8.0        # ohne Eingabe -> Charakter greift zum Handy -> Reset
const MAX_RUN_TIME := 360.0      # Notfall-Limit, damit keine Schlange entsteht
const DIFFICULTY_DIST := 600.0   # nach so vielen Metern Hang ist Schwierigkeit 1.0
const SCORE_FILE := "user://scores.cfg"

const HUD_SCRIPT := preload("res://ui/hud/hud.gd")
const NOTIF_TEXTS := ["99+", "NEU", "LIKE", "@du", "PING", "LIVE", "SALE", "+1", "DM", "!!", "OMG"]
const NOTIF_COLORS := ["ff3b6b", "ffb800", "7c4dff", "00a8ff", "ff6d00", "2ecc71"]

enum State { ATTRACT, RUN, FALLING, RESULTS }

var slope := deg_to_rad(SLOPE_DEG)
var fwd := Vector3.ZERO   # Richtung hangaufwärts
var nrm := Vector3.ZERO   # Normale des Hangs

var state := State.ATTRACT
var hud
var cam: Camera3D
var env: Environment
var ball: Node3D
var ball_mesh: MeshInstance3D
var ball_mat: StandardMaterial3D
var player: Node3D
var player_body: Node3D
var player_head: MeshInstance3D
var phone: MeshInstance3D

# Spielzustand
var s := 0.0          # Position des Balls entlang des Hangs
var x := 0.0          # seitliche Position
var vs := 0.0
var vx := 0.0
var attention := 100.0
var score := 0.0
var streak := 0.0
var t := 0.0
var run_start := 0.0
var smooth_input := Vector2.ZERO
var last_input_time := 0.0
var distract_timer := 0.0
var doomscroll := false
var doom_cooldown := 0.0
var popup_timer := 9.0
var state_time := 0.0
var shake := 0.0
var player_s := 0.0
var player_x := 0.0
var end_reason := ""

var segments := {}
var obstacles: Array = []
var stuck: Array = []
var walls: Array = []
var decor: Array = []
var generated_until := 0.0
var stats := {}
var mats := {}


func _ready() -> void:
	randomize()
	fwd = Vector3(0.0, sin(slope), -cos(slope))
	nrm = Vector3(0.0, cos(slope), sin(slope))
	_build_environment()
	_build_ball()
	_build_player()
	cam = Camera3D.new()
	cam.fov = 62.0
	add_child(cam)
	hud = HUD_SCRIPT.new()
	hud.game = self
	add_child(hud)
	_enter_attract()


# --- Aufbau ------------------------------------------------------------------

func _mat(hex: String, emission := 0.0) -> StandardMaterial3D:
	var key := hex + str(emission)
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = 0.85
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = Color(hex)
		m.emission_energy_multiplier = emission
	mats[key] = m
	return m


func _box(size: Vector3, hex: String, pos := Vector3.ZERO, emission := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(hex, emission)
	mi.position = pos
	return mi


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("4f8fd6")
	sm.sky_horizon_color = Color("dfe8f2")
	sm.ground_horizon_color = Color("dfe8f2")
	sm.ground_bottom_color = Color("8c97a3")
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("dfe8f2")
	env.fog_density = 0.006
	env.adjustment_enabled = true
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.shadow_enabled = true
	sun.light_energy = 1.1
	add_child(sun)


func _build_ball() -> void:
	ball = Node3D.new()
	add_child(ball)
	ball_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = BALL_R
	sm.height = BALL_R * 2.0
	ball_mesh.mesh = sm
	ball_mat = StandardMaterial3D.new()
	ball_mat.emission_enabled = true
	ball_mat.roughness = 0.35
	ball_mesh.material_override = ball_mat
	ball.add_child(ball_mesh)
	# zwei Ringe, damit man das Rollen sieht
	for rot in [Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5)]:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = BALL_R * 0.97
		tm.outer_radius = BALL_R * 1.05
		ring.mesh = tm
		ring.rotation = rot
		ring.material_override = _mat("ffffff", 0.4)
		ball_mesh.add_child(ring)


func _build_player() -> void:
	player = Node3D.new()
	add_child(player)
	player_body = Node3D.new()
	player.add_child(player_body)
	var cloth := "e8505b"
	player_body.add_child(_box(Vector3(0.18, 0.8, 0.18), "2d3142", Vector3(-0.14, 0.4, 0.0)))
	player_body.add_child(_box(Vector3(0.18, 0.8, 0.18), "2d3142", Vector3(0.14, 0.4, 0.0)))
	var torso := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.3
	cm.height = 0.95
	torso.mesh = cm
	torso.position = Vector3(0.0, 1.2, 0.0)
	torso.material_override = _mat(cloth)
	player_body.add_child(torso)
	player_head = MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.24
	hm.height = 0.48
	player_head.mesh = hm
	player_head.position = Vector3(0.0, 1.9, 0.0)
	player_head.material_override = _mat("f1c27d")
	player_body.add_child(player_head)
	player_body.add_child(_box(Vector3(0.13, 0.13, 0.75), cloth, Vector3(-0.32, 1.4, -0.35)))
	player_body.add_child(_box(Vector3(0.13, 0.13, 0.75), cloth, Vector3(0.32, 1.4, -0.35)))
	phone = _box(Vector3(0.2, 0.32, 0.04), "6ec6ff", Vector3(0.0, 1.6, -0.5), 2.5)
	phone.rotation.x = 0.6
	player_body.add_child(phone)


func _slope_point(p: float, lat: float, up := 0.0) -> Vector3:
	return fwd * p + Vector3.RIGHT * lat + nrm * up


func _in_plateau(p: float) -> bool:
	return p > 100.0 and fposmod(p, PLATEAU_EVERY) >= PLATEAU_EVERY - PLATEAU_LEN


func _difficulty_at(p: float) -> float:
	return p / DIFFICULTY_DIST


func _make_segment(k: int) -> Node3D:
	var s0 := k * SEG_LEN
	var seg := Node3D.new()
	seg.transform = Transform3D(Basis(Vector3.RIGHT, slope), fwd * (s0 + SEG_LEN * 0.5))
	var plateau := _in_plateau(s0 + 1.0)
	var ground_col := "9ccc65" if plateau else "c9ced6"
	seg.add_child(_box(Vector3(HALF_WIDTH * 2.0 + 0.4, 1.0, SEG_LEN + 0.05), ground_col, Vector3(0.0, -0.5, 0.0)))
	for side in [-1.0, 1.0]:
		seg.add_child(_box(Vector3(0.6, 0.6, SEG_LEN + 0.05), "5c6b7a", Vector3(side * (HALF_WIDTH + 0.5), 0.3, 0.0)))
		seg.add_child(_box(Vector3(40.0, 1.0, SEG_LEN + 0.05), "7d8a96" if not plateau else "6fa255", Vector3(side * (HALF_WIDTH + 20.8), 1.2, 0.0)))
	# Querstreifen für Geschwindigkeitsgefühl
	for i in 4:
		var z := -SEG_LEN * 0.5 + i * 10.0 + 5.0
		seg.add_child(_box(Vector3(HALF_WIDTH * 2.0, 0.02, 0.25), "b3bac4" if not plateau else "8bbf5a", Vector3(0.0, 0.01, z)))
	if plateau:
		for i in 6:
			var tree := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.0
			cyl.bottom_radius = 0.9
			cyl.height = 2.6
			tree.mesh = cyl
			tree.material_override = _mat("2e7d32")
			var side := -1.0 if i % 2 == 0 else 1.0
			tree.position = Vector3(side * (HALF_WIDTH + 2.5 + randf() * 3.0), 3.0, randf_range(-SEG_LEN * 0.45, SEG_LEN * 0.45))
			seg.add_child(tree)
	add_child(seg)
	return seg


func _update_segments() -> void:
	var first := int(floor((minf(s, player_s) - 60.0) / SEG_LEN))
	var last := int(floor((s + 180.0) / SEG_LEN))
	for k in segments.keys():
		if k < first or k > last:
			segments[k].queue_free()
			segments.erase(k)
	for k in range(first, last + 1):
		if not segments.has(k):
			segments[k] = _make_segment(k)


# --- Hindernisse ---------------------------------------------------------------

func _generate_until(limit: float) -> void:
	while generated_until < limit:
		var cs := generated_until
		generated_until += 20.0
		if cs < 40.0 or _in_plateau(cs) or _in_plateau(cs + 20.0):
			continue
		var d := _difficulty_at(cs)
		if cs > 120.0 and randf() < 0.3:
			_spawn_wall(cs + 10.0)
		else:
			var n := 1 + int(d * 3.0) + randi() % 2
			for i in n:
				_spawn_notif(cs + randf() * 20.0, randf_range(-HALF_WIDTH + 0.8, HALF_WIDTH - 0.8), d, true, false)


func _spawn_notif(p: float, lat: float, d: float, can_move: bool, hidden: bool) -> void:
	var node := Node3D.new()
	var col: String = NOTIF_COLORS.pick_random()
	node.add_child(_box(Vector3(1.4, 0.9, 0.25), col, Vector3.ZERO, 0.6))
	var lbl := Label3D.new()
	lbl.text = NOTIF_TEXTS.pick_random()
	lbl.font_size = 72
	lbl.pixel_size = 0.008
	lbl.outline_size = 0
	lbl.position = Vector3(0.0, 0.0, 0.14)
	node.add_child(lbl)
	node.visible = not hidden
	add_child(node)
	var o := {"node": node, "s": p, "x": lat, "vx": 0.0, "bob": randf() * TAU, "hidden": hidden}
	if can_move and randf() < d * 0.5:
		o["vx"] = randf_range(1.0, 2.5) * (1.0 if randf() < 0.5 else -1.0)
	node.position = _slope_point(p, lat) + Vector3.UP * 1.0
	obstacles.append(o)


## Wand aus Benachrichtigungen, die erst kurz vorher auftaucht.
## Ein Wegweiser davor verrät die Lücke -> Lesen wird belohnt.
func _spawn_wall(p: float) -> void:
	var left := randf() < 0.5
	var gap_w := 3.2
	var gap_x := (-HALF_WIDTH + 2.0) if left else (HALF_WIDTH - 2.0)
	var lx := -HALF_WIDTH + 0.7
	while lx <= HALF_WIDTH - 0.7:
		if absf(lx - gap_x) > gap_w * 0.5:
			_spawn_notif(p, lx, 0.0, false, true)
		lx += 1.5
	walls.append({"s": p, "gap_x": gap_x, "gap_w": gap_w, "done": false})

	var board := Node3D.new()
	board.position = _slope_point(p - 26.0, 0.0)
	for side in [-2.2, 2.2]:
		board.add_child(_box(Vector3(0.15, 3.8, 0.15), "5d4037", Vector3(side, 1.9, 0.0)))
	board.add_child(_box(Vector3(4.8, 1.1, 0.12), "fff8e1", Vector3(0.0, 3.4, 0.0)))
	var lbl := Label3D.new()
	var texts_left := ["GLEICH KOMMT EINE WAND - LÜCKE LINKS", "ACHTUNG: NUR LINKS IST FREI", "LINKS VORBEI, RECHTS ZU"]
	var texts_right := ["GLEICH KOMMT EINE WAND - LÜCKE RECHTS", "ACHTUNG: NUR RECHTS IST FREI", "RECHTS VORBEI, LINKS ZU"]
	lbl.text = texts_left.pick_random() if left else texts_right.pick_random()
	lbl.font_size = 64
	lbl.pixel_size = 0.0065
	lbl.modulate = Color("212121")
	lbl.outline_size = 0
	lbl.width = 680.0
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.position = Vector3(0.0, 3.4, 0.07)
	board.add_child(lbl)
	add_child(board)
	decor.append({"node": board, "s": p - 26.0})


func _update_obstacles(delta: float) -> void:
	var sc := _ball_scale()
	var keep: Array = []
	for o in obstacles:
		var node: Node3D = o["node"]
		if o["s"] < s - 15.0 and state != State.FALLING:
			node.queue_free()
			continue
		if o["hidden"] and s > o["s"] - 9.0:
			o["hidden"] = false
			node.visible = true
			node.scale = Vector3.ONE * 0.1
			create_tween().tween_property(node, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if o["vx"] != 0.0:
			o["x"] += o["vx"] * delta
			if absf(o["x"]) > HALF_WIDTH - 0.7:
				o["vx"] = -o["vx"]
				o["x"] = clampf(o["x"], -HALF_WIDTH + 0.7, HALF_WIDTH - 0.7)
		o["bob"] += delta * 2.0
		node.position = _slope_point(o["s"], o["x"]) + Vector3.UP * (1.0 + sin(o["bob"]) * 0.15)
		if state == State.RUN and not o["hidden"]:
			if Vector2(x - o["x"], s - o["s"]).length() < BALL_R * sc + 0.55:
				_on_hit(o)
				continue
		keep.append(o)
	obstacles = keep
	var keep_decor: Array = []
	for dd in decor:
		if dd["s"] < s - 30.0 and state != State.FALLING:
			dd["node"].queue_free()
		else:
			keep_decor.append(dd)
	decor = keep_decor


func _on_hit(o: Dictionary) -> void:
	attention -= HIT_DAMAGE
	stats["hits"] += 1
	_break_streak()
	vs = minf(vs, 0.0) - 2.5
	shake = 0.35
	# Benachrichtigung bleibt am Ball kleben und macht ihn schwerer
	var node: Node3D = o["node"]
	node.reparent(ball_mesh, false)
	node.position = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * BALL_R * 0.95
	node.rotation = Vector3(randf() * TAU, randf() * TAU, 0.0)
	node.scale = Vector3.ONE * 0.55
	stuck.append({"node": node, "t": 7.0})


func _update_stuck(delta: float) -> void:
	var keep: Array = []
	for st in stuck:
		st["t"] -= delta
		if st["t"] <= 0.0:
			st["node"].queue_free()
		else:
			keep.append(st)
	stuck = keep


# --- Zustände ----------------------------------------------------------------

func _reset_world() -> void:
	for o in obstacles:
		o["node"].queue_free()
	for st in stuck:
		st["node"].queue_free()
	for dd in decor:
		dd["node"].queue_free()
	obstacles.clear()
	stuck.clear()
	decor.clear()
	walls.clear()
	generated_until = 0.0
	s = 0.0
	x = 0.0
	vs = 0.0
	vx = 0.0
	player_s = 0.0
	attention = 100.0
	score = 0.0
	streak = 0.0
	doomscroll = false
	distract_timer = 0.0
	doom_cooldown = 0.0
	smooth_input = Vector2.ZERO
	stats = {
		"hits": 0, "ad_taps": 0, "ads_shown": 0, "ads_closed": 0,
		"popup_time": 0.0, "scroll_time": 0.0, "swipes": 0, "doomscrolls": 0,
		"distractions": 0, "signs_total": 0, "signs_followed": 0,
		"longest_streak": 0.0, "max_height": 0.0, "run_time": 0.0,
	}


func _enter_attract() -> void:
	_reset_world()
	state = State.ATTRACT
	state_time = 0.0
	hud.set_mode("attract", _best_today())


func _start_run() -> void:
	if state != State.ATTRACT:
		_reset_world()
	state = State.RUN
	state_time = 0.0
	run_start = t
	last_input_time = t
	popup_timer = 9.0
	hud.set_mode("run", 0)


func _game_over(reason: String) -> void:
	end_reason = reason
	stats["run_time"] = t - run_start
	state = State.FALLING
	state_time = 0.0
	doomscroll = false
	hud.show_doom(false)
	hud.clear_popups()
	hud.set_mode("falling", 0)
	player_s = s - (BALL_R * _ball_scale() + 0.75)
	player_x = x


func _show_results() -> void:
	state = State.RESULTS
	state_time = 0.0
	var h := int(stats["max_height"])
	var pts := int(score)
	var rank := _save_score(pts, h)
	var titles := {
		"focus": "AUFMERKSAMKEIT AUFGEBRAUCHT",
		"idle": "DU HAST LOSGELASSEN",
		"time": "ZEIT VORBEI",
	}
	var rt: float = stats["run_time"]
	var lines: Array = []
	lines.append("Höhe: %d m      Punkte: %d" % [h, pts])
	lines.append("Spielzeit: %d:%02d" % [int(rt) / 60, int(rt) % 60])
	lines.append("")
	lines.append("Von Benachrichtigungen getroffen: %d" % stats["hits"])
	lines.append("Werbung angetippt: %d von %d" % [stats["ad_taps"], stats["ads_shown"]])
	lines.append("Werbung offen gelassen: %d s" % int(stats["popup_time"]))
	lines.append("Gescrollt: %d s  (%d Swipes)" % [int(stats["scroll_time"]), stats["swipes"]])
	lines.append("Kurz aufs Handy geschaut: %d-mal" % stats["distractions"])
	lines.append("Längster Fokus am Stück: %d s" % int(stats["longest_streak"]))
	if stats["signs_total"] > 0:
		lines.append("Wegweiser gelesen und befolgt: %d von %d" % [stats["signs_followed"], stats["signs_total"]])
	hud.show_results(titles.get(end_reason, "ENDE"), lines, rank, _today_scores())


func _break_streak() -> void:
	streak = 0.0


# --- Callbacks vom HUD -------------------------------------------------------

func on_screen_press() -> void:
	last_input_time = t
	if state == State.ATTRACT:
		_start_run()
	elif state == State.RESULTS and state_time > 2.5:
		_start_run()


func touch() -> void:
	last_input_time = t


func on_ad_tap() -> void:
	if state != State.RUN:
		return
	touch()
	attention -= AD_TAP_DAMAGE
	stats["ad_taps"] += 1
	shake = 0.25
	_break_streak()


func on_ad_closed() -> void:
	touch()
	stats["ads_closed"] += 1


func on_swipe() -> void:
	if state != State.RUN:
		return
	stats["swipes"] += 1
	attention = maxf(attention - 1.0, 0.0)


func end_doomscroll() -> void:
	doomscroll = false
	doom_cooldown = 14.0
	last_input_time = t
	hud.show_doom(false)


func _start_doomscroll() -> void:
	doomscroll = true
	stats["doomscrolls"] += 1
	_break_streak()
	hud.show_doom(true)


func _unhandled_input(event: InputEvent) -> void:
	# Tastatur/Controller zum Testen
	var kb := event as InputEventKey
	var jb := event as InputEventJoypadButton
	if (kb and kb.pressed and not kb.echo) or (jb and jb.pressed):
		on_screen_press()


# --- Loop ----------------------------------------------------------------------

func _read_input() -> Vector2:
	var v: Vector2 = hud.joy_vector()
	var k := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		k.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		k.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		k.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		k.y -= 1.0
	var g := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), -Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if g.length() < 0.2:
		g = Vector2.ZERO
	return (v + k + g).limit_length(1.0)


func _process(delta: float) -> void:
	t += delta
	state_time += delta
	match state:
		State.ATTRACT:
			_process_attract(delta)
		State.RUN:
			_process_run(delta)
		State.FALLING:
			_process_falling(delta)
		State.RESULTS:
			if state_time > 20.0:
				_enter_attract()
	_generate_until(s + 140.0)
	_update_segments()
	_update_obstacles(delta)
	_update_stuck(delta)
	_update_visuals(delta)


func _process_attract(_delta: float) -> void:
	vs = 0.0


func _process_run(delta: float) -> void:
	var inp := _read_input()
	if inp.length() > 0.05:
		last_input_time = t
	var att01 := attention / 100.0
	var lack := 1.0 - att01
	# wenig Aufmerksamkeit -> träge, ungenaue Steuerung
	smooth_input = smooth_input.lerp(inp, clampf(delta * lerpf(14.0, 2.0, lack), 0.0, 1.0))

	distract_timer -= delta
	doom_cooldown -= delta
	if not doomscroll:
		if distract_timer <= 0.0 and attention < 55.0 and randf() < delta * (0.55 - att01) * 0.6:
			distract_timer = 1.6
			stats["distractions"] += 1
			_break_streak()
		if attention < 30.0 and doom_cooldown <= 0.0 and randf() < delta * 0.3:
			_start_doomscroll()

	var pushing := not doomscroll and distract_timer <= 0.0
	var weight := 1.0 + 0.22 * stuck.size()
	var plateau := _in_plateau(s)
	var grav := GRAVITY_PLATEAU if plateau else GRAVITY_SLOPE
	var push := smooth_input.y if pushing else 0.0
	vs += (push * PUSH_FORCE / weight - grav - vs * 0.8) * delta
	s += vs * delta
	if s < 0.0:
		s = 0.0
		vs = maxf(vs, 0.0)
	var wob := (sin(t * 2.3) * 0.6 + sin(t * 5.7 + 1.3) * 0.4) * lack * lack * 1.6
	var steer := smooth_input.x if pushing else 0.0
	vx = (steer * STEER_SPEED + wob * 2.5) / sqrt(weight)
	x = clampf(x + vx * delta, -HALF_WIDTH + BALL_R, HALF_WIDTH - BALL_R)

	# Fokus-Streak & Punkte
	if pushing:
		streak += delta
	stats["longest_streak"] = maxf(stats["longest_streak"], streak)
	var mult := _multiplier()
	if vs > 0.0:
		score += vs * delta * 10.0 * mult
	stats["max_height"] = maxf(stats["max_height"], s * sin(slope))

	# Aufmerksamkeit
	var popups: int = hud.popup_count()
	var drain := 0.35 + _difficulty_at(s) * 1.4 + popups * 1.3
	if doomscroll:
		drain += 1.0
	var regen := 0.0
	if not doomscroll and popups == 0 and streak > 3.0:
		regen = 2.2
	if plateau:
		regen += 7.0
	attention = clampf(attention + (regen - drain) * delta, 0.0, 100.0)

	# Werbung / Popups
	popup_timer -= delta
	if popup_timer <= 0.0 and not doomscroll:
		if popups < 3:
			hud.spawn_popup()
			stats["ads_shown"] += 1
		popup_timer = lerpf(13.0, 4.0, clampf(_difficulty_at(s), 0.0, 1.0)) * randf_range(0.7, 1.3)
	if popups > 0:
		stats["popup_time"] += delta
	if doomscroll:
		stats["scroll_time"] += delta

	# Wegweiser ausgewertet?
	for w in walls:
		if not w["done"] and s > w["s"]:
			w["done"] = true
			stats["signs_total"] += 1
			if absf(x - w["gap_x"]) < w["gap_w"] * 0.5 + 0.3:
				stats["signs_followed"] += 1

	hud.update_hud(int(s * sin(slope)), int(score), mult, attention)

	if attention <= 0.0:
		_game_over("focus")
	elif not doomscroll and t - last_input_time > IDLE_TIMEOUT:
		_game_over("idle")
	elif t - run_start > MAX_RUN_TIME:
		_game_over("time")


func _process_falling(delta: float) -> void:
	vs = lerpf(vs, -14.0, clampf(delta * 1.5, 0.0, 1.0))
	s = maxf(s + vs * delta, 0.0)
	var target_x := player_x + (1.6 if player_x <= 0.0 else -1.6)
	x = lerpf(x, target_x, clampf(delta * 3.0, 0.0, 1.0))
	if state_time > 3.0:
		_show_results()


func _multiplier() -> int:
	return 1 + mini(4, int(streak / 8.0))


func _ball_scale() -> float:
	return lerpf(0.6, 1.0, attention / 100.0)


func _update_visuals(delta: float) -> void:
	var att01 := attention / 100.0
	var lack := 1.0 - att01
	var overstim := clampf((60.0 - attention) / 60.0, 0.0, 1.0)
	if state != State.RUN:
		overstim = 0.0
	var sc := _ball_scale()

	# Ball
	ball.position = _slope_point(s, x, BALL_R * sc)
	ball.scale = Vector3.ONE * sc
	ball_mesh.rotate(Vector3.RIGHT, -vs * delta / (BALL_R * sc))
	ball_mesh.rotate(Vector3.BACK, -vx * delta / (BALL_R * sc))
	ball_mesh.position = Vector3(sin(t * 7.0), sin(t * 9.0) * 0.5, 0.0) * 0.06 * lack
	var col := Color("37d6ff").lerp(Color("6b625a"), lack)
	ball_mat.albedo_color = col
	ball_mat.emission = col
	ball_mat.emission_energy_multiplier = att01 * 0.9

	# Charakter
	var holding_phone := state == State.ATTRACT or state == State.FALLING or state == State.RESULTS \
		or doomscroll or distract_timer > 0.0
	var ps := s - (BALL_R * sc + 0.75)
	var px := x
	if state == State.FALLING or state == State.RESULTS:
		ps = player_s
		px = player_x
	player.position = _slope_point(ps, px)
	var lean := 0.0 if holding_phone else -0.45
	player_body.rotation.x = lerpf(player_body.rotation.x, lean, clampf(delta * 6.0, 0.0, 1.0))
	player_head.rotation.x = lerpf(player_head.rotation.x, -0.6 if holding_phone else 0.0, clampf(delta * 6.0, 0.0, 1.0))
	phone.visible = holding_phone

	# Kamera
	shake = maxf(shake - delta, 0.0)
	var shake_off := Vector3(sin(t * 37.0), cos(t * 41.0), 0.0) * (shake * 0.4 + overstim * 0.04)
	var focus := ball.position
	if state == State.FALLING or state == State.RESULTS:
		focus = _slope_point(player_s, player_x, 1.0)
	var desired: Vector3
	if state == State.ATTRACT:
		var ang := t * 0.25
		desired = focus + Vector3(sin(ang) * 9.0, 4.5, cos(ang) * 9.0)
		cam.position = cam.position.lerp(desired, clampf(delta * 2.0, 0.0, 1.0))
		cam.look_at(focus + Vector3.UP * 0.8)
	else:
		desired = focus - fwd * 8.5 + Vector3.UP * 4.2 + shake_off
		cam.position = cam.position.lerp(desired, clampf(delta * 4.0, 0.0, 1.0))
		cam.look_at(focus + fwd * 5.0 + Vector3.UP * 0.6)

	# Reizüberflutung: Sättigung hoch, Unruhe im HUD (kein Blitzen!)
	env.adjustment_saturation = lerpf(0.9, 1.8, overstim)
	env.adjustment_contrast = lerpf(1.0, 1.15, overstim)
	hud.set_overstim(overstim)


# --- Highscores ----------------------------------------------------------------

func _today_key() -> String:
	return Time.get_date_string_from_system()


func _today_scores() -> Array:
	var cfg := ConfigFile.new()
	cfg.load(SCORE_FILE)
	return cfg.get_value("days", _today_key(), [])


func _best_today() -> int:
	var list := _today_scores()
	return int(list[0]["score"]) if list.size() > 0 else 0


func _save_score(pts: int, h: int) -> int:
	var cfg := ConfigFile.new()
	cfg.load(SCORE_FILE)
	var list: Array = cfg.get_value("days", _today_key(), [])
	var rank := 1
	for e in list:
		if int(e["score"]) > pts:
			rank += 1
	list.append({"score": pts, "height": h})
	list.sort_custom(func(a, b): return a["score"] > b["score"])
	if list.size() > 50:
		list.resize(50)
	cfg.set_value("days", _today_key(), list)
	cfg.save(SCORE_FILE)
	return rank
