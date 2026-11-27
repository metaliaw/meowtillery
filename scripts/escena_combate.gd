extends Control
## Escena de combate: arma la interfaz, la refresca con el estado de Combate
## y traduce los clics en jugadas.
##
## Controles: clic en un tanque tuyo = elegirlo (se ve a dónde puede moverse);
## clic en una casilla azul = moverlo; clic en un enemigo = elegir blanco (se ve
## en rojo lo que amenaza); clic en una carta = jugarla.

const Combate := preload("res://scripts/combate.gd")
const Datos := preload("res://scripts/datos.gd")
const Tablero := preload("res://scripts/tablero.gd")
const Mapa := preload("res://scripts/mapa.gd")
const Estilo := preload("res://scripts/estilo.gd")
const Gato := preload("res://scripts/gato_animado.gd")
const Globo := preload("res://scripts/globo.gd")
const Ficha := preload("res://scripts/ficha.gd")
const ControlSonido := preload("res://scripts/control_sonido.gd")

const ESCENA_MENU := "res://scenes/menu.tscn"
const LINEAS_DE_REGISTRO := 8
const ANCHO_PANEL := 400

var combate: Combate
var actor_sel := 0
var objetivo_sel := 0

var _info: Label
var _tablero: Tablero
var _ficha_actor: Ficha
var _ficha_objetivo: Ficha
var _registro: Label
var _vista_previa: Label
var _michi: Gato
var _fila_michi: HBoxContainer
var _orden: Globo
var _orden_anterior := -2  # para que Michi reaccione solo cuando cambia la orden
var _fin_sonado := false
var _hazanas: Array = []  # trofeos ganados en la acción que se está animando
var _mano: HBoxContainer
var _cara_actor: TextureRect
var _atlas_cara := AtlasTexture.new()
var _boton_turno: Button
var _capa_final: Control
var _capa_pausa: Control
var _capa_confirmar: Control
var _boton_otra: Button
var _boton_volver: Button
var _capa_captura: Control
var _texto_captura: Label
var _opciones_captura: HBoxContainer
var _texto_confirmar: Label
var _texto_final: Label


func _ready() -> void:
	_construir_interfaz()
	_nueva_partida()


func _nueva_partida() -> void:
	if combate != null:
		Partida.cerrar_batalla(combate)  # el botín sin usar vuelve al Arsenal
	combate = Combate.new()
	# Diferido: así no se reconstruye la UI dentro del clic que la disparó.
	combate.cambio.connect(_refrescar, CONNECT_DEFERRED)
	combate.evento.connect(_al_evento)
	# Cada acción se anima en el tablero, en orden (y ahí suenan disparos y explosiones).
	combate.accion.connect(_tablero.encolar)
	# Los trofeos se anuncian cuando termina la animación (después de la kill cam, no antes).
	_hazanas.clear()
	combate.hazana.connect(func(id: String): _hazanas.append(id))
	_fin_sonado = false
	var con_michi := Partida.nueva_batalla(combate)
	_fila_michi.visible = con_michi
	_orden_anterior = -2
	if con_michi:
		combate.registro.insert(0, tr("¡Inspección sorpresa! La teniente Michi toma el mando."))
	actor_sel = 0
	objetivo_sel = 0
	_tablero.preparar(combate)
	_refrescar()


