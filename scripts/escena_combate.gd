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

const ESCENA_MENU := "res://scenes/menu.tscn"
const LINEAS_DE_REGISTRO := 8
const ANCHO_PANEL := 400

var combate: Combate
var actor_sel := 0
var objetivo_sel := 0

var _info: Label
var _tablero: Tablero
var _ficha_actor: Label
var _ficha_objetivo: Label
var _registro: Label
var _vista_previa: Label
var _michi: Gato
var _fila_michi: HBoxContainer
var _orden: Globo
var _orden_anterior := -2  # para que Michi reaccione solo cuando cambia la orden
var _fin_sonado := false
var _mano: HBoxContainer
var _boton_turno: Button
var _capa_final: CenterContainer
var _texto_final: Label


func _ready() -> void:
	_construir_interfaz()
	_nueva_partida()


func _nueva_partida() -> void:
	combate = Combate.new()
	# Diferido: así no se reconstruye la UI dentro del clic que la disparó.
	combate.cambio.connect(_refrescar, CONNECT_DEFERRED)
	combate.evento.connect(_al_evento)
	# Cada acción se anima en el tablero, en orden (y ahí suenan disparos y explosiones).
	combate.accion.connect(_tablero.encolar)
	_fin_sonado = false
	var con_michi := Partida.nueva_batalla(combate)
	_fila_michi.visible = con_michi
	_orden_anterior = -2
	if con_michi:
		combate.registro.insert(0, "¡Inspección sorpresa! La teniente Michi toma el mando.")
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

	var lateral := VBoxContainer.new()
	lateral.custom_minimum_size = Vector2(ANCHO_PANEL, 0)
	lateral.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lateral.add_theme_constant_override("separation", 10)
	medio.add_child(lateral)
	# La teniente Michi, oficial al mando, con la orden del turno.
	var fila_michi := HBoxContainer.new()
	fila_michi.add_theme_constant_override("separation", 22)  # espacio para la colita del globo
	lateral.add_child(fila_michi)
	_fila_michi = fila_michi
	_michi = Gato.new(2, load(Partida.OFICIAL["gato"]))
	_michi.tooltip_text = Partida.OFICIAL["mania_texto"]
	_michi.mouse_filter = Control.MOUSE_FILTER_STOP
	fila_michi.add_child(_michi)
	# Lo que dice Michi va en un globo de cómic que apunta a ella.
	_orden = Globo.new("", 14, "izquierda")
	_orden.cola_pos = 0.5
	fila_michi.add_child(_orden)
	_orden.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_orden.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ficha_actor = _etiqueta(lateral, Color("ffe08a"))
	_ficha_objetivo = _etiqueta(lateral, Color("ff9eb5"))
	_vista_previa = _etiqueta(lateral, Color.WHITE)
	_registro = _etiqueta(lateral, Color(1, 1, 1, 0.7))
	_registro.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Recorta en vez de crecer: si no, un registro largo empuja la mano fuera de la pantalla.
	_registro.clip_text = true

	var abajo := HBoxContainer.new()
	abajo.add_theme_constant_override("separation", 8)
	columna.add_child(abajo)
	_mano = HBoxContainer.new()
	_mano.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mano.add_theme_constant_override("separation", 8)
	abajo.add_child(_mano)
	var menu := Button.new()
	menu.text = "Menú"
	menu.custom_minimum_size = Vector2(90, 100)
	menu.pressed.connect(_ir_al_menu)
	abajo.add_child(menu)
	_boton_turno = Button.new()
	_boton_turno.text = "Terminar turno"
	_boton_turno.custom_minimum_size = Vector2(160, 100)
	_boton_turno.pressed.connect(func(): combate.terminar_turno())
	abajo.add_child(_boton_turno)

	_capa_final = CenterContainer.new()
	_capa_final.set_anchors_preset(Control.PRESET_FULL_RECT)
	_capa_final.visible = false
	add_child(_capa_final)
	var caja_final := VBoxContainer.new()
	caja_final.add_theme_constant_override("separation", 14)
	_capa_final.add_child(caja_final)
	_texto_final = Estilo.titulo("", 64)
	caja_final.add_child(_texto_final)
	var otra := Button.new()
	otra.text = "Jugar de nuevo"
	otra.pressed.connect(_nueva_partida)
	caja_final.add_child(otra)
	var volver := Button.new()
	volver.text = "Volver al menú"
	volver.pressed.connect(_ir_al_menu)
	caja_final.add_child(volver)


