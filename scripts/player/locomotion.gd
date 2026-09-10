extends Node
## Fully procedural locomotion for the Freja deform skeleton.
##
## Why procedural (not mocap): freja.glb was exported "deform bones only", which
## flattened the rig - 375 of 578 bones lost their real parent and sit on the
## armature root (hands, foot toes, head, neck, shoulders, breasts, hair, belt,
## cape...). Retargeting mocap onto that is hopeless. Instead we:
##
##   1. rebuild a small virtual FK hierarchy in code (pelvis -> spine -> neck/head,
##      spine -> shoulder -> full 3-segment arm, pelvis -> full 3-segment leg),
##   2. drive it with hand-authored pose curves for idle / walk / run / crouch /
##      crouch-walk (blended by speed + crouch),
##   3. every frame rigidly re-attach ALL remaining detached bones to their
##      nearest driver so nothing floats.
##
## Bone rotations are authored about MODEL-space axes and conjugated into each
## bone's rest frame, so we never need to know a bone's local roll (see AX_*
## below for the verified sign conventions). Only rotations are written -
## segment lengths are never touched, so limbs can't stretch.
##
## Public API (unchanged): bind(skeleton, model), is_bound,
## update_state(planar_speed, target_speed, crouching, grounded, delta)

# ------------------------------------------------------------------ tuning ----
const RUN_SPEED := 6.2                       # matches player.run_speed

# walk/run cycle
const CADENCE_WALK := 0.92                   # strides/sec at a slow walk
const CADENCE_RUN := 1.45
const THIGH_SWING_WALK := deg_to_rad(17.0)
const THIGH_SWING_RUN := deg_to_rad(26.0)
const KNEE_BEND_WALK := deg_to_rad(34.0)
const KNEE_BEND_RUN := deg_to_rad(50.0)
const KNEE_TUCK := deg_to_rad(6.0)           # constant soft bend, never locked
const ANKLE_RANGE := deg_to_rad(14.0)
const ARM_SWING_WALK := deg_to_rad(16.0)
const ARM_SWING_RUN := deg_to_rad(24.0)
const ELBOW_BASE_WALK := deg_to_rad(14.0)
const ELBOW_BASE_RUN := deg_to_rad(28.0)
const ARM_ADDUCT := deg_to_rad(26.0)         # settle arms in from the exported A-pose
const CR_ARM_IN := deg_to_rad(6.0)
const HIP_BOB := 0.028
const HIP_SWAY := 0.022
const HIP_ROLL := deg_to_rad(4.0)
const HIP_YAW := deg_to_rad(6.5)
const LEAN_WALK := deg_to_rad(3.0)
const LEAN_RUN := deg_to_rad(9.0)
const SPINE_COUNTER := 0.6                   # torso counter-rotates vs hips

# crouch (full = 1.0) - low hips, fairly upright back, head up (game stealth crouch)
const CR_PELVIS_DROP := 0.30
const CR_PELVIS_BACK := 0.05
const CR_PELVIS_PITCH := deg_to_rad(5.0)
const CR_THIGH := deg_to_rad(55.0)
const CR_KNEE := deg_to_rad(88.0)
const CR_ANKLE := deg_to_rad(10.0)
const CR_SPINE := deg_to_rad(10.0)
const CR_EXTRA_LOOK := deg_to_rad(5.0)       # a bit of extra chin-up when crouched
const CR_ARM_FWD := deg_to_rad(14.0)
const CR_ELBOW := deg_to_rad(30.0)

# idle
const BREATH_RATE := 1.5
const IDLE_SWAY_RATE := 0.55

const PELVIS_Y := 1.02
const PELVIS_Z := -0.02

# ---------------------------------------------------------------- internals ----
var is_bound := false
var _sk: Skeleton3D
var _model: Node3D
var _model_base_y := 0.0

# a driver: name -> {idx, vparent (name or ""), root (bool: skeleton parent == -1),
#                     l_rest: Transform3D (rel. virtual parent), g_rest_basis: Basis}
var _drv := {}
var _drv_order: Array[String] = []
var _cur := {}                               # name -> current global Transform3D

# rigid followers: {idx, anchor: String, offset: Transform3D}
var _followers: Array = []

