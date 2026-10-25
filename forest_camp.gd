@tool
extends Node3D
## ฉาก "ค่ายพักแรมกลางป่ายามเย็น" + ตัวละคร 3 ตัว ท่าทางไม่ซ้ำกัน
## วิธีใช้: สร้างฉากใหม่ (Node3D) -> แนบสคริปต์นี้ -> ใส่ค่าใน Inspector -> กด F6

## ลากไฟล์ตัวละคร (.glb / .fbx ที่ import ด้วย Mixamo BoneMap แล้ว) มาใส่ตรงนี้
## ถ้าเว้นว่าง จะใช้ตัวละครชิบิ (มีแขนขา) ที่สคริปต์สร้างให้ พร้อมท่า โบกมือ / ฟันดาบ / กระโดดเชียร์
@export var character_scene: PackedScene:
	set(v):
		character_scene = v
		_queue_rebuild()
## ไฟล์คลังท่าทาง เลือก MeleeLib.res หรือ ShooterLib.res
@export_file("*.res", "*.tres") var animation_library_path: String = "res://Libraries/Humanoid/MeleeLib.res":
	set(v):
		animation_library_path = v
		_queue_rebuild()
## ชื่อท่าของตัวที่ 1, 2, 3 (เว้นว่างไว้ = ให้สคริปต์เลือกท่าที่ต่างกันให้อัตโนมัติ)
@export var animation_names: Array[String] = ["", "", ""]:
	set(v):
		animation_names = v
		_queue_rebuild()
## ปรับขนาดตัวละคร ถ้าตัวใหญ่/เล็กเกินไป
@export var character_scale: float = 1.0:
	set(v):
		character_scale = v
		_queue_rebuild()

# กลุ่มคำค้นชื่อท่า: ตัวที่ 1 ยืนพัก, ตัวที่ 2 โจมตี, ตัวที่ 3 ท่าอื่นๆ
const POSE_GROUPS := [
	["idle", "stand"],
	["attack", "slash", "punch", "kick", "combo", "shoot", "fire"],
	["block", "cheer", "taunt", "aim", "dance", "jump", "roll", "reload"],
]

var _fire_light: OmniLight3D
var _flames: Array[MeshInstance3D] = []
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _chibis: Array[Dictionary] = []

const SPOTS := [
	{"pos": Vector3(-1.7, 0, 0.9), "rot": 25.0},
	{"pos": Vector3(0.0, 0, 1.4), "rot": 0.0},
	{"pos": Vector3(1.7, 0, 1.0), "rot": -25.0},
]


func _ready() -> void:
	_rebuild()


var _rebuild_queued := false

func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


## สร้างฉากใหม่ทั้งหมด (ทำงานทั้งในหน้า Editor และตอนกดเล่น)
func _rebuild() -> void:
	_rebuild_queued = false
	for child in get_children():
		if child.owner == null:  # ลบเฉพาะของที่สคริปต์สร้าง ไม่ลบ node ที่ผู้ใช้เพิ่มเอง
			remove_child(child)
			child.queue_free()
	_flames.clear()
	_chibis.clear()
	_fire_light = null
	_rng.seed = 2026
	_build_environment()
	_build_ground()
	_build_campfire(Vector3(3.4, 0, -1.2))
	_build_tent(Vector3(-3.2, 0, -2.6), 25.0)
	_build_log_bench(Vector3(4.6, 0, -0.4), 60.0)
	_build_trees()
	_build_decorations()
	_spawn_characters()
	_build_camera()


func _process(delta: float) -> void:
	_time += delta
	if _fire_light:
		_fire_light.light_energy = 1.6 + sin(_time * 13.0) * 0.3 + sin(_time * 7.3) * 0.2
	for i in _flames.size():
		var s := 1.0 + sin(_time * (9.0 + i * 3.0)) * 0.12
		_flames[i].scale = Vector3(1.0, s, 1.0)
	_animate_chibis(_time)


# ---------------------------------------------------------------- helpers
func _mat(color: Color, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


func _glow_mat(color: Color, energy: float = 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _add(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO,
		scl := Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	(parent if parent else self).add_child(mi)
	return mi


func _cyl(top: float, bottom: float, h: float, seg: int = 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	return c


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c


func _sphere(r: float, hemi: bool = false) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r if hemi else r * 2.0
	s.is_hemisphere = hemi
	return s


# ---------------------------------------------------------------- sky & light
func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.27, 0.55)
	sky_mat.sky_horizon_color = Color(1.0, 0.62, 0.38)
	sky_mat.ground_horizon_color = Color(0.3, 0.4, 0.28)
	sky_mat.ground_bottom_color = Color(0.15, 0.25, 0.15)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.85, 0.6, 0.45)
	env.fog_density = 0.012

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.72, 0.48)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-28, -35, 0)
	add_child(sun)