func _ir_al_menu() -> void:
	get_tree().change_scene_to_file(ESCENA_MENU)


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
	actor_sel = _seleccion_valida(combate.aliados, actor_sel)
	objetivo_sel = _seleccion_valida(combate.enemigos, objetivo_sel)
	var actor: Dictionary = combate.aliados[actor_sel]
	var objetivo: Dictionary = combate.enemigos[objetivo_sel]
	var jugando := combate.estado == "jugando"

	var energia := "Energía %d" % combate.energia
	if combate.energia > Combate.ENERGIA_POR_TURNO:
		energia += " (+%d extra)" % (combate.energia - Combate.ENERGIA_POR_TURNO)  # Michi o Recarga
	_info.text = "%s   ·   Turno %d   ·   %s   ·   Mazo %d   ·   Descarte %d" % [
		combate.dificultad.get("nombre", ""), combate.turno, energia, combate.mazo.size(), combate.descarte.size()]

	_tablero.actor_pos = actor["pos"] if combate.vivo(actor) else Vector2i(-1, -1)
	_tablero.objetivo_pos = objetivo["pos"] if combate.vivo(objetivo) else Vector2i(-1, -1)
	_tablero.movimiento = combate.casillas_de_movimiento(actor, actor["mov_restante"]) if jugando and combate.vivo(actor) else {}
	_tablero.amenaza = combate.celdas_amenaza(objetivo) if jugando else {}
	_tablero.alcance = _celdas_a_tiro(actor) if jugando and combate.vivo(actor) else {}
	var ordenado: Dictionary = combate.aliados[combate.orden] if combate.orden >= 0 else {}
	_tablero.orden_pos = ordenado["pos"] if jugando and not ordenado.is_empty() and combate.vivo(ordenado) else Vector2i(-1, -1)
	_tablero.queue_redraw()
	_refrescar_orden(ordenado)

	_ficha_actor.text = _ficha(actor) + "\nMovimiento %d/%d" % [actor["mov_restante"], actor["movimiento"]]
	var ficha_obj := _ficha(objetivo) + "\nPlanea: " + combate.texto_intencion(objetivo)
	if combate.vivo(actor) and combate.vivo(objetivo):
		ficha_obj += "\nDesde %s: distancia %d, le das en el %s" % [
			actor["nombre"], Mapa.distancia(actor["pos"], objetivo["pos"]),
			combate.lado_de_impacto(objetivo, actor["pos"])]
	_ficha_objetivo.text = ficha_obj
	# Lo más nuevo arriba: si no cabe todo, lo que se recorta es lo más viejo.
	var ultimas: Array = combate.registro.slice(-LINEAS_DE_REGISTRO)
	ultimas.reverse()
	_registro.text = "\n".join(ultimas)

	_vaciar(_mano)
	for i in combate.mano.size():
		_mano.add_child(_boton_carta(i))
	_ocultar_prevision()

	_boton_turno.disabled = not jugando
	_capa_final.visible = not jugando
	_texto_final.text = "¡Victoria!" if combate.estado == "victoria" else "Derrota"
	if not jugando and not _fin_sonado:
		_fin_sonado = true
		Sonido.tocar(combate.estado)


func _refrescar_orden(ordenado: Dictionary) -> void:
	if combate.oficial.is_empty():
		return  # esta batalla no hubo inspección
	if ordenado.is_empty():
		_orden.texto = "Hoy no hay órdenes. No te acostumbres."
	elif combate.orden_cumplida:
		_orden.texto = "Aceptable. +1 energía el próximo turno."
	else:
		_orden.texto = "¡%s, dispara este turno! Si no, -1 moral." % ordenado["nombre"]
	# Gestos: enojada al dar una orden nueva, feliz (a su manera) cuando la cumplen.
	var estado_orden := combate.orden + (100 if combate.orden_cumplida else 0)
	if estado_orden != _orden_anterior and _michi.is_inside_tree():
		_michi.animar("happy" if combate.orden_cumplida else "angry", 1.2)
		if not ordenado.is_empty():
			Sonido.tocar("ronroneo" if combate.orden_cumplida else "grunido")
	_orden_anterior = estado_orden


func _ficha(u: Dictionary) -> String:
	var b: Dictionary = u["blindaje"]
	var terreno: Dictionary = combate.mapa.terreno(u["pos"])
	var texto := "%s%s\nCasco %d/%d   Escudo %d   Moral %d/%d%s\nBlindaje F%d / L%d / T%d   Mira al %s\nTerreno: %s (+%d cobertura)" % [
		u["nombre"],
		"  (%s)" % u["inspirado_en"] if u.has("inspirado_en") else "",
		u["casco"], u["casco_max"], u["escudo"], u["moral"], u["moral_max"],
		"   PÁNICO" if combate.en_panico(u) else "",
		int(b.get("frente", 0)), int(b.get("flanco", 0)), int(b.get("trasera", 0)),
		_nombre_direccion(u["orientacion"]),
		terreno["nombre"], int(terreno.get("cobertura", 0))]
	if u.has("mania_texto"):
		texto += "\n" + u["mania_texto"]
	if not combate.vivo(u):
		texto += "\nFUERA DE COMBATE"
	return texto