# speed / crouch state (smoothed)
var _spd := 0.0                              # 0 idle .. 1 run
var _run01 := 0.0                            # 0 walk .. 1 run  (for cadence/amplitude)
var _moving := 0.0                           # 0 .. 1 gate
var _crouch := 0.0
var _phase := 0.0
var _idle_t := 0.0
var _ground_drop := 0.0

# ------------------------------------------------------------------- setup ----
func bind(skeleton: Skeleton3D, model: Node3D) -> void:
	_sk = skeleton
	_model = model
	_model_base_y = model.position.y
	_silence_animation_players(model)

	# virtual hierarchy: [name, bone, vparent, is_skeleton_root]
	var spec := [
		["pelvis", "", "", false],
		["spine1", "DEF-Spine1", "pelvis", true],
		["spine2", "DEF-Spine2", "spine1", false],
		["spine3", "DEF-Spine3", "spine2", false],
		["neck", "DEF-Neck", "spine3", true],
		["head", "DEF-Head", "neck", true],
	]
	for s in ["L", "R"]:
		spec.append_array([
			["shoulder." + s, "DEF-Shoulder." + s, "spine3", true],
			["uarm1." + s, "DEF-UpperArm_1." + s, "shoulder." + s, true],
			["uarm2." + s, "DEF-UpperArm_2." + s, "uarm1." + s, false],
			["uarm3." + s, "DEF-UpperArm_3." + s, "uarm2." + s, false],
			["farm1." + s, "DEF-Forearm_1." + s, "uarm3." + s, false],
			["farm2." + s, "DEF-Forearm_2." + s, "farm1." + s, false],
			["farm3." + s, "DEF-Forearm_3." + s, "farm2." + s, false],
			["wrist." + s, "DEF-Wrist." + s, "farm3." + s, false],
			["thigh1." + s, "DEF-Thigh_1." + s, "pelvis", true],
			["thigh2." + s, "DEF-Thigh_2." + s, "thigh1." + s, false],
			["thigh3." + s, "DEF-Thigh_3." + s, "thigh2." + s, false],
			["knee1." + s, "DEF-Knee_1." + s, "thigh3." + s, false],
			["knee2." + s, "DEF-Knee_2." + s, "knee1." + s, false],
			["knee3." + s, "DEF-Knee_3." + s, "knee2." + s, false],
			["foot." + s, "DEF-Foot." + s, "knee3." + s, false],
			["toes." + s, "DEF-Toes." + s, "foot." + s, false],
		])

	var pelvis_g := Transform3D(Basis.IDENTITY, Vector3(0.0, PELVIS_Y, PELVIS_Z))
	var g_rest := {"pelvis": pelvis_g}

	for e in spec:
		var nm: String = e[0]
		var bone: String = e[1]
		var vparent: String = e[2]
		if nm == "pelvis":
			_drv[nm] = {"idx": -1, "vparent": "", "root": false,
				"l_rest": Transform3D.IDENTITY, "g_rest_basis": Basis.IDENTITY}
			_drv_order.append(nm)
			continue
		var idx := _sk.find_bone(bone)
		if idx == -1:
			push_warning("locomotion: missing bone " + bone)
			continue
		var gr := _sk.get_bone_global_rest(idx)
		g_rest[nm] = gr
		var l_rest: Transform3D
		if e[3]:                                          # skeleton root -> rel. virtual parent
			l_rest = g_rest[vparent].affine_inverse() * gr
		else:                                            # real child -> its own local rest
			l_rest = _sk.get_bone_rest(idx)
		_drv[nm] = {"idx": idx, "vparent": vparent, "root": e[3],
			"l_rest": l_rest, "g_rest_basis": gr.basis.orthonormalized()}
		_drv_order.append(nm)

	_build_followers(g_rest)
	is_bound = true