func _construir_interfaz() -> void:
	theme = Estilo.tema()
	var fondo := ColorRect.new()
	fondo.color = Estilo.TAPETE
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 24)
	add_child(margen)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 12)
	margen.add_child(columna)

	_info = Label.new()
	columna.add_child(_info)

	var medio := HBoxContainer.new()
	medio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	medio.add_theme_constant_override("separation", 16)
	columna.add_child(medio)

	_tablero = Tablero.new()
	_tablero.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_tablero.celda_pulsada.connect(_al_pulsar_celda)
	_tablero.animacion_terminada.connect(_refrescar)
	medio.add_child(_tablero)

	# Columna derecha: Michi fija arriba y, debajo, fichas, vista previa y registro dentro
	# de una caja con scroll propio. Así el texto largo nunca empuja la mano ni los botones.
	var lado := VBoxContainer.new()
	lado.custom_minimum_size = Vector2(ANCHO_PANEL, 0)
	lado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lado.add_theme_constant_override("separation", 10)
	medio.add_child(lado)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Sin barra a la vista (distraía): lo que no cabe, que es el registro, se ve con la rueda.
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var margen_scroll := MarginContainer.new()
	margen_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margen_scroll)
	var lateral := VBoxContainer.new()
	lateral.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lateral.add_theme_constant_override("separation", 10)
	margen_scroll.add_child(lateral)
	# La teniente Michi, oficial al mando, con la orden del turno.
	var fila_michi := HBoxContainer.new()
	fila_michi.add_theme_constant_override("separation", 22)  # espacio para la colita del globo
	lado.add_child(fila_michi)
	lado.add_child(scroll)
	_fila_michi = fila_michi
	_michi = Gato.new(2, load(Partida.OFICIAL["gato"]))
	_michi.tooltip_text = tr(Partida.OFICIAL["mania_texto"])
	_michi.mouse_filter = Control.MOUSE_FILTER_STOP
	fila_michi.add_child(_michi)
	# Lo que dice Michi va en un globo de cómic que apunta a ella.
	_orden = Globo.new("", 14, "izquierda")
	_orden.cola_pos = 0.5
	fila_michi.add_child(_orden)
	_orden.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_orden.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# La vista previa va primero: es lo que se mira al pasar el mouse por una carta y
	# así nunca queda escondida bajo el scroll.
	_vista_previa = _etiqueta(lateral, Color.WHITE)
	_ficha_actor = Ficha.new(Color("ffe08a"))
	lateral.add_child(_ficha_actor)
	_ficha_objetivo = Ficha.new(Color("ff9eb5"))
	lateral.add_child(_ficha_objetivo)
	_registro = _etiqueta(lateral, Color(1, 1, 1, 0.7))

	var abajo := HBoxContainer.new()
	abajo.add_theme_constant_override("separation", 8)
	columna.add_child(abajo)
	# Cara del gato del tanque elegido: las cartas de al lado son las suyas.
	_cara_actor = TextureRect.new()
	_cara_actor.texture = _atlas_cara
	_cara_actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cara_actor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cara_actor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cara_actor.custom_minimum_size = Vector2(78, 100)
	abajo.add_child(_cara_actor)
	_mano = HBoxContainer.new()
	_mano.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mano.add_theme_constant_override("separation", 8)
	abajo.add_child(_mano)
	var menu := Button.new()
	menu.text = tr("Menú\n(Esc)")
	menu.custom_minimum_size = Vector2(90, 100)
	menu.pressed.connect(_abrir_pausa)
	abajo.add_child(menu)
	_boton_turno = Button.new()
	_boton_turno.text = tr("Terminar turno")
	_boton_turno.custom_minimum_size = Vector2(160, 100)
	_boton_turno.pressed.connect(_al_terminar_turno)
	abajo.add_child(_boton_turno)

	var final := _capa_oscura()
	_capa_final = final[0]
	var caja_final := VBoxContainer.new()
	caja_final.add_theme_constant_override("separation", 14)
	final[1].add_child(caja_final)
	_texto_final = Estilo.titulo("", 64)
	caja_final.add_child(_texto_final)
	_boton_otra = Button.new()
	_boton_otra.text = tr("Jugar de nuevo")
	_boton_otra.pressed.connect(_nueva_partida)
	caja_final.add_child(_boton_otra)
	_boton_volver = Button.new()
	_boton_volver.text = tr("Volver al menú")
	_boton_volver.pressed.connect(_salir_del_final)
	caja_final.add_child(_boton_volver)

	_construir_pausa()
	_construir_confirmacion()
	_construir_captura()


## Capa a pantalla completa que oscurece el juego (y bloquea sus clics) con un
## contenedor centrado encima. Devuelve [capa, centro]. Empieza oculta.
func _capa_oscura() -> Array:
	var capa := Control.new()
	capa.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.visible = false
	add_child(capa)
	var sombra := ColorRect.new()
	sombra.color = Color(0, 0, 0, 0.6)
	sombra.set_anchors_preset(Control.PRESET_FULL_RECT)
	sombra.mouse_filter = Control.MOUSE_FILTER_STOP
	capa.add_child(sombra)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(centro)
	return [capa, centro]


