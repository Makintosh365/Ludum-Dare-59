class_name BossSpawner
extends Node

signal bosses_spawned(bosses: Array[Boss])

@export var config: BossSpawnConfig

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]


func _ready() -> void:
	var count := 0
	if config != null:
		count = config.boss_count
	GameManager.report_ready("BossSpawner", "count=%d" % count)


func spawn(grid: Grid, _player_coords: Vector2i, parent: Node) -> Array[Boss]:
	var result: Array[Boss] = []
	if grid == null or grid.rng == null:
		push_warning("BossSpawner: grid/rng not ready")
		return result
	if config == null:
		push_warning("BossSpawner: config missing")
		return result
	if config.boss_count <= 0:
		return result
	if not ResourceLoader.exists(config.boss_loadout_path):
		push_warning("BossSpawner: boss loadout missing at %s" % config.boss_loadout_path)
		return result
	var loadout := load(config.boss_loadout_path) as UnitLoadout
	if loadout == null:
		push_warning("BossSpawner: failed to load UnitLoadout at %s" % config.boss_loadout_path)
		return result

	var dist_from_start := _bfs_distance_map(grid, grid.start)
	if dist_from_start.is_empty():
		push_warning("BossSpawner: start unreachable (dist_from_start empty)")
		return result

	var max_dist := 0
	for d in dist_from_start.values():
		if d > max_dist:
			max_dist = d

	var targets := _compute_target_distances(max_dist, config.boss_count)
	if targets.is_empty():
		push_warning("BossSpawner: path too short to place bosses (max_dist=%d)" % max_dist)
		return result
	var placed_coords: Array[Vector2i] = []

	for i in range(targets.size()):
		var target: int = targets[i]
		var dist_from_placed := _multi_source_bfs(grid, placed_coords)
		var coords := _pick_coords(grid, dist_from_start, dist_from_placed, target, placed_coords.size() > 0)
		if coords.x < 0:
			push_warning("BossSpawner: ran out of candidates at %d/%d (target=%d)" % [i, config.boss_count, target])
			break

		var boss := Boss.new()
		boss.loadout = loadout
		boss.name = "Boss_%d" % i
		parent.add_child(boss)
		boss.place_on(grid, coords)

		var cell := grid.get_cell(coords)
		if cell != null:
			cell.has_boss = true

		result.append(boss)
		placed_coords.append(coords)
		print("BossSpawner: placed boss %d at %s (dist_from_start=%d, target=%d)" % [i, coords, dist_from_start.get(coords, -1), target])

	print("BossSpawner: placed %d boss(es) (requested %d)" % [result.size(), config.boss_count])
	bosses_spawned.emit(result)
	return result


static func _compute_target_distances(max_dist: int, count: int) -> Array[int]:
	var out: Array[int] = []
	if count <= 0 or max_dist <= 0:
		return out
	for i in range(count):
		var t: int = int(round(float(max_dist) * float(i + 1) / float(count + 1)))
		out.append(t)
	return out


func _pick_coords(
		grid: Grid,
		dist_from_start: Dictionary,
		dist_from_placed: Dictionary,
		target: int,
		has_any_placed: bool) -> Vector2i:
	var candidates := _collect_candidates(grid, dist_from_start, dist_from_placed, has_any_placed)
	if candidates.is_empty():
		return Vector2i(-1, -1)

	var best_diff: int = -1
	var best_coords: Array[Vector2i] = []
	for coords in candidates:
		var d_start: int = dist_from_start[coords]
		var diff: int = absi(d_start - target)
		if best_diff < 0 or diff < best_diff:
			best_diff = diff
			best_coords = [coords]
		elif diff == best_diff:
			best_coords.append(coords)

	var pick_index := grid.rng.randi_range(0, best_coords.size() - 1)
	return best_coords[pick_index]


func _collect_candidates(
		grid: Grid,
		dist_from_start: Dictionary,
		dist_from_placed: Dictionary,
		has_any_placed: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in range(grid.width):
		for y in range(grid.height):
			var coords := Vector2i(x, y)
			var cell := grid.get_cell(coords)
			if cell == null or not cell.is_walkable:
				continue
			if coords == grid.start or coords == grid.end:
				continue
			if cell.contents != null or cell.has_enemy or cell.has_boss or cell.has_chest:
				continue
			if not dist_from_start.has(coords):
				continue

			var d_start: int = dist_from_start[coords]
			if d_start < config.min_distance_from_start:
				continue
			if config.max_distance_from_start >= 0 and d_start > config.max_distance_from_start:
				continue

			if has_any_placed:
				if not dist_from_placed.has(coords):
					continue
				var d_placed: int = dist_from_placed[coords]
				if d_placed < config.min_distance_between_bosses:
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
