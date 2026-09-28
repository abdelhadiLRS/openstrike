extends StaticBody3D

@export var max_health := 100
@export var team := "RED"

var health := max_health
var collision_shape: CollisionShape3D

func _ready() -> void:
    collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D

func take_damage(amount: int) -> void:
    if health <= 0:
        return
    health = maxi(0, health - amount)
    if health == 0:
        visible = false
        if collision_shape:
            collision_shape.disabled = true

func reset_target() -> void:
    health = max_health
    visible = true
    if collision_shape:
        collision_shape.disabled = false
