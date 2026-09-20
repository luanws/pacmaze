class_name LevelData
extends RefCounted
## A level as plain data: read from / written to a JSON file and turned into a playable Level.
##
## File format (all cells are [column, row], counted from the top-left corner). The border is
## always the outer ring of the grid, so only walls need listing:
## {
##   "format": "pacmaze-level", "version": 2,
##   "name": "...", "instructions": "...",
##   "scoring": {"level_bonus": 10, "move_sensitivity": 200, "time_sensitivity": 100},
##   "size": [width, height],
##   "walls": [{"cell": [x, y], "style": "classic"}],
##   "pushable_walls": [{"cell": [x, y], "style": "crate"}],
##   "player": [x, y], "pill": [x, y],
##   "ghosts": [{"color": "blue", "cell": [x, y], "speed": 7.5, "path": [[dx, dy], ...]}],
##   "portals": [{"color": "#ff0000", "a": [x, y], "b": [x, y]}],
##   "locks": [{"color": "#00c8ff", "key": [x, y], "door": [x, y]}]   # the key opens the door
## }

enum Cell { EMPTY, WALL, BORDER, PUSHABLE }

const FORMAT := "pacmaze-level"
const VERSION := 2
const TILE_SIZE := 30
const DEFAULT_SIZE := Vector2i(43, 27)
## Name of each wall style, in the order of row 1 of the walls atlas.
const WALL_STYLE_NAMES := [
	"classic", "neon", "red_brick", "gem", "metal", "grass", "crate", "ice", "lava", "circuit", "candy",
]
const GHOST_COLOR_NAMES := ["blue", "green", "purple", "yellow"]
const DEFAULT_GHOST_SPEED := 7.5

const LEVEL_SCENE := preload("res://scenes/level.tscn")
const GHOST_SCENE := preload("res://scenes/ghost.tscn")
const PORTAL_SCENE := preload("res://scenes/portal.tscn")
const KEY_SCENE := preload("res://scenes/key.tscn")
const DOOR_SCENE := preload("res://scenes/door.tscn")


class GhostData:
	var color := 0 ## Ghost.GhostColor
	var cell := Vector2i.ZERO
	var speed := DEFAULT_GHOST_SPEED
	var path: Array[Vector2i] = [] ## Straight moves, in tiles.

	func path_end() -> Vector2i:
		var end := cell
		for move in path:
			end += move
		return end


class PortalData:
	var color := Color.WHITE
	var a := Vector2i.ZERO
	var b := Vector2i.ZERO


class LockData:
	var color := Color.WHITE
	var key := Vector2i.ZERO
	var door := Vector2i.ZERO


var name := "Nova fase"
var instructions := ""
var level_bonus := 10
var move_sensitivity := 200
var time_sensitivity := 100
var size := DEFAULT_SIZE
var cells := PackedByteArray()
var wall_styles := PackedByteArray() ## Style of each wall cell, an index into WALL_STYLE_NAMES.
var player := Vector2i.ZERO
var pill := Vector2i.ZERO
var ghosts: Array[GhostData] = []
var portals: Array[PortalData] = []
var locks: Array[LockData] = []


## An empty level surrounded by border blocks.
static func create_empty(level_size := DEFAULT_SIZE) -> LevelData:
	var data := LevelData.new()
	data.size = level_size
	data.cells.resize(level_size.x * level_size.y)
	data.wall_styles.resize(data.cells.size())
	data._add_border()
	data.player = Vector2i(1, level_size.y - 2)
	data.pill = Vector2i(level_size.x - 2, 1)
	return data


## The border is always the outer ring of the grid, so it's never stored in the file.
func _add_border() -> void:
	for y in size.y:
		for x in size.x:
			if x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1:
				set_cell(Vector2i(x, y), Cell.BORDER)


static func load_file(path: String) -> LevelData:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_warning("Could not read level file: %s" % path)
		return null
	return from_json(text)


## Parses the contents of a level file. Returns null if it isn't a Pacmaze level.
static func from_json(text: String) -> LevelData:
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary or parsed.get("format") != FORMAT:
		push_warning("Not a Pacmaze level")
		return null
	return from_dict(parsed)


