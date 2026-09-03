extends Spatial

# Attach to the "Model" node (child of Player, holds your mesh + AnimationTree).
# Expects a child AnimationTree with a root AnimationNodeStateMachine
# containing states: "Idle", "Walk", "Run", "Jump".

# Below what speed counts as "stopped" vs walking, and above what speed
# counts as running. Tune these against Player.gd's walk_speed / run_speed.
export var walk_threshold := 0.5
export var run_threshold := 4.5

onready var anim_tree: AnimationTree = $AnimationTree
onready var player: KinematicBody = get_parent()  # Player, reads current_speed from it
onready var playback: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")

func _ready():
	anim_tree.active = true
	playback.start("Idle")

func _process(_delta):
	if playback.get_current_node() == "Jump":
		# Wait until the jump clip has actually finished playing before
		# handing control back to movement — checked manually here rather
		# than relying on the state machine's own auto-advance, which can
		# be flaky in Godot 3.5.
		if playback.get_current_play_position() >= playback.get_current_length() - 0.05:
			_update_movement_state()
	else:
		_update_movement_state()

	if Input.is_action_just_pressed("jump"):
		playback.travel("Jump")

func _update_movement_state():
	var target_state := "Idle"
	if player.current_speed > run_threshold:
		target_state = "Run"
	elif player.current_speed > walk_threshold:
		target_state = "Walk"
	playback.travel(target_state)
