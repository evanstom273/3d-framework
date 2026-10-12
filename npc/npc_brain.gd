class_name NPCBrain
extends RefCounted
## What an NPC decides to do: an obliging, unflappable assistant.
##   IDLE       stand about, ready to help (breathing, glancing round)
##   ATTEND     the player's close: turn to face them and pay attention
##   POTTER     now and then, wander a few steps somewhere nearby
##   FOLLOW     asked to follow: keep a polite distance behind the player
##   FLINCH     just been hit: a wince, then...
##   STEP_BACK  ...a pace or two back from whatever hit him, and carry on
## No running away. Knocked over, getting up and dead are handled by
## NPCCharacter / NPCRagdoll.
##
## Movement follows routes on the scene's navmesh (NPCNavigation), which knows
## the walls, stairs and furniture; doors on the way are opened as he reaches
## them, and a locked one is blocked off so the next route goes round. Until the
## navmesh is baked (or if there's no route) he falls back to steering: the
## player's footsteps when following, and destinations a body-sized shape can
## slide straight to when pottering. Either way, if he gets nowhere for a while
## he gives up on that destination instead of grinding against it.

enum State { IDLE, ATTEND, POTTER, FOLLOW, FLINCH, STEP_BACK }

const ATTEND_DISTANCE := 3.2
## Following: how close he keeps, and when he sets off after the player.
const FOLLOW_NEAR := 1.8
const FOLLOW_FAR := 3.0
const BODY_RADIUS := 0.28
const BODY_HEIGHT := 1.5

var npc: NPCCharacter
var state := State.IDLE
var timer := 3.0
var target := Vector3.INF
var following := false
var _heading := Vector3.ZERO
var _stuck_time := 0.0
var _last_position := Vector3.ZERO
var _careful_cooldown := 0.0
var _door_cooldown := 0
## A door he's just opened, while it swings: he keeps out of its way.
var _swing_door: Node
var _swing_centre := Vector3.ZERO
var _swing_until := 0
var _swing_last := INF
var _swing_from := Vector3.ZERO
var _sees_until := 0
var _sees_last := true
## While following: the player's footsteps (oldest first), so he goes the way
## they went (up stairs, round corners, through doors) without a navmesh.
var _trail: Array[Vector3] = []
const CRUMB_SPACING := 0.6
const MAX_CRUMBS := 80
var _rng := RandomNumberGenerator.new()
## The navmesh route being walked (corner points) and where it leads.
var _nav: NPCNavigation
var _route := PackedVector3Array()
var _route_index := 0
var _route_goal := Vector3.INF
var _route_age := 0.0
var _route_stuck := 0
var _headway := 0.0
var _unstick_until := 0
var _unstick_direction := Vector3.ZERO
## A locked door was found: wait for the mesh without it, then plan again.
var _replan_after_bake := false
var _bakes_seen := 0
## Door node -> [bottom, height] of its leaves (as first seen).
var _door_shapes: Dictionary = {}


func _init(owner: NPCCharacter) -> void:
	npc = owner
	_rng.randomize()
	timer = _rng.randf_range(2.0, 5.0)


## Hit by something coming from `from`: wince, then step back from it.
func hit(from: Vector3) -> void:
	var away := npc.global_position - from
	away.y = 0.0
	if away.length() < 0.05:
		away = npc.global_basis.z
	target = npc.global_position + away.normalized() * 0.9
	if not _clear_path(npc.global_position, target):
		target = Vector3.INF
	_enter(State.FLINCH, 0.5)


