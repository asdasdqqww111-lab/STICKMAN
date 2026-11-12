extends RefCounted
## Builds the visible planet surface: a cube-sphere of quads with per-vertex
## colouring (one draw call per face) plus a faceted ocean shell.
##
## The mesh is generated in the background on a worker thread, so the first frame
## after "New Game" is not blocked by 6 x 16 x 16 terrain evaluations.

const Math3D = preload("res://scripts/planet/sphere_math.gd")
const Terrain = preload("res://scripts/planet/terrain.gd")

## Quads per cube-face edge.  16 x 16 x 6 faces = 1536 quads, ~3k triangles.
const DEFAULT_RESOLUTION := 16

var resolution: int = DEFAULT_RESOLUTION
var seed_value: int = 1337


class MeshPayload:
	var arrays: Array = []
	var colours: PackedColorArray = PackedColorArray()
	var face: String = ""
	var bounds_min: Vector3 = Vector3.ZERO
	var bounds_max: Vector3 = Vector3.ZERO


## Cube-face parametrisation (u, v in [-1, 1]) -> unit direction.
static func face_direction(face: String, u: float, v: float) -> Vector3:
	match face:
		"px": return Vector3(1.0, v, -u).normalized()
		"nx": return Vector3(-1.0, v, u).normalized()
		"py": return Vector3(u, 1.0, -v).normalized()
		"ny": return Vector3(u, -1.0, v).normalized()
		"pz": return Vector3(u, v, 1.0).normalized()
		"nz": return Vector3(-u, v, -1.0).normalized()
	return Vector3.FORWARD


static func face_exists(face: String) -> bool:
	return face in ["px", "nx", "py", "ny", "pz", "nz"]


## Generate one cube face.  Pure function: callable from a worker thread.
static func build_face(face: String, resolution_quads: int) -> MeshPayload:
	var payload := MeshPayload.new()
	payload.face = face
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var step := 2.0 / float(resolution_quads)

	# Vertices (grid of (res + 1)^2).
	for iy in range(resolution_quads + 1):
		for ix in range(resolution_quads + 1):
			var u := -1.0 + step * float(ix)
			var v := -1.0 + step * float(iy)
			var dir := face_direction(face, u, v)
			var height := Terrain.elevation(dir)
			var point := dir * (Math3D.RADIUS + maxf(height, Terrain.WATER_LEVEL - 1.6))
			verts.append(point)
			normals.append(Terrain.ground_normal(dir))
			uvs.append(Vector2(float(ix) / resolution_quads, float(iy) / resolution_quads))
			var biome := Terrain.biome_at(dir)
			var colour := Terrain.biome_color(biome)
			# Subtle per-quad tint variation keeps the low-poly look from flattening out.
			var jitter := 0.94 + 0.12 * absf(sin(float(ix * 12.9898 + iy * 78.233 + resolution_quads) ))
			colour = Color(colour.r * jitter, colour.g * jitter, colour.b * jitter, 1.0)
			# Beach tint fades in where the terrain meets the water.
			if biome != Terrain.Biome.OCEAN and height < Terrain.WATER_LEVEL + 1.6:
				colour = colour.lerp(Terrain.biome_color(Terrain.Biome.BEACH), 0.45)
			colours.append(colour)

	# Two triangles per quad.
	var stride := resolution_quads + 1
	for iy in range(resolution_quads):
		for ix in range(resolution_quads):
			var a := iy * stride + ix
			var b := a + 1
			var c := a + stride
			var d := c + 1
			indices.append_array([a, b, d, a, d, c])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	payload.arrays = arrays
	payload.colours = colours

	var lo := Vector3.ONE * 1.0e9
	var hi := -Vector3.ONE * 1.0e9
	for p in verts:
		lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
		hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
	payload.bounds_min = lo
	payload.bounds_max = hi
	return payload


## Build a headless, physics-free collision shape covering the whole planet.
## Gameplay collision uses analytic terrain queries, this is only for raycasts/tools.
static func build_collision_mesh(resolution_quads: int = DEFAULT_RESOLUTION) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for face in ["px", "nx", "py", "ny", "pz", "nz"]:
		var payload := build_face(face, resolution_quads)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, payload.arrays)
	return mesh


## Material applied to planet faces: vertex colour, no texture, cheap on mobile.
static func make_planet_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.95
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return material


static func make_ocean_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("2b6d8f")
	material.roughness = 0.18
	material.metallic = 0.15
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.88
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
