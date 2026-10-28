extends Label3D

func aparecer(texto: String = "") -> void:
	if texto != "":
		text = texto

	# Começa totalmente visível
	transparency = 0.0

	var tween = create_tween()
	tween.set_parallel(true)

	# Faz o popup subir
	tween.tween_property(self, "position:y", position.y + 1.0, 0.6)

	# Faz o popup ficar transparente até desaparecer
	tween.tween_property(self, "transparency", 1.0, 0.6)

	tween.set_parallel(false)
	tween.tween_callback(queue_free)
