extends Node2D
## In-game level editor: paint the maze, place entities and save the level as a JSON file.

enum Tool { WALL, ERASE, PLAYER, PILL, GHOST, ROUTE, PORTAL, KEY, PUSH_WALL }

const PANEL_WIDTH := 320.0
const MARGIN := 24.0
const STATUS_DURATION := 4.0
const TOOL_NAMES := {
	Tool.WALL: "Parede",
	Tool.ERASE: "Apagar",
	Tool.PLAYER: "Pac",
	Tool.PILL: "Pílula",
	Tool.GHOST: "Fantasma",
	Tool.ROUTE: "Rota",
	Tool.PORTAL: "Portal",
	Tool.KEY: "Chave",
	Tool.PUSH_WALL: "Empurrável",
}
const TOOL_HINTS := {
	Tool.WALL: "Clique ou arraste para desenhar paredes no estilo escolhido. Pintar sobre uma parede troca o estilo dela.",
	Tool.ERASE: "Clique ou arraste para apagar paredes, fantasmas, portais, chaves e portas.",
	Tool.PLAYER: "Clique para definir onde o pac começa.",
	Tool.PILL: "Clique para posicionar a pílula, o objetivo da fase.",
	Tool.GHOST: "Clique numa célula para criar um fantasma, ou num fantasma para selecioná-lo. Depois use a ferramenta Rota.",
	Tool.ROUTE: "Clique em células na mesma linha ou coluna do fim da rota (linhas destacadas) para adicionar trechos ao fantasma selecionado. A rota se repete em loop.",
	Tool.PORTAL: "Clique em duas células livres para criar um par de portais.",
	Tool.KEY: "Clique onde fica a chave e depois onde fica a porta. Com a chave da mesma cor, o pac abre a porta empurrando contra ela.",
	Tool.PUSH_WALL: "Clique ou arraste para desenhar paredes empurráveis. O pac pode empurrá-las se insistir na direção, mas não se houver uma parede fixa atrás.",
}
const WALLS_TEXTURE := preload("res://assets/sprites/walls.png")
## Same order as LevelData.WALL_STYLE_NAMES.
const WALL_STYLE_LABELS := [
	"Clássica", "Neon", "Tijolo vermelho", "Gema", "Metal", "Grama",
	"Caixote", "Gelo", "Lava", "Circuito", "Doce",
]
const GHOST_COLOR_LABELS := ["Azul", "Verde", "Roxo", "Amarelo"]
const GHOST_DRAW_COLORS := [
	Color(0.1, 0.75, 0.85),
	Color(0.2, 0.85, 0.3),
	Color(0.75, 0.35, 0.9),
	Color(0.95, 0.85, 0.1),
]
## Fixed palette for portals and keys/doors, so saved levels always use visually distinct colors.
const PAIR_COLOR_LABELS := ["Azul", "Verde", "Vermelho", "Amarelo", "Laranja", "Roxo", "Ciano", "Magenta"]
const PAIR_COLORS := [
	Color(0.15, 0.4, 0.95),
	Color(0.15, 0.8, 0.25),
	Color(0.9, 0.15, 0.15),
	Color(0.95, 0.85, 0.1),
	Color(0.95, 0.55, 0.05),
	Color(0.55, 0.15, 0.85),
	Color(0.05, 0.85, 0.9),
	Color(0.9, 0.1, 0.75),
]

var data: LevelData
var path := ""
var tool := Tool.WALL
var preview: Level
var selected_ghost := -1
## First cell of a portal pair or a key waiting for its second click.
var pending_cell := Vector2i.ZERO
var has_pending := false
var hover_cell := Vector2i(-1, -1)
var pair_color_index := 0
var wall_style_index := 0 ## Style painted by the wall tool, an index into LevelData.WALL_STYLE_NAMES.
var _space_held := false
var _panning := false
var _status_serial := 0
var _tool_buttons := {}
## Only set on the web build, where levels are saved and opened through the browser.
var _web: WebFiles
## The level whose file the browser can overwrite without asking again. Static so it survives test runs.
static var _web_file_owner: LevelData

