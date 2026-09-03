extends Area

# Attach to an Area node placed on or near any object the player should be able
# to interact with (a door, a chair, a light switch, etc).
# Requires a CollisionShape child sized to the interaction range.
# The Player must be in the "player" group — Player.gd already does this in _ready().

signal interacted

export var prompt_text := "Press E to interact"

func _ready():
	connect("body_entered", self, "_on_body_entered")
	connect("body_exited", self, "_on_body_exited")

func _on_body_entered(body):
	if body.is_in_group("player"):
		body.set_current_interactable(self)

func _on_body_exited(body):
	if body.is_in_group("player"):
		body.clear_current_interactable(self)

func interact():
	# gives every interactable free console feedback out of the box;
	# connect to the "interacted" signal (like Door.gd does) to add real behavior
	print("Interacted: ", prompt_text)
	emit_signal("interacted")
