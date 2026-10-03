extends Label3D

func aparecer(texto: String = ""):
	if texto != "":
		text = texto

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y + 1.0, 0.6)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