@onready var camera: Camera2D = $Camera2D
@onready var preview_container: Node2D = $PreviewContainer
@onready var overlay: Node2D = %Overlay
@onready var file_label: Label = %FileLabel
@onready var tool_grid: GridContainer = %ToolGrid
@onready var tool_hint: Label = %ToolHint
@onready var ghost_options: Control = %GhostOptions
@onready var ghost_color: OptionButton = %GhostColor
@onready var ghost_speed: SpinBox = %GhostSpeed
@onready var route_info: Label = %RouteInfo
@onready var pair_options: Control = %PairOptions
@onready var wall_options: Control = %WallOptions
@onready var wall_style: OptionButton = %WallStyle
@onready var pair_color: OptionButton = %PairColor
@onready var name_edit: LineEdit = %NameEdit
@onready var instructions_edit: TextEdit = %InstructionsEdit
@onready var bonus_spin: SpinBox = %BonusSpin
@onready var moves_spin: SpinBox = %MovesSpin
@onready var time_spin: SpinBox = %TimeSpin
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	_build_tool_buttons()
	_build_pair_color_options()
	_build_wall_style_options()
	for i in GHOST_COLOR_LABELS.size():
		ghost_color.add_icon_item(_ghost_icon(i), GHOST_COLOR_LABELS[i])

	%NewButton.pressed.connect(_confirm_new)
	%OpenButton.pressed.connect(_open_dialog.bind(FileDialog.FILE_MODE_OPEN_FILE))
	%SaveButton.pressed.connect(_save)
	%SaveAsButton.pressed.connect(_open_dialog.bind(FileDialog.FILE_MODE_SAVE_FILE))
	%TestButton.pressed.connect(_test)
	%BackButton.pressed.connect(GameState.go_to_main_menu)
	%UndoRouteButton.pressed.connect(_undo_route_step)
	%ClearRouteButton.pressed.connect(_clear_route)
	ghost_color.item_selected.connect(_on_ghost_color_selected)
	ghost_speed.value_changed.connect(_on_ghost_speed_changed)
	pair_color.item_selected.connect(_select_pair_color)
	name_edit.text_changed.connect(func(text: String) -> void: data.name = text)
	wall_style.item_selected.connect(_select_wall_style)
	instructions_edit.text_changed.connect(func() -> void: data.instructions = instructions_edit.text)
	bonus_spin.value_changed.connect(func(value: float) -> void: data.level_bonus = int(value))
	moves_spin.value_changed.connect(func(value: float) -> void: data.move_sensitivity = int(value))
	time_spin.value_changed.connect(func(value: float) -> void: data.time_sensitivity = int(value))
	overlay.draw.connect(_draw_overlay)
	get_viewport().size_changed.connect(_fit_camera)

	if OS.has_feature("web"):
		_web = WebFiles.new()
		_web.saved.connect(_on_web_saved)
		_web.downloaded.connect(_on_web_downloaded)
		_web.opened.connect(_on_web_opened)
		_web.failed.connect(func(message: String) -> void: _show_status("Erro ao acessar o arquivo: %s" % message))

	var initial := GameState.editor_data if GameState.editor_data else LevelData.create_empty()
	_set_data(initial, GameState.editor_path)
	_select_tool(Tool.WALL)


func _unhandled_input(event: InputEvent) -> void:
	# The editor needs a mouse, so a gamepad can at least leave it. Only the gamepad:
	# Esc is too easy to hit by accident while editing.
	if event is InputEventJoypadButton and event.is_action_pressed("ui_cancel"):
		GameState.go_to_main_menu()
		return
	if event is InputEventKey:
		if event.keycode == KEY_SPACE:
			_space_held = event.pressed
			_update_cursor()
		if event.pressed and not event.echo:
			if event.keycode == KEY_S and event.ctrl_pressed:
				_save()
			elif event.keycode >= KEY_1 and event.keycode < KEY_1 + Tool.size():
				_select_tool(event.keycode - KEY_1)
			return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE or (event.button_index == MOUSE_BUTTON_LEFT and _space_held):
			_panning = event.pressed
			_update_cursor()
			return
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_use_tool(_mouse_cell())
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_erase_at(_mouse_cell())
	elif event is InputEventMouseMotion:
		if _panning:
			camera.position -= event.relative / camera.zoom
			return
		var cell := _mouse_cell()
		if cell == hover_cell:
			return
		hover_cell = cell
		overlay.queue_redraw()
		# Dragging paints/erases along the way.
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_erase_at(cell)
		elif event.button_mask & MOUSE_BUTTON_MASK_LEFT and tool in [Tool.WALL, Tool.ERASE, Tool.PUSH_WALL]:
			_use_tool(cell)


