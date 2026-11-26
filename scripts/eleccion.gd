extends Control
## Elegir batallón: una carta grande por batallón con su lema, sus gatos y sus manías.

const Estilo := preload("res://scripts/estilo.gd")
const Datos := preload("res://scripts/datos.gd")
const Gato := preload("res://scripts/gato_animado.gd")

const ESCENA_COMBATE := "res://scenes/combate.tscn"
const ESCENA_MENU := "res://scenes/menu.tscn"
const ANCHO_CARTA := 300


var _nombres_cartas := {}  # id -> nombre, para mostrar las cartas de cada gato
var _arsenal: HBoxContainer


func _ready() -> void:
	for c in Datos.leer("res://data/cartas.json"):
		_nombres_cartas[c["id"]] = c["nombre"]
	theme = Estilo.tema()
	var fondo := ColorRect.new()
	fondo.color = Estilo.TAPETE
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 8)
	centro.add_child(columna)
	columna.add_child(Estilo.titulo(tr("ELIGE TU BATALLÓN"), 34))
	var opciones := HBoxContainer.new()
	opciones.alignment = BoxContainer.ALIGNMENT_CENTER
	opciones.add_theme_constant_override("separation", 40)
	opciones.add_child(_selector_dificultad())
	opciones.add_child(_selector_rival())
	columna.add_child(opciones)

	var cartas := HBoxContainer.new()
	cartas.add_theme_constant_override("separation", 14)
	columna.add_child(cartas)
	var batallones: Dictionary = Partida.batallones()
	for id in batallones:
		cartas.add_child(_carta(id, batallones[id]))

	# Abajo: Volver y el Arsenal (cartas de botín guardadas para llevar a la batalla).
	var pie := HBoxContainer.new()
	pie.add_theme_constant_override("separation", 16)
	columna.add_child(pie)
	var volver := Button.new()
	volver.text = tr("Volver")
	volver.custom_minimum_size = Vector2(140, 44)
	volver.pressed.connect(func(): get_tree().change_scene_to_file(ESCENA_MENU))
	pie.add_child(volver)
	_arsenal = HBoxContainer.new()
	_arsenal.add_theme_constant_override("separation", 8)
	_arsenal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pie.add_child(_arsenal)
	_refrescar_arsenal()


## Fila del Arsenal: cada carta guardada es un botón que se marca para llevarla (hasta 2).
func _refrescar_arsenal() -> void:
	for hijo in _arsenal.get_children():
		_arsenal.remove_child(hijo)
		hijo.queue_free()
	var titulo := Label.new()
	titulo.add_theme_color_override("font_color", Estilo.ACENTO)
	_arsenal.add_child(titulo)
	if Partida.arsenal.is_empty():
		titulo.text = tr("Arsenal vacío: derriba tanques enemigos y quédate con sus cartas.")
		return
	titulo.text = tr("Arsenal (llevas %d/%d):") % [Partida.llevar.size(), Partida.LLEVAR_MAX]
	for i in Partida.arsenal.size():
		var id: String = Partida.arsenal[i]
		var b := Button.new()
		b.text = _nombres_cartas.get(id, id)
		b.toggle_mode = true
		b.button_pressed = Partida.llevar.has(i)
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_stylebox_override("normal", Estilo.caja(Color("fff1c2"), Color("c8961e"), 3))
		b.add_theme_stylebox_override("pressed", Estilo.caja(Color("ffd166"), Estilo.TINTA, 3))
		b.toggled.connect(func(_activo: bool):
			Partida.alternar_llevar(i)
			_refrescar_arsenal.call_deferred())
		_arsenal.add_child(b)


## Rival: al azar o un batallón fijo. Si eliges el mismo que juegas, sale uno al azar.
func _selector_rival() -> Control:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 4)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	caja.add_child(fila)
	var etiqueta := Label.new()
	etiqueta.text = tr("Rival:")
	fila.add_child(etiqueta)
	var grupo := ButtonGroup.new()
	var nombres := {"": tr("Al azar")}
	var batallones: Dictionary = Partida.batallones()
	for id in batallones:
		nombres[id] = batallones[id]["nombre_corto"]
	for id in nombres:
		var b := Button.new()
		b.text = nombres[id]
		b.toggle_mode = true
		b.button_group = grupo
		b.custom_minimum_size = Vector2(0, 30)
		b.add_theme_font_size_override("font_size", 14)
		b.button_pressed = id == Partida.rival_elegido
		b.toggled.connect(func(activo: bool):
			if activo:
				Partida.rival_elegido = id)
		fila.add_child(b)
	caja.add_child(_fila_mapas())
	return caja


