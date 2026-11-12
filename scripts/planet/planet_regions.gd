extends RefCounted
## Cube-sphere region grid.  A region is the streaming unit: 6 faces x SIZE x SIZE
## cells.  Region ids are stable strings ("pz:3:5") and are what the save file
## records as "discovered", which makes exploration progress independent of the
## floating-point position of the player.

const SIZE := 12
const FACES := ["px", "nx", "py", "ny", "pz", "nz"]
const PlanetMesh = preload("res://scripts/planet/planet_mesh.gd")

## Direction for a region id.  Returns Vector3.ZERO for malformed ids.
static func region_center(id: String) -> Vector3:
	var parts := id.split(":")
	if parts.size() != 3 or parts[0] not in FACES:
		return Vector3.ZERO
	if not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return Vector3.ZERO
	var x := int(parts[1])
	var y := int(parts[2])
	if x < 0 or x >= SIZE or y < 0 or y >= SIZE:
		return Vector3.ZERO
	var u := (float(x) + 0.5) / float(SIZE) * 2.0 - 1.0
	var v := (float(y) + 0.5) / float(SIZE) * 2.0 - 1.0
	return PlanetMesh.face_direction(parts[0], u, v)


## Region id containing a unit direction.
static func region_of(direction: Vector3) -> String:
	var d := direction.normalized()
	if d.length_squared() < 0.5:
		return ""
	var a := d.abs()
	var face := "pz"
	var u := 0.0
	var v := 0.0
	if a.x >= a.y and a.x >= a.z:
		face = "px" if d.x >= 0.0 else "nx"
		u = (-d.z if d.x >= 0.0 else d.z) / a.x
		v = d.y / a.x
	elif a.y >= a.z:
		face = "py" if d.y >= 0.0 else "ny"
		u = d.x / a.y
		v = (-d.z if d.y >= 0.0 else d.z) / a.y
	else:
		face = "pz" if d.z >= 0.0 else "nz"
		u = (d.x if d.z >= 0.0 else -d.x) / a.z
		v = d.y / a.z
	var x := clampi(floori((u + 1.0) * 0.5 * SIZE), 0, SIZE - 1)
	var y := clampi(floori((v + 1.0) * 0.5 * SIZE), 0, SIZE - 1)
	return "%s:%d:%d" % [face, x, y]


static func is_valid(id: String) -> bool:
	return region_center(id) != Vector3.ZERO


## Region id plus its 8 neighbours (seamless across cube-face borders).
static func neighborhood(direction: Vector3, radius: int = 1) -> Array[String]:
	var centre := region_of(direction)
	var parts := centre.split(":")
	var result: Array[String] = []
	if parts.size() != 3:
		return result
	var cx := int(parts[1])
	var cy := int(parts[2])
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			# Extended face coordinates wrap cleanly when projected back onto the sphere.
			var u := (float(cx + dx) + 0.5) / float(SIZE) * 2.0 - 1.0
			var v := (float(cy + dy) + 0.5) / float(SIZE) * 2.0 - 1.0
			var id := region_of(PlanetMesh.face_direction(parts[0], u, v))
			if id != "" and id not in result:
				result.append(id)
	return result


## Approximate radius of one region in metres (for streaming distance decisions).
static func region_radius_metres() -> float:
	return TAU * 250.0 / (4.0 * float(SIZE))


## Human-readable location used by the HUD when the player crosses a border.
static func region_label(id: String) -> String:
	var parts := id.split(":")
	if parts.size() != 3:
		return "Unknown"
	return "%s-%s%s" % [parts[0].to_upper(), parts[1], parts[2]]
