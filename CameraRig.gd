extends Spatial

# Attach to "CameraYaw" (a Spatial child of Player, at the player's origin).
# CameraYaw orbits freely and does NOT rotate the Player itself — that
# decoupling is what makes free-look + auto-recenter possible.
#
# Structure:
# CameraYaw (Spatial)          <- this script
# └── CameraPitch (Spatial)    <- head-height pivot for vertical look
#     └── SpringArm            <- shrinks on wall collision automatically
#         └── Camera

export var mouse_sensitivity := 0.15
export var min_pitch := -40.0
export var max_pitch := 70.0

# zoom is clamped so the camera can never get close enough to clip into
# the character — min_zoom should always stay comfortably outside the
# Camera node's Near clipping plane (default 0.05, so 1.5 is very safe)
export var min_zoom := 1.5
export var max_zoom := 6.0
export var zoom_step := 0.5
export var zoom_speed := 8.0

export var shoulder_offset := 0.6
export var shoulder_switch_speed := 8.0

# how fast the camera's orbit eases back behind the character while moving —
# keep this slower than Player.gd's rotation_speed so the character turns
# first and the camera visibly "catches up" behind it
export var recenter_enabled := false
export var recenter_speed := 3.0

onready var pitch_node: Spatial = $CameraPitch
onready var spring_arm: SpringArm = $CameraPitch/SpringArm
onready var player: KinematicBody = get_parent()

var _shoulder_side := 1.0
var _target_zoom := 4.0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_target_zoom = spring_arm.spring_length

func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(deg2rad(-event.relative.x * mouse_sensitivity))
		pitch_node.rotation.x = clamp(
			pitch_node.rotation.x - deg2rad(event.relative.y * mouse_sensitivity),
			deg2rad(min_pitch), deg2rad(max_pitch)
		)

	if event.is_action_pressed("switch_shoulder"):
		_shoulder_side *= -1.0

	if event.is_action_pressed("zoom_in"):
		_target_zoom = clamp(_target_zoom - zoom_step, min_zoom, max_zoom)
	if event.is_action_pressed("zoom_out"):
		_target_zoom = clamp(_target_zoom + zoom_step, min_zoom, max_zoom)

func _process(delta):
	# smooth, clamped zoom — never allowed inside min_zoom
	spring_arm.spring_length = lerp(spring_arm.spring_length, _target_zoom, zoom_speed * delta)

	# shoulder swap lerp
	var target_x := shoulder_offset * _shoulder_side
	spring_arm.translation.x = lerp(spring_arm.translation.x, target_x, shoulder_switch_speed * delta)

	# auto-recenter: while the player is moving, ease the camera's orbit
	# back in line with the character's facing direction, restoring the
	# default "behind the back" view without fighting manual mouse input
	# while the player is standing still
	if recenter_enabled and player.current_speed > 0.1:
		rotation.y = lerp_angle(rotation.y, player.model.rotation.y, recenter_speed * delta)