func _update_cursor() -> void:
	if _panning:
		Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	elif _space_held:
		Input.set_default_cursor_shape(Input.CURSOR_MOVE)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _mouse_cell() -> Vector2i:
	return Vector2i((get_global_mouse_position() / LevelData.TILE_SIZE).floor())


#region Tools

func _build_tool_buttons() -> void:
	var group := ButtonGroup.new()
	for t: Tool in TOOL_NAMES:
		var button := Button.new()
		button.theme_type_variation = &"ToolButton"
		button.text = TOOL_NAMES[t]
		button.icon = _tool_icon(t)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = "%s (%d)" % [TOOL_NAMES[t], t + 1]
		button.pressed.connect(_select_tool.bind(t))
		# Keyboard shortcut in the corner.
		var shortcut := Label.new()
		shortcut.theme_type_variation = &"ToolKey"
		shortcut.text = str(t + 1)
		shortcut.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		shortcut.position += Vector2(-5, 1)
		button.add_child(shortcut)
		tool_grid.add_child(button)
		_tool_buttons[t] = button


## Tool icons come from the game sprites; erase and route have no sprite, so they are drawn here.
func _tool_icon(t: Tool) -> Texture2D:
	match t:
		Tool.WALL:
			return _atlas_icon(WALLS_TEXTURE, Rect2(0, LevelData.TILE_SIZE, LevelData.TILE_SIZE, LevelData.TILE_SIZE))
		Tool.PLAYER:
			return _atlas_icon(preload("res://assets/sprites/pacman.png"), Rect2(242, 0, 242, 256))
		Tool.PILL:
			return _atlas_icon(preload("res://assets/sprites/pill.png"), Rect2(0, 0, 30, 30))
		Tool.GHOST:
			return _ghost_icon(0)
		Tool.PORTAL:
			return _atlas_icon(preload("res://assets/sprites/portal.png"), Rect2(0, 0, 30, 30))
		Tool.KEY:
			return preload("res://assets/sprites/key.png")
		Tool.PUSH_WALL:
			return _atlas_icon(WALLS_TEXTURE, Rect2(6 * LevelData.TILE_SIZE, LevelData.TILE_SIZE, LevelData.TILE_SIZE, LevelData.TILE_SIZE))
	var image := Image.create(30, 30, false, Image.FORMAT_RGBA8)
	if t == Tool.ERASE:
		var color := Color(0.95, 0.4, 0.4)
		for i in range(7, 23):
			image.fill_rect(Rect2i(i - 1, i - 1, 3, 3), color)
			image.fill_rect(Rect2i(28 - i, i - 1, 3, 3), color)
	else:
		# An L-shaped route with a dot at each end.
		var color := Color(0.1, 0.75, 0.85)
		for x in range(6, 24, 4):
			image.fill_rect(Rect2i(x, 21, 3, 3), color)
		for y in range(7, 22, 4):
			image.fill_rect(Rect2i(21, y, 3, 3), color)
		image.fill_rect(Rect2i(4, 19, 7, 7), Color.WHITE)
		image.fill_rect(Rect2i(19, 4, 7, 7), color)
	return ImageTexture.create_from_image(image)