## Desired horizontal velocity for this frame.
func update(delta: float) -> Vector3:
	timer -= delta
	_careful_cooldown -= delta
	_route_age += delta
	if _nav == null or not is_instance_valid(_nav):
		_nav = NPCNavigation.for_scene(npc)
	var player := npc.find_player()
	var player_pos := player.global_position if player != null else Vector3.INF
	var distance := npc.global_position.distance_to(player_pos) if player != null else INF
	npc.rig.look_at = Vector3.INF
	npc.rig.panic = false
	npc.rig.guard = false
	# A tool waved about up close: clipboard up, and a polite word.
	if distance < 1.8 and _player_armed(player) and state != State.FLINCH:
		npc.rig.guard = true
		if _careful_cooldown <= 0.0:
			_careful_cooldown = 8.0
			npc.bark("careful")
	if following and player != null:
		_drop_crumb(player_pos)
	var speed := npc.definition.walk_speed * npc.speed_factor()
	match state:
		State.IDLE:
			if following and (distance > FOLLOW_FAR or distance > 1.0 and not _sees(player_pos)):
				_enter(State.FOLLOW, 0.0)
			elif distance < ATTEND_DISTANCE:
				_enter(State.ATTEND, 0.0)
			elif timer <= 0.0 and not following:
				_choose_potter()
			return _move(Vector3.ZERO, 0.0, delta)
		State.ATTEND:
			npc.rig.look_at = player_pos + Vector3.UP * 1.55
			npc.face_towards(player_pos, delta, 3.0)
			if following and (distance > FOLLOW_FAR or distance > 1.0 and not _sees(player_pos)):
				_enter(State.FOLLOW, 0.0)
			elif distance > ATTEND_DISTANCE + 1.0:
				_enter(State.IDLE, _rng.randf_range(4.0, 9.0))
			return _move(Vector3.ZERO, 0.0, delta)
		State.POTTER:
			if distance < ATTEND_DISTANCE:
				_enter(State.ATTEND, 0.0)
				return _move(Vector3.ZERO, 0.0, delta)
			return _go(target, speed * 0.8, delta, State.IDLE)
		State.FOLLOW:
			if not following:
				_enter(State.IDLE, 2.0)
				return _move(Vector3.ZERO, 0.0, delta)
			npc.rig.look_at = player_pos + Vector3.UP * 1.55
			if distance < FOLLOW_NEAR and absf(player_pos.y - npc.global_position.y) < 0.5 and _sees(player_pos):
				_enter(State.ATTEND, 0.0)
				return _move(Vector3.ZERO, 0.0, delta)
			# A walk close by, trotting up toward his run speed the further behind he is.
			var catch_up := clampf((distance - FOLLOW_FAR) / 4.0, 0.0, 1.0)
			var pace := lerpf(npc.definition.walk_speed, npc.definition.run_speed, catch_up) * npc.speed_factor()
			var routed: Variant = _route_step(player_pos, pace, delta)
			if routed != null:
				return routed
			return _follow_trail(player_pos, pace, delta)
		State.FLINCH:
			npc.rig.flinch = 1.0
			if timer <= 0.0:
				_enter(State.STEP_BACK, 1.2)
			return _move(Vector3.ZERO, 0.0, delta)
		State.STEP_BACK:
			npc.rig.look_at = player_pos + Vector3.UP * 1.55
			if not target.is_finite() or timer <= 0.0:
				_enter(State.ATTEND if distance < ATTEND_DISTANCE else State.IDLE, _rng.randf_range(3.0, 6.0))
				return _move(Vector3.ZERO, 0.0, delta)
			# Backing off while still facing the trouble.
			var v := _go(target, speed * 0.7, delta, State.ATTEND)
			if player != null:
				npc.face_towards(player_pos, delta, 6.0)
			return v
	return Vector3.ZERO


## Whether he can see the player (not just near them through a wall).
## Checked a few times a second.
func _sees(player_pos: Vector3) -> bool:
	var now := Time.get_ticks_msec()
	if now < _sees_until:
		return _sees_last
	_sees_until = now + 250
	var space := npc.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(npc.global_position + Vector3.UP * 1.4, player_pos + Vector3.UP * 1.2, 1)
	var exclude := npc.own_rids()
	var player := npc.find_player() as CollisionObject3D
	if player != null:
		exclude.append(player.get_rid())
	query.exclude = exclude
	_sees_last = space.intersect_ray(query).is_empty()
	return _sees_last


## Asked by the player (E menu).
func set_following(value: bool) -> void:
	following = value
	_trail.clear()
	_enter(State.FOLLOW if value else State.ATTEND, 0.0)


