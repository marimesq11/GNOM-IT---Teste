extends Button

@export_file("*.tscn") var cena_destino: String  # escolha a cena no Inspetor

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	get_tree().paused = false  # garante que a próxima cena não nasça pausada
	get_tree().change_scene_to_file(cena_destino)
