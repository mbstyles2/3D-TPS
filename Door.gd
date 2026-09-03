extends StaticBody

# Node setup:
# Door (StaticBody, this script)
# ├── CollisionShape
# └── Panel (Spatial)        <- the visual door slab; this is what rotates
#     └── MeshInstance/CSGBox

export var is_open := false
export var is_locked := false
export var required_key := ""     # must match an entry in player.inventory
export var open_angle_degrees := 90.0
export var swing_speed := 4.0

onready var panel = get_node_or_null("Panel")

var _target_angle := 0.0


func _ready():
	add_to_group("interactable")
	_target_angle = 0.0


func _process(delta):
	if not panel:
		return
	panel.rotation.y = lerp_angle(panel.rotation.y, _target_angle, swing_speed * delta)


func interact(player):
	if is_locked:
		if required_key != "" and player.inventory.has(required_key):
			is_locked = false
			print("Unlocked the door with ", required_key)
		else:
			print("The door is locked.")
			return

	is_open = not is_open
	_target_angle = deg2rad(open_angle_degrees) if is_open else 0.0
