extends SceneTree
## Headless numeric check. Defers so the skeleton actually processes frames.
const Loco := preload("res://scripts/player/locomotion.gd")

func _find(n: Node, c: String) -> Node:
	if n.get_class() == c: return n
	for k in n.get_children():
		var r := _find(k, c)
		if r: return r
	return null

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	var out := FileAccess.open("res://tools/anim_probe.txt", FileAccess.WRITE)
	var glb: Node = load("res://assets/characters/freja/freja.glb").instantiate()
	get_root().add_child(glb)
	var skel: Skeleton3D = _find(glb, "Skeleton3D")
	var model := glb
	var loco = Loco.new()
	get_root().add_child(loco)
	loco.bind(skel, model)
	await process_frame
	await process_frame

	var states := [
		["idle", 0.0, false, 0.0], ["walk", 2.4, false, 1.6],
		["run", 6.2, false, 1.6], ["crouch", 0.0, true, 0.0],
	]
	for st in states:
		for i in 160:
			loco.update_state(st[1], st[1], st[2], true, 1.0 / 60.0)
		if st[1] > 0.0:
			loco._phase = st[3]
			loco._pose()
		await process_frame
		skel.force_update_all_bone_transforms()
		out.store_line("\n=== %s ===" % st[0])
		for s in ["L", "R"]:
			var hip := _g(skel, "DEF-Thigh_1." + s)
			var knee := _g(skel, "DEF-Knee_1." + s)
			var foot := _g(skel, "DEF-Foot." + s)
			var toe := _g(skel, "DEF-Toes." + s)
			out.store_line("  %s hip=%s knee=%s foot=%s toe=%s" % [s, _v(hip), _v(knee), _v(foot), _v(toe)])
			out.store_line("     thigh_len=%.3f shin_len=%.3f (rest .485/.495)" % [hip.distance_to(knee), knee.distance_to(foot)])
		var sp1 := _g(skel, "DEF-Spine1")
		var head := _g(skel, "DEF-Head")
		var wl := _g(skel, "DEF-Wrist.L")
		var il := _g(skel, "DEF-Finger_Index1.L")
		out.store_line("  spine1=%s head=%s  wrist.L=%s idxL=%s (idx-wrist %.3f)" % [_v(sp1), _v(head), _v(wl), _v(il), wl.distance_to(il)])
	out.close()
	print("probe done")
	quit()

func _nowait() -> void: pass
func _g(skel: Skeleton3D, n: String) -> Vector3:
	return skel.get_bone_global_pose(skel.find_bone(n)).origin
func _v(v: Vector3) -> String:
	return "(%.2f,%.2f,%.2f)" % [v.x, v.y, v.z]
