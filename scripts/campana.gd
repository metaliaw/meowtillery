extends Control
## Campaña: 5 batallas seguidas, de Recluta a As. Muestra, según el momento:
##  - sin campaña: elegir batallón para empezar;
##  - tras una victoria: elegir 1 de 3 cartas de recompensa (van al Arsenal);
##  - en curso: progreso, próxima batalla, medallas de los gatos y el Arsenal;
##  - al final: ¡campaña completada!

const Estilo := preload("res://scripts/estilo.gd")
const Datos := preload("res://scripts/datos.gd")
const Gato := preload("res://scripts/gato_animado.gd")
const ESCENA_MENU := "res://scenes/menu.tscn"
const ESCENA_COMBATE := "res://scenes/combate.tscn"
const NOMBRES_DIFICULTAD := {"recluta": "Recluta", "veterano": "Veterano", "as": "As"}

var _cartas := {}
var _contenido: VBoxContainer


func _ready() -> void:
	for c in Datos.leer("res://data/cartas.json"):
		_cartas[c["id"]] = c
	theme = Estilo.tema()
	var fondo := ColorRect.new()
	fondo.color = Estilo.TAPETE
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	_contenido = VBoxContainer.new()
	_contenido.add_theme_constant_override("separation", 14)
	_contenido.custom_minimum_size = Vector2(900, 0)
	centro.add_child(_contenido)
	_refrescar()


func _refrescar() -> void:
	for hijo in _contenido.get_children():
		_contenido.remove_child(hijo)
		hijo.queue_free()
	_contenido.add_child(Estilo.titulo("CAMPAÑA", 44))
	if not Partida.campana_activa():
		_pantalla_inicio()
	elif not Partida.campana.get("recompensa", []).is_empty():
		_pantalla_recompensa()
	elif int(Partida.campana["batalla"]) >= Partida.CAMPANA.size():
		_pantalla_final()
	else:
		_pantalla_progreso()


func _texto(t: String, tam: int = 17, color: Color = Estilo.PAPEL) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	return l


func _boton(texto: String, accion: Callable, ancho: int = 260) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(ancho, 50)
	b.pressed.connect(accion)
	return b


func _fila_centrada() -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 14)
	_contenido.add_child(fila)
	return fila


func _pantalla_inicio() -> void:
	_contenido.add_child(_texto("5 batallas seguidas, de Recluta a As, en tres mapas distintos.\n" +
		"Cada gato que sobrevive a una victoria gana una medalla (+%d de vida para el resto de la campaña),\n" % Partida.VIDA_POR_MEDALLA +
		"y después de cada victoria eliges una carta para tu Arsenal. Si pierdes, reintentas esa batalla."))
	_contenido.add_child(_texto("Elige tu batallón:", 20, Estilo.ACENTO))
	var fila := _fila_centrada()
	var batallones: Dictionary = Partida.batallones()
	for id in batallones:
		fila.add_child(_boton(batallones[id]["nombre"], func():
			Partida.empezar_campana(id)
			_refrescar()))
	_fila_centrada().add_child(_boton("Volver al menú", _ir_al_menu))


func _pantalla_recompensa() -> void:
	_contenido.add_child(_texto("¡Victoria! Tus gatos ganaron medallas.", 22, Estilo.ACENTO))
	_contenido.add_child(_texto("Elige una carta de recompensa: va a tu Arsenal y la puedes llevar a la próxima batalla."))
	var fila := _fila_centrada()
	for id in Partida.campana["recompensa"]:
		var c: Dictionary = _cartas[id]
		var b := _boton("%s  [%d]\n%s" % [c["nombre"], int(c["coste"]), c["texto"]], func():
			Partida.elegir_recompensa(id)
			_refrescar(), 250)
		b.custom_minimum_size = Vector2(250, 110)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_stylebox_override("normal", Estilo.caja(Color("fff1c2"), Color("c8961e"), 3))
		b.set_meta("sonido", "carta")
		fila.add_child(b)


func _pantalla_final() -> void:
	_contenido.add_child(_texto("¡CAMPAÑA COMPLETADA!", 30, Estilo.ACENTO))
	_contenido.add_child(_texto("Tus gatos ganaron las 5 batallas. Estas son sus medallas:"))
	_contenido.add_child(_fila_gatos())
	_fila_centrada().add_child(_boton("Terminar campaña", func():
		Partida.abandonar_campana()
		_ir_al_menu()))


