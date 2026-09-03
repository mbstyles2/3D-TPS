extends KinematicBody

# Attach to the root Player (KinematicBody) node.
# Expected children: CollisionShape, Model (with AnimationController.gd + AnimationTree),
# CameraYaw (with CameraRig.gd)
#
# NOTE: this node no longer rotates itself from mouse input — CameraYaw
# orbits independently now, so free-look and auto-recenter both work.

export var walk_speed := 3.0
export var run_speed := 6.0
export var acceleration := 12.0     # how quickly current_speed eases toward target
export var rotation_speed := 10.0  # how fast the model turns to face movement dir
export var jump_force := 8.0
export var gravity := -20.0

export var interact_prompt_path: NodePath  # optional: point this at a UI Label in the Inspector

onready var model: Spatial = $Model
onready var camera_yaw: Spatial = $CameraYaw
onready var interact_label: Label = get_node_or_null(interact_prompt_path)

var velocity := Vector3.ZERO
var current_speed := 0.0  # read by AnimationController.gd to drive the blend tree
var current_interactable = null  # set/cleared by Interactable.gd when in range

func _ready():
	add_to_group("player")
	if interact_label:
		interact_label.visible = false

func set_current_interactable(interactable):
	current_interactable = interactable
	if interact_label:
		interact_label.text = interactable.prompt_text
		interact_label.visible = true

func clear_current_interactable(interactable):
	if current_interactable == interactable:
		current_interactable = null
		if interact_label:
			interact_label.visible = false

func _physics_process(delta):
	if Input.is_action_just_pressed("interact") and current_interactable:
		current_interactable.interact()

	
	var forward_input := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var right_input := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")

	# movement is relative to CameraYaw's current orbit, not the Player's own
	# rotation (Player itself no longer turns from mouse input), so "forward"
	# is always "where the camera is currently looking" — Free Fire style
	var camera_forward := -camera_yaw.transform.basis.z
	var camera_right := camera_yaw.transform.basis.x
	camera_forward.y = 0
	camera_right.y = 0
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()

	var direction := (camera_right * right_input + camera_forward * forward_input).normalized()

	var target_speed := 0.0
	if direction.length() > 0.1:
		target_speed = run_speed if Input.is_action_pressed("run") else walk_speed

	current_speed = lerp(current_speed, target_speed, acceleration * delta)

	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed

	if is_on_floor():
		velocity.y = -0.1
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_force
	else:
		velocity.y += gravity * delta

	velocity = move_and_slide(velocity, Vector3.UP, true)

	# turn the visual model to face the direction you're actually moving,
	# not just the camera's yaw — this is what sells the "third person action" look
	if direction.length() > 0.1:
		var target_angle := atan2(direction.x, direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_angle, rotation_speed * delta)
