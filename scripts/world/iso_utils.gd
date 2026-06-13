class_name IsoUtils
extends RefCounted
## Isometrische Koordinaten-Hilfe für 64×32-Kacheln (Raute 64 px breit × 32 px hoch).
## Die Umrechnung orientiert sich an Godots TileMapLayer (map_to_local / local_to_map).

const TILE_WIDTH := 64
const TILE_HEIGHT := 32


static func half_w() -> float:
	return TILE_WIDTH / 2.0


static func half_h() -> float:
	return TILE_HEIGHT / 2.0


## Zellmitte – entspricht TileMapLayer.map_to_local().
static func cell_center_to_world(cell: Vector2i) -> Vector2:
	var hw := half_w()
	var hh := half_h()
	return Vector2(
			(cell.x - cell.y) * hw + hw,
			(cell.x + cell.y) * hh + hh
	)


## Obere linke Ecke der Kachel-Bounding-Box (Anker für Gebäude-Sprites).
static func cell_to_world(cell: Vector2i) -> Vector2:
	return cell_center_to_world(cell) - Vector2(half_w(), half_h())


## Mittelpunkt der Raute.
static func cell_to_world_center(cell: Vector2i) -> Vector2:
	return cell_center_to_world(cell)


static func world_to_cell(world_pos: Vector2) -> Vector2i:
	var hw := half_w()
	var hh := half_h()
	# Inverse zu Godots map_to_local (Zellmitte).
	var col := (world_pos.x / hw + world_pos.y / hh) / 2.0 - 0.5
	var row := (world_pos.y / hh - world_pos.x / hw) / 2.0 - 0.5
	return Vector2i(int(floor(col)), int(floor(row)))


## Sichtbare Boden-Raute für ein Gebäude mit footprint size×size Zellen.
static func footprint_size(size: Vector2i) -> Vector2:
	return Vector2(
			(size.x + size.y) * half_w(),
			(size.x + size.y) * half_h()
	)


## Tiefe für z_index (weiter unten/rechts = vorne).
static func depth_key(cell: Vector2i, size: Vector2i = Vector2i.ONE) -> int:
	return cell.x + cell.y + size.x + size.y


## Eckpunkte der Raute in lokalen Koordinaten (Origin = obere Ecke der Bounding-Box).
static func diamond_polygon_local() -> PackedVector2Array:
	var hw := half_w()
	var hh := half_h()
	return PackedVector2Array([
		Vector2(hw, 0.0),
		Vector2(TILE_WIDTH, hh),
		Vector2(hw, TILE_HEIGHT),
		Vector2(0.0, hh),
	])


## Raute für ein mehrzelliges Gebäude (Origin = obere Ecke der Bodenfläche).
static func footprint_polygon_local(size: Vector2i) -> PackedVector2Array:
	var fp := footprint_size(size)
	var hw := fp.x / 2.0
	var hh := fp.y / 2.0
	return PackedVector2Array([
		Vector2(hw, 0.0),
		Vector2(fp.x, hh),
		Vector2(hw, fp.y),
		Vector2(0.0, hh),
	])