func _enter(next: State, seconds: float) -> void:
	state = next
	timer = seconds
	_stuck_time = 0.0
	_last_position = npc.global_position
	_route.clear()
	_route_stuck = 0


## Walks toward `goal`; `done` is the state once there (or given up).
func _go(goal: Vector3, speed: float, delta: float, done: State) -> Vector3:
	if not goal.is_finite():
		_enter(done, _rng.randf_range(4.0, 9.0))
		return _move(Vector3.ZERO, 0.0, delta)
	var to_goal := goal - npc.global_position
	to_goal.y = 0.0
	if to_goal.length() < 0.35:
		_enter(done, _rng.randf_range(5.0, 12.0))
		return _move(Vector3.ZERO, 0.0, delta)
	var routed: Variant = _route_step(goal, speed, delta)
	if routed != null:
		# Route walked to its end without arriving: as near as he can get.
		if _route_index >= _route.size() and not _replan_after_bake:
			_enter(done, _rng.randf_range(4.0, 9.0))
		return routed
	# Getting nowhere: drop it rather than shuffle against something.
	if npc.global_position.distance_to(_last_position) > 0.12:
		_last_position = npc.global_position
		_stuck_time = 0.0
	else:
		_stuck_time += delta
		if _stuck_time > 1.0 and _free_from_door():
			_stuck_time = 0.0
		elif _stuck_time > 1.0:
			_enter(done, _rng.randf_range(3.0, 6.0))
			return _move(Vector3.ZERO, 0.0, delta)
	var dodge: Variant = _door_escape(speed, delta)
	if dodge != null:
		return dodge
	_open_door_ahead(to_goal.normalized())
	return _move(_avoid(to_goal.normalized()), speed, delta)


## Smooths the heading so he doesn't twitch between directions.
func _move(direction: Vector3, speed: float, delta: float, turn := 4.0) -> Vector3:
	if speed <= 0.0 or direction.is_zero_approx():
		_heading = _heading.lerp(Vector3.ZERO, minf(delta * 8.0, 1.0))
	else:
		_heading = _heading.lerp(direction * speed, minf(delta * turn, 1.0))
	return _heading


## Walks the navmesh route to `goal`, planning (and replanning as the goal
## moves) as needed. Null when there's no navmesh to plan with, or he keeps
## getting stuck on it: the caller falls back to plain steering.
func _route_step(goal: Vector3, speed: float, delta: float) -> Variant:
	if _nav == null or not _nav.is_ready or _route_stuck >= 3:
		return null
	# A locked door turned up: wait for the mesh without it, then go round.
	if _replan_after_bake:
		if _nav.is_baking():
			return _move(Vector3.ZERO, 0.0, delta)
		_replan_after_bake = false
		_route.clear()
	# The mesh has changed (a door opened, something moved): plan afresh.
	if _nav.bakes != _bakes_seen:
		_bakes_seen = _nav.bakes
		_route.clear()
	var moved := goal.distance_to(_route_goal) if _route_goal.is_finite() else INF
	if _route.is_empty() or moved > 3.0 or moved > 0.5 and _route_age > 0.5 or _route_age > 3.0:
		_route = _nav.path(npc.global_position, goal)
		_route_index = 1
		_route_goal = goal
		_route_age = 0.0
		if _route.size() < 2:
			_route.clear()
			return null
	var here := npc.global_position
	while _route_index < _route.size():
		var corner := _route[_route_index]
		if Vector2(corner.x - here.x, corner.z - here.z).length() < 0.35 and absf(corner.y - here.y) < 1.0:
			_route_index += 1
		else:
			break
	if _route_index >= _route.size():
		_stuck_time = 0.0
		return _move(Vector3.ZERO, 0.0, delta)
	var to_corner := _route[_route_index] - here
	to_corner.y = 0.0
	var direction := to_corner.normalized()
	# Bumped into something: a step back off it before trying again.
	if Time.get_ticks_msec() < _unstick_until:
		return _move(_unstick_direction, npc.definition.walk_speed * 0.8, delta, 10.0)
	if here.distance_to(_last_position) > 0.12:
		_last_position = here
		_stuck_time = 0.0
		# Making headway again: forget earlier trouble.
		_headway += 0.12
		if _headway > 1.5:
			_route_stuck = 0
	else:
		_stuck_time += delta
		if _stuck_time > 0.8:
			_stuck_time = 0.0
			if _free_from_door():
				return _move(Vector3.ZERO, 0.0, delta)
			# Something's in the way that the mesh didn't know about (moved
			# since the bake): back off it, rebake, and plan again.
			_headway = 0.0
			_route_stuck += 1
			_route.clear()
			_nav.request_rebake()
			var bump := npc.get_last_slide_collision()
			_unstick_direction = -direction
			if bump != null:
				var normal := bump.get_normal()
				normal.y = 0.0
				if normal.length() > 0.3:
					_unstick_direction = (normal.normalized() - direction * 0.5).normalized()
			_unstick_until = Time.get_ticks_msec() + 450
	# Round the next corner too: a door there is opened before he's beside it
	# (and can swing into him).
	if _route_index + 1 < _route.size() and to_corner.length() < 1.6:
		var corner := _route[_route_index]
		var onward := _route[_route_index + 1] - corner
		onward.y = 0.0
		if onward.length() > 0.05:
			_open_door_ahead(onward.normalized(), corner)
	var dodge: Variant = _door_escape(speed, delta)
	if dodge != null:
		return dodge
	# A door in the way: ease up while it opens.
	if _open_door_ahead(direction):
		return _move(direction, speed * 0.3, delta)
	# The route already keeps clear of what the mesh knows about: only swerve
	# for something right in front of him, and turn briskly at corners.
	return _move(_avoid(direction, 0.45), speed, delta, 9.0)