## Every bone still parented to the armature root that we don't explicitly drive
## gets welded to the nearest driver (by rest position) and carried rigidly.
func _build_followers(g_rest: Dictionary) -> void:
	var driven := {}
	for nm in _drv:
		if _drv[nm]["idx"] != -1:
			driven[_drv[nm]["idx"]] = true

	# candidate anchors: name -> rest origin
	var anchors := {}
	for nm in ["pelvis", "spine1", "spine2", "spine3", "neck", "head"]:
		if g_rest.has(nm):
			anchors[nm] = g_rest[nm].origin
	for s in ["L", "R"]:
		for nm in ["shoulder." + s, "uarm2." + s, "farm2." + s, "wrist." + s,
				"thigh2." + s, "knee2." + s, "foot." + s, "toes." + s]:
			if g_rest.has(nm):
				anchors[nm] = g_rest[nm].origin

	for i in _sk.get_bone_count():
		if _sk.get_bone_parent(i) != -1 or driven.has(i):
			continue
		var p := _sk.get_bone_global_rest(i).origin
		var best := ""
		var best_d := INF
		for nm in anchors:
			var d: float = p.distance_squared_to(anchors[nm])
			if d < best_d:
				best_d = d
				best = nm
		if best == "":
			continue
		var anchor_g: Transform3D = g_rest.get(best, Transform3D.IDENTITY)
		_followers.append({
			"idx": i,
			"anchor": best,
			"offset": anchor_g.affine_inverse() * _sk.get_bone_global_rest(i),
		})

func _silence_animation_players(n: Node) -> void:
	if n is AnimationPlayer:
		n.active = false
	if n is AnimationTree:
		n.active = false
	for c in n.get_children():
		_silence_animation_players(c)

# ------------------------------------------------------------------- update ----
func update_state(planar_speed: float, _target_speed: float, crouching: bool, _grounded: bool, delta: float) -> void:
	if not is_bound:
		return
	var dt := clampf(delta, 0.0, 0.05)
	var moving := planar_speed > 0.35
	var spd_t := clampf(planar_speed / RUN_SPEED, 0.0, 1.0)
	var run_t := clampf(inverse_lerp(0.30, 0.92, spd_t), 0.0, 1.0)

	_spd = lerpf(_spd, spd_t, clampf(8.0 * dt, 0, 1))
	_run01 = lerpf(_run01, run_t, clampf(6.0 * dt, 0, 1))
	_moving = lerpf(_moving, 1.0 if moving else 0.0, clampf(9.0 * dt, 0, 1))
	_crouch = lerpf(_crouch, 1.0 if crouching else 0.0, clampf(9.0 * dt, 0, 1))
	_idle_t += dt

	var cadence: float = lerpf(CADENCE_WALK, CADENCE_RUN, _run01) * lerpf(1.0, 0.8, _crouch)
	if moving:
		_phase = fmod(_phase + dt * cadence * TAU, TAU)
	else:
		# ease the cycle to a rest so we don't stop mid-stride
		var tgt: float = round(_phase / PI) * PI
		_phase = lerp_angle(_phase, tgt, clampf(8.0 * dt, 0, 1))

	_pose()

# model-space rotation axes, signs verified against the exported skeleton:
#   +X : a downward limb (thigh/arm) swings BACK  -> forward swing is -X
#        an upright part (spine/head) tips FORWARD
#   +X on a knee/elbow : natural flexion (heel toward hip)
#   +Z : the LEFT-side limb abducts OUT / up      -> adduction is -Z on the left
const AX_X := Vector3(1, 0, 0)
const AX_Y := Vector3(0, 1, 0)
const AX_Z := Vector3(0, 0, 1)
const FOOT_CONTACT_Y := 0.05     # keep the lower foot near the rest ground plane