static func from_dict(d: Dictionary) -> LevelData:
	var size := _to_cell(d.get("size"), Vector2i.ZERO)
	if size.x <= 0 or size.y <= 0:
		push_warning("Level has no map")
		return null

	var data := LevelData.new()
	data.name = d.get("name", data.name)
	data.instructions = d.get("instructions", "")
	var scoring: Dictionary = d.get("scoring", {})
	data.level_bonus = int(scoring.get("level_bonus", data.level_bonus))
	data.move_sensitivity = int(scoring.get("move_sensitivity", data.move_sensitivity))
	data.time_sensitivity = int(scoring.get("time_sensitivity", data.time_sensitivity))
	data.size = size
	data.cells.resize(size.x * size.y)
	data.wall_styles.resize(data.cells.size())
	data._add_border()
	for w: Dictionary in d.get("walls", []):
		var style := maxi(WALL_STYLE_NAMES.find(w.get("style", "classic")), 0)
		data.set_wall(_to_cell(w.get("cell"), Vector2i.ZERO), style)
	for pw: Dictionary in d.get("pushable_walls", []):
		var style := maxi(WALL_STYLE_NAMES.find(pw.get("style", "crate")), 0)
		data.set_pushable_wall(_to_cell(pw.get("cell"), Vector2i.ZERO), style)
	data.player = _to_cell(d.get("player"), Vector2i(1, data.size.y - 2))
	data.pill = _to_cell(d.get("pill"), Vector2i(data.size.x - 2, 1))

	for g: Dictionary in d.get("ghosts", []):
		var ghost := GhostData.new()
		ghost.color = maxi(GHOST_COLOR_NAMES.find(g.get("color", "blue")), 0)
		ghost.cell = _to_cell(g.get("cell"), Vector2i.ZERO)
		ghost.speed = float(g.get("speed", DEFAULT_GHOST_SPEED))
		for move in g.get("path", []):
			ghost.path.append(_to_cell(move, Vector2i.ZERO))
		data.ghosts.append(ghost)

	for p: Dictionary in d.get("portals", []):
		var portal := PortalData.new()
		portal.color = _to_color(p.get("color"))
		portal.a = _to_cell(p.get("a"), Vector2i.ZERO)
		portal.b = _to_cell(p.get("b"), Vector2i.ZERO)
		data.portals.append(portal)

	for l: Dictionary in d.get("locks", []):
		var lock := LockData.new()
		lock.color = _to_color(l.get("color"))
		lock.key = _to_cell(l.get("key"), Vector2i.ZERO)
		lock.door = _to_cell(l.get("door"), Vector2i.ZERO)
		data.locks.append(lock)
	return data


static func _to_color(value: Variant) -> Color:
	var text := str(value)
	return Color.html(text) if Color.html_is_valid(text) else Color.WHITE


static func _to_cell(value: Variant, fallback: Vector2i) -> Vector2i:
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return fallback


static func _from_cell(cell: Vector2i) -> Array:
	return [cell.x, cell.y]


func to_dict() -> Dictionary:
	var wall_list := []
	var pushable_wall_list := []
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			if get_cell(cell) == Cell.WALL:
				wall_list.append({
					"cell": _from_cell(cell),
					"style": WALL_STYLE_NAMES[get_wall_style(cell)],
				})
			elif get_cell(cell) == Cell.PUSHABLE:
				pushable_wall_list.append({
					"cell": _from_cell(cell),
					"style": WALL_STYLE_NAMES[get_wall_style(cell)],
				})
	var ghost_list := []
	for ghost in ghosts:
		ghost_list.append({
			"color": GHOST_COLOR_NAMES[ghost.color],
			"cell": _from_cell(ghost.cell),
			"speed": ghost.speed,
			"path": ghost.path.map(_from_cell),
		})
	var portal_list := []
	for portal in portals:
		portal_list.append({
			"color": "#" + portal.color.to_html(false),
			"a": _from_cell(portal.a),
			"b": _from_cell(portal.b),
		})
	var lock_list := []
	for lock in locks:
		lock_list.append({
			"color": "#" + lock.color.to_html(false),
			"key": _from_cell(lock.key),
			"door": _from_cell(lock.door),
		})
	return {
		"format": FORMAT,
		"version": VERSION,
		"name": name,
		"instructions": instructions,
		"scoring": {
			"level_bonus": level_bonus,
			"move_sensitivity": move_sensitivity,
			"time_sensitivity": time_sensitivity,
		},
		"size": _from_cell(size),
		"walls": wall_list,
		"pushable_walls": pushable_wall_list,
		"player": _from_cell(player),
		"pill": _from_cell(pill),
		"ghosts": ghost_list,
		"portals": portal_list,
		"locks": lock_list,
	}


## JSON with one wall / ghost / portal per line, so files stay readable and diffable.
func to_json() -> String:
	var d := to_dict()
	var lines := PackedStringArray()
	for key: String in d:
		var value: Variant = d[key]
		if value is Array and not value.is_empty() and not (value[0] is int):
			var items := PackedStringArray()
			for item: Variant in value:
				items.append("\t\t" + JSON.stringify(item, "", false))
			lines.append("\t%s: [\n%s\n\t]" % [JSON.stringify(key), ",\n".join(items)])
		else:
			lines.append("\t%s: %s" % [JSON.stringify(key), JSON.stringify(value, "", false)])
	return "{\n%s\n}\n" % ",\n".join(lines)


