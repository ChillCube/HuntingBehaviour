extends State
class_name TopDownHuntingBehaviour

var mover : TopDownMovement
var direction : Vector2 = Vector2.RIGHT
@export var prey : Node2D ## The target node this enemy will hunt
@export var view_radius : float = 300.0 ## Maximum distance at which the enemy can see the prey
@export var view_angle : float = 360.0 ## Field-of-view cone in degrees (360 = omnidirectional)
@export var speed : float = 100.0 ## Movement speed passed to the TopDownMovement component
@export var max_sight_chain : int = 3 ## Number of ray-cast waypoints built when sight is lost (higher = smarter pathing around obstacles)
@export var enable_wander_off : bool = true ## If true, enemy wanders briefly before returning to its previous state when it loses sight
@export var wander_duration : float = 1.5 ## How many seconds the enemy continues in the last-known direction before giving up
var last_known_position : Vector2 = Vector2.ZERO
var has_seen_player : bool = false
var _waypoint_chain : Array[Vector2] = []
var _chain_built : bool = false
var _rebuilds_left : int = 0
var _wandering_off : bool = false
var _wander_start_time : float = 0.0
var _collision_radius : float = 0.0

func _ready():
	super()
	call_deferred("_setup")

func _setup():
	mover = _get_or_create_mover()
	_collision_radius = _read_collision_radius()

func _get_or_create_mover() -> TopDownMovement:
	for child in get_parent().get_children():
		if child is TopDownMovement:
			return child
	var _mover = TopDownMovement.new()
	_mover.name = "TopDownMovement"
	_mover.speed = speed
	get_parent().add_child(_mover)
	return _mover

func _read_collision_radius() -> float:
	for child in get_parent().get_children():
		if not child is CollisionShape2D or child.shape == null:
			continue
		if child.shape is CircleShape2D:
			return child.shape.radius
		if child.shape is CapsuleShape2D:
			return child.shape.radius
		if child.shape is RectangleShape2D:
			return minf(child.shape.size.x, child.shape.size.y) * 0.5
	return 0.0

func _cast_ray(from: Vector2, to: Vector2, extra_exclude: Array = []) -> Dictionary:
	var space_state = get_parent().get_world_2d().direct_space_state
	var exclude : Array[RID] = []
	exclude.append(get_parent().get_rid())
	for node in extra_exclude:
		if node and node.has_method("get_rid"):
			exclude.append(node.get_rid())
	var query = PhysicsRayQueryParameters2D.create(from, to, 0xFFFFFFFF)
	query.exclude = exclude
	return space_state.intersect_ray(query)

func can_see_player() -> bool: ## Returns true if prey is within view_radius, inside the view_angle cone, and not blocked by geometry
	if prey == null:
		return false

	var enemy = get_parent()
	var to_player = prey.global_position - enemy.global_position
	if to_player.length() > view_radius:
		return false

	if view_angle < 360.0:
		var facing = direction if direction != Vector2.ZERO else Vector2.RIGHT
		var angle_to_player = rad_to_deg(acos(clamp(facing.normalized().dot(to_player.normalized()), -1.0, 1.0)))
		if angle_to_player > view_angle * 0.5:
			return false

	var result = _cast_ray(enemy.global_position, prey.global_position)
	return result.is_empty() or result.get("collider") == prey

func _build_waypoint_chain():
	_waypoint_chain.clear()
	_waypoint_chain.append(last_known_position)
	var origin = last_known_position
	for i in max_sight_chain:
		var result = _cast_ray(origin, prey.global_position)
		if result.is_empty() or result.get("collider") == prey:
			_waypoint_chain.append(prey.global_position)
			break
		var ray_dir = (result["position"] - origin).normalized()
		_waypoint_chain.append(result["position"])
		origin = result["position"]
	_chain_built = true

func _steer_away_from_walls(desired: Vector2) -> Vector2:
	if desired == Vector2.ZERO or _collision_radius <= 0.0:
		return desired

	var origin = get_parent().global_position
	var perp = desired.orthogonal().normalized()
	var look_dist = maxf(_collision_radius * 2.0, 40.0)
	var look_vec = desired.normalized() * look_dist

	var steer = Vector2.ZERO
	var left = _cast_ray(origin + perp * _collision_radius, origin + perp * _collision_radius + look_vec, [prey])
	var right = _cast_ray(origin - perp * _collision_radius, origin - perp * _collision_radius + look_vec, [prey])

	if not left.is_empty():
		var dist = (origin + perp * _collision_radius).distance_to(left["position"])
		steer -= perp * (1.0 - dist / look_dist)
	if not right.is_empty():
		var dist = (origin - perp * _collision_radius).distance_to(right["position"])
		steer += perp * (1.0 - dist / look_dist)

	return (desired + steer).normalized() if steer != Vector2.ZERO else desired

func _move_toward(target: Vector2):
	direction = _steer_away_from_walls((target - get_parent().global_position).normalized())
	mover.request_movement(direction)

func _start_wander_off():
	if not enable_wander_off:
		mover.request_movement(Vector2.ZERO)
		has_seen_player = false
		return_to_previous()
		return
	_wandering_off = true
	_wander_start_time = Time.get_ticks_msec() / 1000.0

func process_behaviour(): ## Each frame: pursue prey when visible, follow waypoints when sight is lost, wander off when chain exhausted
	if prey == null:
		on = false
		return
	if mover == null:
		return

	if _wandering_off:
		if Time.get_ticks_msec() / 1000.0 - _wander_start_time >= wander_duration:
			_wandering_off = false
			mover.request_movement(Vector2.ZERO)
			has_seen_player = false
			return_to_previous()
			return
		direction = _steer_away_from_walls(direction)
		mover.request_movement(direction)
		return

	if can_see_player():
		last_known_position = prey.global_position
		has_seen_player = true
		_chain_built = false
		_rebuilds_left = max_sight_chain
		_wandering_off = false
		_waypoint_chain.clear()
		_move_toward(prey.global_position)
		return

	if not has_seen_player:
		mover.request_movement(Vector2.ZERO)
		return

	if not _chain_built:
		_build_waypoint_chain()

	if _waypoint_chain.is_empty():
		_start_wander_off()
		return

	var target = _waypoint_chain[0]
	if get_parent().global_position.distance_to(target) < 15.0:
		_waypoint_chain.remove_at(0)
		if _waypoint_chain.is_empty():
			if _rebuilds_left > 0:
				_rebuilds_left -= 1
				last_known_position = get_parent().global_position
				_chain_built = false
				return
			_start_wander_off()
			return
		target = _waypoint_chain[0]

	_move_toward(target)
