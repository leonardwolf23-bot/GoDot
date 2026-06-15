class_name IsoUtils
extends RefCounted
## Isometrische Koordinaten für 32×64-Rauten (TileMap-Maß).
## Ursprung einer Zelle = nördliche Spitze der Raute (klassisches Iso-Grid).

const TILE_WIDTH := 32
const TILE_HEIGHT := 64


static func half_w() -> float:
	return TILE_WIDTH / 2.0


static func half_h() -> float:
	return TILE_HEIGHT / 2.0


## Nördliche Spitze der Zelle.
static func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
			(cell.x - cell.y) * half_w(),
			(cell.x + cell.y) * half_h()
	)


## Zellmitte der Raute.
static func cell_to_world_center(cell: Vector2i) -> Vector2:
	return cell_to_world(cell) + Vector2(0.0, half_h())


static func world_to_cell(world_pos: Vector2) -> Vector2i:
	var fx := (world_pos.x / half_w() + world_pos.y / half_h()) / 2.0
	var fy := (world_pos.y / half_h() - world_pos.x / half_w()) / 2.0
	return Vector2i(int(floor(fx)), int(floor(fy)))


## Ecke der Gebäude-Grundfläche in lokalen Pixeln (offset in Rasterzellen).
static func cell_corner_offset(offset: Vector2) -> Vector2:
	return Vector2(
			(offset.x - offset.y) * half_w(),
			(offset.x + offset.y) * half_h()
	)


## Die vier Ecken der Grundfläche für size.x × size.y Zellen.
static func footprint_corners(size: Vector2i) -> PackedVector2Array:
	return PackedVector2Array([
		cell_corner_offset(Vector2.ZERO),
		cell_corner_offset(Vector2(size.x, 0)),
		cell_corner_offset(Vector2(size.x, size.y)),
		cell_corner_offset(Vector2(0, size.y)),
	])


static func footprint_top_left_bbox(size: Vector2i) -> Vector2:
	var corners := footprint_corners(size)
	var min_x := corners[0].x
	var min_y := corners[0].y
	for p in corners:
		min_x = minf(min_x, p.x)
		min_y = minf(min_y, p.y)
	return Vector2(min_x, min_y)


## Zeichenposition für eine Boden-Textur in Original-Pixelgröße (zentriert auf der Zelle).
static func terrain_texture_pos(cell: Vector2i, tex_size: Vector2) -> Vector2:
	return cell_to_world_center(cell) - tex_size * 0.5


static func depth_key(cell: Vector2i, size: Vector2i = Vector2i.ONE) -> int:
	return cell.x + cell.y + size.x + size.y
