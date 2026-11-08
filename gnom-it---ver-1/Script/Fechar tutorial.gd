extends Button

@export var sprite: Sprite2D
@export var outros_botoes: Array[Button]

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	sprite.visible = false
	visible = false

	for botao in outros_botoes:
		botao.disabled = false