func _pose() -> void:
	var p := _phase
	var w := _moving                       # 0 idle .. 1 moving
	var cr := _crouch
	var cr_walk: float = lerpf(1.0, 0.5, cr)
	var idle: float = 1.0 - w
	var breath := sin(_idle_t * BREATH_RATE)

	var thigh_amp: float = lerpf(THIGH_SWING_WALK, THIGH_SWING_RUN, _run01) * w * cr_walk
	var knee_amp: float = lerpf(KNEE_BEND_WALK, KNEE_BEND_RUN, _run01) * w * cr_walk
	var arm_amp: float = lerpf(ARM_SWING_WALK, ARM_SWING_RUN, _run01) * w * cr_walk
	var elbow_base: float = lerpf(ELBOW_BASE_WALK, ELBOW_BASE_RUN, _run01)
	var lean: float = lerpf(LEAN_WALK, LEAN_RUN, _run01) * w

	# ---- pelvis -----------------------------------------------------------
	var bob := (0.5 * cos(p * 2.0) - 0.5) * HIP_BOB * w * cr_walk    # dips twice / cycle
	var sway := sin(p) * HIP_SWAY * w * cr_walk
	var pel_pos := Vector3(
		sway + sin(_idle_t * IDLE_SWAY_RATE) * 0.006 * idle,
		PELVIS_Y + bob - CR_PELVIS_DROP * cr,
		PELVIS_Z - CR_PELVIS_BACK * cr)
	var hip_yaw := sin(p) * HIP_YAW * w * cr_walk \
		+ sin(_idle_t * IDLE_SWAY_RATE * 0.7) * deg_to_rad(1.2) * idle
	var hip_roll := -sin(p) * HIP_ROLL * w * cr_walk
	var pel_pitch := lean + CR_PELVIS_PITCH * cr                     # +X tips the torso forward
	_cur["pelvis"] = Transform3D(
		Basis(AX_Y, hip_yaw) * Basis(AX_Z, hip_roll) * Basis(AX_X, pel_pitch), pel_pos)

	# ---- spine : counter-rotate the torso vs the hips, breathe -----------
	var c_yaw := -hip_yaw * SPINE_COUNTER
	var c_roll := -hip_roll * 0.5
	var s_pitch := (CR_SPINE * cr) / 3.0 + breath * deg_to_rad(0.5) * idle / 3.0
	for sp in ["spine1", "spine2", "spine3"]:
		_apply(sp, AX_Y, c_yaw / 3.0, AX_Z, c_roll / 3.0, AX_X, s_pitch)

	# ---- neck / head : keep the gaze roughly level ----------------------
	var torso_fwd := lean + CR_PELVIS_PITCH * cr + CR_SPINE * cr
	# counter most of the torso pitch so the gaze stays level (-X tips the head back/up)
	var look := -(torso_fwd * 0.85) - CR_EXTRA_LOOK * cr - breath * deg_to_rad(0.4) * idle
	_apply("neck", AX_Y, -c_yaw * 0.35, AX_X, look * 0.45, AX_Z, 0.0)
	_apply("head", AX_Y, -c_yaw * 0.30, AX_X, look * 0.55, AX_Z, 0.0)

	# ---- arms : swing opposite the same-side leg, settled in from the A-pose ----
	for s in ["L", "R"]:
		var side := 1.0 if s == "L" else -1.0
		var aph := p + PI
		var swing := sin(aph) * arm_amp                       # +X = arm back
		var adduct := -side * (ARM_ADDUCT + CR_ARM_IN * cr)   # -Z pulls the left arm in
		var fwd := CR_ARM_FWD * cr
		var idle_arm := sin(_idle_t * BREATH_RATE + side) * deg_to_rad(0.7) * idle
		_apply("shoulder." + s, AX_X, swing * 0.10 + breath * deg_to_rad(0.4) * idle,
			AX_Z, -side * breath * deg_to_rad(0.3) * idle, AX_X, 0.0)
		_apply("uarm1." + s, AX_X, swing - fwd + idle_arm, AX_Z, adduct, AX_X, 0.0)
		_carry_chain(["uarm2." + s, "uarm3." + s])
		# elbow: soft constant bend + coupled swing, flexes forward (-X)
		var elbow: float = -(elbow_base + CR_ELBOW * cr + maxf(0.0, sin(aph + 0.5)) * arm_amp * 0.6)
		_apply("farm1." + s, AX_X, elbow * 0.5, AX_X, 0.0, AX_X, 0.0)
		_apply("farm2." + s, AX_X, elbow * 0.3, AX_X, 0.0, AX_X, 0.0)
		_apply("farm3." + s, AX_X, elbow * 0.2, AX_X, 0.0, AX_X, 0.0)
		_apply("wrist." + s, AX_X, 0.0, AX_X, 0.0, AX_X, 0.0)

	# ---- legs : contralateral stride, knees flex through swing ----------
	for s in ["L", "R"]:
		var lp := p if s == "L" else p + PI
		var t_swing := -sin(lp) * thigh_amp - CR_THIGH * cr           # -X = thigh forward
		var swing_bend: float = knee_amp * pow(maxf(0.0, cos(lp)), 1.3)
		var knee: float = KNEE_TUCK + swing_bend + CR_KNEE * cr       # +X = knee flex
		var ankle: float = -(t_swing + knee) * 0.45 \
			+ maxf(0.0, sin(lp)) * ANKLE_RANGE * w - CR_ANKLE * cr
		_apply("thigh1." + s, AX_X, t_swing, AX_X, 0.0, AX_X, 0.0)
		_carry_chain(["thigh2." + s, "thigh3." + s])
		_apply("knee1." + s, AX_X, knee * 0.7, AX_X, 0.0, AX_X, 0.0)
		_apply("knee2." + s, AX_X, knee * 0.18, AX_X, 0.0, AX_X, 0.0)
		_apply("knee3." + s, AX_X, knee * 0.12, AX_X, 0.0, AX_X, 0.0)
		_apply("foot." + s, AX_X, ankle, AX_X, 0.0, AX_X, 0.0)
		_apply("toes." + s, AX_X, maxf(0.0, sin(lp)) * ANKLE_RANGE * 0.5 * w, AX_X, 0.0, AX_X, 0.0)

	_compute_fk()
	_ground()
	_flush()

	_model.position.y = lerpf(_model.position.y, _model_base_y, 0.3)