func _nombre_direccion(o: Vector2i) -> String:
	if o == Vector2i.RIGHT:
		return "este"
	if o == Vector2i.LEFT:
		return "oeste"
	if o == Vector2i.UP:
		return "norte"
	return "sur"


## Celdas que el tanque elegido alcanza con alguna carta de ataque de la mano.
func _celdas_a_tiro(actor: Dictionary) -> Dictionary:
	var res := {}
	for id in combate.mano:
		var c: Dictionary = combate.cartas[id]
		if c.get("tipo") != "ataque":
			continue
		for y in combate.mapa.alto:
			for x in combate.mapa.ancho:
				var celda := Vector2i(x, y)
				var dist: int = Mapa.distancia(actor["pos"], celda)
				if dist >= c["alcance"][0] and dist <= c["alcance"][1]:
					res[celda] = true
	return res


func _boton_carta(i_mano: int) -> Button:
	var c: Dictionary = combate.cartas[combate.mano[i_mano]]
	var b := Button.new()
	# El coste puede depender del tanque elegido (manías).
	b.text = "%s  [%d]\n%s" % [c["nombre"], combate.coste_de(c, combate.aliados[actor_sel]), c["texto"]]
	# Ancho repartido y texto en varias líneas: si no, la mano empuja el panel fuera de la pantalla.
	b.custom_minimum_size = Vector2(120, 100)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 15)
	var motivo := combate.motivo_no_jugable(i_mano, actor_sel, objetivo_sel)
	b.disabled = motivo != ""
	b.set_meta("sonido", "carta")
	b.tooltip_text = motivo if motivo != "" else c["texto"]
	b.pressed.connect(combate.jugar_carta.bind(i_mano, actor_sel, objetivo_sel))
	# Los botones deshabilitados también avisan el hover: así se ve por qué no se puede.
	b.mouse_entered.connect(_mostrar_prevision.bind(i_mano))
	b.mouse_exited.connect(_ocultar_prevision)
	return b


## Al pasar el mouse sobre una carta: qué haría con el tanque y el blanco elegidos.
func _mostrar_prevision(i_mano: int) -> void:
	if i_mano >= combate.mano.size() or not _puede_previsualizar():
		return
	var c: Dictionary = combate.cartas[combate.mano[i_mano]]
	var actor: Dictionary = combate.aliados[actor_sel]
	var lineas := PackedStringArray()
	var impactos := combate.prever_carta(i_mano, actor_sel, objetivo_sel)
	var marcas := {}
	if impactos.is_empty():
		lineas.append("%s: %s" % [c["nombre"], c["texto"].replace("\n", " ")])
	for imp in impactos:
		var e: Dictionary = combate.enemigos[imp["indice"]]
		var marca := "-%d" % imp["al_casco"]
		if imp["derriba"]:
			marca += " KO"
		marcas[e["pos"]] = {"texto": marca, "derriba": imp["derriba"]}
		if imp["principal"]:
			lineas.append("%s de %s a %s, por %s:" % [c["nombre"], actor["nombre"], e["nombre"], _lado_con_articulo(imp["lado"])])
			lineas.append("  %d daño - (blindaje %d + cobertura %d - penetración %d) = %d" % [
				imp["dano"], imp["blindaje"], imp["cobertura"], imp["penetracion"], imp["al_casco"] + imp["absorbido"]])
			if imp["absorbido"] > 0:
				lineas.append("  El escudo absorbe %d." % imp["absorbido"])
			var final := "  Casco %d, queda en %d" % [e["casco"], imp["casco_final"]]
			if imp["derriba"]:
				final += "   ¡Lo deja fuera de combate!"
			elif imp["baja_moral"]:
				final += "   (baja 1 de moral)"
			lineas.append(final)
			var pl: Dictionary = imp["por_lado"]
			lineas.append("  Por el frente %d · flanco %d · trasera %d" % [pl["frente"], pl["flanco"], pl["trasera"]])
		else:
			lineas.append("  Salpica a %s: %s" % [e["nombre"], marca])
	var motivo := combate.motivo_no_jugable(i_mano, actor_sel, objetivo_sel)
	if motivo != "":
		lineas.append("No se puede jugar: " + motivo)
	_vista_previa.text = "\n".join(lineas)
	_tablero.prevision = marcas
	_tablero.queue_redraw()


func _ocultar_prevision() -> void:
	_vista_previa.text = "Pasa el mouse sobre una carta para ver qué haría."
	if not _tablero.prevision.is_empty():
		_tablero.prevision = {}
		_tablero.queue_redraw()


func _lado_con_articulo(lado: String) -> String:
	return {"frente": "el frente", "flanco": "el flanco", "trasera": "la trasera"}.get(lado, lado)


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
