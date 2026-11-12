extends RefCounted
## Cube-face partition of the unit sphere. The mesh itself is still a smooth sphere.
const SIZE := 64
const FACES := ["px", "nx", "py", "ny", "pz", "nz"]

static func direction(face: String, u: float, v: float) -> Vector3:
	match face:
		"px": return Vector3(1, v, -u).normalized()
		"nx": return Vector3(-1, v, u).normalized()
		"py": return Vector3(u, 1, -v).normalized()
		"ny": return Vector3(u, -1, v).normalized()
		"pz": return Vector3(u, v, 1).normalized()
		"nz": return Vector3(-u, v, -1).normalized()
	return Vector3.ZERO

static func cell(dir: Vector3) -> String:
	var a := dir.abs()
	if a.length_squared() < 0.000001: return ""
	var face := ""; var u := 0.0; var v := 0.0
	if a.x >= a.y and a.x >= a.z:
		if dir.x >= 0: face = "px"; u = -dir.z / a.x
		else: face = "nx"; u = dir.z / a.x
		v = dir.y / a.x
	elif a.y >= a.z:
		if dir.y >= 0: face = "py"; v = -dir.z / a.y
		else: face = "ny"; v = dir.z / a.y
		u = dir.x / a.y
	else:
		if dir.z >= 0: face = "pz"; u = dir.x / a.z
		else: face = "nz"; u = -dir.x / a.z
		v = dir.y / a.z
	var x := clampi(floori((u + 1.0) * 0.5 * SIZE), 0, SIZE - 1)
	var y := clampi(floori((v + 1.0) * 0.5 * SIZE), 0, SIZE - 1)
	return "%s:%d:%d" % [face, x, y]

static func parse(id: String) -> Dictionary:
	var p := id.split(":")
	if p.size() != 3 or p[0] not in FACES or not p[1].is_valid_int() or not p[2].is_valid_int(): return {}
	var x := int(p[1]); var y := int(p[2])
	if x < 0 or x >= SIZE or y < 0 or y >= SIZE: return {}
	return {"face": p[0], "x": x, "y": y}

static func point(id: String, dx: float = 0.5, dy: float = 0.5) -> Vector3:
	var parts := parse(id)
	if parts.is_empty(): return Vector3.ZERO
	var u: float = (float(parts.x) + dx) * 2.0 / SIZE - 1.0
	var v: float = (float(parts.y) + dy) * 2.0 / SIZE - 1.0
	return direction(parts.face, u, v)

static func neighbors(dir: Vector3) -> Array[String]:
	var parts := parse(cell(dir))
	var result: Array[String] = []
	if parts.is_empty(): return result
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			# Sampling extended cube-face coordinates projects seamlessly to adjacent faces.
			var u: float = (float(parts.x + dx) + 0.5) * 2.0 / SIZE - 1.0
			var v: float = (float(parts.y + dy) + 0.5) * 2.0 / SIZE - 1.0
			var id := cell(direction(parts.face, u, v))
			if id not in result: result.append(id)
	return result

static func from_legacy(id: String) -> String:
	var parts := id.split(":")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): return id
	var x := int(parts[0]); var y := int(parts[1])
	if x < -70 or x > 69 or y < -35 or y > 34: return id
	var lon := (x + 0.5) * 0.045
	var lat := clampf((y + 0.5) * 0.045, -PI / 2.0, PI / 2.0)
	return cell(Vector3(sin(lon) * cos(lat), sin(lat), cos(lon) * cos(lat)))