# ---------------------------------------------------------------- ground
func _build_ground() -> void:
	# เกาะหญ้า
	_add(_cyl(40, 40, 0.8, 64), _mat(Color(0.26, 0.46, 0.22)), Vector3(0, -0.4, 0))
	# ลานดินตรงกลาง
	_add(_cyl(3.6, 3.6, 0.04, 40), _mat(Color(0.45, 0.33, 0.22)), Vector3(0.6, 0.02, -0.5))
	# ทางเดินหินเข้าค่าย
	var stone := _mat(Color(0.6, 0.58, 0.55))
	for i in 5:
		var x := sin(i * 0.9) * 0.3
		_add(_cyl(0.42, 0.45, 0.08, 10), stone, Vector3(x, 0.04, 3.4 + i * 1.1),
			Vector3(0, i * 23, 0), Vector3(1.0, 1.0, 0.8))


# ---------------------------------------------------------------- campfire
func _build_campfire(p: Vector3) -> void:
	var fire := Node3D.new()
	fire.position = p
	add_child(fire)

	# วงหิน
	var rock := _mat(Color(0.45, 0.44, 0.42))
	for i in 9:
		var a := TAU * i / 9.0
		_add(_sphere(0.17), rock, Vector3(cos(a) * 0.6, 0.08, sin(a) * 0.6),
			Vector3(0, i * 40, 0), Vector3(1.0, 0.6, 0.9), fire)
	# ฟืน
	var wood := _mat(Color(0.4, 0.25, 0.14))
	for i in 3:
		_add(_cyl(0.07, 0.07, 0.95, 8), wood, Vector3(0, 0.1, 0),
			Vector3(0, i * 60, 80), Vector3.ONE, fire)
	# เปลวไฟ (2 ชั้น)
	_flames.append(_add(_cyl(0.0, 0.28, 0.7, 10), _glow_mat(Color(1.0, 0.35, 0.05), 4.0),
		Vector3(0, 0.45, 0), Vector3.ZERO, Vector3.ONE, fire))
	_flames.append(_add(_cyl(0.0, 0.15, 0.45, 10), _glow_mat(Color(1.0, 0.85, 0.3), 5.0),
		Vector3(0, 0.38, 0), Vector3.ZERO, Vector3.ONE, fire))
	# แสงไฟกะพริบ
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.55, 0.2)
	_fire_light.omni_range = 4.5
	_fire_light.shadow_enabled = true
	_fire_light.position = Vector3(0, 0.9, 0)
	fire.add_child(_fire_light)


func _build_log_bench(p: Vector3, rot_y: float) -> void:
	_add(_cyl(0.22, 0.22, 1.6, 12), _mat(Color(0.48, 0.3, 0.17)),
		p + Vector3(0, 0.22, 0), Vector3(0, rot_y, 90))


# ---------------------------------------------------------------- tent
func _build_tent(p: Vector3, rot_y: float) -> void:
	var tent := Node3D.new()
	tent.position = p
	tent.rotation_degrees.y = rot_y
	add_child(tent)

	var body := PrismMesh.new()
	body.size = Vector3(2.4, 1.7, 2.6)
	_add(body, _mat(Color(0.85, 0.42, 0.22)), Vector3(0, 0.85, 0), Vector3.ZERO, Vector3.ONE, tent)
	var door := PrismMesh.new()
	door.size = Vector3(0.9, 1.0, 0.04)
	_add(door, _mat(Color(0.2, 0.12, 0.08)), Vector3(0, 0.5, 1.31), Vector3.ZERO, Vector3.ONE, tent)
	# เสาเต็นท์
	var pole := _mat(Color(0.35, 0.3, 0.25))
	for z in [-1.35, 1.35]:
		_add(_cyl(0.03, 0.03, 1.9, 6), pole, Vector3(0, 0.95, z), Vector3.ZERO, Vector3.ONE, tent)


# ---------------------------------------------------------------- trees
func _build_pine(p: Vector3, size: float) -> void:
	var tree := Node3D.new()
	tree.position = p
	tree.scale = Vector3.ONE * size
	tree.rotation_degrees.y = _rng.randf_range(0, 360)
	add_child(tree)
	_add(_cyl(0.14, 0.18, 1.0, 8), _mat(Color(0.38, 0.24, 0.14)), Vector3(0, 0.5, 0),
		Vector3.ZERO, Vector3.ONE, tree)
	var leaf := _mat(Color(0.16, 0.42, 0.24).lerp(Color(0.25, 0.5, 0.2), _rng.randf()))
	for i in 3:
		_add(_cyl(0.0, 1.0 - i * 0.25, 1.1, 10), leaf, Vector3(0, 1.3 + i * 0.6, 0),
			Vector3.ZERO, Vector3.ONE, tree)


