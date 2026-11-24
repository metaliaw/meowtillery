extends Control
## Elegir batallón: una carta grande por batallón con su lema, sus gatos y sus manías.

const Estilo := preload("res://scripts/estilo.gd")
const Gato := preload("res://scripts/gato_animado.gd")

const ESCENA_COMBATE := "res://scenes/combate.tscn"
const ESCENA_MENU := "res://scenes/menu.tscn"
const ANCHO_CARTA := 590


func _ready() -> void:
	theme = Estilo.tema()
	var fondo := ColorRect.new()
	fondo.color = Estilo.TAPETE
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 14)
	centro.add_child(columna)
	columna.add_child(Estilo.titulo("ELIGE TU BATALLÓN", 40))
	columna.add_child(_selector_dificultad())

	var cartas := HBoxContainer.new()
	cartas.add_theme_constant_override("separation", 20)
	columna.add_child(cartas)
	var batallones: Dictionary = Partida.batallones()
	for id in batallones:
		cartas.add_child(_carta(id, batallones[id]))

	var volver := Button.new()
	volver.text = "Volver"
	volver.custom_minimum_size = Vector2(140, 44)
	volver.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	volver.pressed.connect(func(): get_tree().change_scene_to_file(ESCENA_MENU))
	columna.add_child(volver)


## Tres botones (Recluta / Veterano / As) y una línea que explica el elegido.
func _selector_dificultad() -> Control:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 4)
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 10)
	caja.add_child(fila)
	var etiqueta := Label.new()
	etiqueta.text = "Dificultad:"
	fila.add_child(etiqueta)
	var explicacion := Label.new()
	explicacion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explicacion.add_theme_color_override("font_color", Estilo.ACENTO)
	var grupo := ButtonGroup.new()
	for id in Partida.DIFICULTADES:
		var d: Dictionary = Partida.DIFICULTADES[id]
		var b := Button.new()
		b.text = d["nombre"]
		b.toggle_mode = true
		b.button_group = grupo
		b.custom_minimum_size = Vector2(130, 36)
		b.button_pressed = id == Partida.dificultad
		b.toggled.connect(func(activo: bool):
			if activo:
				Partida.dificultad = id
				explicacion.text = d["texto"])
		fila.add_child(b)
	explicacion.text = Partida.DIFICULTADES[Partida.dificultad]["texto"]
	caja.add_child(explicacion)
	return caja


func _carta(id: String, b: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(ANCHO_CARTA, 0)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	panel.add_child(caja)

	var titulo := Estilo.texto_en_papel(b["nombre"], 26)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(titulo)
	var lema := Estilo.texto_en_papel("«%s»" % b["lema"], 16)
	lema.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(lema)
	caja.add_child(Estilo.texto_en_papel(b["descripcion"], 14))

	var gatos: Array[Gato] = []
	for u in b["unidades"]:
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 10)
		var gato := Gato.new(2, load(u["gato"]))
		gatos.append(gato)
		fila.add_child(gato)
		var datos := VBoxContainer.new()
		datos.add_theme_constant_override("separation", 0)
		datos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		datos.add_child(Estilo.texto_en_papel("%s · %s" % [u["nombre"], u["inspirado_en"]], 15))
		datos.add_child(Estilo.texto_en_papel(u["mania_texto"], 13))
		fila.add_child(datos)
		fila.add_child(Estilo.imagen(u["sprite"], 1))
		caja.add_child(fila)

	var elegir := Button.new()
	elegir.text = "Jugar con este batallón"
	elegir.custom_minimum_size = Vector2(0, 48)
	elegir.pressed.connect(func():
		Partida.elegir(id)
		get_tree().change_scene_to_file(ESCENA_COMBATE))
	# Al pasar por el botón, los gatos de ese batallón se alegran.
	elegir.mouse_entered.connect(func():
		for g in gatos:
			g.animar("happy", 0.9))
	caja.add_child(elegir)
	return panel