## A short wander to somewhere he can actually walk to.
func _choose_potter() -> void:
	if _nav != null and _nav.is_ready:
		_choose_potter_on_mesh()
		return
	for attempt in 10:
		var angle := _rng.randf() * TAU
		var reach := _rng.randf_range(1.0, minf(3.0, npc.definition.wander_radius))
		# Mostly stays near home, drifting back if he's wandered off.
		var origin := npc.global_position.lerp(npc.home, 0.5)
		var candidate := origin + Vector3(cos(angle), 0, sin(angle)) * reach
		candidate.y = npc.global_position.y
		if candidate.distance_to(npc.home) > npc.definition.wander_radius:
			continue
		if _floor_at(candidate) and _clear_path(npc.global_position, candidate):
			target = candidate
			_enter(State.POTTER, 10.0)
			return
	timer = _rng.randf_range(3.0, 6.0)


## Pottering with a navmesh: somewhere near home with a sensible route there.
func _choose_potter_on_mesh() -> void:
	var here := npc.global_position
	for attempt in 6:
		var origin := here.lerp(npc.home, 0.5)
		origin.y = here.y
		var candidate := _nav.random_near(origin, minf(3.0, npc.definition.wander_radius))
		if not candidate.is_finite() or candidate.distance_to(npc.home) > npc.definition.wander_radius:
			continue
		var route := _nav.path(here, candidate)
		if route.size() < 2 or route[route.size() - 1].distance_to(candidate) > 0.3:
			continue
		var length := 0.0
		for i in range(1, route.size()):
			length += route[i - 1].distance_to(route[i])
		# Not the long way round to somewhere just the other side of a wall.
		if length > here.distance_to(candidate) * 2.0 + 1.0:
			continue
		target = candidate
		_enter(State.POTTER, 15.0)
		_route = route
		_route_index = 1
		_route_goal = candidate
		_route_age = 0.0
		return
	timer = _rng.randf_range(3.0, 6.0)


## Whether a body-sized capsule can slide from `from` to `to` without touching anything.
func _clear_path(from: Vector3, to: Vector3) -> bool:
	var space := npc.get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	shape.radius = BODY_RADIUS
	shape.height = BODY_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, from + Vector3.UP * (BODY_HEIGHT * 0.5 + 0.12))
	query.motion = Vector3(to.x - from.x, 0.0, to.z - from.z)
	query.collision_mask = 1 | 16
	query.exclude = npc.own_rids()
	var fractions := space.cast_motion(query)
	return fractions.size() == 2 and fractions[0] >= 0.999