## Menú de pausa: seguir, reiniciar la batalla o volver al menú. Se abre con el botón
## "Menú" o con Esc, y Esc también lo cierra.
func _construir_pausa() -> void:
	var pausa := _capa_oscura()
	_capa_pausa = pausa[0]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	pausa[1].add_child(panel)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 12)
	panel.add_child(caja)
	var titulo := Estilo.texto_en_papel(tr("Pausa"), 30)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(titulo)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 22)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_child(fila)
	fila.add_child(Gato.new(3))
	var globo := Globo.new(tr("¿Te vas tan pronto?\nLa batalla te espera."), 15, "izquierda")
	globo.cola_pos = 0.6
	globo.custom_minimum_size = Vector2(220, 0)  # sin ancho mínimo el texto se apila en columna
	fila.add_child(globo)
	for opcion in [[tr("Seguir jugando"), _cerrar_pausa], [tr("Reiniciar batalla"), _reiniciar_desde_pausa],
			[tr("Volver al menú"), _ir_al_menu]]:
		var b := Button.new()
		b.text = opcion[0]
		b.custom_minimum_size = Vector2(0, 46)
		b.pressed.connect(opcion[1])
		caja.add_child(b)
	var sonido := ControlSonido.new(Estilo.TINTA)
	sonido.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_child(sonido)
	var aviso := Estilo.texto_en_papel(tr("Reiniciar o salir pierde la batalla en curso."), 13)
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(aviso)


## Ventana de botín: al derribar un enemigo, elegir con cuál de sus cartas quedarse.
func _construir_captura() -> void:
	var capa := _capa_oscura()
	_capa_captura = capa[0]
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Estilo.caja(Color("fff6d6"), Color("c8961e"), 4))
	panel.custom_minimum_size = Vector2(520, 0)
	capa[1].add_child(panel)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 12)
	panel.add_child(caja)
	var titulo := Estilo.texto_en_papel(tr("¡Botín!"), 30)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(titulo)
	_texto_captura = Estilo.texto_en_papel("", 16)
	_texto_captura.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(_texto_captura)
	_opciones_captura = HBoxContainer.new()
	_opciones_captura.add_theme_constant_override("separation", 12)
	caja.add_child(_opciones_captura)


func _refrescar_captura() -> void:
	if combate.capturas.is_empty():
		_capa_captura.visible = false
		return
	var captura: Dictionary = combate.capturas[0]
	_texto_captura.text = tr("Derribaste a %s. Quédate con una de sus cartas:
se usa una vez y cualquier tanque tuyo la puede jugar.
Si no la usas, se guarda en tu Arsenal.") % captura["de"]
	_vaciar(_opciones_captura)
	for id in captura["opciones"]:
		var c: Dictionary = combate.cartas[id]
		var b := Button.new()
		b.text = "%s  [%d]
%s" % [c["nombre"], int(c["coste"]), c["texto"]]
		b.custom_minimum_size = Vector2(240, 110)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 15)
		b.set_meta("sonido", "carta")
		b.pressed.connect(func(): combate.elegir_botin(id))
		_opciones_captura.add_child(b)
	_capa_captura.visible = true


## Carta de botín: dorada, de un solo uso; la juega el tanque elegido.
func _boton_botin(i_botin: int) -> Button:
	var id: String = combate.botin[i_botin]
	var c: Dictionary = combate.cartas[id]
	var b := Button.new()
	b.text = tr("BOTÍN · %s  [%d]
%s") % [c["nombre"], int(c["coste"]), c["texto"]]
	b.custom_minimum_size = Vector2(120, 100)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_stylebox_override("normal", Estilo.caja(Color("fff1c2"), Color("c8961e"), 3))
	b.add_theme_stylebox_override("hover", Estilo.caja(Color("fff8dc"), Color("e0a82a"), 3))
	var motivo := combate.motivo_botin(i_botin, actor_sel, objetivo_sel)
	b.disabled = motivo != ""
	b.set_meta("sonido", "carta")
	b.tooltip_text = motivo if motivo != "" else tr("Botín de un solo uso. ") + c["texto"]
	b.pressed.connect(combate.usar_botin.bind(i_botin, actor_sel, objetivo_sel))
	b.mouse_entered.connect(_mostrar_prevision.bind(id, i_botin))
	b.mouse_exited.connect(_ocultar_prevision)
	return b


## Pregunta antes de terminar el turno si todavía hay tanques con cartas por jugar.
func _construir_confirmacion() -> void:
	var capa := _capa_oscura()
	_capa_confirmar = capa[0]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	capa[1].add_child(panel)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 12)
	panel.add_child(caja)
	var titulo := Estilo.texto_en_papel(tr("¿Terminar el turno?"), 26)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(titulo)
	_texto_confirmar = Estilo.texto_en_papel("", 16)
	_texto_confirmar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(_texto_confirmar)
	var seguir := Button.new()
	seguir.text = tr("Seguir jugando")
	seguir.custom_minimum_size = Vector2(0, 46)
	seguir.pressed.connect(func(): _capa_confirmar.visible = false)
	caja.add_child(seguir)
	var terminar := Button.new()
	terminar.text = tr("Terminar de todos modos")
	terminar.custom_minimum_size = Vector2(0, 46)
	terminar.pressed.connect(func():
		_capa_confirmar.visible = false
		combate.terminar_turno())
	caja.add_child(terminar)