## Mapa de la batalla suelta: al azar o uno fijo.
func _fila_mapas() -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	var etiqueta := Label.new()
	etiqueta.text = tr("Mapa:")
	fila.add_child(etiqueta)
	var grupo := ButtonGroup.new()
	for nombre in [""] + Partida.MAPAS.keys():
		var b := Button.new()
		b.text = tr("Al azar") if nombre == "" else tr(nombre)
		b.toggle_mode = true
		b.button_group = grupo
		b.custom_minimum_size = Vector2(0, 30)
		b.add_theme_font_size_override("font_size", 14)
		b.button_pressed = nombre == Partida.mapa_elegido
		b.toggled.connect(func(activo: bool):
			if activo:
				Partida.mapa_elegido = nombre)
		fila.add_child(b)
	return fila


## Tres botones (Recluta / Veterano / As) y una línea que explica el elegido.
func _selector_dificultad() -> Control:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 4)
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 10)
	caja.add_child(fila)
	var etiqueta := Label.new()
	etiqueta.text = tr("Dificultad:")
	fila.add_child(etiqueta)
	var explicacion := Label.new()
	explicacion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explicacion.add_theme_color_override("font_color", Estilo.ACENTO)
	explicacion.add_theme_font_size_override("font_size", 13)
	explicacion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explicacion.custom_minimum_size = Vector2(470, 0)  # que el texto largo no ensanche la pantalla
	var grupo := ButtonGroup.new()
	for id in Partida.DIFICULTADES:
		var d: Dictionary = Partida.DIFICULTADES[id]
		var b := Button.new()
		b.text = tr(d["nombre"])
		b.toggle_mode = true
		b.button_group = grupo
		b.custom_minimum_size = Vector2(130, 36)
		b.button_pressed = id == Partida.dificultad
		b.toggled.connect(func(activo: bool):
			if activo:
				Partida.dificultad = id
				explicacion.text = tr(d["texto"]))
		fila.add_child(b)
	explicacion.text = tr(Partida.DIFICULTADES[Partida.dificultad]["texto"])
	caja.add_child(explicacion)
	return caja


func _carta(id: String, b: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(ANCHO_CARTA, 0)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	panel.add_child(caja)

	var titulo := Estilo.texto_en_papel(b["nombre"], 22)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(titulo)
	var lema := Estilo.texto_en_papel("«%s»" % b["lema"], 14)
	lema.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(lema)
	# Con 4 batallones no entra la descripción: queda al pasar el mouse sobre la carta.
	panel.tooltip_text = b["descripcion"]

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
		datos.add_child(Estilo.texto_en_papel(u["mania_texto"], 12))
		var nombres_cartas: Array = u.get("habilidades", []).map(func(id): return _nombres_cartas.get(id, id))
		if not nombres_cartas.is_empty():
			var cartas_gato := Estilo.texto_en_papel(tr("Cartas: ") + ", ".join(nombres_cartas), 12)
			cartas_gato.add_theme_color_override("font_color", Color("3b6fb0"))
			datos.add_child(cartas_gato)
		fila.add_child(datos)
		caja.add_child(fila)

	var elegir := Button.new()
	elegir.text = tr("Jugar con este batallón")
	elegir.custom_minimum_size = Vector2(0, 48)
	elegir.pressed.connect(func():
		Partida.preparar_partida_libre()
		Partida.elegir(id)
		get_tree().change_scene_to_file(ESCENA_COMBATE))
	# Al pasar por el botón, los gatos de ese batallón se alegran.
	elegir.mouse_entered.connect(func():
		for g in gatos:
			g.animar("happy", 0.9))
	caja.add_child(elegir)
	return panel
