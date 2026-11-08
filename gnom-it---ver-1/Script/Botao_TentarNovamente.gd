
extends Button

# Arraste a cena da fase pelo Inspector
@export_file("*.tscn") var cena_destino: String


func _ready() -> void:
	pressed.connect(tentar_novamente)


func tentar_novamente() -> void:
	if cena_destino.is_empty():
		push_error("Cena de destino não configurada!")
		return

	# Carrega uma nova instância da fase
	get_tree().change_scene_to_file(cena_destino)
