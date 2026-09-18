class_name LevelData
extends RefCounted
## A level as plain data: read from / written to a JSON file and turned into a playable Level.
##
## File format (all cells are [column, row], counted from the top-left corner):
## {
##   "format": "pacmaze-level", "version": 1,
##   "name": "...", "instructions": "...",
##   "scoring": {"level_bonus": 10, "move_sensitivity": 200, "time_sensitivity": 100},
##   "map": ["+++", "+.+", ...],       # "+" border block, "#" wall, "." empty
##   "player": [x, y], "pill": [x, y],
##   "ghosts": [{"color": "blue", "cell": [x, y], "speed": 7.5, "path": [[dx, dy], ...]}],
##   "portals": [{"color": "#ff0000", "a": [x, y], "b": [x, y]}]
## }

enum Cell { EMPTY, WALL, BORDER }

const FORMAT := "pacmaze-level"
const VERSION := 1
const TILE_SIZE := 30
const DEFAULT_SIZE := Vector2i(43, 27)
const CELL_CHARS := {Cell.EMPTY: ".", Cell.WALL: "#", Cell.BORDER: "+"}
const CHAR_CELLS := {".": Cell.EMPTY, "#": Cell.WALL, "+": Cell.BORDER}
const GHOST_COLOR_NAMES := ["blue", "green", "purple", "yellow"]
const DEFAULT_GHOST_SPEED := 7.5

const LEVEL_SCENE := preload("res://scenes/level.tscn")
const GHOST_SCENE := preload("res://scenes/ghost.tscn")
const PORTAL_SCENE := preload("res://scenes/portal.tscn")


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


var name := "Nova fase"
var instructions := ""
var level_bonus := 10
var move_sensitivity := 200
var time_sensitivity := 100
var size := DEFAULT_SIZE
var cells := PackedByteArray()
var player := Vector2i.ZERO
var pill := Vector2i.ZERO
var ghosts: Array[GhostData] = []
var portals: Array[PortalData] = []


## An empty level surrounded by border blocks.
static func create_empty(level_size := DEFAULT_SIZE) -> LevelData:
	var data := LevelData.new()
	data.size = level_size
	data.cells.resize(level_size.x * level_size.y)
	for y in level_size.y:
		for x in level_size.x:
			if x == 0 or y == 0 or x == level_size.x - 1 or y == level_size.y - 1:
				data.set_cell(Vector2i(x, y), Cell.BORDER)
	data.player = Vector2i(1, level_size.y - 2)
	data.pill = Vector2i(level_size.x - 2, 1)
	return data


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
	var rows: Array = d.get("map", [])
	var width := 0
	for row: String in rows:
		width = maxi(width, row.length())
	if rows.is_empty() or width == 0:
		push_warning("Level has no map")
		return null

	var data := LevelData.new()
	data.name = d.get("name", data.name)
	data.instructions = d.get("instructions", "")
	var scoring: Dictionary = d.get("scoring", {})
	data.level_bonus = int(scoring.get("level_bonus", data.level_bonus))
	data.move_sensitivity = int(scoring.get("move_sensitivity", data.move_sensitivity))
	data.time_sensitivity = int(scoring.get("time_sensitivity", data.time_sensitivity))
	data.size = Vector2i(width, rows.size())
	data.cells.resize(width * rows.size())
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			data.set_cell(Vector2i(x, y), CHAR_CELLS.get(row[x], Cell.EMPTY))
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
		var color: String = p.get("color", "#ffffff")
		portal.color = Color.html(color) if Color.html_is_valid(color) else Color.WHITE
		portal.a = _to_cell(p.get("a"), Vector2i.ZERO)
		portal.b = _to_cell(p.get("b"), Vector2i.ZERO)
		data.portals.append(portal)
	return data


static func _to_cell(value: Variant, fallback: Vector2i) -> Vector2i:
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return fallback


static func _from_cell(cell: Vector2i) -> Array:
	return [cell.x, cell.y]


func to_dict() -> Dictionary:
	var rows: Array[String] = []
	for y in size.y:
		var row := ""
		for x in size.x:
			row += CELL_CHARS[get_cell(Vector2i(x, y))]
		rows.append(row)
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
		"map": rows,
		"player": _from_cell(player),
		"pill": _from_cell(pill),
		"ghosts": ghost_list,
		"portals": portal_list,
	}


## JSON with one map row / ghost / portal per line, so files stay readable and diffable.
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


func set_cell(cell: Vector2i, value: int) -> void:
	if is_inside(cell):
		cells[cell.y * size.x + cell.x] = value


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
				walls.set_cell(Vector2i(x, y), 0, Vector2i(0 if cell == Cell.BORDER else 1, 0))

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
	return level


static func _create_portal(cell: Vector2i, color: Color, parent: Node) -> Portal:
	var portal: Portal = PORTAL_SCENE.instantiate()
	portal.position = cell_center(cell)
	portal.modulate = color
	parent.add_child(portal)
	return portal


static func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE_SIZE