func _al_terminar_turno() -> void:
	var pendientes := combate.tanques_con_acciones()
	if pendientes.is_empty():
		combate.terminar_turno()
		return
	var cuantos := pendientes.size()
	var plantilla := tr("Todavía te queda %d tanque con cartas por usar: %s.\nTe queda %d de energía.") \
		if cuantos == 1 else tr("Todavía te quedan %d tanques con cartas por usar: %s.\nTe queda %d de energía.")
	_texto_confirmar.text = plantilla % [cuantos, ", ".join(pendientes), combate.energia]
	_capa_confirmar.visible = true


func _abrir_pausa() -> void:
	if not _capa_final.visible:
		_capa_pausa.visible = true


func _cerrar_pausa() -> void:
	_capa_pausa.visible = false


func _reiniciar_desde_pausa() -> void:
	_capa_pausa.visible = false
	_nueva_partida()


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel") and not _capa_final.visible:
		if _capa_captura.visible:
			return  # el botín hay que elegirlo
		if _capa_confirmar.visible:
			_capa_confirmar.visible = false  # Esc = seguir jugando
		else:
			_capa_pausa.visible = not _capa_pausa.visible
		get_viewport().set_input_as_handled()


func _salir_del_final() -> void:
	if Partida.modo_campana:
		get_tree().change_scene_to_file("res://scenes/campana.tscn")
	else:
		_ir_al_menu()


func _ir_al_menu() -> void:
	get_tree().change_scene_to_file(ESCENA_MENU)


## Al salir de la escena (menú, cerrar el juego...), el botín sin usar vuelve al Arsenal.
func _exit_tree() -> void:
	Partida.cerrar_batalla(combate)


func _etiqueta(padre: Control, color: Color) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.modulate = color
	padre.add_child(l)
	return l


## Sonidos que no dependen de una animación del tablero.
func _al_evento(nombre: String) -> void:
	if nombre == "turno":
		Sonido.tocar("turno")


## Mientras el tablero anima: nada se puede tocar y no se muestran resaltados viejos.
func _bloquear() -> void:
	for b in _mano.get_children():
		(b as Button).disabled = true
	_boton_turno.disabled = true
	_tablero.movimiento = {}
	_tablero.amenaza = {}
	_tablero.alcance = {}
	_tablero.prevision = {}
	_tablero.actor_pos = Vector2i(-1, -1)
	_tablero.objetivo_pos = Vector2i(-1, -1)
	_tablero.queue_redraw()


