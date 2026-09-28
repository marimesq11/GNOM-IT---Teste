extends Node3D

@onready var timer: Timer = $Timer
@onready var label: Label = $Label

func _ready():
	timer.start()
	label.text = str(ceil(timer.time_left))


func _process(_delta):
	label.text = str(ceil(timer.time_left))


func _on_timer_timeout():
	morrer()


func morrer():
	print("Você morreu!")
