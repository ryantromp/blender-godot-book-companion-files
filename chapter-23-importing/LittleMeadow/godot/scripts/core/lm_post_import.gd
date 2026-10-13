@tool
extends EditorScenePostImport
## Replaces the placeholder materials of every imported glb by the shared ones of res://assets/materials.

const SHARED: Dictionary = {
	"M_farm": "res://assets/materials/M_farm.tres",
	"M_farm_ao": "res://assets/materials/M_farm_ao.tres",
	"M_char": "res://assets/materials/M_char.tres",
	"M_emissive": "res://assets/materials/M_emissive.tres",
}


func _post_import(scene: Node) -> Object:
	_swap(scene)
	return scene


func _swap(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var mat: Material = mesh.surface_get_material(s)
			if mat != null and SHARED.has(mat.resource_name):
				mesh.surface_set_material(s, load(SHARED[mat.resource_name]) as Material)
	for child in node.get_children():
		_swap(child)