func _refrescar() -> void:
	if _tablero.animando:
		_bloquear()  # se refresca de verdad cuando termina la animación
		return
	_tablero.sincronizar()
	for id in _hazanas:
		Trofeos.conseguir(id)
	_hazanas.clear()
	actor_sel = _seleccion_valida(combate.aliados, actor_sel)
	objetivo_sel = _seleccion_valida(combate.enemigos, objetivo_sel)
	var actor: Dictionary = combate.aliados[actor_sel]
	var objetivo: Dictionary = combate.enemigos[objetivo_sel]
	var jugando := combate.estado == "jugando"

	var energia := tr("Energía %d") % combate.energia
	if combate.energia > Combate.ENERGIA_POR_TURNO:
		energia += tr(" (+%d extra)") % (combate.energia - Combate.ENERGIA_POR_TURNO)  # Michi o Recarga
	var evento_dado := ""
	if not combate.evento_frente.is_empty() and combate.evento_activo(combate.evento_frente["id"]):
		evento_dado = tr("   ·   Dado: %s") % combate.evento_frente["nombre"]
	_info.text = tr("%s   ·   Turno %d   ·   %s%s   ·   Elige un tanque para ver sus cartas") % [
		tr(combate.dificultad.get("nombre", "")), combate.turno, energia, evento_dado]

	_tablero.actor_pos = actor["pos"] if combate.vivo(actor) else Vector2i(-1, -1)
	_tablero.objetivo_pos = objetivo["pos"] if combate.vivo(objetivo) else Vector2i(-1, -1)
	_tablero.movimiento = combate.casillas_de_movimiento(actor, actor["mov_restante"]) if jugando and combate.vivo(actor) else {}
	_tablero.amenaza = combate.celdas_amenaza(objetivo) if jugando else {}
	_tablero.alcance = _celdas_a_tiro(actor) if jugando and combate.vivo(actor) else {}
	var ordenado: Dictionary = combate.aliados[combate.orden] if combate.orden >= 0 else {}
	_tablero.orden_pos = ordenado["pos"] if jugando and not ordenado.is_empty() and combate.vivo(ordenado) else Vector2i(-1, -1)
	# Peligro: tanques propios que los enemigos podrían destruir en su próxima fase.
	var peligro := {}
	if jugando:
		for u in combate.aliados:
			if combate.vivo(u) and combate.dano_en_peligro(u) >= u["casco"]:
				peligro[u["pos"]] = true
	_tablero.peligro = peligro
	_tablero.queue_redraw()
	_refrescar_orden(ordenado)

	var aviso := ""
	var en_riesgo := combate.dano_en_peligro(actor) if jugando else 0
	if en_riesgo >= actor["casco"]:
		aviso = tr("¡PELIGRO! Si se queda aquí, los enemigos le pueden quitar hasta %d de vida.") % en_riesgo
		if combate.dificultad.get("salvavidas", false) and actor["casco"] == actor["casco_max"]:
			aviso += tr(" Está sano: si cae, se salva por los bigotes.")
	elif en_riesgo > 0:
		aviso = tr("Si se queda aquí, le pueden quitar hasta %d de vida.") % en_riesgo
	_ficha_actor.mostrar(actor, combate, aviso)
	# Ficha del blanco: qué planea y, desde el tanque elegido, por qué lado le pegarías
	# (ese lado queda marcado con un anillo amarillo en el dibujo del blindaje).
	var extra := tr("Planea: ") + combate.texto_intencion(objetivo)
	var lado := ""
	if combate.vivo(actor) and combate.vivo(objetivo):
		lado = combate.lado_de_impacto(objetivo, actor["pos"])
		extra += tr("\nDesde %s (a %d casillas) le das por %s.") % [
			actor["nombre"], Mapa.distancia(actor["pos"], objetivo["pos"]), _lado_con_articulo(lado)]
	_ficha_objetivo.mostrar(objetivo, combate, extra, lado)
	# Lo más nuevo arriba: si no cabe todo, lo que se recorta es lo más viejo.
	var ultimas: Array = combate.registro.slice(-LINEAS_DE_REGISTRO)
	ultimas.reverse()
	_registro.text = "\n".join(ultimas)

	# Abajo: las cartas del tanque elegido, con la cara de su gato al principio.
	_vaciar(_mano)
	if combate.vivo(actor):
		if actor.has("gato"):
			_atlas_cara.atlas = load(actor["gato"])
			_atlas_cara.region = Rect2(3, (3 if combate.en_panico(actor) else 0) * 32, 26, 20)
		_cara_actor.visible = actor.has("gato")
		for id in combate.cartas_de(actor_sel):
			_mano.add_child(_boton_carta(id))
		for i in combate.botin.size():
			_mano.add_child(_boton_botin(i))
		# Con muchas cartas (botín incluido) la letra se achica para que la fila no crezca.
		if _mano.get_child_count() > 5:
			for carta in _mano.get_children():
				(carta as Button).add_theme_font_size_override("font_size", 12)
	_ocultar_prevision()
	_refrescar_captura()

	_boton_turno.disabled = not jugando
	# El botón cuenta cuántos tanques todavía pueden jugar alguna carta.
	var pendientes := combate.tanques_con_acciones() if jugando else []
	_boton_turno.text = tr("Terminar turno") if pendientes.is_empty() else tr("Terminar turno
(%d con cartas)") % pendientes.size()
	_capa_final.visible = not jugando
	_texto_final.text = tr("¡Victoria!") if combate.estado == "victoria" else tr("Derrota")
	# En campaña: la victoria suma medallas y avanza; la derrota permite reintentar.
	if Partida.modo_campana:
		_boton_otra.text = tr("Reintentar batalla")
		_boton_otra.visible = combate.estado != "victoria"
		_boton_volver.text = tr("Continuar campaña") if combate.estado == "victoria" else tr("Volver a la campaña")
	if not jugando and not _fin_sonado:
		_fin_sonado = true
		if combate.estado == "victoria":
			Trofeos.victoria_con(Partida.jugador, Partida.batallones().size())
		if Partida.modo_campana and combate.estado == "victoria":
			var batallon: String = Partida.campana.get("batallon", "")
			if Partida.campana_ganada(combate):
				Trofeos.campana_terminada(batallon)
		Sonido.tocar(combate.estado)
		if combate.estado == "victoria":
			# Después de la fanfarria, los gatos ronronean contentos.
			get_tree().create_timer(0.7).timeout.connect(func(): Sonido.tocar("ronroneo"))


func _refrescar_orden(ordenado: Dictionary) -> void:
	if combate.oficial.is_empty():
		return  # esta batalla no hubo inspección
	if ordenado.is_empty():
		_orden.texto = tr("Hoy no hay órdenes. No te acostumbres.")
	elif combate.orden_cumplida:
		_orden.texto = tr("Aceptable. +1 energía el próximo turno.")
	else:
		_orden.texto = tr("¡%s, dispara este turno! Si no, -1 moral.") % ordenado["nombre"]
	# Gestos: enojada al dar una orden nueva, feliz (a su manera) cuando la cumplen.
	var estado_orden := combate.orden + (100 if combate.orden_cumplida else 0)
	if estado_orden != _orden_anterior and _michi.is_inside_tree():
		_michi.animar("happy" if combate.orden_cumplida else "angry", 1.2)
		if not ordenado.is_empty():
			Sonido.tocar("michi_aprueba" if combate.orden_cumplida else "michi_grunido")
	_orden_anterior = estado_orden


## Celdas que el tanque elegido alcanza con alguna de sus cartas de ataque disponibles.
func _celdas_a_tiro(actor: Dictionary) -> Dictionary:
	var res := {}
	var disponibles: Array = combate.cartas_de(actor_sel).filter(
		func(id): return not actor.get("usadas", {}).has(id) and not actor.get("recargas", {}).has(id))
	for id in disponibles + combate.botin:
		var c: Dictionary = combate.cartas[id]
		if c.get("tipo") != "ataque":
			continue
		for y in combate.mapa.alto:
			for x in combate.mapa.ancho:
				var celda := Vector2i(x, y)
				var dist: int = Mapa.distancia(actor["pos"], celda)
				var alc: Array = combate.alcance_de(c)
				if dist >= alc[0] and dist <= alc[1] and combate.ve_a(c, actor["pos"], celda):
					res[celda] = true
	return res


func _boton_carta(id: String) -> Button:
	var c: Dictionary = combate.cartas[id]
	var b := Button.new()
	# El coste puede depender del tanque elegido (manías).
	b.text = tr("%s  [%d]\n%s") % [c["nombre"], combate.coste_de(c, combate.aliados[actor_sel]), c["texto"]]
	var recarga := int(c.get("recarga", 0))
	if recarga > 0 and recarga < 50:  # recargas enormes = "una vez por batalla" (ya lo dice el texto)
		b.text += tr("\nRecarga: %d turno%s") % [recarga, "" if recarga == 1 else "s"]
	# Ancho repartido, texto en varias líneas y alto fijo: el texto no puede agrandar la carta
	# (clip_text), así la fila de abajo nunca se corre.
	b.custom_minimum_size = Vector2(120, 100)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 14)
	var motivo := combate.motivo_uso(id, actor_sel, objetivo_sel)
	b.disabled = motivo != ""
	b.set_meta("sonido", "carta")
	b.tooltip_text = motivo if motivo != "" else c["texto"]
	b.pressed.connect(combate.usar.bind(id, actor_sel, objetivo_sel))
	# Los botones deshabilitados también avisan el hover: así se ve por qué no se puede.
	b.mouse_entered.connect(_mostrar_prevision.bind(id))
	b.mouse_exited.connect(_ocultar_prevision)
	return b


