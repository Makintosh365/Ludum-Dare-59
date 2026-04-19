class_name EnemySpawner
extends Node

signal enemies_spawned(enemies: Array[Enemy])

@export var config: EnemySpawnConfig

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]


func _ready() -> void:
	var rule_count := 0
	if config != null and config.rules != null:
		rule_count = config.rules.size()
	GameManager.report_ready("EnemySpawner", "rules=%d" % rule_count)


func spawn(grid: Grid, player_coords: Vector2i, parent: Node) -> Array[Enemy]:
	var result: Array[Enemy] = []
	if grid == null or grid.rng == null:
		push_warning("EnemySpawner: grid/rng not ready")
		return result
	if config == null or config.rules == null or config.rules.is_empty():
		push_warning("EnemySpawner: config missing or has no rules")
		return result

	var dist_from_player := _bfs_distance_map(grid, player_coords)
	if dist_from_player.is_empty():
		push_warning("EnemySpawner: player unreachable (dist_from_player empty)")
		return result

	var placed_any: Array[Vector2i] = []
	var placed_by_type: Dictionary = {}
	var global_index := 0

	for rule_index in range(config.rules.size()):
		var rule: EnemyTypeSpawnRule = config.rules[rule_index]
		if rule == null:
			push_warning("EnemySpawner: rule %d is null, skipping" % rule_index)
			continue
		if not ResourceLoader.exists(rule.enemy_type_path):
			push_warning("EnemySpawner: rule %d loadout missing at %s, skipping" % [rule_index, rule.enemy_type_path])
			continue
		var loadout := load(rule.enemy_type_path) as UnitLoadout
		if loadout == null:
			push_warning("EnemySpawner: rule %d failed to load UnitLoadout at %s" % [rule_index, rule.enemy_type_path])
			continue

		var same_type_cells: Array[Vector2i] = []
		if placed_by_type.has(rule.enemy_type_path):
			same_type_cells = placed_by_type[rule.enemy_type_path]

		for i in range(rule.count):
			var dist_from_any := _multi_source_bfs(grid, placed_any)
			var dist_from_same := _multi_source_bfs(grid, same_type_cells)

			var candidates := _collect_candidates(grid, rule, dist_from_player, dist_from_any, dist_from_same, placed_any.size() > 0, same_type_cells.size() > 0)
			if candidates.is_empty():
				push_warning("EnemySpawner: rule %d ran out of candidates at %d/%d" % [rule_index, i, rule.count])
				break

			var pick_index := grid.rng.randi_range(0, candidates.size() - 1)
			var coords: Vector2i = candidates[pick_index]

			var enemy := Enemy.new()
			enemy.loadout = loadout
			enemy.name = "Enemy_%d" % global_index
			parent.add_child(enemy)
			enemy.place_on(grid, coords)

			var cell := grid.get_cell(coords)
			if cell != null:
				cell.has_enemy = true
				cell.enemy_type = rule.enemy_type_path

			result.append(enemy)
			placed_any.append(coords)
			same_type_cells.append(coords)
			global_index += 1

		placed_by_type[rule.enemy_type_path] = same_type_cells

	print("EnemySpawner: placed %d enemies across %d rule(s)" % [result.size(), config.rules.size()])
	enemies_spawned.emit(result)
	return result


func _collect_candidates(
		grid: Grid,
		rule: EnemyTypeSpawnRule,
		dist_from_player: Dictionary,
		dist_from_any: Dictionary,
		dist_from_same: Dictionary,
		has_any_placed: bool,
		has_same_placed: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in range(grid.width):
		for y in range(grid.height):
			var coords := Vector2i(x, y)
			var cell := grid.get_cell(coords)
			if cell == null or not cell.is_walkable:
				continue
			if coords == grid.start or coords == grid.end:
				continue
			if cell.contents != null or cell.has_enemy or cell.has_boss:
				continue
			if not dist_from_player.has(coords):
				continue
			var d_player: int = dist_from_player[coords]
			if d_player < rule.min_distance_from_player:
				continue
			if rule.max_distance_from_player >= 0 and d_player > rule.max_distance_from_player:
				continue

			if has_any_placed:
				if not dist_from_any.has(coords):
					continue
				var d_any: int = dist_from_any[coords]
				if d_any < rule.min_distance_from_any_enemy:
					continue
				if rule.max_distance_from_any_enemy >= 0 and d_any > rule.max_distance_from_any_enemy:
					continue

			if has_same_placed:
				if not dist_from_same.has(coords):
					continue
				var d_same: int = dist_from_same[coords]
				if d_same < rule.min_distance_from_same_type:
					continue
				if rule.max_distance_from_same_type >= 0 and d_same > rule.max_distance_from_same_type:
					continue

			out.append(coords)
	return out


static func _bfs_distance_map(grid: Grid, origin: Vector2i) -> Dictionary:
	var result: Dictionary = {}
	if not grid.in_bounds(origin):
		return result
	var origin_cell := grid.get_cell(origin)
	if origin_cell == null or not origin_cell.is_walkable:
		return result
	result[origin] = 0
	var queue: Array = [origin]
	while queue.size() > 0:
		var here: Vector2i = queue.pop_front()
		var here_dist: int = result[here]
		for dir in DIRECTIONS:
			var n: Vector2i = here + dir
			if not grid.in_bounds(n) or result.has(n):
				continue
			var cell := grid.get_cell(n)
			if cell == null or not cell.is_walkable:
				continue
			result[n] = here_dist + 1
			queue.push_back(n)
	return result


static func _multi_source_bfs(grid: Grid, sources: Array[Vector2i]) -> Dictionary:
	var result: Dictionary = {}
	if sources.is_empty():
		return result
	var queue: Array = []
	for src in sources:
		if not grid.in_bounds(src):
			continue
		result[src] = 0
		queue.push_back(src)
	while queue.size() > 0:
		var here: Vector2i = queue.pop_front()
		var here_dist: int = result[here]
		for dir in DIRECTIONS:
			var n: Vector2i = here + dir
			if not grid.in_bounds(n) or result.has(n):
				continue
			var cell := grid.get_cell(n)
			if cell == null or not cell.is_walkable:
				continue
			result[n] = here_dist + 1
			queue.push_back(n)
	return result