# ---- pose helpers --------------------------------------------------------
## rotate a driver about up-to-three model-space axes (angles may be 0)
func _apply(nm: String, ax0: Vector3, a0: float, ax1: Vector3, a1: float, ax2: Vector3, a2: float) -> void:
	if not _drv.has(nm):
		return
	var w := Basis.IDENTITY
	if ax0 != Vector3.ZERO and not is_zero_approx(a0):
		w = Basis(ax0.normalized(), a0)
	if ax1 != Vector3.ZERO and not is_zero_approx(a1):
		w = w * Basis(ax1.normalized(), a1)
	if ax2 != Vector3.ZERO and not is_zero_approx(a2):
		w = w * Basis(ax2.normalized(), a2)
	var d: Dictionary = _drv[nm]
	var grb: Basis = d["g_rest_basis"]
	var local_delta := grb.inverse() * w * grb
	var l: Transform3D = d["l_rest"]
	var l_new := Transform3D(l.basis * local_delta, l.origin)
	d["_lnew"] = l_new

## chain segments that just follow their parent rigidly (no local rotation)
func _carry_chain(names: Array) -> void:
	for nm in names:
		if _drv.has(nm):
			var d: Dictionary = _drv[nm]
			d["_lnew"] = d["l_rest"]

## forward-kinematics pass: resolve every driver's global transform from the
## `_lnew` locals set by _apply / _carry_chain (no skeleton writes yet)
func _compute_fk() -> void:
	for nm in _drv_order:
		if nm == "pelvis":
			continue
		var d: Dictionary = _drv[nm]
		var l_new: Transform3D = d.get("_lnew", d["l_rest"])
		d["_lnew"] = l_new
		_cur[nm] = _cur[d["vparent"]] * l_new

## drop the whole rig so the lower foot rests on the ground (cheap pelvis IK).
## smoothed so a crouch/stand transition can't pop.
func _ground() -> void:
	var lo: float = min(
		min(_cur["foot.L"].origin.y, _cur["foot.R"].origin.y),
		min(_cur["toes.L"].origin.y, _cur["toes.R"].origin.y))
	_ground_drop = lerpf(_ground_drop, lo - FOOT_CONTACT_Y, 0.5)
	if is_zero_approx(_ground_drop):
		return
	var shift := Vector3(0.0, -_ground_drop, 0.0)
	for nm in _cur:
		var t: Transform3D = _cur[nm]
		t.origin += shift
		_cur[nm] = t

func _flush() -> void:
	for nm in _drv_order:
		if nm == "pelvis":
			continue
		var d: Dictionary = _drv[nm]
		if d["root"]:
			var g: Transform3D = _cur[nm]
			_sk.set_bone_pose_position(d["idx"], g.origin)
			_sk.set_bone_pose_rotation(d["idx"], g.basis.get_rotation_quaternion())
		else:
			_sk.set_bone_pose_rotation(d["idx"], (d["_lnew"] as Transform3D).basis.get_rotation_quaternion())
	for f in _followers:
		var gf: Transform3D = _cur[f["anchor"]] * f["offset"]
		_sk.set_bone_pose_position(f["idx"], gf.origin)
		_sk.set_bone_pose_rotation(f["idx"], gf.basis.get_rotation_quaternion())