## Al pasar el mouse sobre una carta: qué haría con el tanque y el blanco elegidos.
func _mostrar_prevision(id: String, i_botin: int = -1) -> void:
	if not combate.cartas.has(id) or not _puede_previsualizar():
		return
	var c: Dictionary = combate.cartas[id]
	var actor: Dictionary = combate.aliados[actor_sel]
	var lineas := PackedStringArray()
	var impactos := combate.prever_uso(id, actor_sel, objetivo_sel)
	var marcas := {}
	if impactos.is_empty():
		lineas.append("%s: %s" % [c["nombre"], c["texto"].replace("\n", " ")])
	for imp in impactos:
		var e: Dictionary = combate.enemigos[imp["indice"]]
		var marca := "-%d" % imp["al_casco"]
		if imp["derriba"]:
			marca += tr(" KO")
		if imp.get("acierto", 1.0) < 1.0:
			marca += " %d%%" % roundi(imp["acierto"] * 100)
		marcas[e["pos"]] = {"texto": marca, "derriba": imp["derriba"]}
		if imp["principal"]:
			lineas.append(tr("%s de %s a %s, por %s:") % [c["nombre"], actor["nombre"], e["nombre"], _lado_con_articulo(imp["lado"])])
			lineas.append(tr("  %d daño - (blindaje %d + cobertura %d - penetración %d) = %d") % [
				imp["dano"], imp["blindaje"], imp["cobertura"], imp["penetracion"], imp["al_casco"] + imp["absorbido"]])
			if imp.get("acierto", 1.0) < 1.0:
				lineas.append(tr("  %d%% de pegar de lleno; si roza, hace %d.") % [roundi(imp["acierto"] * 100), imp["roce"]])
			if imp.get("penal", 0) > 0:
				lineas.append(tr("  Ya incluye -%d por disparar sin encararlo: usa Encarar primero.") % imp["penal"])
			if imp["absorbido"] > 0:
				lineas.append(tr("  El escudo absorbe %d.") % imp["absorbido"])
			var final := tr("  Vida %d, queda en %d") % [e["casco"], imp["casco_final"]]
			if imp["derriba"]:
				final += tr("   ¡Lo deja fuera de combate!")
			elif imp["baja_moral"]:
				final += tr("   (baja 1 de moral)")
			lineas.append(final)
			var pl: Dictionary = imp["por_lado"]
			lineas.append(tr("  Por el frente %d · flanco %d · trasera %d") % [pl["frente"], pl["flanco"], pl["trasera"]])
		else:
			lineas.append(tr("  Salpica a %s: %s") % [e["nombre"], marca])
	var motivo := combate.motivo_botin(i_botin, actor_sel, objetivo_sel) if i_botin >= 0 		else combate.motivo_uso(id, actor_sel, objetivo_sel)
	if motivo != "":
		lineas.append(tr("No se puede jugar: ") + motivo)
	_vista_previa.text = "\n".join(lineas)
	_tablero.prevision = marcas
	_tablero.queue_redraw()


