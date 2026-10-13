class_name Animal
extends CharacterBody3D

enum State { IDLE, WANDER, EAT, CHEER }

const GIVE_UP_SECONDS: float = 30.0
const TURN_RATE: float = 8.0

@export var data: AnimalData
@export var pickup_scene: PackedScene

var state: State = State.IDLE
var fed: bool = false
var days_fed: int = 0
var home: Vector3
var pickup: Node3D
var rng := RandomNumberGenerator.new()

var _timer: float = 0.0

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var player: AnimationPlayer = $Model/AnimationPlayer
@onready var spot: AnimalSpot = $Spot


func _ready() -> void:
	home = global_position
	rng.randomize()
	Events.day_started.connect(_on_day_started)
	_refresh_prompt()
	_enter(State.IDLE)


func _physics_process(delta: float) -> void:
	_timer -= delta
	var direction := Vector3.ZERO
	if spot.is_hovered and state == State.WANDER:
		_enter(State.IDLE)
	match state:
		State.IDLE:
			if _timer <= 0.0 and not spot.is_hovered:
				_leave_idle()
		State.WANDER:
			if agent.is_navigation_finished() or _timer <= 0.0:
				_enter(State.IDLE)
			else:
				direction = global_position.direction_to(agent.get_next_path_position())
				direction.y = 0.0
				direction = direction.normalized()
		State.EAT, State.CHEER:
			if _timer <= 0.0:
				_enter(State.IDLE)
	velocity.x = direction.x * data.speed
	velocity.z = direction.z * data.speed
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
	if direction != Vector3.ZERO:
		var yaw: float = atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-TURN_RATE * delta))


func problem_for(farmer: Farmer) -> String:
	if farmer.tools.current != &"hand":
		return "Use your hands (4)."
	if fed:
		return "%s is fed. Come back tomorrow." % data.display_name
	if has_product():
		return "Collect the %s first." % data.product.display_name.to_lower()
	if Inventory.count_of(data.feed_item) <= 0:
		return "You have no %s." % data.feed_item.display_name.to_lower()
	return ""


func has_product() -> bool:
	return is_instance_valid(pickup)


func feed_by(_farmer: Farmer) -> void:
	Inventory.remove(data.feed_item)
	fed = true
	_refresh_prompt()
	Events.animal_fed.emit(self)
	_enter(State.EAT if data.eat_clip != &"" else State.CHEER)


func save_key() -> String:
	return "animal/" + String(name)


func to_save() -> Dictionary:
	return {
		"position": SaveSystem.pack(global_position), "yaw": snappedf(rotation.y, 0.001),
		"fed": fed, "days_fed": days_fed,
		"product": SaveSystem.pack(pickup.global_position) if has_product() else [],
	}


func from_save(saved: Dictionary) -> void:
	global_position = SaveSystem.unpack(saved["position"])
	rotation.y = float(saved["yaw"])
	velocity = Vector3.ZERO
	fed = bool(saved["fed"])
	days_fed = maxi(0, int(saved["days_fed"]))
	if has_product():
		pickup.free()
	pickup = null
	if data.product != null and saved["product"].size() == 3:
		_spawn_product(SaveSystem.unpack(saved["product"]))
	_refresh_prompt()
	_enter(State.IDLE)


func _leave_idle() -> void:
	if data.eat_clip != &"" and rng.randf() < data.eat_chance:
		_enter(State.EAT)
		return
	var goal: Variant = _pick_goal()
	if goal == null:
		_enter(State.IDLE)
		return
	agent.target_position = goal as Vector3
	_enter(State.WANDER)


func _pick_goal() -> Variant:
	var map: RID = agent.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return null
	var start: Vector3 = NavigationServer3D.map_get_closest_point(map, global_position)
	for _try: int in 4:
		var angle: float = rng.randf() * TAU
		var distance: float = sqrt(rng.randf()) * data.wander_radius
		var wanted: Vector3 = home + Vector3(cos(angle), 0.0, sin(angle)) * distance
		var goal: Vector3 = NavigationServer3D.map_get_closest_point(map, wanted)
		if _length(NavigationServer3D.map_get_path(map, start, goal, true)) <= data.wander_radius * 3.0:
			goal.y -= agent.path_height_offset
			return goal
	return null


func _length(path: PackedVector3Array) -> float:
	var total: float = INF if path.size() < 2 else 0.0
	for index: int in range(1, path.size()):
		total += path[index - 1].distance_to(path[index])
	return total


func _enter(next: State) -> void:
	state = next
	player.speed_scale = 1.0
	match next:
		State.IDLE:
			_timer = rng.randf_range(data.idle_seconds.x, data.idle_seconds.y)
			_play(&"idle")
		State.WANDER:
			_timer = GIVE_UP_SECONDS
			player.speed_scale = data.speed / data.clip_speed
			_play(&"walk")
		State.EAT:
			_timer = rng.randf_range(data.eat_seconds.x, data.eat_seconds.y)
			_play(data.eat_clip)
		State.CHEER:
			_play(data.cheer_clip)
			_timer = player.get_animation(player.current_animation).length


func _play(clip: StringName) -> void:
	var full: StringName = StringName("an_%s_%s" % [data.id, clip])
	if player.current_animation != full:
		player.play(full, 0.2)


func _refresh_prompt() -> void:
	var kind: String = data.display_name
	spot.prompt_text = "%s is fed" % kind if fed else "Feed %s" % kind.to_lower()


func _on_day_started(_day: int) -> void:
	if not fed:
		return
	fed = false
	days_fed += 1
	if data.product != null and days_fed >= data.days_to_produce:
		days_fed = 0
		_make_product()
	_refresh_prompt()


func _make_product() -> void:
	var wanted: Vector3 = global_transform * data.product_offset
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null and (camera.global_position - global_position).dot(wanted - global_position) < 0.0:
		wanted = global_position * 2.0 - wanted
	var map: RID = agent.get_navigation_map()
	var place: Vector3 = NavigationServer3D.map_get_closest_point(map, wanted)
	_spawn_product(Vector3(place.x, global_position.y, place.z))


func _spawn_product(at: Vector3) -> void:
	var made: Node3D = pickup_scene.instantiate() as Node3D
	get_parent().add_child(made)
	made.global_position = at
	(made.get_node("Spot") as ProductPickup).setup(data.product, data.product_mesh, self)
	pickup = made