## Solid floor at about the same level (no stepping off edges or up steps).
func _floor_at(point: Vector3) -> bool:
	var space := npc.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.5, point + Vector3.DOWN * 0.5, 1 | 16)
	query.exclude = npc.own_rids()
	var hit := space.intersect_ray(query)
	return not hit.is_empty() and absf(hit["position"].y - npc.global_position.y) < 0.1


## A gentle nudge round small things in the way (the route was checked already).
func _avoid(wanted: Vector3, reach := 0.7) -> Vector3:
	var space := npc.get_world_3d().direct_space_state
	# Above anything he can step or walk over (and the top edge of a stair flight).
	var from := npc.global_position + Vector3.UP * 0.6
	for angle in [0.0, 0.5, -0.5, 1.0, -1.0]:
		var dir := wanted.rotated(Vector3.UP, angle)
		var query := PhysicsRayQueryParameters3D.create(from, from + dir * reach, 1 | 16)
		query.exclude = npc.own_rids()
		var hit := space.intersect_ray(query)
		# Slopes he can walk up (the stairs are a ramp) aren't obstacles.
		if hit.is_empty() or hit["normal"].dot(Vector3.UP) >= cos(npc.floor_max_angle):
			return dir
	return Vector3.ZERO


func _player_armed(player: Node3D) -> bool:
	if player == null:
		return false
	var tools: Object = player.get(&"tool_handler")
	return tools != null and tools.has_method(&"is_equipped") and bool(tools.call(&"is_equipped"))


func _drop_crumb(player_pos: Vector3) -> void:
	if _trail.is_empty() or _trail.back().distance_to(player_pos) > CRUMB_SPACING:
		_trail.append(player_pos)
		if _trail.size() > MAX_CRUMBS:
			_trail.pop_front()


## Walks after the player along their footsteps, cutting the corner straight to
## them when they're on the same level with a clear way there.
func _follow_trail(player_pos: Vector3, speed: float, delta: float) -> Vector3:
	var here := npc.global_position
	if absf(player_pos.y - here.y) < 0.3 and _clear_path(here, player_pos):
		_trail.clear()
		return _steer_to(player_pos, speed, delta)
	# Drop footsteps already reached, or passed by a nearer one further along.
	while not _trail.is_empty():
		var crumb := _trail[0]
		var flat := Vector2(crumb.x - here.x, crumb.z - here.z).length()
		if flat < 0.5 and absf(crumb.y - here.y) < 0.9:
			_trail.pop_front()
		elif _trail.size() > 1 and here.distance_to(_trail[1]) < here.distance_to(crumb) and absf(_trail[1].y - here.y) < 0.9:
			_trail.pop_front()
		else:
			break
	var goal := _trail[0] if not _trail.is_empty() else player_pos
	var velocity := _steer_to(goal, speed, delta)
	# Stuck on a footstep: skip it (the next one may be reachable).
	if npc.global_position.distance_to(_last_position) > 0.12:
		_last_position = npc.global_position
		_stuck_time = 0.0
	else:
		_stuck_time += delta
		if _stuck_time > 1.2:
			_stuck_time = 0.0
			if _free_from_door():
				return velocity
			if not _trail.is_empty():
				_trail.pop_front()
	return velocity


func _steer_to(goal: Vector3, speed: float, delta: float) -> Vector3:
	var to_goal := goal - npc.global_position
	to_goal.y = 0.0
	if to_goal.length() < 0.05:
		return _move(Vector3.ZERO, 0.0, delta)
	var dodge: Variant = _door_escape(speed, delta)
	if dodge != null:
		return dodge
	_open_door_ahead(to_goal.normalized())
	return _move(_avoid(to_goal.normalized()), speed, delta)