func _pantalla_progreso() -> void:
	var c: Dictionary = Partida.campana
	var n: int = c["batalla"]
	var batallones: Dictionary = Partida.batallones()
	_contenido.add_child(_texto("%s · batalla %d de %d" % [batallones[c["batallon"]]["nombre"], n + 1, Partida.CAMPANA.size()], 20, Estilo.ACENTO))
	# Las 5 batallas: hechas, la próxima y las que vienen.
	var fila := _fila_centrada()
	for i in Partida.CAMPANA.size():
		var paso: Dictionary = Partida.CAMPANA[i]
		var mapa: Dictionary = Datos.leer(paso["mapa"])
		var rival_nombre := String(batallones[Partida.rival_de_campana(i)]["nombre"]).replace("Batallón ", "")
		var estado := "Ganada" if i < n else ("Próxima" if i == n else "")
		var panel := PanelContainer.new()
		var color := Color("cfe8c4") if i < n else (Color("fff1c2") if i == n else Estilo.PAPEL)
		panel.add_theme_stylebox_override("panel", Estilo.caja(color, Estilo.TINTA, 3 if i == n else 2))
		panel.custom_minimum_size = Vector2(168, 0)
		var t := Estilo.texto_en_papel("%d. %s\n%s\nvs %s\n%s" % [i + 1, mapa.get("nombre", "Mapa"),
			NOMBRES_DIFICULTAD[paso["dificultad"]], rival_nombre, estado], 14)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(t)
		fila.add_child(panel)
	_contenido.add_child(_texto("Medallas de tus gatos (+%d de vida cada una):" % Partida.VIDA_POR_MEDALLA))
	_contenido.add_child(_fila_gatos())
	_contenido.add_child(_fila_arsenal())
	var botones := _fila_centrada()
	botones.add_child(_boton("¡A la batalla!", func():
		Partida.preparar_batalla_campana()
		get_tree().change_scene_to_file(ESCENA_COMBATE)))
	botones.add_child(_boton("Abandonar campaña", func():
		Partida.abandonar_campana()
		_refrescar(), 220))
	botones.add_child(_boton("Volver al menú", _ir_al_menu, 200))


## Los gatos del batallón de la campaña, con sus medallas.
func _fila_gatos() -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 30)
	var medallas: Dictionary = Partida.campana.get("medallas", {})
	for u in Partida.batallones()[Partida.campana["batallon"]]["unidades"]:
		var caja := VBoxContainer.new()
		caja.add_theme_constant_override("separation", 2)
		var gato := Gato.new(3, load(u["gato"]))
		gato.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		caja.add_child(gato)
		var n := int(medallas.get(u["id"], 0))
		caja.add_child(_texto("%s\n%s" % [u["nombre"], "★".repeat(n) if n > 0 else "sin medallas"], 15))
		fila.add_child(caja)
	return fila


## Arsenal: marcar hasta 2 cartas para llevar a la próxima batalla.
func _fila_arsenal() -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 8)
	var titulo := Label.new()
	titulo.add_theme_color_override("font_color", Estilo.ACENTO)
	fila.add_child(titulo)
	if Partida.arsenal.is_empty():
		titulo.text = "Arsenal vacío: derriba tanques y gana batallas para conseguir cartas."
		return fila
	titulo.text = "Arsenal (llevas %d/%d):" % [Partida.llevar.size(), Partida.LLEVAR_MAX]
	for i in Partida.arsenal.size():
		var id: String = Partida.arsenal[i]
		var b := Button.new()
		b.text = _cartas[id]["nombre"] if _cartas.has(id) else id
		b.toggle_mode = true
		b.button_pressed = Partida.llevar.has(i)
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_stylebox_override("normal", Estilo.caja(Color("fff1c2"), Color("c8961e"), 3))
		b.add_theme_stylebox_override("pressed", Estilo.caja(Color("ffd166"), Estilo.TINTA, 3))
		b.toggled.connect(func(_activo: bool):
			Partida.alternar_llevar(i)
			_refrescar.call_deferred())
		fila.add_child(b)
	return fila


func _ir_al_menu() -> void:
	get_tree().change_scene_to_file(ESCENA_MENU)