func save_file(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(to_json())
	return OK


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func get_cell(cell: Vector2i) -> int:
	return cells[cell.y * size.x + cell.x] if is_inside(cell) else Cell.EMPTY


## Tile of the walls atlas for a non-empty cell. Walls take their style's tile
## from row 1. Border bricks run across neighbouring border cells, so a border
## cell (row 0) closes them with a half brick only on the sides where the border
## ends: 0 none, 1 left, 2 right, 3 both.
func wall_atlas_coords(cell: Vector2i) -> Vector2i:
	if get_cell(cell) == Cell.WALL or get_cell(cell) == Cell.PUSHABLE:
		return Vector2i(get_wall_style(cell), 1)
	# Border cells
	var cap_left := int(get_cell(cell + Vector2i.LEFT) != Cell.BORDER)
	var cap_right := int(get_cell(cell + Vector2i.RIGHT) != Cell.BORDER)
	return Vector2i(cap_left + cap_right * 2, 0)


func set_cell(cell: Vector2i, value: int) -> void:
	if is_inside(cell):
		cells[cell.y * size.x + cell.x] = value


func get_wall_style(cell: Vector2i) -> int:
	return wall_styles[cell.y * size.x + cell.x] if is_inside(cell) else 0


## Makes the cell a wall of the given style (an index into WALL_STYLE_NAMES).
func set_wall(cell: Vector2i, style: int) -> void:
	if is_inside(cell):
		set_cell(cell, Cell.WALL)
		wall_styles[cell.y * size.x + cell.x] = style


## Makes the cell a pushable wall of the given style.
func set_pushable_wall(cell: Vector2i, style: int) -> void:
	if is_inside(cell):
		set_cell(cell, Cell.PUSHABLE)
		wall_styles[cell.y * size.x + cell.x] = style


func is_blocked(cell: Vector2i) -> bool:
	return not is_inside(cell) or get_cell(cell) != Cell.EMPTY


func ghost_at(cell: Vector2i) -> int:
	for i in ghosts.size():
		if ghosts[i].cell == cell:
			return i
	return -1


func portal_at(cell: Vector2i) -> int:
	for i in portals.size():
		if portals[i].a == cell or portals[i].b == cell:
			return i
	return -1


## Index of the lock whose key or door is at the cell.
func lock_at(cell: Vector2i) -> int:
	for i in locks.size():
		if locks[i].key == cell or locks[i].door == cell:
			return i
	return -1


## Returns an error message, or an empty string when the level can be played.
func validate() -> String:
	if is_blocked(player):
		return "O pac está sobre uma parede ou fora do mapa."
	if is_blocked(pill):
		return "A pílula está sobre uma parede ou fora do mapa."
	if player == pill:
		return "O pac e a pílula estão na mesma célula."
	for portal in portals:
		if is_blocked(portal.a) or is_blocked(portal.b):
			return "Há um portal sobre uma parede ou fora do mapa."
	for lock in locks:
		if is_blocked(lock.key) or is_blocked(lock.door):
			return "Há uma chave ou porta sobre uma parede ou fora do mapa."
		if player in [lock.key, lock.door] or pill in [lock.key, lock.door]:
			return "Há uma chave ou porta sobre o pac ou a pílula."
	return ""


func instantiate() -> Level:
	var level: Level = LEVEL_SCENE.instantiate()
	level.level_bonus = level_bonus
	level.move_sensitivity = move_sensitivity
	level.time_sensitivity = time_sensitivity
	level.instructions = instructions
	level.grid_size = size

	var walls: TileMapLayer = level.get_node("Walls")
	for y in size.y:
		for x in size.x:
			var cell := get_cell(Vector2i(x, y))
			if cell != Cell.EMPTY:
				walls.set_cell(Vector2i(x, y), 0, wall_atlas_coords(Vector2i(x, y)))
				if cell == Cell.PUSHABLE:
					level.pushable_cells[Vector2i(x, y)] = get_wall_style(Vector2i(x, y))

	level.get_node("Player").position = cell_center(player)
	level.get_node("Pill").position = cell_center(pill)

	var ghost_parent := level.get_node("Ghosts")
	for data in ghosts:
		var ghost: Ghost = GHOST_SCENE.instantiate()
		ghost.color = data.color
		ghost.speed = data.speed
		ghost.path = data.path.duplicate()
		ghost.position = cell_center(data.cell)
		ghost_parent.add_child(ghost)

	var portal_parent := level.get_node("Portals")
	for data in portals:
		var a := _create_portal(data.a, data.color, portal_parent)
		var b := _create_portal(data.b, data.color, portal_parent)
		a.partner = b
		b.partner = a

	for data in locks:
		var door: Door = DOOR_SCENE.instantiate()
		door.position = cell_center(data.door)
		door.color = data.color
		# In a vertical wall the halves open up and down, into the wall.
		door.slides_vertically = is_blocked(data.door + Vector2i.UP) or is_blocked(data.door + Vector2i.DOWN)
		level.get_node("Doors").add_child(door)
		var key: Key = KEY_SCENE.instantiate()
		key.position = cell_center(data.key)
		key.modulate = data.color
		key.door = door
		level.get_node("Keys").add_child(key)
	return level


static func _create_portal(cell: Vector2i, color: Color, parent: Node) -> Portal:
	var portal: Portal = PORTAL_SCENE.instantiate()
	portal.position = cell_center(cell)
	portal.modulate = color
	parent.add_child(portal)
	return portal


static func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE_SIZE