## A closed door, gate or garage door in the way: open it the way the player
## would (its "Open" action). Only doorways: leaves reaching down to his feet,
## not windows, and not cupboards (those belong to furniture). A locked one he
## can't open: he says so and it's blocked off, so the next route goes round.
## True when he should hold back a moment: a leaf still swinging right in front of him.
func _open_door_ahead(direction: Vector3, origin := Vector3.INF) -> bool:
	if not origin.is_finite():
		origin = npc.global_position
	var space := npc.get_world_3d().direct_space_state
	var door: Node = null
	var reach := 0.0
	# Looks a step or two ahead, so a door's already swinging by the time he
	# gets there. Low too, for garden gates and the bottom panels of garage
	# doors, and either side of centre (the gap between a pair of doors).
	var side := direction.cross(Vector3.UP) * 0.2
	for probe: Vector3 in [Vector3.UP, Vector3.UP + side, Vector3.UP - side, Vector3.UP * 0.5, Vector3.UP * 0.5 + side, Vector3.UP * 0.5 - side]:
		var from := origin + probe
		var query := PhysicsRayQueryParameters3D.create(from, from + direction * 1.6, 1 | 16)
		query.exclude = npc.own_rids()
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			door = _door_of(hit["collider"] as Node)
			if door != null:
				reach = from.distance_to(hit["position"])
				break
	if door == null:
		return false
	var now := Time.get_ticks_msec()
	var opened := {}
	for action: Dictionary in door.call(&"get_interaction_actions"):
		var id := String(action["id"])
		# Every leaf (French doors, double gates): the first way of opening each.
		var group := id.get_slice(":", 1)
		if id.begins_with("open") and action.get("enabled", true) and not opened.has(group):
			opened[group] = id
	if not opened.is_empty() and _door_cooldown <= now:
		var swing := _swing_time(door)
		_door_cooldown = now + maxi(1500, int(swing * 1000.0) + 500)
		_swing_door = door
		_swing_centre = _leaves_bounds(door).get_center()
		_swing_until = now + int((swing + 0.4) * 1000.0)
		_swing_last = INF
		_swing_from = npc.global_position
		if _nav != null:
			_nav.door_moved(swing + 0.2)
		for id: String in opened.values():
			door.call(&"perform_interaction_action", StringName(id), npc)
		if _rng.randf() < 0.3:
			npc.bark("door")
		return reach < 0.6
	if opened.is_empty() and door.has_method(&"is_locked") and bool(door.call(&"is_locked")):
		if _nav != null and _nav.is_ready and not _nav.is_blocked(door):
			npc.bark("locked")
			_nav.block_door(door, _leaves_bounds(door))
			_replan_after_bake = true
			_route_stuck = 0
		elif _nav == null or not _nav.is_ready:
			if _door_cooldown <= now:
				_door_cooldown = now + 1500
				npc.bark("locked")
			# No navmesh: try the next footstep, or give up.
			if not _trail.is_empty():
				_trail.pop_front()
			_stuck_time = 2.0
		return true
	# Open, or opening: only hold back if it's still swinging right in front of him.
	return reach < 0.6 and _door_cooldown > now


## Seconds a door takes to open.
func _swing_time(door: Node) -> float:
	var seconds: Variant = door.get(&"duration")
	if seconds == null:
		seconds = door.get(&"animation_duration")
	return float(seconds) if seconds != null else 0.8


## A door he's opened swinging his way: wait for it, or back off out of its path (away from
## the doorway, so he isn't swept round into the corner behind it). Null when
## there's nothing to dodge.
func _door_escape(speed: float, delta: float) -> Variant:
	if _swing_door == null:
		return null
	if not is_instance_valid(_swing_door) or Time.get_ticks_msec() > _swing_until:
		_swing_door = null
		return null
	var distance := _leaf_distance(_swing_door)
	# Is the leaf itself moving towards him (measured from where he opened it)?
	var from_start := _leaf_distance(_swing_door, _swing_from)
	var coming := from_start < _swing_last - 0.001
	_swing_last = from_start
	# Swinging away from him (or done), or too far off to reach him: walk on.
	if not coming and distance > 0.6 or distance > 1.3:
		return null
	_stuck_time = 0.0
	if distance > 0.75:
		# Coming his way but not on him yet: wait for it.
		return _move(Vector3.ZERO, 0.0, delta)
	# On him: back off, away from the doorway (not round into the corner behind it).
	var away := npc.global_position - _swing_centre
	away.y = 0.0
	if away.length() < 0.05:
		away = npc.global_basis.z
	return _move(away.normalized(), maxf(speed, npc.definition.walk_speed), delta, 10.0)