func _atlas_icon(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var icon := AtlasTexture.new()
	icon.atlas = texture
	icon.region = region
	return icon


func _ghost_icon(color: int) -> AtlasTexture:
	var textures := [
		preload("res://assets/sprites/ghost_blue.png"),
		preload("res://assets/sprites/ghost_green.png"),
		preload("res://assets/sprites/ghost_purple.png"),
		preload("res://assets/sprites/ghost_yellow.png"),
	]
	return _atlas_icon(textures[color], Rect2(0, 0, 30, 30))


func _build_pair_color_options() -> void:
	for i in PAIR_COLORS.size():
		pair_color.add_icon_item(_color_swatch(PAIR_COLORS[i]), PAIR_COLOR_LABELS[i])
	pair_color.select(pair_color_index)


## A small solid-color square used as the icon for each palette entry in the combo box.
func _color_swatch(color: Color) -> ImageTexture:
	var image := Image.create(16, 16, false, Image.FORMAT_RGB8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _select_pair_color(index: int) -> void:
	pair_color_index = index
	overlay.queue_redraw()


func _select_tool(new_tool: Tool) -> void:
	tool = new_tool
	_tool_buttons[tool].button_pressed = true
	tool_hint.text = TOOL_HINTS[tool]
	ghost_options.visible = tool in [Tool.GHOST, Tool.ROUTE]
	pair_options.visible = tool in [Tool.PORTAL, Tool.KEY]
	wall_options.visible = tool in [Tool.WALL, Tool.PUSH_WALL]
	has_pending = false
	overlay.queue_redraw()


func _use_tool(cell: Vector2i) -> void:
	if not data.is_inside(cell):
		return
	match tool:
		Tool.WALL:
			_paint_wall(cell)
		Tool.ERASE:
			_erase_at(cell)
		Tool.PLAYER:
			if _can_place_marker(cell, data.pill):
				data.player = cell
				_rebuild_preview()
		Tool.PILL:
			if _can_place_marker(cell, data.player):
				data.pill = cell
				_rebuild_preview()
		Tool.GHOST:
			_place_or_select_ghost(cell)
		Tool.ROUTE:
			_add_route_step(cell)
		Tool.PORTAL:
			_place_portal(cell)
		Tool.KEY:
			_place_lock(cell)
		Tool.PUSH_WALL:
			_paint_pushable_wall(cell)


func _paint_wall(cell: Vector2i) -> void:
	# Border cells are fixed and can't be overwritten. Walls also can't cover the pac,
	# the pill or a portal; dragging over any of them just skips the cell.
	if data.get_cell(cell) == LevelData.Cell.BORDER:
		return
	if cell == data.player or cell == data.pill or data.portal_at(cell) >= 0 or data.lock_at(cell) >= 0:
		return
	if has_pending and cell == pending_cell:
		return
	data.set_wall(cell, wall_style_index)
	preview.walls.set_cell(cell, 0, data.wall_atlas_coords(cell))


func _paint_pushable_wall(cell: Vector2i) -> void:
	if data.get_cell(cell) == LevelData.Cell.BORDER:
		return
	if cell == data.player or cell == data.pill or data.portal_at(cell) >= 0 or data.lock_at(cell) >= 0:
		return
	if has_pending and cell == pending_cell:
		return
	data.set_pushable_wall(cell, wall_style_index)
	preview.walls.set_cell(cell, 0, data.wall_atlas_coords(cell))


func _erase_at(cell: Vector2i) -> void:
	if not data.is_inside(cell):
		return
	var ghost := data.ghost_at(cell)
	if ghost >= 0:
		data.ghosts.remove_at(ghost)
		if selected_ghost == ghost:
			_select_ghost(-1)
		elif selected_ghost > ghost:
			selected_ghost -= 1
		_rebuild_preview()
		return
	var portal := data.portal_at(cell)
	if portal >= 0:
		data.portals.remove_at(portal)
		_rebuild_preview()
		return
	var lock := data.lock_at(cell)
	if lock >= 0:
		data.locks.remove_at(lock)
		_rebuild_preview()
		return
	if has_pending and cell == pending_cell:
		has_pending = false
		overlay.queue_redraw()
		return
	if data.get_cell(cell) in [LevelData.Cell.WALL, LevelData.Cell.PUSHABLE]:
		data.set_cell(cell, LevelData.Cell.EMPTY)
		preview.walls.erase_cell(cell)


## The pac and the pill need a free cell that isn't a portal nor the other marker.
func _can_place_marker(cell: Vector2i, other: Vector2i) -> bool:
	if data.get_cell(cell) != LevelData.Cell.EMPTY:
		_show_status("Não dá para posicionar sobre uma parede.")
	elif cell == other:
		_show_status("O pac e a pílula precisam ficar em células diferentes.")
	elif data.portal_at(cell) >= 0 or data.lock_at(cell) >= 0 or (has_pending and cell == pending_cell):
		_show_status("Não dá para posicionar sobre um portal, uma chave ou uma porta.")
	else:
		return true
	return false


func _place_or_select_ghost(cell: Vector2i) -> void:
	var existing := data.ghost_at(cell)
	if existing >= 0:
		_select_ghost(existing)
		return
	var ghost := LevelData.GhostData.new()
	ghost.cell = cell
	ghost.color = ghost_color.selected
	ghost.speed = ghost_speed.value
	data.ghosts.append(ghost)
	_select_ghost(data.ghosts.size() - 1)
	_rebuild_preview()


func _add_route_step(cell: Vector2i) -> void:
	var clicked_ghost := data.ghost_at(cell)
	if clicked_ghost >= 0 and clicked_ghost != selected_ghost:
		_select_ghost(clicked_ghost)
		return
	if selected_ghost < 0:
		_show_status("Selecione um fantasma primeiro (clique nele).")
		return
	var ghost := data.ghosts[selected_ghost]
	var end := ghost.path_end()
	if cell == end:
		return
	if cell.x != end.x and cell.y != end.y:
		_show_status("Cada trecho da rota precisa ser horizontal ou vertical.")
		return
	ghost.path.append(cell - end)
	_update_route_info()
	_rebuild_preview()


func _undo_route_step() -> void:
	if selected_ghost >= 0 and not data.ghosts[selected_ghost].path.is_empty():
		data.ghosts[selected_ghost].path.pop_back()
		_update_route_info()
		_rebuild_preview()


func _clear_route() -> void:
	if selected_ghost >= 0:
		data.ghosts[selected_ghost].path.clear()
		_update_route_info()
		_rebuild_preview()


func _place_portal(cell: Vector2i) -> void:
	if not _pick_pair_cell(cell, "Agora clique onde fica o outro portal do par."):
		return
	var portal := LevelData.PortalData.new()
	portal.a = pending_cell
	portal.b = cell
	portal.color = PAIR_COLORS[pair_color_index]
	data.portals.append(portal)
	_rebuild_preview()


func _place_lock(cell: Vector2i) -> void:
	if not _pick_pair_cell(cell, "Agora clique onde fica a porta que esta chave abre."):
		return
	var lock := LevelData.LockData.new()
	lock.key = pending_cell
	lock.door = cell
	lock.color = PAIR_COLORS[pair_color_index]
	data.locks.append(lock)
	_rebuild_preview()


## Portals and keys are placed with two clicks. Returns true on the second one, with the first in pending_cell.
func _pick_pair_cell(cell: Vector2i, next_hint: String) -> bool:
	if data.get_cell(cell) != LevelData.Cell.EMPTY:
		_show_status("Escolha uma célula sem parede.")
		return false
	if data.portal_at(cell) >= 0 or data.lock_at(cell) >= 0:
		_show_status("Esta célula já tem um portal, uma chave ou uma porta.")
		return false
	if cell == data.player or cell == data.pill:
		_show_status("Não dá para colocar sobre o pac ou a pílula.")
		return false
	if not has_pending:
		pending_cell = cell
		has_pending = true
		_show_status(next_hint)
		overlay.queue_redraw()
		return false
	if cell == pending_cell:
		return false
	has_pending = false
	return true

#endregion


#region Ghost selection

func _select_ghost(index: int) -> void:
	selected_ghost = index
	if index >= 0:
		var ghost := data.ghosts[index]
		ghost_color.select(ghost.color)
		ghost_speed.set_value_no_signal(ghost.speed)
	_update_route_info()
	overlay.queue_redraw()


func _on_ghost_color_selected(index: int) -> void:
	if selected_ghost >= 0:
		data.ghosts[selected_ghost].color = index
		_rebuild_preview()


func _on_ghost_speed_changed(value: float) -> void:
	if selected_ghost >= 0:
		data.ghosts[selected_ghost].speed = value


func _update_route_info() -> void:
	if selected_ghost < 0:
		route_info.text = "Nenhum fantasma selecionado."
		return
	var ghost := data.ghosts[selected_ghost]
	var text := "Rota com %d trecho(s)." % ghost.path.size()
	if ghost.path_end() != ghost.cell:
		text += " A rota não volta ao início, então o fantasma se desloca a cada volta."
	route_info.text = text

#endregion


#region Level data and preview

func _set_data(new_data: LevelData, new_path: String) -> void:
	data = new_data
	path = new_path
	GameState.editor_data = data
	GameState.editor_path = path
	has_pending = false
	_select_ghost(-1)
	name_edit.text = data.name
	instructions_edit.text = data.instructions
	bonus_spin.set_value_no_signal(data.level_bonus)
	moves_spin.set_value_no_signal(data.move_sensitivity)
	time_spin.set_value_no_signal(data.time_sensitivity)
	_update_file_label()
	_rebuild_preview()
	_fit_camera()


## Each option shows its wall tile, taken from the walls atlas.
func _build_wall_style_options() -> void:
	var tile := float(LevelData.TILE_SIZE)
	for i in WALL_STYLE_LABELS.size():
		var icon := AtlasTexture.new()
		icon.atlas = WALLS_TEXTURE
		icon.region = Rect2(i * tile, tile, tile, tile)
		wall_style.add_icon_item(icon, WALL_STYLE_LABELS[i])
	wall_style.select(wall_style_index)


func _select_wall_style(index: int) -> void:
	wall_style_index = index


func _rebuild_preview() -> void:
	if preview:
		preview_container.remove_child(preview)
		preview.queue_free()
	preview = data.instantiate()
	# Frozen: ghosts and animations stay still while editing.
	preview.process_mode = Node.PROCESS_MODE_DISABLED
	preview_container.add_child(preview)
	overlay.queue_redraw()


func _fit_camera() -> void:
	var view := get_viewport_rect().size
	var area := Vector2(view.x - PANEL_WIDTH, view.y) - Vector2(MARGIN, MARGIN) * 2
	var grid := Vector2(data.size) * LevelData.TILE_SIZE
	var zoom := minf(area.x / grid.x, area.y / grid.y)
	camera.zoom = Vector2(zoom, zoom)
	# Center the map in the area left of the side panel.
	camera.position = grid / 2 + Vector2(PANEL_WIDTH / 2 / zoom, 0)


func _draw_overlay() -> void:
	var tile := float(LevelData.TILE_SIZE)
	var grid := Vector2(data.size) * tile
	var grid_color := Color(1, 1, 1, 0.07)
	for x in data.size.x + 1:
		overlay.draw_line(Vector2(x * tile, 0), Vector2(x * tile, grid.y), grid_color)
	for y in data.size.y + 1:
		overlay.draw_line(Vector2(0, y * tile), Vector2(grid.x, y * tile), grid_color)

	for portal in data.portals:
		overlay.draw_dashed_line(_center(portal.a), _center(portal.b), Color(portal.color, 0.5), 2.0, 8.0)
	for lock in data.locks:
		overlay.draw_dashed_line(_center(lock.key), _center(lock.door), Color(lock.color, 0.5), 2.0, 4.0)
	if has_pending:
		overlay.draw_rect(_cell_rect(pending_cell), PAIR_COLORS[pair_color_index], false, 3.0)

	# Mark pushable walls with a small arrows icon so they're visually distinct.
	var push_color := Color(1, 1, 0.3, 0.8)
	for y in data.size.y:
		for x in data.size.x:
			if data.get_cell(Vector2i(x, y)) == LevelData.Cell.PUSHABLE:
				var center := _center(Vector2i(x, y))
				var s := LevelData.TILE_SIZE * 0.2
				# Four small arrows pointing outward.
				for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
					var tip: Vector2 = center + dir * (s * 1.6)
					var base: Vector2 = center + dir * (s * 0.4)
					overlay.draw_line(base, tip, push_color, 2.0)

	if tool == Tool.ROUTE and selected_ghost >= 0:
		var end := data.ghosts[selected_ghost].path_end()
		var band := Color(1, 1, 1, 0.08)
		overlay.draw_rect(Rect2(0, end.y * tile, grid.x, tile), band)
		overlay.draw_rect(Rect2(end.x * tile, 0, tile, grid.y), band)

	for i in data.ghosts.size():
		_draw_ghost_route(data.ghosts[i], i == selected_ghost)

	if data.is_inside(hover_cell):
		overlay.draw_rect(_cell_rect(hover_cell), Color(1, 1, 1, 0.5), false, 2.0)


func _draw_ghost_route(ghost: LevelData.GhostData, selected: bool) -> void:
	var color: Color = GHOST_DRAW_COLORS[ghost.color]
	var points := PackedVector2Array([_center(ghost.cell)])
	var cell := ghost.cell
	for move in ghost.path:
		cell += move
		points.append(_center(cell))
	if points.size() > 1:
		overlay.draw_polyline(points, Color(color, 0.9 if selected else 0.45), 3.0 if selected else 2.0)
		for i in range(1, points.size()):
			overlay.draw_circle(points[i], 4.0, color)
	if selected:
		overlay.draw_rect(_cell_rect(ghost.cell).grow(2), Color.WHITE, false, 2.0)


func _center(cell: Vector2i) -> Vector2:
	return LevelData.cell_center(cell)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell) * LevelData.TILE_SIZE, Vector2.ONE * LevelData.TILE_SIZE)

