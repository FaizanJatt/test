extends SceneTree
## Dump the Freja skeleton hierarchy + rest transforms and the UAL clip list.
## Run: godot --headless --path . --script tools/probe_skeleton.gd

func _find(n: Node, cls: String) -> Node:
	if n.get_class() == cls:
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r:
			return r
	return null

func _init() -> void:
	var out := FileAccess.open("res://tools/skeleton_dump.txt", FileAccess.WRITE)

	var packed: PackedScene = load("res://assets/characters/freja/freja.glb")
	var root: Node = packed.instantiate()
	var skel: Skeleton3D = _find(root, "Skeleton3D")
	out.store_line("BONE_COUNT %d" % skel.get_bone_count())
	for i in skel.get_bone_count():
		var parent := skel.get_bone_parent(i)
		var rest := skel.get_bone_rest(i)
		var grest := skel.get_bone_global_rest(i)
		out.store_line("%d\t%s\tparent=%d(%s)\tlpos=%s\tgpos=%s" % [
			i, skel.get_bone_name(i), parent,
			(skel.get_bone_name(parent) if parent != -1 else "ROOT"),
			str(rest.origin), str(grest.origin)])

	out.store_line("\n=== CHILDREN MAP ===")
	var kids := {}
	for i in skel.get_bone_count():
		var p := skel.get_bone_parent(i)
		if not kids.has(p): kids[p] = []
		kids[p].append(skel.get_bone_name(i))
	for k in kids.keys():
		var nm := (skel.get_bone_name(k) if k != -1 else "ROOT")
		out.store_line("%s -> %s" % [nm, str(kids[k])])

	# UAL clips
	out.store_line("\n=== UAL CLIPS ===")
	var uscn: PackedScene = load("res://assets/anims/universal_anim_library.gltf")
	var uroot: Node = uscn.instantiate()
	var ap: AnimationPlayer = _find(uroot, "AnimationPlayer")
	if ap:
		for lib_name in ap.get_animation_library_list():
			var lib := ap.get_animation_library(lib_name)
			for a in lib.get_animation_list():
				var anim := lib.get_animation(a)
				out.store_line("%s  len=%.2f  tracks=%d" % [a, anim.length, anim.get_track_count()])
	var usk: Skeleton3D = _find(uroot, "Skeleton3D")
	if usk:
		out.store_line("\n=== UAL SKELETON BONES ===")
		for i in usk.get_bone_count():
			out.store_line("%s" % usk.get_bone_name(i))

	out.close()
	print("dump written")
	quit()
