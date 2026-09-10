extends Node
## Locomotion = play CC0 mocap clips (Quaternius Universal Animation Library) on a
## hidden reference skeleton, then retarget its pose onto the Freja deform
## skeleton bone-by-bone: D_pose_world = R_i * S_pose, where R_i = D_rest * S_rest^-1
## is cached per bone, so the two rigs' very different rest poses don't matter.
## The Freja export flattened several chain-start bones
## onto the armature root; those are handled as "managed" - we also set their
## position from the intended parent so the limb stays attached.

const UAL := "res://assets/anims/universal_anim_library.gltf"

# UAL (Rigify DEF names) -> Freja (CloudRig DEF names). Ordered parent-first.
const MAP := [
	["DEF-spine.001", "DEF-Spine1", true],
	["DEF-spine.002", "DEF-Spine2", false],
	["DEF-spine.003", "DEF-Spine3", false],
	["DEF-neck", "DEF-Neck", true],
	["DEF-head", "DEF-Head", true],
	["DEF-shoulder.L", "DEF-Shoulder.L", true], ["DEF-shoulder.R", "DEF-Shoulder.R", true],
	["DEF-upper_arm.L", "DEF-UpperArm_1.L", true], ["DEF-upper_arm.R", "DEF-UpperArm_1.R", true],
	["DEF-forearm.L", "DEF-Forearm_1.L", false], ["DEF-forearm.R", "DEF-Forearm_1.R", false],
	["DEF-hand.L", "DEF-Wrist.L", false], ["DEF-hand.R", "DEF-Wrist.R", false],
	["DEF-thigh.L", "DEF-Thigh_1.L", true], ["DEF-thigh.R", "DEF-Thigh_1.R", true],
	["DEF-shin.L", "DEF-Knee_1.L", false], ["DEF-shin.R", "DEF-Knee_1.R", false],
	["DEF-foot.L", "DEF-Foot.L", false], ["DEF-foot.R", "DEF-Foot.R", false],
	["DEF-toe.L", "DEF-Toes.L", false], ["DEF-toe.R", "DEF-Toes.R", false],
]
# managed Freja bone -> its intended parent (real parent is the armature root)
const MANAGED_PARENT := {
	"DEF-Spine1": "", "DEF-Neck": "DEF-Spine3", "DEF-Head": "DEF-Neck",
	"DEF-Shoulder.L": "DEF-Spine3", "DEF-Shoulder.R": "DEF-Spine3",
	"DEF-UpperArm_1.L": "DEF-Shoulder.L", "DEF-UpperArm_1.R": "DEF-Shoulder.R",
	"DEF-Thigh_1.L": "DEF-Spine1", "DEF-Thigh_1.R": "DEF-Spine1",
}
const FINGER_AXIS := Vector3(0, 0, 1)

var is_bound := false
var _src_skel: Skeleton3D
var _dst: Skeleton3D
var _model: Node3D
var _tree: AnimationTree
var _pairs := []          # {src:int, dst:int, r:Basis, managed:bool, parent:int, offset:Transform3D}
var _src_ref := {}        # source bone idx -> global pose Transform3D in the idle stance
var _fingers: Array[int] = []
var _finger_rest := {}
var _src_hips := -1
var _src_hips_rest_y := 0.0
var _model_base_y := 0.0

var _spd := 0.0
var _crouch := 0.0
var _cspeed := 0.0

func bind(dst_skel: Skeleton3D, model: Node3D) -> void:
	_dst = dst_skel
	_model = model
	_model_base_y = model.position.y

	var scn: PackedScene = load(UAL)
	var src_root: Node3D = scn.instantiate()
	src_root.name = "AnimSource"
	src_root.visible = false
	add_child(src_root)
	_src_skel = _find(src_root, "Skeleton3D")
	var src_ap: AnimationPlayer = _find(src_root, "AnimationPlayer")

	_build_tree(src_root, src_ap)
	_sample_reference()
	_build_pairs()

	_src_hips = _src_skel.find_bone("DEF-hips")
	if _src_hips != -1:
		_src_hips_rest_y = _src_ref[_src_hips].origin.y

	# relaxed static finger curl
	for i in _dst.get_bone_count():
		var bn := _dst.get_bone_name(i)
		if bn.begins_with("DEF-Finger_") and not bn.contains("Carpal"):
			_fingers.append(i)
			_finger_rest[i] = _dst.get_bone_pose_rotation(i)

	is_bound = true

func _build_tree(src_root: Node, src_ap: AnimationPlayer) -> void:
	var bt := AnimationNodeBlendTree.new()

	var stand := AnimationNodeBlendSpace1D.new()
	stand.min_space = 0.0
	stand.max_space = 1.0
	stand.add_blend_point(_clip("Idle"), 0.0)
	stand.add_blend_point(_clip("Walk"), 0.33)
	stand.add_blend_point(_clip("Jog_Fwd"), 0.66)
	stand.add_blend_point(_clip("Sprint"), 1.0)
	bt.add_node("stand", stand)

	var crouch := AnimationNodeBlendSpace1D.new()
	crouch.min_space = 0.0
	crouch.max_space = 1.0
	crouch.add_blend_point(_clip("Crouch_Idle"), 0.0)
	crouch.add_blend_point(_clip("Crouch_Fwd"), 1.0)
	bt.add_node("crouch", crouch)

	var mix := AnimationNodeBlend2.new()
	bt.add_node("mix", mix)
	bt.connect_node("mix", 0, "stand")
	bt.connect_node("mix", 1, "crouch")
	bt.connect_node("output", 0, "mix")

	_tree = AnimationTree.new()
	_tree.tree_root = bt
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_tree.deterministic = false
	add_child(_tree)
	_tree.add_animation_library("", src_ap.get_animation_library(""))
	_tree.root_node = _tree.get_path_to(src_root)
	_tree.active = true
	src_ap.active = false