#endregion


#region Files

func _confirm_new() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Nova fase"
	dialog.dialog_text = "Descartar a fase atual e começar uma nova?"
	dialog.ok_button_text = "Descartar"
	dialog.cancel_button_text = "Cancelar"
	dialog.confirmed.connect(func() -> void: _set_data(LevelData.create_empty(), ""))
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible:
			dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


func _open_dialog(mode: FileDialog.FileMode) -> void:
	var saving := mode == FileDialog.FILE_MODE_SAVE_FILE
	if _web:
		if saving:
			_web.save(data.to_json(), _file_name_for(data.name), true)
		else:
			_web.open()
		return
	var title := "Salvar fase" if saving else "Abrir fase"
	var start_dir := ProjectSettings.globalize_path(GameState.USER_LEVELS_DIR)
	var file_name := _file_name_for(data.name) if saving else ""
	var filters := PackedStringArray(["*.json ; Fase do Pacmaze"])
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		var native_mode := DisplayServer.FILE_DIALOG_MODE_SAVE_FILE if saving else DisplayServer.FILE_DIALOG_MODE_OPEN_FILE
		DisplayServer.file_dialog_show(title, start_dir, file_name, false, native_mode, filters,
			func(status: bool, paths: PackedStringArray, _filter: int) -> void:
				if status and not paths.is_empty():
					(_write if saving else _load).call_deferred(paths[0]))
		return
	var dialog := FileDialog.new()
	dialog.title = title
	dialog.file_mode = mode
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = filters
	dialog.current_dir = start_dir
	dialog.current_file = file_name
	dialog.file_selected.connect(_write if saving else _load)
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible:
			dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(900, 560))