## Pinned behind an open door (between it and the wall): pull it shut to get
## out, and leave it a moment before opening it again (he'll keep clear then).
func _free_from_door() -> bool:
	var space := npc.get_world_3d().direct_space_state
	var ball := SphereShape3D.new()
	ball.radius = 0.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.transform = Transform3D(Basis.IDENTITY, npc.global_position + Vector3.UP * 0.9)
	query.collision_mask = 1 | 16
	query.exclude = npc.own_rids()
	for result in space.intersect_shape(query, 16):
		var door := _door_of(result["collider"] as Node)
		if door == null or _leaf_distance(door) > 0.6:
			continue
		var closed := false
		for action: Dictionary in door.call(&"get_interaction_actions"):
			if String(action["id"]).begins_with("close") and action.get("enabled", true):
				door.call(&"perform_interaction_action", action["id"], npc)
				closed = true
				if _nav != null:
					_nav.door_moved(_swing_time(door) + 0.2)
		if closed:
			_swing_door = null
			_door_cooldown = Time.get_ticks_msec() + int(_swing_time(door) * 1000.0) + 1200
			_route.clear()
			return true
	return false


## How close his body (the middle of it) is to any of a door's leaves.
func _leaf_distance(door: Node, at := Vector3.INF) -> float:
	if not at.is_finite():
		at = npc.global_position
	var nearest := INF
	var points := [at + Vector3.UP * 0.5, at + Vector3.UP * 1.2]
	for leaf in door.find_children("*", "VoxelBody", true, false):
		var body := leaf as VoxelBody
		var cells := body.get_cell_bounds()
		var box := AABB(cells.position * body.voxel_size, cells.size * body.voxel_size)
		var to_local := body.global_transform.affine_inverse()
		for point: Vector3 in points:
			var local := to_local * point
			var inside := local.clamp(box.position, box.end)
			nearest = minf(nearest, point.distance_to(body.global_transform * inside))
	return nearest


## The openable doorway a collider belongs to, or null.
func _door_of(collider: Node) -> Node:
	var node := collider
	var door: Node = null
	for depth in 8:
		if node == null:
			break
		if node is NPCCharacter or node is FurnitureAssembly:
			return null
		if door == null and node.has_method(&"get_interaction_actions") and node.has_method(&"perform_interaction_action") \
				and (node.has_meta(&"door") or node.has_method(&"is_open")):
			door = node
		node = node.get_parent()
	# Cupboards and wardrobes further up belong to furniture: not his to open.
	while node != null:
		if node is FurnitureAssembly:
			return null
		node = node.get_parent()
	if door == null:
		return null
	if not _door_shapes.has(door):
		var box := _leaves_bounds(door)
		_door_shapes[door] = Vector2(box.position.y, box.size.y)
	var shape: Vector2 = _door_shapes[door]
	# Reaches the floor he's on and is at least gate height: not a window.
	return door if shape.x < npc.global_position.y + 0.35 and shape.y > 0.7 else null


## Everything a door moves (its leaves, panels, glass), in world space.
func _leaves_bounds(door: Node) -> AABB:
	var box := AABB()
	var first := true
	for leaf in door.find_children("*", "RigidBody3D", true, false):
		var leaf_box := NPCNavigation._bounds(leaf)
		box = leaf_box if first else box.merge(leaf_box)
		first = false
	if first and door is Node3D:
		box = AABB((door as Node3D).global_position - Vector3(0.5, 0, 0.5), Vector3(1, 2, 1))
	return box