func _ocultar_prevision() -> void:
	_vista_previa.text = tr("Pasa el mouse sobre una carta para ver qué haría.")
	if not _tablero.prevision.is_empty():
		_tablero.prevision = {}
		_tablero.queue_redraw()


func _lado_con_articulo(lado: String) -> String:
	return {"frente": tr("el frente"), "flanco": tr("el flanco"), "trasera": tr("la trasera"),
		"techo": tr("el techo (desde el aire)")}.get(lado, lado)


func _al_pulsar_celda(celda: Vector2i) -> void:
	var u := combate.unidad_en(celda)
	if u.get("bando") == "aliado":
		actor_sel = u["indice"]
	elif u.get("bando") == "enemigo":
		objetivo_sel = u["indice"]
	elif combate.mover(actor_sel, celda):
		return  # mover() emite "cambio" y eso refresca
	_refrescar.call_deferred()


## Al pasar el mouse por una carta mientras se anima, no se muestra nada.
func _puede_previsualizar() -> bool:
	return not _tablero.animando


## Mantiene la selección si sigue en pie; si no, pasa a la primera unidad viva.
func _seleccion_valida(lista: Array, actual: int) -> int:
	if actual >= 0 and actual < lista.size() and combate.vivo(lista[actual]):
		return actual
	for i in lista.size():
		if combate.vivo(lista[i]):
			return i
	return 0


func _vaciar(nodo: Node) -> void:
	for hijo in nodo.get_children():
		nodo.remove_child(hijo)
		hijo.queue_free()