func _build_trees() -> void:
	var spots := [
		Vector3(-6.5, 0, -4), Vector3(-4.8, 0, -6.5), Vector3(-1.5, 0, -7.2),
		Vector3(1.8, 0, -6.8), Vector3(5, 0, -5.8), Vector3(7.2, 0, -3),
		Vector3(-8, 0, -0.5), Vector3(8, 0, 0.5), Vector3(-7, 0, 3.5),
		Vector3(6.8, 0, 4), Vector3(-3.5, 0, -8.5), Vector3(4, 0, -8.6),
	]
	for s in spots:
		_build_pine(s, _rng.randf_range(0.9, 1.5))


# ---------------------------------------------------------------- props
func _build_decorations() -> void:
	# ก้อนหิน
	var rock := _mat(Color(0.5, 0.5, 0.52))
	for p in [Vector3(-5, 0, 1), Vector3(5.3, 0, -1.8), Vector3(-6.5, 0, 5.5), Vector3(5.5, 0, 6.5)]:
		_add(_sphere(0.5), rock, p + Vector3(0, 0.15, 0),
			Vector3(0, _rng.randf_range(0, 360), 0), Vector3(1.3, 0.7, 1.0))
	# พุ่มไม้
	var bush := _mat(Color(0.3, 0.55, 0.25))
	for p in [Vector3(-4.5, 0, 2.5), Vector3(4.8, 0, 2.2), Vector3(-1.2, 0, -5), Vector3(6, 0, -4.5)]:
		for k in 3:
			_add(_sphere(0.45 - k * 0.08), bush,
				p + Vector3(k * 0.45 - 0.45, 0.3, _rng.randf_range(-0.2, 0.2)))
	# เห็ดแดง
	var cap := _mat(Color(0.85, 0.15, 0.12), 0.6)
	var stem := _mat(Color(0.95, 0.92, 0.85))
	for p in [Vector3(-2.8, 0, 2.6), Vector3(-2.5, 0, 2.9), Vector3(4.2, 0, 1.5)]:
		_add(_cyl(0.05, 0.06, 0.25, 8), stem, p + Vector3(0, 0.12, 0))
		_add(_sphere(0.16, true), cap, p + Vector3(0, 0.24, 0))
	# บ่อน้ำเล็ก
	var water := _mat(Color(0.25, 0.55, 0.8, 0.85), 0.1)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_add(_cyl(1.6, 1.6, 0.02, 32), water, Vector3(-5.5, 0.05, -1.8), Vector3.ZERO, Vector3(1.0, 1.0, 0.7))
	# โคมไฟข้างเต็นท์
	_add(_cyl(0.03, 0.03, 1.4, 6), _mat(Color(0.3, 0.25, 0.2)), Vector3(-1.6, 0.7, -2.2))
	_add(_sphere(0.14), _glow_mat(Color(1.0, 0.8, 0.4), 3.0), Vector3(-1.6, 1.45, -2.2))
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.45)
	lamp.light_energy = 1.2
	lamp.omni_range = 3.0
	lamp.position = Vector3(-1.6, 1.45, -2.2)
	add_child(lamp)


# ---------------------------------------------------------------- characters
func _spawn_characters() -> void:
	if character_scene == null:
		print("ไม่ได้ใส่ character_scene -> ใช้ตัวละครชิบิในตัวสคริปต์แทน")
		for i in SPOTS.size():
			_build_chibi(SPOTS[i]["pos"], SPOTS[i]["rot"], i)
		return

	var lib: AnimationLibrary = null
	if animation_library_path != "" and ResourceLoader.exists(animation_library_path):
		lib = load(animation_library_path)
	elif animation_library_path != "":
		push_warning("หาไฟล์คลังท่าทางไม่เจอ: " + animation_library_path)

	var spots := SPOTS
	var used: Array[String] = []
	for i in spots.size():
		var c: Node3D = character_scene.instantiate()
		c.position = spots[i]["pos"]
		c.rotation_degrees.y = spots[i]["rot"]
		c.scale = Vector3.ONE * character_scale
		add_child(c)

		var ap := _find_anim_player(c)
		if lib and not ap.has_animation_library("Lib"):
			ap.add_animation_library("Lib", lib)
		if i == 0:
			print("ท่าที่มีให้เลือก: ", ap.get_animation_list())

		var wanted: String = animation_names[i] if i < animation_names.size() else ""
		var anim := _pick_animation(ap, wanted, i, used)
		if anim == "":
			push_warning("ตัวที่ %d ไม่มีท่าให้เล่น" % (i + 1))
			continue
		used.append(anim)
		ap.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
		ap.play(anim)
		print("ตัวที่ %d เล่นท่า: %s" % [i + 1, anim])


