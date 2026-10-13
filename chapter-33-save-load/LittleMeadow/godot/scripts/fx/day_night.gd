class_name DayNight
extends Node

const SUN_SCALE: Array[float] = [1.0, 0.55, 0.25]
const GREY: Array[float] = [0.0, 0.45, 0.75]
const FOG: Array[float] = [0.0, 0.003, 0.008]
const AMBIENT: Array[float] = [1.0, 0.85, 0.7]
const WEATHER_SPEED: float = 0.5

@export var sun: DirectionalLight3D
@export var moon: DirectionalLight3D
@export var world_environment: WorldEnvironment
@export var weather: Weather
@export var sun_energy: Curve
@export var sun_color: Gradient
@export var sky_top: Gradient
@export var sky_horizon: Gradient
@export var ambient_color: Gradient
@export var ambient_energy: Curve
@export var sunrise_hour: float = 5.0
@export var noon_elevation: float = 52.0
@export var noon_yaw: float = -35.0
@export var moon_color: Color = Color("86A0FF")
@export var moon_energy: float = 0.55

var _noon: Vector3
var _east: Vector3
var _lift: float
var _weather_position: float = 0.0
var _sky: ProceduralSkyMaterial
var _environment: Environment


func _ready() -> void:
	var toward_ground: Vector3 = Basis.from_euler(Vector3(deg_to_rad(-noon_elevation), deg_to_rad(noon_yaw), 0.0)) * Vector3.FORWARD
	_noon = -toward_ground
	_east = Vector3.UP.cross(_noon).normalized()
	if _east.x < 0.0:
		_east = -_east
	_lift = -_noon.y * sin((sunrise_hour - 6.0) / 24.0 * TAU)
	_environment = world_environment.environment
	_sky = _environment.sky.sky_material as ProceduralSkyMaterial
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	Events.game_loaded.connect(snap.unbind(1))
	snap()


func _process(delta: float) -> void:
	var goal: float = float(weather.state) if weather != null else 0.0
	_weather_position = move_toward(_weather_position, goal, WEATHER_SPEED * delta)
	apply(GameClock.minute_float())


func snap() -> void:
	_weather_position = float(weather.state) if weather != null else 0.0
	apply(GameClock.minute_float())


func apply(minute: float) -> void:
	var t: float = fposmod(minute, float(GameClock.MINUTES_PER_DAY)) / GameClock.MINUTES_PER_DAY
	var angle: float = (t - 0.25) * TAU
	var up: Vector3 = (_east * cos(angle) + _noon * sin(angle) + Vector3.UP * _lift).normalized()
	_aim(sun, -up)
	_aim(moon, up)
	sun.light_energy = sun_energy.sample_baked(t) * _look(SUN_SCALE)
	sun.light_color = sun_color.sample(t)
	sun.visible = sun.light_energy > 0.01
	if weather != null:
		weather.daylight = clampf(sun_energy.sample_baked(t) * 1.6, 0.0, 1.0)
	moon.light_color = moon_color
	moon.light_energy = moon_energy * clampf(-up.y * 3.0, 0.0, 1.0) * _look(SUN_SCALE)
	moon.visible = moon.light_energy > 0.01
	var grey: float = _look(GREY)
	var top: Color = _greyed(sky_top.sample(t), grey)
	var horizon: Color = _greyed(sky_horizon.sample(t), grey)
	_sky.sky_top_color = top
	_sky.sky_horizon_color = horizon
	_sky.ground_horizon_color = horizon
	_sky.ground_bottom_color = top.darkened(0.5)
	_environment.ambient_light_color = _greyed(ambient_color.sample(t), grey)
	_environment.ambient_light_energy = ambient_energy.sample_baked(t) * _look(AMBIENT)
	var fog_density: float = _look(FOG)
	_environment.fog_enabled = fog_density > 0.0001
	_environment.fog_density = fog_density
	_environment.fog_light_color = horizon


func _aim(light: DirectionalLight3D, direction: Vector3) -> void:
	light.global_basis = Basis.looking_at(direction, Vector3.UP)


func _look(table: Array[float]) -> float:
	var low: int = floori(_weather_position)
	var high: int = mini(low + 1, table.size() - 1)
	return lerpf(table[low], table[high], _weather_position - low)


func _greyed(color: Color, amount: float) -> Color:
	var level: float = color.get_luminance()
	return color.lerp(Color(level, level, level), amount).darkened(amount * 0.3)
