class_name Fx
extends RefCounted
## One call starts a short effect: Fx.spawn(self, &"dust", position). Its Timer frees it.

const EFFECTS: Dictionary = {
	&"dust": preload("res://scenes/fx/dust_puff.tscn"),
	&"splash": preload("res://scenes/fx/water_splash.tscn"),
	&"sparkle": preload("res://scenes/fx/sparkle.tscn"),
}
## No more than this many effects at once. Further calls do nothing.
const MAX_ACTIVE: int = 24

static var active: int = 0


## Returns the new effect, or null when the name is unknown or too many effects are running.
static func spawn(context: Node, effect: StringName, position: Vector3) -> Node3D:
	if not EFFECTS.has(effect):
		push_warning("Fx: no effect called %s" % effect)
		return null
	if active >= MAX_ACTIVE:
		return null
	var scene: PackedScene = EFFECTS[effect]
	var node: Node3D = scene.instantiate()
	var tree: SceneTree = context.get_tree()
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	parent.add_child(node)
	node.global_position = position
	# A scene may be saved with Emitting off, so every particle node is started here.
	for child: Node in node.get_children():
		if child is GPUParticles3D:
			(child as GPUParticles3D).restart()
	active += 1
	node.tree_exited.connect(_on_gone)
	return node


static func _on_gone() -> void:
	active -= 1