func _find_anim_player(root: Node) -> AnimationPlayer:
	var found := root.find_children("*", "AnimationPlayer", true, false)
	if found.size() > 0:
		return found[0]
	# ไม่มี AnimationPlayer ในตัวละคร -> สร้างให้
	var ap := AnimationPlayer.new()
	root.add_child(ap)
	return ap


func _pick_animation(ap: AnimationPlayer, wanted: String, index: int, used: Array[String]) -> String:
	var all := ap.get_animation_list()
	if wanted != "":
		for n in all:
			if n == wanted or n.ends_with("/" + wanted):
				return n
		push_warning("ไม่พบท่า '%s' จะเลือกท่าอื่นให้แทน" % wanted)
	# เลือกจากกลุ่มท่าประจำตัว เพื่อให้ 3 ตัวท่าไม่เหมือนกัน
	var groups := [POSE_GROUPS[index % POSE_GROUPS.size()]]
	groups.append_array(POSE_GROUPS)
	for keys in groups:
		for key in keys:
			for n in all:
				if n.to_lower().contains(key) and not used.has(n) and not _is_reset(n):
					return n
	for n in all:
		if not used.has(n) and not _is_reset(n):
			return n
	return ""


func _is_reset(n: String) -> bool:
	return n == "RESET" or n.ends_with("/RESET")


# ---------------------------------------------------------------- camera
func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.fov = 55
	add_child(cam)
	cam.position = Vector3(0.3, 2.4, 7.2)
	cam.look_at(Vector3(0.3, 1.0, 0))
	cam.current = true


