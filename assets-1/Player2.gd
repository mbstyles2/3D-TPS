extends KinematicBody

# Attach to the root Player (KinematicBody) node.
# Expected children: CollisionShape, Model (with AnimationController.gd + AnimationTree),
# CameraYaw (with CameraRig.gd)

export var walk_speed := 3.0
export var run_speed := 6.0
export var acceleration := 12.0     # how quickly current_speed eases toward target
export var rotation_speed := 10.0  # how fast the model turns to face movement dir
export var jump_force := 8.0
export var gravity := -20.0
export var max_interaction_distance := 2.5 # Maximum distance to chair/interactable

export var interact_prompt_path: NodePath  # optional: point this at a UI Label in the Inspector

onready var model: Spatial = $Model
onready var camera_yaw: Spatial = $CameraYaw
onready var interact_label: Label = get_node_or_null(interact_prompt_path)
onready var seecast: RayCast = $CameraYaw/CameraPitch/SpringArm/Camera/SeeCast
onready var text: Label = $CanvasLayer/VBoxContainer/Text
onready var anim_controller: Node = model  # AnimationController.gd attached to Model

var velocity := Vector3.ZERO
var current_speed := 0.0  # read by AnimationController.gd to drive the blend tree
var current_interactable = null  # set/cleared by Interactable.gd when in range
var is_seated := false

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

func sit_at(seat_transform: Transform, pose_key: String) -> void:
	if is_seated:
		return
	is_seated = true
	velocity = Vector3.ZERO
	current_speed = 0.0
	
	# Align player position and rotation to the sit position
	global_transform.origin = seat_transform.origin
	model.rotation.y = seat_transform.basis.get_euler().y
	
	# Trigger sitting animation state
	if anim_controller.has_method("sit"):
		anim_controller.sit(pose_key)

func stand_up() -> void:
	if not is_seated:
		return
	is_seated = false
	if anim_controller.has_method("stand_up"):
		anim_controller.stand_up()

func _physics_process(delta):
	text.hide()
	
	# Handle standing up while seated
	if is_seated:
		if Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("jump"):
			stand_up()
		return  # position/animation are fully controlled by the seat while seated

	# RayCast check for interaction range and seat marker proximity
	if seecast.is_colliding():
		var target = seecast.get_collider()
		var hit_point = seecast.get_collision_point()
		var dist_to_target = global_transform.origin.distance_to(hit_point)
		
		if target != null and target.has_method("interact") and dist_to_target <= max_interaction_distance:
			text.text = "Press E to Interact"
			text.show()
			if Input.is_action_just_pressed("interact"):
				target.interact(self)

	if Input.is_action_just_pressed("interact") and current_interactable:
		var dist_to_interactable = global_transform.origin.distance_to(current_interactable.global_transform.origin)
		if dist_to_interactable <= max_interaction_distance:
			current_interactable.interact(self)

	var forward_input := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var right_input := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")

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

	if direction.length() > 0.1:
		var target_angle := atan2(direction.x, direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_angle, rotation_speed * delta)