func _clip(anim_name: String) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = anim_name
	n.loop_mode = Animation.LOOP_LINEAR
	return n

## Drive the tree to a clean standing Idle and snapshot every source bone's
## global pose. This - not the T-pose skeleton rest - is the retarget reference,
## because every UAL clip already holds the arms ~90 deg down from that T-rest;
## measuring deltas from the idle stance keeps Freja's A-pose arms from overshoot.
func _sample_reference() -> void:
	_tree.set("parameters/stand/blend_position", 0.0)
	_tree.set("parameters/crouch/blend_position", 0.0)
	_tree.set("parameters/mix/blend_amount", 0.0)
	for _i in 20:
		_tree.advance(0.05)
	_src_skel.force_update_all_bone_transforms()
	for i in _src_skel.get_bone_count():
		_src_ref[i] = _src_skel.get_bone_global_pose(i)

func _build_pairs() -> void:
	for e in MAP:
		var si: int = _src_skel.find_bone(e[0])
		var di: int = _dst.find_bone(e[1])
		if si == -1 or di == -1:
			continue
		var managed: bool = e[2] and MANAGED_PARENT.has(e[1])
		var pi := -1
		var offset := Transform3D.IDENTITY
		if managed:
			var pn: String = MANAGED_PARENT[e[1]]
			pi = _dst.find_bone(pn) if pn != "" else -1
			var pgr: Transform3D = _dst.get_bone_global_rest(pi) if pi != -1 else Transform3D.IDENTITY
			offset = pgr.affine_inverse() * _dst.get_bone_global_rest(di)  # bone rest, relative to parent (or world if pi==-1)
		# R_i maps the source bone's *idle-stance* orientation onto Freja's rest
		# orientation. Applied as D_pose_world = R_i * S_pose it carries the mocap
		# motion across both rigs' very different rest rolls (arms ~50 deg, legs
		# ~7 deg) and any 180 deg facing difference, with no global flip needed.
		var s_ref_b: Basis = _src_ref[si].basis.orthonormalized()
		var d_rest_b: Basis = _dst.get_bone_global_rest(di).basis.orthonormalized()
		_pairs.append({
			"src": si, "dst": di,
			"r": d_rest_b * s_ref_b.inverse(),
			"managed": managed, "parent": pi, "offset": offset,
		})

func update_state(planar_speed: float, target_speed: float, crouching: bool, _grounded: bool, delta: float) -> void:
	if not is_bound:
		return
	var moving := planar_speed > 0.25
	# normalize to the clip blend axis: ~2.4 = walk, ~6.2 = sprint
	var target := 0.0
	if moving:
		target = clampf(inverse_lerp(0.0, 6.5, planar_speed), 0.08, 1.0)
	_spd = lerpf(_spd, target, clampf(10.0 * delta, 0, 1))
	_crouch = lerpf(_crouch, 1.0 if crouching else 0.0, clampf(12.0 * delta, 0, 1))
	_cspeed = lerpf(_cspeed, 1.0 if moving else 0.0, clampf(10.0 * delta, 0, 1))

	_tree.set("parameters/stand/blend_position", _spd)
	_tree.set("parameters/crouch/blend_position", _cspeed)
	_tree.set("parameters/mix/blend_amount", _crouch)
	_tree.advance(delta)


	_retarget()
	_pose_fingers()

	# follow the mocap hip height (crouch drop, walk bob) with the model node
	if _src_hips != -1:
		var dy: float = _src_skel.get_bone_global_pose(_src_hips).origin.y - _src_hips_rest_y
		_model.position.y = lerpf(_model.position.y, _model_base_y + dy, clampf(14.0 * delta, 0, 1))

func _retarget() -> void:
	for p in _pairs:
		var src_gp: Basis = _src_skel.get_bone_global_pose(p["src"]).basis.orthonormalized()
		var target_world: Basis = (p["r"] * src_gp).orthonormalized()

		if p["managed"]:
			var parent_g := Transform3D.IDENTITY
			if p["parent"] != -1:
				parent_g = _dst.get_bone_global_pose(p["parent"])
			_dst.set_bone_pose_position(p["dst"], (parent_g * p["offset"]).origin)
			# real parent is the armature root -> local rotation == world rotation
			_dst.set_bone_pose_rotation(p["dst"], target_world.get_rotation_quaternion())
		else:
			var par := _dst.get_bone_parent(p["dst"])
			var par_b: Basis = _dst.get_bone_global_pose(par).basis.orthonormalized() if par != -1 else Basis.IDENTITY
			var local_b: Basis = (par_b.inverse() * target_world).orthonormalized()
			_dst.set_bone_pose_rotation(p["dst"], local_b.get_rotation_quaternion())

func _pose_fingers() -> void:
	var curl := 0.28 + 0.3 * _crouch
	for i in _fingers:
		_dst.set_bone_pose_rotation(i, _finger_rest[i] * Quaternion(FINGER_AXIS, curl))

func _find(n: Node, cls: String) -> Node:
	if n.get_class() == cls:
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r:
			return r
	return null
