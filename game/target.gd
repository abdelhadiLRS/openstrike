extends StaticBody3D

var health := 100

func take_damage(amount: int) -> void:
    health -= amount
    if health <= 0:
        health = 100
