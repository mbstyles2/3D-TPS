extends Spatial

# Attach to the "Model" node (child of Player, holds your mesh + AnimationTree).
# Expects a child AnimationTree with a root AnimationNodeStateMachine
# containing states: "Idle", "Walk", "Run", "Jump", "Attack1".."Attack4", "block", "Sitting" (or direct pose keys).

export var walk_threshold := 0.5
export var run_threshold := 4.5
export var combo_window := 0.65

const ATTACK_STATES := ["Attack1", "Attack2", "Attack3", "Attack4"]

onready var anim_tree: AnimationTree = $AnimationTree
onready var player: KinematicBody = get_parent()  # Player, reads current_speed & is_seated from it
onready var playback: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")

var _jumping := false
var _attack_stage := 0  # 0 = not attacking, 1-4 = current combo stage
var _combo_buffered := false
var _is_seated := false  # Prevents _process from overriding the sitting animation

func _ready():
	anim_tree.active = true
	playback.start("Idle")

func _process(_delta):
	# STOP animation overrides if the player is currently sitting
	if _is_seated or (player and player.get("is_seated")):
		return

	if Input.is_action_just_pressed("jump") and not _jumping and _attack_stage == 0:
		_jumping = true
		playback.travel("Jump")
		return

	if _jumping:
		if playback.get_current_node() == "Jump" and playback.get_current_play_position() >= playback.get_current_length() - 0.05:
			_jumping = false
		return

	if _handle_attack_input_and_state():
		return

	if _handle_block():
		return

	_update_movement_state()

func _handle_attack_input_and_state() -> bool:
	if Input.is_action_just_pressed("attack") and _attack_stage == 0:
		_start_attack(1)
		return true

	if _attack_stage == 0:
		return false

	if Input.is_action_just_pressed("attack"):
		_combo_buffered = true

	if playback.get_current_node() != ATTACK_STATES[_attack_stage - 1]:
		return true

	var length: float = playback.get_current_length()
	var time_left: float = length - playback.get_current_play_position()

	var has_next_stage: bool = _attack_stage < ATTACK_STATES.size()
	if _combo_buffered and has_next_stage and time_left <= combo_window:
		_start_attack(_attack_stage + 1)
	elif time_left <= 0.05:
		_attack_stage = 0
		_combo_buffered = false
		_update_movement_state()
	return true

func _start_attack(stage: int) -> void:
	_attack_stage = stage
	_combo_buffered = false
	playback.travel(ATTACK_STATES[stage - 1])

func _handle_block() -> bool:
	if Input.is_action_pressed("block"):
		if playback.get_current_node() != "block":
			playback.travel("block")
		return true
	elif playback.get_current_node() == "block":
		_update_movement_state()
		return true
	return false

func _update_movement_state():
	var target_state := "Idle"
	if player.current_speed > run_threshold:
		target_state = "Run"
	elif player.current_speed > walk_threshold:
		target_state = "Walk"
	playback.travel(target_state)
	
func sit(pose_key: String) -> void:
	_is_seated = true
	
	# Option A: Direct travel if your state is added directly to the main AnimationTree StateMachine
	playback.travel(pose_key)
	
	# Option B: If you use a nested StateMachine named "Sitting"
	var sitting_playback: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/Sitting/playback")
	if sitting_playback:
		playback.travel("Sitting")
		sitting_playback.travel(pose_key)

func stand_up() -> void:
	_is_seated = false
	playback.travel("Idle")
