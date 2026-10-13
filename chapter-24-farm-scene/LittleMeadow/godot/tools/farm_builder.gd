@tool
class_name FarmBuilder
extends RefCounted
## Chapter 24: fills the Farm scene with everything FarmLayout lists. build() adds what is missing,
## moves what is already there to its listed place, and never deletes anything, so you can run it
## again after you change a number in the layout.
##
## The groups sit under World, the NavigationRegion3D, because the navigation bake reads its children.

const GROUPS: Array[String] = [
	"Terrain", "Paths", "Field", "Buildings", "Machines", "Fences", "Cliffs", "Rocks", "Trees", "Plants", "Props",
]
const GRASS_COUNT: int = 1400


## Returns how many nodes each group holds when it is done.
func build(farm: Node3D) -> Dictionary:
	var world: Node3D = farm.get_node("World") as Node3D
	var groups: Dictionary = {}
	for group_name: String in GROUPS:
		groups[group_name] = _group(world, group_name, farm)
	for item: FarmLayout.Placement in FarmLayout.placements():
		var parent: Node3D = groups[item.group]
		var node: Node3D = parent.get_node_or_null(item.node_name) as Node3D
		if node == null:
			node = (load(item.scene) as PackedScene).instantiate() as Node3D
			node.name = item.node_name
			parent.add_child(node)
			node.owner = farm
		node.position = item.position
		node.rotation_degrees = Vector3(0.0, item.yaw, 0.0)
	_grass(groups["Plants"] as Node3D, farm)
	_backdrop(farm)
	_start_marker(farm)
	var counts: Dictionary = {}
	for group_name: String in GROUPS:
		counts[group_name] = (groups[group_name] as Node).get_child_count()
	return counts


func _group(world: Node3D, group_name: String, farm: Node3D) -> Node3D:
	var group: Node3D = world.get_node_or_null(group_name) as Node3D
	if group == null:
		group = Node3D.new()
		group.name = group_name
		world.add_child(group)
		group.owner = farm
	return group


## One MultiMeshInstance3D draws all the tufts in a single call, instead of 1,400 nodes.
func _grass(plants: Node3D, farm: Node3D) -> void:
	var old: Node = plants.get_node_or_null("GrassTufts")
	if old != null:
		plants.remove_child(old)
		old.free()
	var tuft: Node = (load(FarmLayout.MODELS + "grass_tuft.glb") as PackedScene).instantiate()
	var source: MeshInstance3D = tuft.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var transforms: Array[Transform3D] = FarmLayout.grass_transforms(GRASS_COUNT)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = source.mesh
	multimesh.instance_count = transforms.size()
	for i: int in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var grass := MultiMeshInstance3D.new()
	grass.name = "GrassTufts"
	grass.multimesh = multimesh
	plants.add_child(grass)
	grass.owner = farm
	tuft.free()


## A big dark-green plane under the farm, so nothing shows beyond the last tile.
func _backdrop(farm: Node3D) -> void:
	if farm.has_node("Backdrop"):
		return
	var plane := PlaneMesh.new()
	plane.size = Vector2(400.0, 400.0)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("2F5F2B")
	paint.roughness = 1.0
	plane.material = paint
	var backdrop := MeshInstance3D.new()
	backdrop.name = "Backdrop"
	backdrop.mesh = plane
	backdrop.position = Vector3(0.0, -0.6, 0.0)
	farm.add_child(backdrop)
	backdrop.owner = farm


## Where the farmer will stand when the game starts (Chapter 25).
func _start_marker(farm: Node3D) -> void:
	if farm.has_node("FarmerStart"):
		return
	var marker := Marker3D.new()
	marker.name = "FarmerStart"
	marker.position = Vector3(0.5, 0.0, -3.5)
	farm.add_child(marker)
	marker.owner = farm
