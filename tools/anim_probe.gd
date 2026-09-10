extends SceneTree
## Headless numeric QA for the procedural locomotion.
##  - segment lengths (rubber check)
##  - foot world travel while "planted" (slide check)
##  - pelvis-height frame-to-frame jitter
##  - arm / thigh self-intersection distances
##  - strafe / turn behaviour
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
	var loco = Loco.new()
	get_root().add_child(loco)
	loco.bind(skel, glb)
	await process_frame
	await process_frame

	for st in [["idle", 0.0, false], ["walk", 2.4, false], ["run", 6.2, false], ["crouch", 0.0, true], ["crouchwalk", 1.4, true]]:
		var name: String = st[0]
		var spd: float = st[1]
		var cr: bool = st[2]
		for i in 240:
			loco.update_state(spd, spd, cr, true, 1.0 / 60.0)
		# now sample one full cycle
		var min_len := INF
		var max_len := 0.0
		var pelvis_prev := 999.0
		var max_jitter := 0.0
		var min_arm_torso := INF
		var min_thigh_gap := INF
		var planted_pos := {}
		var max_slide := 0.0
		for k in 120:
			loco.update_state(spd, spd, cr, true, 1.0 / 120.0)
			skel.force_update_all_bone_transforms()
			for s in ["L", "R"]:
				var tl := _seg(skel, "DEF-Thigh_1." + s, "DEF-Knee_1." + s)
				var sl := _seg(skel, "DEF-Knee_1." + s, "DEF-Foot." + s)
				var al := _seg(skel, "DEF-UpperArm_1." + s, "DEF-Wrist." + s)
				min_len = min(min_len, min(tl, min(sl, al)))
				max_len = max(max_len, max(tl, sl))
				var foot := _g(skel, "DEF-Foot." + s)
				if foot.y < 0.10:                         # roughly planted
					if planted_pos.has(s):
						max_slide = max(max_slide, Vector2(foot.x - planted_pos[s].x, foot.z - planted_pos[s].z).length())
					else:
						planted_pos[s] = foot
				else:
					planted_pos.erase(s)
				var wrist := _g(skel, "DEF-Wrist." + s)
				var spine := _g(skel, "DEF-Spine2")
				min_arm_torso = min(min_arm_torso, Vector2(wrist.x - spine.x, wrist.z - spine.z).length())
			min_thigh_gap = min(min_thigh_gap, _g(skel, "DEF-Knee_1.L").distance_to(_g(skel, "DEF-Knee_1.R")))
			var ph := _g(skel, "DEF-Spine1").y
			if pelvis_prev < 900.0:
				max_jitter = max(max_jitter, abs(ph - pelvis_prev))
			pelvis_prev = ph
		out.store_line("%s: seg_len %.3f..%.3f (rest .485/.495)  foot_slide %.3fm  pelvisY_step_max %.4fm  wrist-spine_min %.3fm  knee_gap_min %.3fm" % [
			name, min_len, max_len, max_slide, max_jitter, min_arm_torso, min_thigh_gap])

	# strafe: feed a lateral move, see if the rig stays sane (player faces travel so this is a turn)
	out.store_line("\n(strafe is handled by player.gd yaw - locomotion only sees planar speed)")
	out.close()
	print("probe done")
	quit()

func _g(skel: Skeleton3D, n: String) -> Vector3:
	return skel.get_bone_global_pose(skel.find_bone(n)).origin
func _seg(skel: Skeleton3D, a: String, b: String) -> float:
	return _g(skel, a).distance_to(_g(skel, b))