func _save() -> void:
	if _web:
		_web.save(data.to_json(), _file_name_for(data.name), _web_file_owner != data)
	# Campaign files live inside the game package, which is read-only once exported.
	elif path.is_empty() or path.begins_with("res://"):
		_open_dialog(FileDialog.FILE_MODE_SAVE_FILE)
	else:
		_write(path)


func _write(target: String) -> void:
	if target.get_extension() != "json":
		target += ".json"
	var error := data.save_file(target)
	if error != OK:
		_show_status("Não foi possível salvar: %s" % error_string(error))
		return
	_set_path(target)
	_show_status("Fase salva.")


func _load(source: String) -> void:
	var loaded := LevelData.load_file(source)
	if loaded == null:
		_show_status("Não foi possível abrir: o arquivo não é uma fase válida.")
		return
	_set_data(loaded, source)
	_show_status("Fase aberta.")


func _set_path(new_path: String) -> void:
	path = new_path
	GameState.editor_path = path
	_update_file_label()


func _on_web_saved(file_name: String) -> void:
	_web_file_owner = data
	_after_web_save(file_name, "Fase salva.")


func _on_web_downloaded(file_name: String) -> void:
	_after_web_save(file_name, "Fase baixada para a pasta de downloads.")


## A copy also goes to the browser storage, so the level shows up in the level select screen.
func _after_web_save(file_name: String, message: String) -> void:
	data.save_file(GameState.USER_LEVELS_DIR.path_join(file_name))
	_set_path(file_name)
	_show_status(message)


func _on_web_opened(file_name: String, text: String) -> void:
	var loaded := LevelData.from_json(text)
	if loaded == null:
		_show_status("Não foi possível abrir: o arquivo não é uma fase válida.")
		return
	_web.accept_opened()
	_web_file_owner = loaded
	_set_data(loaded, file_name)
	_show_status("Fase aberta.")


func _test() -> void:
	var problem := data.validate()
	if not problem.is_empty():
		_show_status(problem)
		return
	GameState.test_level(data, path)


func _update_file_label() -> void:
	file_label.text = "Arquivo: %s" % (path.get_file() if not path.is_empty() else "(não salvo)")
	file_label.tooltip_text = path


static func _file_name_for(level_name: String) -> String:
	var base := level_name.strip_edges().to_lower().replace(" ", "_").validate_filename()
	return (base if not base.is_empty() else "fase") + ".json"

#endregion


func _show_status(message: String) -> void:
	_status_serial += 1
	var serial := _status_serial
	status_label.text = message
	await get_tree().create_timer(STATUS_DURATION).timeout
	if serial == _status_serial:
		status_label.text = ""
