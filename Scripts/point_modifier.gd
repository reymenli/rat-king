class_name PointModifier
extends SkeletonModifier3D
# Points the Rat King's right arm at `target` on top of whatever clip is playing, so he can
# walk and point at once. The player fades `influence` in while aiming (right click).

const ARM := "upper_arm.R"
const FOREARM := "forearm.R"

var target := Vector3.ZERO  # world position to point at

var _arm := -1
var _forearm := -1


func _ready() -> void:
	var skeleton := get_skeleton()
	_arm = skeleton.find_bone(ARM)
	_forearm = skeleton.find_bone(FOREARM)


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _arm < 0:
		return
	# Straight arm: forearm back to its rest bend, then turn the upper arm toward the target.
	if _forearm >= 0:
		skeleton.set_bone_pose_rotation(_forearm, skeleton.get_bone_rest(_forearm).basis.get_rotation_quaternion())
	var pose := skeleton.get_bone_global_pose(_arm)
	var want := (skeleton.global_transform.affine_inverse() * target - pose.origin).normalized()
	var have := pose.basis.y.normalized()  # bones point along their +Y
	if want.is_zero_approx() or have.is_equal_approx(want):
		return
	pose.basis = Basis(Quaternion(have, want)) * pose.basis
	skeleton.set_bone_global_pose(_arm, pose)