# ---------------------------------------------------------------- chibi (ตัวละครมีแขนขา)
func _build_chibi(pos: Vector3, rot_y: float, pose: int) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_y
	root.scale = Vector3.ONE * character_scale
	add_child(root)
	var body := Node3D.new()
	root.add_child(body)

	var skin := _mat(Color(1.0, 0.86, 0.76), 0.7)
	var shirt := _mat(Color(0.27, 0.72, 0.6))
	var shorts := _mat(Color(0.93, 0.86, 0.68))
	var shoe := _mat(Color(0.22, 0.32, 0.65))
	var hair := _mat(Color(0.14, 0.13, 0.17), 0.6)
	var dark := _mat(Color(0.05, 0.05, 0.07), 0.3)

	# ขา
	var legs: Array[Node3D] = []
	for side in [-1, 1]:
		var hip := Node3D.new()
		hip.position = Vector3(0.09 * side, 0.48, 0)
		body.add_child(hip)
		_add(_capsule(0.075, 0.42), skin, Vector3(0, -0.2, 0), Vector3.ZERO, Vector3.ONE, hip)
		_add(_capsule(0.09, 0.22), shorts, Vector3(0, -0.06, 0), Vector3.ZERO, Vector3.ONE, hip)
		var b := BoxMesh.new()
		b.size = Vector3(0.14, 0.09, 0.22)
		_add(b, shoe, Vector3(0, -0.44, 0.03), Vector3.ZERO, Vector3.ONE, hip)
		legs.append(hip)

	# ลำตัว
	_add(_capsule(0.17, 0.48), shirt, Vector3(0, 0.74, 0), Vector3.ZERO, Vector3.ONE, body)

	# หัว
	var head := Node3D.new()
	head.position = Vector3(0, 1.0, 0)
	body.add_child(head)
	_add(_sphere(0.3), skin, Vector3(0, 0.28, 0), Vector3.ZERO, Vector3.ONE, head)
	for side in [-1, 1]:
		_add(_sphere(0.045), dark, Vector3(0.11 * side, 0.27, 0.27), Vector3.ZERO, Vector3(1, 1.3, 0.6), head)
		_add(_sphere(0.014), _glow_mat(Color.WHITE, 1.0), Vector3(0.11 * side + 0.012, 0.29, 0.3), Vector3.ZERO, Vector3.ONE, head)
		_add(_sphere(0.05), _mat(Color(1.0, 0.6, 0.6)), Vector3(0.18 * side, 0.19, 0.23), Vector3.ZERO, Vector3(1, 0.6, 0.4), head)
	var mouth := BoxMesh.new()
	mouth.size = Vector3(0.05, 0.015, 0.01)
	_add(mouth, _mat(Color(0.6, 0.2, 0.2)), Vector3(0, 0.16, 0.29), Vector3.ZERO, Vector3.ONE, head)
	# ผมทรงตั้ง
	_add(_sphere(0.315, true), hair, Vector3(0, 0.3, -0.02), Vector3(-18, 0, 0), Vector3.ONE, head)
	for i in 10:
		var a := TAU * i / 10.0
		var d := Vector3(cos(a) * 0.55, 1.0, sin(a) * 0.55 - 0.15).normalized()
		var spike := _add(_cyl(0.0, 0.08, 0.22, 6), hair, Vector3(0, 0.3, 0) + d * 0.28,
			Vector3.ZERO, Vector3.ONE, head)
		spike.basis = Basis(Vector3.UP.cross(d).normalized(), Vector3.UP.angle_to(d))
	_add(_cyl(0.0, 0.09, 0.26, 6), hair, Vector3(0, 0.62, 0), Vector3.ZERO, Vector3.ONE, head)

	# แขน
	var arms: Array[Node3D] = []
	for side in [-1, 1]:
		var sh := Node3D.new()
		sh.position = Vector3(0.23 * side, 0.93, 0)
		sh.rotation.z = 0.15 * side
		body.add_child(sh)
		_add(_capsule(0.07, 0.18), shirt, Vector3(0, -0.06, 0), Vector3.ZERO, Vector3.ONE, sh)
		_add(_capsule(0.055, 0.36), skin, Vector3(0, -0.17, 0), Vector3.ZERO, Vector3.ONE, sh)
		_add(_sphere(0.07), skin, Vector3(0, -0.37, 0), Vector3.ZERO, Vector3.ONE, sh)
		arms.append(sh)

	# ตัวที่ 2 ถือดาบ
	if pose == 1:
		var blade := BoxMesh.new()
		blade.size = Vector3(0.05, 0.62, 0.015)
		_add(blade, _mat(Color(0.85, 0.88, 0.92), 0.2), Vector3(0, -0.76, 0), Vector3.ZERO, Vector3.ONE, arms[0])
		var guard := BoxMesh.new()
		guard.size = Vector3(0.2, 0.035, 0.06)
		_add(guard, _mat(Color(0.85, 0.65, 0.2), 0.4), Vector3(0, -0.44, 0), Vector3.ZERO, Vector3.ONE, arms[0])

	_chibis.append({
		"pose": pose, "root": root, "body": body, "head": head, "base_y": pos.y,
		"arm_r": arms[0], "arm_l": arms[1], "leg_r": legs[0], "leg_l": legs[1],
		"phase": pose * 0.7,
	})


func _animate_chibis(t: float) -> void:
	for c in _chibis:
		var tt: float = t + c["phase"]
		var body: Node3D = c["body"]
		var arm_r: Node3D = c["arm_r"]
		var arm_l: Node3D = c["arm_l"]
		var leg_r: Node3D = c["leg_r"]
		var leg_l: Node3D = c["leg_l"]
		match c["pose"]:
			0: # โบกมือทักทาย
				body.position.y = sin(tt * 3.0) * 0.015
				arm_r.rotation = Vector3(0, 0, -2.5 + sin(tt * 9.0) * 0.35)
				arm_l.rotation = Vector3(0, 0, 0.15 + sin(tt * 3.0) * 0.05)
				c["head"].rotation.z = sin(tt * 3.0) * 0.08
			1: # ฟันดาบ
				var s := sin(tt * 4.5)
				arm_r.rotation = Vector3(-1.3 + s * 1.3, 0, -0.25)
				arm_l.rotation = Vector3(-0.6 - s * 0.3, 0, 0.3)
				body.rotation = Vector3(s * 0.1, s * 0.2, 0)
				leg_l.rotation.x = -0.35
				leg_r.rotation.x = 0.25
			2: # กระโดดเชียร์
				var h := absf(sin(tt * 3.5))
				c["root"].position.y = c["base_y"] + h * 0.35
				arm_r.rotation = Vector3(0, 0, -2.7 + sin(tt * 7.0) * 0.2)
				arm_l.rotation = Vector3(0, 0, 2.7 - sin(tt * 7.0) * 0.2)
				leg_l.rotation.x = -h * 0.6
				leg_r.rotation.x = -h * 0.3
