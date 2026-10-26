extends Button

@export var sprite: Sprite2D
@export var botao_x: Button
@export var outros_botoes: Array[Button]

func _ready() -> void:
	sprite.visible = false
	botao_x.visible = false
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	sprite.visible = true
	botao_x.visible = true

	for botao in outros_botoes:
		botao.disabled = true
