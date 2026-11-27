extends SceneTree
## Pruebas de la lógica (mapa + combate). Desde la carpeta del proyecto:
##   godot --headless --path . -s tests/test_combate.gd
## Sale con código 0 si todo pasa, 1 si algo falla.
##
## Casi todas usan unidades fijas de prueba (tests/datos/), para que los números no
## cambien al equilibrar los batallones: Rosita (0,2), Menta (1,3), Bombón (0,4);
## Gruñón (8,1), Cascarrabias (9,3), Jefe Ceño (8,5).
## _probar_batallones() usa los datos reales de data/batallones.json.

const Combate := preload("res://scripts/combate.gd")
const Datos := preload("res://scripts/datos.gd")
const Mapa := preload("res://scripts/mapa.gd")
const PartidaScript := preload("res://scripts/partida.gd")

var _fallos := 0


func _init() -> void:
	# Si algún script no compila, las pruebas no pueden dar "TODO OK".
	# Las escenas que usan los autoloads (Partida, Sonido) no compilan fuera del juego;
	# esas se revisan abriéndolas. Aquí van las que no dependen de ellos.
	var de_interfaz := ["tablero", "ficha", "globo", "gato_animado", "sonido", "trofeos"]
	for s in [Combate, Mapa, PartidaScript] + de_interfaz.map(func(n): return load("res://scripts/%s.gd" % n)):
		if not s.can_instantiate():
			printerr("FALLO el script %s no compila" % s.resource_path)
			quit(1)
			return
	_probar_mapa()
	_probar_lado_de_impacto()
	_probar_golpear()
	_probar_inicio()
	_probar_mover()
	_probar_ataque_y_alcance()
	_probar_emboscada_por_el_flanco()
	_probar_salpicadura()
	_probar_vista_previa()
	_probar_cartas_de_apoyo()
	_probar_ia_se_acerca()
	_probar_ia_dispara()
	_probar_fin_de_turno()
	_probar_victoria()
	_probar_semilla()
	_probar_batallones()
	_probar_manias()
	_probar_cartas_de_batallon()
	_probar_michi()
	_probar_acciones()
	_probar_dificultad()
	_probar_punteria()
	_probar_salvavidas()
	_probar_pendientes()
	_probar_botin()
	_probar_tercer_equipo()
	_probar_vision()
	_probar_roces()
	_probar_campana()
	_probar_italianos()
	_probar_aereo()
	_probar_dado()
	_probar_trofeos()
	_probar_mapas_nuevos()
	_probar_ingles()
	_probar_ia_cuidadosa()
	print("\nTODO OK" if _fallos == 0 else "\n%d FALLOS" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _comprobar(condicion: bool, descripcion: String) -> void:
	if condicion:
		print("ok    " + descripcion)
	else:
		_fallos += 1
		printerr("FALLO " + descripcion)


func _nuevo(semilla: int = 1) -> Combate:
	var c := Combate.new()
	c.iniciar(
		Datos.leer("res://data/mapa.json"),
		Datos.leer("res://tests/datos/tanques.json"),
		Datos.leer("res://tests/datos/enemigos.json"),
		Datos.leer("res://data/cartas.json"),
		Datos.leer("res://data/mazo_inicial.json"),
		semilla)
	return c


func _unidad() -> Dictionary:
	return {"nombre": "T", "casco": 30, "casco_max": 30, "escudo": 0, "moral": 10, "moral_max": 10,
		"pos": Vector2i(5, 5), "orientacion": Vector2i.RIGHT,
		"blindaje": {"frente": 4, "flanco": 1, "trasera": 0}}


func _probar_mapa() -> void:
	var m := Mapa.new()
	m.cargar({
		"terreno": {
			".": {"coste": 1},
			"b": {"coste": 2, "cobertura": 1},
			"#": {"coste": -1},
		},
		"filas": ["..b", ".#.", "..."],
	})
	var r := m.alcanzables(Vector2i(0, 0), 2, {})
	_comprobar(r.size() == 4, "con 2 de movimiento se llega a 4 celdas (origen incluido)")
	_comprobar(not r.has(Vector2i(2, 0)), "el bosque cuesta 2: no alcanza")
	_comprobar(not r.has(Vector2i(1, 1)), "la roca no se atraviesa")
	var bloqueado := m.alcanzables(Vector2i(0, 0), 2, {Vector2i(0, 1): true})
	_comprobar(not bloqueado.has(Vector2i(0, 2)), "una unidad rival bloquea el paso")
	_comprobar(m.cobertura(Vector2i(2, 0)) == 1, "el bosque da +1 de cobertura")


func _probar_lado_de_impacto() -> void:
	var c := Combate.new()
	var u := _unidad()  # en (5,5) mirando al este
	_comprobar(c.lado_de_impacto(u, Vector2i(8, 5)) == "frente", "de frente")
	_comprobar(c.lado_de_impacto(u, Vector2i(2, 5)) == "trasera", "por detrás")
	_comprobar(c.lado_de_impacto(u, Vector2i(5, 2)) == "flanco", "de costado")
	_comprobar(c.lado_de_impacto(u, Vector2i(7, 6)) == "frente", "más adelante que al costado: frente")
	_comprobar(c.lado_de_impacto(u, Vector2i(6, 6)) == "flanco", "diagonal exacta: flanco")
	_comprobar(Combate.direccion_hacia(Vector2i(0, 0), Vector2i(3, 1)) == Vector2i.RIGHT, "mirar al este")
	_comprobar(Combate.direccion_hacia(Vector2i(0, 0), Vector2i(1, -3)) == Vector2i.UP, "mirar al norte")


func _probar_golpear() -> void:
	var c := Combate.new()
	var u := _unidad()
	_comprobar(c.golpear(u, 7, 2, "frente") == 5, "frente 4, pen 2: 7 de daño deja 5")
	_comprobar(u["casco"] == 25 and u["moral"] == 9, "5 de daño baja 1 de moral")
	_comprobar(c.golpear(_unidad(), 7, 2, "flanco") == 7, "flanco 1, pen 2: entra todo")
	_comprobar(c.golpear(_unidad(), 7, 2, "frente", 2) == 3, "la cobertura suma blindaje")
	_comprobar(c.golpear(_unidad(), 2, 0, "frente") == 1, "siempre entra al menos 1")
	var con_escudo := _unidad()
	con_escudo["escudo"] = 3
	_comprobar(c.golpear(con_escudo, 7, 4, "frente") == 4, "el escudo absorbe 3 de 7")


func _probar_inicio() -> void:
	var c := _nuevo()
	_comprobar(c.mano.size() == Combate.CARTAS_POR_TURNO, "se roban 5 cartas")
	_comprobar(c.energia == Combate.ENERGIA_POR_TURNO and c.turno == 1, "turno 1 con 3 de energía")
	_comprobar(c.aliados[0]["pos"] == Vector2i(0, 2) and c.enemigos[0]["pos"] == Vector2i(8, 1), "posiciones del mapa")
	_comprobar(c.unidad_en(Vector2i(1, 3)) == {"bando": "aliado", "indice": 1}, "unidad_en encuentra a Menta")
	var con_intencion := c.enemigos.filter(func(e): return not e["intencion"].is_empty())
	_comprobar(con_intencion.size() == c.enemigos.size(), "cada enemigo anuncia su intención")


func _probar_mover() -> void:
	var c := _nuevo()
	_comprobar(c.mover(0, Vector2i(2, 2)), "Rosita avanza 2 al este")
	var rosita: Dictionary = c.aliados[0]
	_comprobar(rosita["mov_restante"] == 2 and rosita["orientacion"] == Vector2i.RIGHT, "gasta 2 y mira al este")
	_comprobar(c.mover(0, Vector2i(2, 1)), "sube 1")
	_comprobar(rosita["orientacion"] == Vector2i.UP, "ahora mira al norte")
	_comprobar(not c.mover(0, Vector2i(9, 1)), "no llega tan lejos")
	_comprobar(not c.mover(2, Vector2i(1, 3)), "no se puede parar sobre otro tanque")


func _probar_ataque_y_alcance() -> void:
	var c := _nuevo()
	var grunon: Dictionary = c.enemigos[0]
	c.mano = ["disparo_ap"]
	_comprobar(c.motivo_no_jugable(0, 0, 0) != "", "Gruñón a distancia 11: fuera de alcance")
	grunon["pos"] = Vector2i(4, 2)  # a 4 de Rosita, mirándola de frente
	_comprobar(c.jugar_carta(0, 0, 0), "a distancia 4 sí se puede")
	_comprobar(c.energia == 2 and c.descarte.has("disparo_ap"), "gasta energía y va al descarte")
	_comprobar(grunon["casco"] == 12, "AP 6 con pen 3 contra frente 3: entra todo")


func _probar_emboscada_por_el_flanco() -> void:
	var c := _nuevo()
	var grunon: Dictionary = c.enemigos[0]
	grunon["pos"] = Vector2i(1, 2)
	grunon["orientacion"] = Vector2i.UP  # Rosita le queda al costado
	c.mano = ["emboscada"]
	_comprobar(c.jugar_carta(0, 0, 0), "Emboscada a distancia 1")
	_comprobar(grunon["casco"] == 9, "5 +4 por flanco, flanco 1 - pen 1: entra 9")


func _probar_salpicadura() -> void:
	var c := _nuevo()
	c.enemigos[0]["pos"] = Vector2i(3, 2)
	c.enemigos[1]["pos"] = Vector2i(3, 3)
	c.mano = ["disparo_he"]
	_comprobar(c.jugar_carta(0, 0, 0), "HE a distancia 3")
	_comprobar(c.enemigos[0]["casco"] == 17, "al blanco: 4 contra frente 3, entra 1")
	_comprobar(c.enemigos[1]["casco"] == 15, "al pegado: 2 contra frente 2, entra 1")


## La vista previa no cambia nada y anuncia exactamente lo que pasa al jugar la carta.
func _probar_vista_previa() -> void:
	var c := _nuevo()
	var grunon: Dictionary = c.enemigos[0]
	grunon["pos"] = Vector2i(1, 2)
	grunon["orientacion"] = Vector2i.UP
	grunon["escudo"] = 2
	c.mano = ["emboscada", "humo"]
	var p := c.prever_carta(0, 0, 0)
	_comprobar(p.size() == 1 and p[0]["lado"] == "flanco", "prevé el impacto por el flanco")
	_comprobar(grunon["casco"] == 18 and grunon["escudo"] == 2 and c.mano.size() == 2, "prever no cambia nada")
	_comprobar(p[0]["absorbido"] == 2 and p[0]["al_casco"] == 7, "prevé 9, 2 al escudo y 7 al casco")
	_comprobar(p[0]["por_lado"] == {"frente": 3, "flanco": 9, "trasera": 9}, "compara frente, flanco y trasera")
	_comprobar(c.prever_carta(1, 0, 0).is_empty(), "una carta sin daño no prevé impactos")
	c.jugar_carta(0, 0, 0)
	_comprobar(grunon["casco"] == p[0]["casco_final"], "el casco queda en lo previsto")

	var h := _nuevo()
	h.enemigos[0]["pos"] = Vector2i(3, 2)
	h.enemigos[1]["pos"] = Vector2i(3, 3)
	h.enemigos[0]["casco"] = 1
	h.mano = ["disparo_he"]
	var ph := h.prever_carta(0, 0, 0)
	_comprobar(ph.size() == 2 and not ph[1]["principal"], "HE prevé también la salpicadura")
	_comprobar(ph[0]["derriba"], "avisa que lo deja fuera de combate")


func _probar_cartas_de_apoyo() -> void:
	var c := _nuevo()
	c.aliados[1]["pos"] = Vector2i(1, 2)  # Menta pegada a Rosita
	c.mano = ["humo", "acelerar", "girar"]
	c.energia = 3
	c.jugar_carta(0, 0, 0)
	_comprobar(c.aliados[0]["escudo"] == 4 and c.aliados[1]["escudo"] == 4, "Humo cubre a los pegados")
	_comprobar(c.aliados[2]["escudo"] == 0, "Humo no llega a distancia 2")
	c.jugar_carta(0, 0, 0)
	_comprobar(c.aliados[0]["mov_restante"] == 6, "Acelerar da +2 de movimiento")
	c.aliados[0]["orientacion"] = Vector2i.UP
	c.jugar_carta(0, 0, 0)
	_comprobar(c.aliados[0]["orientacion"] == Vector2i.RIGHT, "Girar casco mira al enemigo elegido")


func _solo_grunon_con(c: Combate, intencion: Dictionary) -> void:
	c.enemigos[1]["casco"] = 0
	c.enemigos[2]["casco"] = 0
	c.enemigos[0]["intencion"] = intencion


func _probar_ia_se_acerca() -> void:
	var c := _nuevo()
	_solo_grunon_con(c, {"nombre": "Prueba", "dano": 7, "penetracion": 2, "alcance": [1, 4]})
	var antes := Mapa.distancia(c.enemigos[0]["pos"], c.aliados[0]["pos"])
	c.terminar_turno()
	var despues := Mapa.distancia(c.enemigos[0]["pos"], c.aliados[0]["pos"])
	_comprobar(despues < antes, "si no llega, el enemigo se acerca")
	_comprobar(c.aliados[0]["casco"] == c.aliados[0]["casco_max"], "y no dispara")


func _probar_ia_dispara() -> void:
	var c := _nuevo()
	_solo_grunon_con(c, {"nombre": "Prueba", "dano": 7, "penetracion": 2, "alcance": [1, 4]})
	c.aliados[0]["pos"] = Vector2i(6, 1)
	c.terminar_turno()
	_comprobar(c.aliados[0]["casco"] < c.aliados[0]["casco_max"], "a tiro, el enemigo dispara")


func _probar_fin_de_turno() -> void:
	var c := _nuevo()
	var total := c.mazo.size() + c.mano.size() + c.descarte.size()
	c.aliados[0]["mov_restante"] = 0
	c.terminar_turno()
	_comprobar(c.turno == 2 and c.mano.size() == Combate.CARTAS_POR_TURNO, "turno 2 con mano nueva")
	_comprobar(c.aliados[0]["mov_restante"] == c.aliados[0]["movimiento"], "se recupera el movimiento")
	c.terminar_turno()
	c.terminar_turno()
	_comprobar(c.mazo.size() + c.mano.size() + c.descarte.size() == total, "el rebarajado conserva las cartas")


func _probar_victoria() -> void:
	var c := _nuevo()
	c.enemigos[1]["casco"] = 0
	c.enemigos[2]["casco"] = 0
	c.enemigos[0]["casco"] = 1
	c.enemigos[0]["pos"] = Vector2i(3, 2)
	c.mano = ["disparo_ap"]
	c.jugar_carta(0, 0, 0)
	_comprobar(c.estado == "victoria", "sin enemigos en pie hay victoria")
	_comprobar(not c.mover(0, Vector2i(1, 2)), "tras la victoria no se mueve")


func _probar_semilla() -> void:
	var a := _nuevo(42)
	var b := _nuevo(42)
	_comprobar(a.mano == b.mano, "misma semilla, misma mano")


func _batalla(jugador: String = "britanico", rival: String = "sovietico") -> Combate:
	var c := Combate.new()
	PartidaScript.iniciar_combate(c, jugador, rival, 7)
	return c


func _indice(lista: Array, id: String) -> int:
	for i in lista.size():
		if lista[i]["id"] == id:
			return i
	return -1


func _probar_batallones() -> void:
	var c := _batalla()
	_comprobar(c.aliados.size() == 3 and c.enemigos.size() == 3, "3 británicos contra 3 soviéticos")
	_comprobar(c.mazo.is_empty() and c.mano.is_empty(), "no hay mazo compartido: cada gato trae sus cartas")
	_comprobar(c.cartas_de(_indice(c.aliados, "earl_grey")) == ["disparo_17lb", "tiro_precision", "te", "girar"],
		"Earl Grey: su cañón, sus 2 cartas y Girar")
	var s := _batalla("sovietico", "britanico")
	_comprobar(s.aliados.size() == 3 and s.cartas_de(0)[0] == "canonazo_122", "también se puede jugar soviético")
	var e := _batalla("estadounidense", "sovietico")
	_comprobar(e.aliados.map(func(u): return u["nombre"]) == ["Pancake", "Waffles", "Donut"], "y estadounidense")
	for u in c.aliados + s.aliados + e.aliados + [s.refuerzo]:
		for id in u["habilidades"]:
			_comprobar(c.cartas.has(id), "%s: existe su carta %s" % [u["nombre"], id])
	for id in ["te", "tiro_precision", "casco_oculto", "cortina_termica", "ura", "andanada"]:
		_comprobar(c.cartas.has(id), "existe la carta " + id)

	# En Recluta actúan 2 de los 3 rivales: queda en reserva el más lejano.
	c = _con_dificultad("recluta")
	var en_reserva := c.enemigos.filter(func(x): return x["intencion"].get("reserva", false))
	_comprobar(en_reserva.size() == 1, "Recluta: de 3 soviéticos, 1 queda en reserva")
	var cerca := func(x) -> int:
		return c.aliados.map(func(u): return Mapa.distancia(u["pos"], x["pos"])).min()
	_comprobar(c.enemigos.all(func(x): return cerca.call(x) <= cerca.call(en_reserva[0])), "el de reserva es el más lejano")
	var pos_reserva: Vector2i = en_reserva[0]["pos"]
	c.terminar_turno()
	_comprobar(en_reserva[0]["pos"] == pos_reserva, "el de reserva no se mueve ni actúa")
	en_reserva[0]["casco"] = 0
	c._elegir_intenciones()
	_comprobar(c.enemigos.all(func(x): return not x["intencion"].get("reserva", false)), "con 2 en pie actúan todos")
	_comprobar(s.enemigos.all(func(e): return not e["intencion"].get("reserva", false)), "3 británicos de rival: nadie en reserva")


## Sin intenciones, la fase enemiga no toca a nadie (para medir solo las manías).
func _enemigos_quietos(c: Combate) -> void:
	for e in c.enemigos:
		e["intencion"] = {}


func _probar_manias() -> void:
	var u := _unidad()
	u["mania"] = "asustadizo"
	var c := Combate.new()
	c.golpear(u, 2, 0, "trasera")
	_comprobar(u["moral"] == 8, "asustadizo: un golpe flojo por detrás quita 2 de moral")
	var v := _unidad()
	v["mania"] = "valiente"
	v["moral"] = 1
	c.golpear(v, 20, 0, "trasera")
	_comprobar(v["moral"] == 1, "valiente: los golpes no lo dejan en pánico")

	var b := _batalla()
	var marmalade: Dictionary = b.aliados[_indice(b.aliados, "marmalade")]
	# Escaladora: el bosque (1,1) le cuesta 1 a Lady Marmalade; a Earl Grey, 2.
	marmalade["pos"] = Vector2i(0, 1)
	var opciones: Dictionary = b.casillas_de_movimiento(marmalade, 1)
	_comprobar(opciones.has(Vector2i(1, 1)), "escaladora: entra al bosque con 1 de movimiento")
	var earl_m: Dictionary = b.aliados[_indice(b.aliados, "earl_grey")]
	var pos_earl: Vector2i = earl_m["pos"]
	marmalade["pos"] = Vector2i(5, 5)
	earl_m["pos"] = Vector2i(0, 1)  # el mismo lugar desde donde Lady Marmalade sí entró
	_comprobar(not b.casillas_de_movimiento(earl_m, 1).has(Vector2i(1, 1)), "a los demás el bosque les cuesta 2")
	earl_m["pos"] = pos_earl
	_comprobar(b.coste_de(b.cartas["girar"], marmalade) == 0, "Encarar no le cuesta energía a nadie")

	var earl: Dictionary = b.aliados[_indice(b.aliados, "earl_grey")]
	earl["moral"] = 3
	_enemigos_quietos(b)
	b.terminar_turno()
	_comprobar(earl["moral"] == 4, "ritual del té: sin moverse recupera 1 de moral")
	earl["moral"] = 3
	b.mover(_indice(b.aliados, "earl_grey"), earl["pos"] + Vector2i(1, 0))
	_enemigos_quietos(b)
	b.terminar_turno()
	_comprobar(earl["moral"] == 3, "si se movió, no hay té")

	var s := _batalla("sovietico", "britanico")
	var i_boris := _indice(s.aliados, "boris")
	s.enemigos[0]["pos"] = s.aliados[i_boris]["pos"] + Vector2i(3, 0)
	s.energia = 3
	_comprobar(s.usar("canonazo_122", i_boris, 0), "Boris dispara su cañonazo")
	_comprobar(s.motivo_uso("canonazo_122", i_boris, 0).contains("ya la usó"), "cada carta, una vez por turno")
	_enemigos_quietos(s)
	s.terminar_turno()
	_comprobar(s.motivo_uso("canonazo_122", i_boris, 0).contains("Recargando"), "recarga 1: el turno siguiente no está lista")
	_enemigos_quietos(s)
	s.terminar_turno()
	_comprobar(s.motivo_uso("canonazo_122", i_boris, 0) == "", "y al otro turno vuelve a estar lista")

	var kasha: Dictionary = s.aliados[_indice(s.aliados, "kasha")]
	var mishka: Dictionary = s.aliados[_indice(s.aliados, "mishka")]
	kasha["pos"] = Vector2i(5, 0)
	mishka["pos"] = Vector2i(5, 1)
	_comprobar(s.bonus_de_ataque(kasha, s.cartas["disparo_ap"], s.enemigos[0]) == 1, "camarada: +1 con un aliado pegado")
	mishka["pos"] = Vector2i(5, 3)
	_comprobar(s.bonus_de_ataque(kasha, s.cartas["disparo_ap"], s.enemigos[0]) == 0, "camarada solo, sin bono")


func _probar_michi() -> void:
	var sin := _batalla()
	_comprobar(sin.oficial.is_empty() and sin.orden == -1, "sin inspección no hay órdenes")

	var c := Combate.new()
	PartidaScript.iniciar_combate(c, "britanico", "sovietico", 7, true)
	_comprobar(c.orden >= 0 and c.orden < c.aliados.size(), "con Michi, un tanque recibe la orden")
	var i_crumpet := _indice(c.aliados, "crumpet")
	c.orden = i_crumpet  # Crumpet no tiene manía de moral que enrede la cuenta
	var crumpet: Dictionary = c.aliados[i_crumpet]
	c.enemigos[0]["pos"] = crumpet["pos"] + Vector2i(3, 0)
	_enemigos_quietos(c)
	c.usar("disparo_17lb", i_crumpet, 0)
	_comprobar(c.orden_cumplida, "si el tanque ordenado ataca, la orden se cumple")
	c.terminar_turno()
	_comprobar(c.energia == Combate.ENERGIA_POR_TURNO + 1, "orden cumplida: +1 energía el turno siguiente")

	c.orden = i_crumpet
	c.orden_cumplida = false
	var moral_antes: int = crumpet["moral"]
	_enemigos_quietos(c)
	c.terminar_turno()
	_comprobar(crumpet["moral"] == moral_antes - 1, "orden ignorada: el ordenado pierde 1 de moral")
	_comprobar(c.energia == Combate.ENERGIA_POR_TURNO, "y no hay energía extra")

	var p := PartidaScript.new()
	p.batallas_sin_michi = PartidaScript.BATALLAS_SIN_MICHI_MAX
	_comprobar(p.nueva_batalla(Combate.new()), "tras 3 batallas sin Michi, viene seguro")
	_comprobar(p.batallas_sin_michi == 0, "y el contador vuelve a 0")
	p.free()


## La señal `accion` cuenta lo que pasa, en orden y con lo necesario para animarlo.
func _probar_acciones() -> void:
	var c := _batalla()
	var acciones: Array = []
	c.accion.connect(func(a): acciones.append(a))
	var origen: Vector2i = c.aliados[0]["pos"]
	c.mover(0, origen + Vector2i(2, 0))
	_comprobar(acciones.size() == 1 and acciones[0]["tipo"] == "mover", "mover avisa una acción")
	var camino: Array = acciones[0]["camino"]
	_comprobar(camino[0] == origen and camino[-1] == origen + Vector2i(2, 0) and camino.size() == 3,
		"el camino va del origen al destino, casilla por casilla")

	# Pasar por encima de un tanque propio: el camino lo atraviesa sin romperse.
	acciones.clear()
	var amigo: Dictionary = c.aliados[1]
	amigo["pos"] = c.aliados[0]["pos"] + Vector2i(1, 0)
	c.aliados[0]["mov_restante"] = 3
	var antes: Vector2i = c.aliados[0]["pos"]
	_comprobar(c.mover(0, antes + Vector2i(2, 0)), "se puede mover atravesando a un tanque propio")
	_comprobar(acciones[0]["camino"].has(amigo["pos"]), "y el camino pasa por su casilla")

	acciones.clear()
	var blanco: Dictionary = c.enemigos[0]
	blanco["pos"] = c.aliados[0]["pos"] + Vector2i(2, -1)  # con vista (la roca está en la columna 6)
	c.usar("disparo_17lb", 0, 0)
	var tipos: Array = acciones.map(func(a): return a["tipo"])
	_comprobar(tipos == ["disparo", "golpe"], "un ataque avisa disparo y después golpe")
	_comprobar(acciones[0]["objetivo"] == blanco["clave"] and acciones[1]["casco"] == blanco["casco"],
		"el golpe trae el casco que le queda al blanco")

	acciones.clear()
	for e in c.enemigos:
		e["intencion"] = {"nombre": "Prueba", "dano": 5, "penetracion": 0, "alcance": [1, 4]}
	c.terminar_turno()
	var claves: Array = acciones.filter(func(a): return a["tipo"] == "disparo").map(func(a): return a["clave"])
	var ordenadas := claves.duplicate()
	ordenadas.sort()
	_comprobar(claves == ordenadas, "en la fase enemiga las acciones salen en orden, enemigo por enemigo")

	# El golpe que deja a un tanque en pánico trae el maullido de susto.
	var p := _batalla()
	var avisos: Array = []
	p.accion.connect(func(a): avisos.append(a))
	var victima: Dictionary = p.enemigos[1]
	victima["moral"] = 1
	p.golpear(victima, 9, 9, "trasera")
	_comprobar(avisos[-1].get("voz") == "susto", "entrar en pánico suena con un maullido de susto")


func _con_dificultad(dif: String) -> Combate:
	var c := Combate.new()
	PartidaScript.iniciar_combate(c, "britanico", "sovietico", 7, false, dif)
	return c


func _probar_dificultad() -> void:
	var recluta := _con_dificultad("recluta")
	var en_reserva := recluta.enemigos.filter(func(e): return e["intencion"].get("reserva", false))
	_comprobar(en_reserva.size() == 1, "Recluta: de 3 soviéticos solo actúan 2")
	var as_ := _con_dificultad("as")
	_comprobar(as_.enemigos.all(func(e): return not e["intencion"].get("reserva", false)), "As: actúan todos")

	# El daño anunciado ya trae el ajuste de la dificultad.
	var base: Dictionary = recluta.enemigos[0]
	for c in [recluta, as_]:
		var e: Dictionary = c.enemigos[0]
		e["acciones"] = [{"nombre": "Prueba", "dano": 6, "alcance": [1, 4]}]
		c._elegir_intenciones()
	_comprobar(recluta.enemigos[0]["intencion"]["dano"] == 5, "Recluta: el enemigo pega 1 menos (y lo anuncia)")
	_comprobar(as_.enemigos[0]["intencion"]["dano"] == 7, "As: el enemigo pega 1 más (y lo anuncia)")

	# IA lista: entre dos blancos a tiro, remata al que puede derribar.
	var v := _con_dificultad("veterano")
	for i in range(1, v.enemigos.size()):
		v.enemigos[i]["casco"] = 0
	var e: Dictionary = v.enemigos[0]
	e["pos"] = Vector2i(4, 3)
	e["intencion"] = {"nombre": "Prueba", "dano": 6, "penetracion": 3, "alcance": [1, 4]}
	v.aliados[0]["pos"] = Vector2i(2, 2)
	v.aliados[1]["pos"] = Vector2i(2, 4)
	v.aliados[1]["casco"] = 2
	v.aliados[2]["pos"] = Vector2i(0, 6)
	v.terminar_turno()
	_comprobar(not v.vivo(v.aliados[1]), "Veterano: la IA remata al tanque casi destruido")
	_comprobar(v.aliados[0]["casco"] == v.aliados[0]["casco_max"], "y no gasta el disparo en el que está sano")


## Disparar a un blanco fuera del frente resta 2; Girar lo arregla (y solo una vez por turno).
func _probar_punteria() -> void:
	var c := _batalla()
	var earl: Dictionary = c.aliados[0]  # mira al este
	var blanco: Dictionary = c.enemigos[0]
	blanco["pos"] = earl["pos"] + Vector2i(0, 3)  # al sur: fuera de su frente
	_comprobar(c.penalizacion_punteria(earl, blanco) == 2, "blanco al costado: -2 por no encararlo")
	_comprobar(c.prever_uso("disparo_17lb", 0, 0)[0]["penal"] == 2, "la vista previa avisa el -2")
	blanco["pos"] = earl["pos"] + Vector2i(2, 2)
	_comprobar(c.penalizacion_punteria(earl, blanco) == 0, "en diagonal exacta todavía es su frente")
	blanco["pos"] = earl["pos"] + Vector2i(0, 3)
	_comprobar(c.usar("girar", 0, 0), "Girar hacia el blanco")
	_comprobar(earl["orientacion"] == Vector2i.DOWN and c.penalizacion_punteria(earl, blanco) == 0, "ya lo encara: sin -2")
	_comprobar(not c.usar("girar", 0, 0), "Girar, una vez por turno")
	var antes: int = blanco["casco"]
	c.usar("disparo_17lb", 0, 0)
	var sin_penal: int = antes - blanco["casco"]
	var d := _batalla()
	d.enemigos[0]["pos"] = d.aliados[0]["pos"] + Vector2i(0, 3)
	var antes_d: int = d.enemigos[0]["casco"]
	d.usar("disparo_17lb", 0, 0)
	_comprobar(antes_d - d.enemigos[0]["casco"] == sin_penal - 2, "sin girar, el mismo disparo hace 2 menos")


## Recluta y Veterano: un tanque sano no cae en una sola fase enemiga. As: sí puede.
func _probar_salvavidas() -> void:
	for dif in ["veterano", "as"]:
		var c := _con_dificultad(dif)
		var crumpet: Dictionary = c.aliados[_indice(c.aliados, "crumpet")]
		# Todos los enemigos pegados a Crumpet y con un disparo enorme.
		var vecinas := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
		crumpet["pos"] = Vector2i(5, 3)
		for i in c.enemigos.size():
			c.enemigos[i]["pos"] = crumpet["pos"] + vecinas[i] * 2
			c.enemigos[i]["intencion"] = {"nombre": "Prueba", "dano": 30, "penetracion": 9, "alcance": [1, 4]}
		_comprobar(c.dano_en_peligro(crumpet) >= crumpet["casco"], "%s: Crumpet está en peligro (calavera)" % dif)
		c.terminar_turno()
		if dif == "veterano":
			_comprobar(c.vivo(crumpet) and crumpet["casco"] == 1, "Veterano: Crumpet sano se salva por los bigotes con 1")
		else:
			_comprobar(not c.vivo(crumpet), "As: sin red de seguridad, Crumpet cae")
	var r := _con_dificultad("veterano")
	var lejos: Dictionary = r.aliados[0]
	_comprobar(r.dano_en_peligro(lejos) == 0, "al inicio, lejos de todos, no hay peligro")


## Antes de terminar el turno se avisa qué tanques todavía pueden jugar alguna carta.
func _probar_pendientes() -> void:
	var c := _batalla()
	_comprobar(c.tanques_con_acciones().has("Earl Grey"), "al empezar, Earl Grey tiene cartas por usar")
	for u in c.aliados:
		for id in u["habilidades"]:
			u["usadas"][id] = true
	_comprobar(c.tanques_con_acciones().is_empty(), "si ya usaron todo (Girar no cuenta), no hay pendientes")


## Botín: al derribar un enemigo se elige una de sus cartas; se usa una vez y la puede
## jugar cualquier tanque. Lo que no se usa vuelve al Arsenal entre batallas.
func _probar_botin() -> void:
	var c := _batalla()
	var earl: Dictionary = c.aliados[0]
	var i_kasha := _indice(c.enemigos, "kasha")
	var kasha: Dictionary = c.enemigos[i_kasha]
	kasha["pos"] = earl["pos"] + Vector2i(3, 0)
	kasha["casco"] = 1
	c.usar("disparo_17lb", 0, i_kasha)
	_comprobar(not c.vivo(kasha) and c.capturas.size() == 1, "derribar a Kasha deja una captura pendiente")
	_comprobar(c.capturas[0]["opciones"] == ["andanada", "ura"], "se ofrecen sus dos cartas propias (sin el cañón)")
	_comprobar(not c.elegir_botin("disparo_85"), "no se puede elegir una carta que no se ofrece")
	_comprobar(c.elegir_botin("ura") and c.botin == ["ura"], "elegida: ¡Urá! pasa al botín")
	var i_crumpet := _indice(c.aliados, "crumpet")
	_comprobar(c.motivo_uso("ura", i_crumpet, 0) != "" and c.motivo_botin(0, i_crumpet, 0) == "",
		"Crumpet no tiene ¡Urá!, pero sí la puede jugar del botín")
	c.energia = 3
	var mov_antes: int = c.aliados[i_crumpet]["mov_restante"]
	_comprobar(c.usar_botin(0, i_crumpet, 0) and c.botin.is_empty(), "usar el botín lo gasta")
	_comprobar(c.aliados[i_crumpet]["mov_restante"] == mov_antes + 1, "y hace su efecto")

	# Arsenal: lo que no se usó vuelve; al llevarlo a la batalla, sale del arsenal.
	var p := PartidaScript.new()
	p.archivo_arsenal = "user://arsenal_prueba.json"
	p.arsenal = []
	var d := _batalla()
	d.set_meta("arsenal_cerrado", false)
	d.botin = ["humo"]
	d.capturas = [{"de": "Kasha", "opciones": ["andanada", "cortina_termica"]}]
	p.cerrar_batalla(d)
	_comprobar(p.arsenal == ["humo", "andanada"], "al cerrar: botín sin usar y capturas sin elegir van al Arsenal")
	p.cerrar_batalla(d)
	_comprobar(p.arsenal.size() == 2, "cerrar dos veces no duplica")
	p.cargar_arsenal()
	_comprobar(p.arsenal == ["humo", "andanada"], "el Arsenal se guarda y se vuelve a cargar")
	_comprobar(p.alternar_llevar(1) and p.alternar_llevar(0) and not p.alternar_llevar(5), "se eligen hasta 2 para llevar")
	var e := Combate.new()
	p.nueva_batalla(e)
	_comprobar(e.botin == ["humo", "andanada"] and p.arsenal.is_empty(), "las llevadas salen del Arsenal y entran como botín")
	DirAccess.remove_absolute(p.archivo_arsenal)
	p.free()


## 3 vs 3: refuerzos soviéticos y lo nuevo de los estadounidenses.
func _probar_tercer_equipo() -> void:
	var s := _batalla("sovietico", "britanico")
	var i_boris := _indice(s.aliados, "boris")
	s.energia = 3
	_comprobar(s.usar("refuerzos", i_boris, 0), "Boris llama refuerzos")
	_comprobar(s.aliados.size() == 4 and s.aliados[3]["nombre"] == "Mishka", "llega Mishka como cuarto tanque")
	_comprobar(s.aliados[3]["clave"] == "a3" and s.unidad_en(s.aliados[3]["pos"]).get("indice") == 3, "en una casilla libre de su borde")
	s.energia = 3
	_enemigos_quietos(s)
	s.terminar_turno()
	s.terminar_turno()
	_comprobar(s.motivo_uso("refuerzos", i_boris, 0).contains("una vez por batalla"), "solo una vez por batalla")

	var e := _batalla("estadounidense", "sovietico")
	var pancake: Dictionary = e.aliados[0]
	var waffles: Dictionary = e.aliados[1]
	waffles["pos"] = pancake["pos"] + Vector2i(0, 1)
	waffles["casco"] = 10
	pancake["casco"] = 20
	e.energia = 3
	_comprobar(e.usar("taller", 0, 0), "Pancake usa el taller")
	_comprobar(pancake["casco"] == 24 and waffles["casco"] == 14, "repara 4 a él y al pegado (sin pasar del máximo)")
	_enemigos_quietos(e)
	e.terminar_turno()
	_comprobar(waffles["casco"] == 16, "mecánico: al final del turno repara 2 al pegado")
	var donut: Dictionary = e.aliados[2]
	donut["moral"] = 3
	_enemigos_quietos(e)
	e.terminar_turno()
	_comprobar(donut["moral"] == 4, "glotón: sin atacar, recupera 1 de moral")
	_comprobar(waffles["movimiento"] == 6, "velocista: 6 de movimiento")

	# La artillería ignora la cobertura del terreno.
	var r := _batalla("estadounidense", "sovietico")
	var blanco: Dictionary = r.enemigos[0]  # Boris empieza en ruinas (+2)
	_comprobar(r.mapa.cobertura(blanco["pos"]) == 2, "Boris está en ruinas")
	r.aliados[2]["pos"] = blanco["pos"] + Vector2i(-5, 0)
	r.aliados[2]["orientacion"] = Vector2i.RIGHT
	var imp: Array = r.prever_uso("artilleria", 2, 0)
	_comprobar(not imp.is_empty() and imp[0]["cobertura"] == 0, "Llamar artillería: no cuenta la cobertura")


## Línea de visión: las rocas (columna 6, filas 2 a 4) tapan; la artillería no la necesita.
func _probar_vision() -> void:
	var m := Mapa.new()
	m.cargar(Datos.leer("res://data/mapa.json"))
	_comprobar(not m.linea_de_vision(Vector2i(4, 3), Vector2i(8, 3)), "una roca en medio tapa la vista")
	_comprobar(m.linea_de_vision(Vector2i(4, 1), Vector2i(8, 1)), "por encima de las rocas se ve")
	_comprobar(m.linea_de_vision(Vector2i(5, 1), Vector2i(7, 1)), "pegado a la roca, pero sin cruzarla, se ve")
	var c := _batalla("estadounidense", "sovietico")
	var pancake: Dictionary = c.aliados[0]
	var blanco: Dictionary = c.enemigos[0]
	pancake["pos"] = Vector2i(5, 3)
	blanco["pos"] = Vector2i(7, 3)
	_comprobar(c.motivo_uso("disparo_75", 0, 0).contains("visión"), "el cañón no dispara a través de la roca")
	var donut: Dictionary = c.aliados[2]
	donut["pos"] = Vector2i(3, 3)
	donut["orientacion"] = Vector2i.RIGHT
	c.energia = 3
	_comprobar(c.motivo_uso("artilleria", 2, 0) == "", "la artillería dispara por encima de la roca")
	# La IA tampoco dispara a través de rocas: queda tapado y no la alcanza.
	var v := _con_dificultad("veterano")
	for i in range(1, v.enemigos.size()):
		v.enemigos[i]["casco"] = 0
	var e: Dictionary = v.enemigos[0]
	e["pos"] = Vector2i(7, 3)
	e["movimiento"] = 0
	e["intencion"] = {"nombre": "Prueba", "dano": 6, "penetracion": 3, "alcance": [1, 4]}
	for i in v.aliados.size():
		v.aliados[i]["pos"] = [Vector2i(5, 3), Vector2i(0, 0), Vector2i(0, 6)][i]
	var vida: int = v.aliados[0]["casco"]
	_comprobar(not v.celdas_amenaza(e).has(Vector2i(5, 3)), "la zona de amenaza respeta la roca")
	v.terminar_turno()
	_comprobar(v.aliados[0]["casco"] == vida, "el enemigo no le dispara a través de la roca")


## Roces: en Veterano y As, de lejos el disparo puede pegar solo la mitad.
func _probar_roces() -> void:
	var r := _con_dificultad("recluta")
	var v := _con_dificultad("veterano")
	for c in [r, v]:
		c.enemigos[0]["pos"] = c.aliados[0]["pos"] + Vector2i(1, -1)
	_comprobar(r.probabilidad_acierto(r.aliados[0], r.enemigos[0]) == 1.0, "Recluta: nunca se roza")
	_comprobar(v.probabilidad_acierto(v.aliados[0], v.enemigos[0]) == 1.0, "Veterano: de cerca siempre de lleno")
	v.enemigos[0]["pos"] = v.aliados[0]["pos"] + Vector2i(3, -1)
	_comprobar(v.probabilidad_acierto(v.aliados[0], v.enemigos[0]) == 0.85, "Veterano: a 4 casillas, 85%")
	var p: Dictionary = v.prever_uso("disparo_17lb", 0, 0)[0]
	_comprobar(p["acierto"] == 0.85 and p["roce"] < p["al_casco"], "la vista previa dice el % y cuánto hace si roza")
	var vida: int = v.enemigos[0]["casco"]
	v.forzar_tirada = 0.99
	v.usar("disparo_17lb", 0, 0)
	_comprobar(vida - v.enemigos[0]["casco"] == p["roce"], "con mala tirada, roza: hace lo anunciado para el roce")


## Campaña: mapas, medallas (+vida), avance, recompensas al Arsenal y guardado.
func _probar_campana() -> void:
	for ruta in ["res://data/mapas/colinas.json", "res://data/mapas/bosque.json", "res://data/mapas/ciudad.json",
			"res://data/mapas/desierto.json", "res://data/mapas/rio.json"]:
		var m: Dictionary = Datos.leer(ruta)
		_comprobar(m["filas"].size() == 7 and m["aliados"].size() >= 4, "el mapa %s carga" % m["nombre"])
	var p := PartidaScript.new()
	p.archivo_campana = "user://campana_prueba.json"
	p.archivo_arsenal = "user://arsenal_prueba.json"
	p.arsenal = []
	p.empezar_campana("britanico")
	p.preparar_batalla_campana()
	_comprobar(p.modo_campana and p.dificultad == "recluta" and p.rival in ["sovietico", "estadounidense"], "batalla 1: Recluta")
	var c := Combate.new()
	p.nueva_batalla(c)
	_comprobar(c.mapa.ancho == 12, "la batalla de campaña usa su mapa")
	c.aliados[1]["casco"] = 0  # Crumpet cae: no gana medalla
	for e in c.enemigos:
		e["casco"] = 0
	c.estado = "victoria"
	p.campana_ganada(c)
	_comprobar(p.campana["batalla"] == 1, "la victoria avanza a la batalla 2")
	_comprobar(p.campana["medallas"].get("earl_grey", 0) == 1 and not p.campana["medallas"].has("crumpet"),
		"medalla solo para los que siguen en pie")
	_comprobar(p.campana["recompensa"].size() == 3, "quedan 3 cartas de recompensa para elegir")
	var hay_refuerzos := false
	for _i in 20:
		hay_refuerzos = hay_refuerzos or p._opciones_recompensa().has("refuerzos")
	_comprobar(not hay_refuerzos, "¡Refuerzos! nunca sale de recompensa")
	var elegida: String = p.campana["recompensa"][0]
	p.elegir_recompensa(elegida)
	_comprobar(p.arsenal.has(elegida) and p.campana["recompensa"].is_empty(), "la recompensa va al Arsenal")
	p.cargar_campana()
	_comprobar(p.campana["batalla"] == 1 and p.campana["medallas"].get("earl_grey", 0) == 1, "la campaña se guarda y se carga")
	p.preparar_batalla_campana()
	var d := Combate.new()
	p.nueva_batalla(d)
	var earl: Dictionary = d.aliados[0]
	_comprobar(earl["casco_max"] == 25 + PartidaScript.VIDA_POR_MEDALLA and earl["nombre"].ends_with("★"),
		"con medalla, Earl Grey tiene +2 de vida y una estrella")
	_comprobar(p.dificultad == "recluta" and p.mapa_actual.ends_with("bosque.json"), "batalla 2: el bosque")
	p.abandonar_campana()
	_comprobar(not p.campana_activa(), "se puede abandonar la campaña")
	DirAccess.remove_absolute(p.archivo_campana)
	DirAccess.remove_absolute(p.archivo_arsenal)
	p.free()


## Batallón italiano: sin torreta, perfil bajo, emboscador, EP, camuflaje, dramático y remachado.
func _probar_italianos() -> void:
	var c := _batalla("italiano", "britanico")
	_comprobar(c.aliados.map(func(u): return u["nombre"]) == ["Tiramisù", "Cannoli", "Panettone"], "batallón italiano")
	for u in c.aliados:
		for id in u["habilidades"]:
			_comprobar(c.cartas.has(id), "%s: existe su carta %s" % [u["nombre"], id])
	_enemigos_quietos(c)
	var tira: Dictionary = c.aliados[0]
	var cannoli: Dictionary = c.aliados[1]
	var pane: Dictionary = c.aliados[2]
	var blanco: Dictionary = c.enemigos[0]
	for i in c.enemigos.size():
		c.enemigos[i]["pos"] = Vector2i(9 + i, 0)
	tira["pos"] = Vector2i(0, 0)
	pane["pos"] = Vector2i(1, 0)
	cannoli["pos"] = Vector2i(2, 6)
	cannoli["orientacion"] = Vector2i.UP
	blanco["pos"] = Vector2i(4, 6)
	blanco["orientacion"] = Vector2i.LEFT
	_comprobar(c.cobertura_de(cannoli) == 1, "Semovente: perfil bajo, +1 de cobertura en el llano")
	_comprobar(c.motivo_uso("disparo_75_18", 1, 0).begins_with("Sin torreta"), "sin torreta: no dispara a un costado")
	_comprobar(c.usar("girar", 1, 0) and c.motivo_uso("disparo_75_18", 1, 0) == "", "después de Encarar, sí")
	_comprobar(c.prever_uso("disparo_75_18", 1, 0)[0]["bonus"] == 2, "emboscador: quieto pega +2")
	cannoli["se_movio"] = true
	_comprobar(c.prever_uso("disparo_75_18", 1, 0)[0]["bonus"] == 0, "emboscador: si se movió, no")
	cannoli["se_movio"] = false

	c.dificultad = {"punteria": true}
	blanco["pos"] = Vector2i(6, 6)  # a 4 casillas
	cannoli["orientacion"] = Vector2i.RIGHT
	_comprobar(is_equal_approx(c.prever_uso("proyectil_ep", 1, 0)[0]["acierto"], 1.0), "Proyectil EP: carga hueca, nunca roza")
	_comprobar(c.prever_uso("proyectil_ep", 1, 0)[0]["penetracion"] == 5, "y perfora 5")

	_comprobar(c.usar("camuflaje", 1, 0) and cannoli.get("camuflado", false), "Camuflaje")
	_comprobar(not c.puede_apuntar(cannoli, cannoli["pos"] + Vector2i(3, 0)), "camuflado: no le apuntan desde 3")
	_comprobar(c.puede_apuntar(cannoli, cannoli["pos"] + Vector2i(2, 0)), "pero sí desde 2")
	c.energia = 3
	c.usar("proyectil_ep", 1, 0)
	_comprobar(not cannoli.get("camuflado", false), "al disparar deja el camuflaje")

	var energia_antes := c.energia
	_comprobar(c.usar("espresso", 0, 0) and c.energia == energia_antes + 1, "Espresso: +1 de energía")

	cannoli["moral"] = 3
	pane["moral"] = 5
	c.golpear(tira, 9, 0, "flanco")
	_comprobar(cannoli["moral"] == 4 and pane["moral"] == 5, "dramático: un golpe fuerte da +1 de moral al resto")
	var duro: Dictionary = Combate.calcular_impacto(pane, 9, 0, "trasera")
	var suave: Dictionary = Combate.calcular_impacto(pane, 5, 0, "trasera")
	_comprobar(duro["al_casco"] == 9 and suave["al_casco"] == 4, "remachado: si entran 7 o más, 1 extra")


## Apoyo aéreo: Veterano y As. El propio busca al marcado al turno siguiente; el
## enemigo (solo As) marca una casilla y se puede esquivar.
func _probar_aereo() -> void:
	var r := Combate.new()
	PartidaScript.iniciar_combate(r, "britanico", "sovietico", 7, false, "recluta")
	_comprobar(not r.cartas_de(0).has("aereo_typhoon"), "Recluta: sin avión")
	var c := Combate.new()
	PartidaScript.iniciar_combate(c, "britanico", "sovietico", 7, false, "veterano")
	_comprobar(c.cartas_de(0).has("aereo_typhoon") and c.cartas_de(2).has("aereo_typhoon"), "Veterano: cualquier tanque pide el Typhoon")
	_comprobar(c.aereo_rival == "", "Veterano: el rival no tiene avión")
	_enemigos_quietos(c)
	var blanco: Dictionary = c.enemigos[0]
	var prev: Array = c.prever_uso("aereo_typhoon", 0, 0)
	_comprobar(prev[0]["lado"] == "techo" and prev[0]["cobertura"] == 0, "pega al techo, sin cobertura")
	c.energia = 3
	_comprobar(c.usar("aereo_typhoon", 0, 0) and c.energia == 1, "pedirlo cuesta 2")
	_comprobar(c.motivo_uso("aereo_typhoon", 1, 0) != "", "una vez por batalla")
	var casco: int = blanco["casco"]
	_comprobar(blanco["casco"] == casco, "no pega en el mismo turno")
	blanco["pos"] += Vector2i(0, 1) if c.mapa.transitable(blanco["pos"] + Vector2i(0, 1)) and c.unidad_en(blanco["pos"] + Vector2i(0, 1)).is_empty() else Vector2i(0, -1)
	c.terminar_turno()
	_comprobar(blanco["casco"] < casco and c.aereo_pendiente.is_empty(), "al turno siguiente busca al marcado aunque se mueva")

	var e := Combate.new()
	PartidaScript.iniciar_combate(e, "estadounidense", "italiano", 7, false, "as")
	_comprobar(e.aereo_rival == "aereo_cr42" and e.cartas_de(0).has("aereo_p47"), "As: los dos bandos tienen avión")
	e.turno = PartidaScript.batallones().size() * 0 + e.TURNO_AVION_ENEMIGO
	e._planear_aereo_enemigo()
	_comprobar(not e.aereo_enemigo_plan.is_empty(), "el rival marca una casilla")
	var celda: Vector2i = e.aereo_enemigo_plan["celda"]
	var marcado: Dictionary = e.unidad_en(celda)
	_comprobar(marcado.get("bando") == "aliado", "la de un tanque propio")
	var propio: Dictionary = e.aliados[marcado["indice"]]
	_comprobar(e.dano_en_peligro(propio) > 0, "la calavera cuenta el avión")
	var antes: int = propio["casco"]
	_enemigos_quietos(e)
	var libre := celda
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if e.mapa.transitable(celda + d) and e.unidad_en(celda + d).is_empty():
			libre = celda + d
			break
	propio["pos"] = libre
	e.terminar_turno()
	_comprobar(propio["casco"] == antes and e.aereo_enemigo_plan.is_empty(), "si sales de la casilla, el avión enemigo falla")


## Prepara el turno del dado y lo tira con el valor pedido.
func _dado(valor: int, dif: String = "veterano") -> Combate:
	var c := Combate.new()
	PartidaScript.iniciar_combate(c, "britanico", "sovietico", 11, false, dif)
	c.turno = c.TURNO_DADO
	c.forzar_dado = valor
	return c


func _probar_dado() -> void:
	var c := Combate.new()
	PartidaScript.iniciar_combate(c, "britanico", "sovietico", 11, false, "veterano")
	_comprobar(c.eventos_frente and c.evento_frente.is_empty(), "el dado no sale antes del turno 3")
	c.forzar_dado = 3
	_enemigos_quietos(c)
	c.terminar_turno()
	_enemigos_quietos(c)
	c.terminar_turno()
	_comprobar(c.turno == 3 and c.evento_frente.get("valor") == 3 and c.energia == c.ENERGIA_POR_TURNO + 1,
		"turno 3: sale el dado (suministros: +1 energía)")
	_enemigos_quietos(c)
	c.terminar_turno()
	_comprobar(not c.evento_activo("suministros") and c.energia == c.ENERGIA_POR_TURNO, "dura un solo turno")

	var l := _dado(1)
	var u: Dictionary = l.aliados[0]
	u["mov_restante"] = u["movimiento"]
	l._tirar_dado()
	_comprobar(u["mov_restante"] == u["movimiento"] - 1 and l.movimiento_de(l.enemigos[0]) == int(l.enemigos[0]["movimiento"]) - 1,
		"lluvia: todos se mueven 1 menos")

	var n := _dado(2)
	n._tirar_dado()
	var lejos := {"alcance": [1, 5]}
	_comprobar(n.alcance_de(lejos) == [1, 2], "niebla: nadie dispara a más de 2")
	var e0: Dictionary = n.enemigos[0]
	n.aliados[0]["pos"] = e0["pos"] + Vector2i(-4, 0)
	var ataque := ""
	for id in n.cartas_de(0):
		if n.cartas[id].get("tipo") == "ataque" and n.cartas[id]["alcance"][1] >= 4:
			ataque = id
	_comprobar(ataque == "" or n.motivo_uso(ataque, 0, 0).begins_with("Hay niebla"), "niebla: el motivo lo explica")

	var m := _dado(4)
	m.aliados[0]["moral"] = 3
	m._tirar_dado()
	_comprobar(m.aliados[0]["moral"] == 4, "cartas de casa: +1 moral")

	var a := _dado(5)
	for e in a.enemigos:
		e["intencion"] = {"nombre": "Disparo", "dano": 3, "alcance": [1, 1]}
	a._tirar_dado()
	var averiados := a.enemigos.filter(func(e): return e["intencion"].get("averia", false))
	_comprobar(averiados.size() == 1, "avería: un enemigo no actúa")
	_comprobar(a.texto_intencion(averiados[0]).begins_with("Avería"), "avería: se ve en su cartelito")

	var p := _dado(6)
	p.aliados[1]["casco"] = 3
	p._tirar_dado()
	_comprobar(p.aliados[1]["casco"] == 5, "pescado: repara 2")

	var buenos := true
	for s in 60:
		var r := Combate.new()
		PartidaScript.iniciar_combate(r, "britanico", "sovietico", s, false, "recluta")
		r.turno = r.TURNO_DADO
		r._tirar_dado()
		buenos = buenos and int(r.evento_frente["valor"]) >= 3
	_comprobar(buenos, "Recluta: solo salen eventos buenos (3 a 6)")


func _probar_trofeos() -> void:
	# Hazañas que avisa el combate.
	var c := Combate.new()
	var ganadas: Array = []
	c.hazana.connect(func(id): ganadas.append(id))
	PartidaScript.iniciar_combate(c, "britanico", "sovietico", 3, false, "veterano")
	c.forzar_tirada = 0.0
	var e: Dictionary = c.enemigos[0]
	e["casco"] = 1
	e["orientacion"] = Vector2i.LEFT
	c.aliados[0]["pos"] = e["pos"] + Vector2i(2, 0)  # detrás de él (mira a la izquierda)
	c.aliados[0]["orientacion"] = Vector2i.LEFT
	if not c.mapa.transitable(c.aliados[0]["pos"]) or not c.unidad_en(c.aliados[0]["pos"]).is_empty():
		c.aliados[0]["pos"] = e["pos"] + Vector2i(1, 0)
	var ataque := ""
	for id in c.cartas_de(0):
		if c.cartas[id].get("tipo") == "ataque" and c.motivo_uso(id, 0, 0) == "":
			ataque = id
	c.energia = 3
	_comprobar(ataque != "" and c.usar(ataque, 0, 0) and "por_la_espalda" in ganadas, "trofeo: derribar por la trasera")
	for x in c.enemigos:
		x["casco"] = 0
	c._comprobar_fin()
	_comprobar("primera_victoria" in ganadas and "sin_bajas" in ganadas and not "as_de_ases" in ganadas,
		"trofeo: victoria sin bajas (no en As)")

	var d := _dado(6)
	var de_dado: Array = []
	d.hazana.connect(func(id): de_dado.append(id))
	d._tirar_dado()
	_comprobar(de_dado == ["banquete"], "trofeo: banquete con un 6")

	var a := Combate.new()
	var de_avion: Array = []
	a.hazana.connect(func(id): de_avion.append(id))
	PartidaScript.iniciar_combate(a, "estadounidense", "italiano", 7, false, "as")
	a._ataque_aereo(a.aereo_rival, Vector2i(5, 0) if a.unidad_en(Vector2i(5, 0)).is_empty() else Vector2i(6, 0), "enemigo")
	_comprobar("esquivado" in de_avion, "trofeo: esquivar el avión enemigo")

	# La vitrina: se guarda, no se repite y cuenta los batallones.
	var T = load("res://scripts/trofeos.gd").new()
	T.archivo = "user://trofeos_prueba.json"
	T.silencioso = true
	T.borrar_todo()
	_comprobar(T.conseguir("banquete") and not T.conseguir("banquete"), "vitrina: un trofeo se gana una sola vez")
	_comprobar(not T.conseguir("no_existe"), "vitrina: ids desconocidos no cuentan")
	for b in ["britanico", "sovietico", "estadounidense"]:
		T.victoria_con(b, 4)
	_comprobar(not T.tiene("gira_mundial"), "vitrina: con 3 batallones no hay gira")
	T.victoria_con("italiano", 4)
	_comprobar(T.tiene("gira_mundial"), "vitrina: con los 4, gira mundial")
	var T2 = load("res://scripts/trofeos.gd").new()
	T2.archivo = T.archivo
	T2.silencioso = true
	T2.cargar()
	_comprobar(T2.tiene("banquete") and T2.cuantos() == 2, "vitrina: se guarda entre partidas")
	for i in 3:
		T2.ficha_vista(i, 3)
	_comprobar(T2.tiene("gato_de_biblioteca"), "vitrina: gato de biblioteca")
	DirAccess.remove_absolute(T.archivo)
	T.free()
	T2.free()
	_comprobar(PartidaScript.batallones().size() == 4, "4 batallones para la gira mundial")


func _probar_mapas_nuevos() -> void:
	var c := Combate.new()
	var ganadas: Array = []
	c.hazana.connect(func(id): ganadas.append(id))
	PartidaScript.iniciar_combate(c, "britanico", "sovietico", 5, false, "recluta", "res://data/mapas/desierto.json")
	_comprobar(c.mapa.tiene("mina") and c.mapa.tapa_vista(Vector2i(4, 3)), "desierto: hay minas y la duna tapa la vista")
	_comprobar(not c.mapa.linea_de_vision(Vector2i(3, 3), Vector2i(5, 3)), "desierto: la duna corta la línea de visión")
	_enemigos_quietos(c)
	var u: Dictionary = c.aliados[1]  # en (1, 3)
	u["pos"] = Vector2i(4, 1)
	u["mov_restante"] = 9
	c.forzar_mina = 6
	var casco: int = u["casco"]
	_comprobar(c.mover(1, Vector2i(5, 1)) and u["casco"] == casco and c.minas_pisadas == 1, "mina: con 6 no explota")
	c.forzar_mina = 1
	_comprobar(c.mover(1, Vector2i(6, 1)) and u["casco"] == casco - c.DANO_MINA and c.minas_explotadas == 1,
		"mina: con 1 explota y quita %d" % c.DANO_MINA)
	_comprobar(not c.mapa.terreno(Vector2i(6, 1)).get("mina", false), "mina: la que explotó desaparece")
	for e in c.enemigos:
		e["casco"] = 0
	c._comprobar_fin()
	_comprobar(not "pisando_huevos" in ganadas, "pisando huevos: no si te explotó una")

	var s := Combate.new()
	var de_s: Array = []
	s.hazana.connect(func(id): de_s.append(id))
	PartidaScript.iniciar_combate(s, "britanico", "sovietico", 5, false, "recluta", "res://data/mapas/desierto.json")
	s.aliados[0]["pos"] = Vector2i(4, 1)
	s.aliados[0]["mov_restante"] = 9
	s.forzar_mina = 5
	s.mover(0, Vector2i(5, 1))
	for e in s.enemigos:
		e["casco"] = 0
	s._comprobar_fin()
	_comprobar("pisando_huevos" in de_s, "pisando huevos: cruzar sin que explote")

	var r := Combate.new()
	PartidaScript.iniciar_combate(r, "britanico", "sovietico", 5, false, "recluta", "res://data/mapas/rio.json")
	_comprobar(not r.mapa.transitable(Vector2i(6, 3)) and r.mapa.linea_de_vision(Vector2i(4, 3), Vector2i(8, 3)),
		"río: no se cruza, pero se ve por encima")
	_comprobar(r.mapa.transitable(Vector2i(6, 1)) and r.mapa.coste(Vector2i(6, 5)) == 3, "río: puente y vado (cuesta 3)")


## Inglés: con la traducción cargada, los datos y el registro salen en inglés.
func _probar_ingles() -> void:
	var tr_en := Translation.new()
	tr_en.locale = "en"
	var dic: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/idioma/en.json"))
	for es in dic:
		tr_en.add_message(es, dic[es])
	TranslationServer.add_translation(tr_en)
	var antes := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var cartas: Array = Datos.leer("res://data/cartas.json")
	var ap: Dictionary = cartas.filter(func(c): return c["id"] == "disparo_ap")[0]
	_comprobar(ap["nombre"] == "AP Shot" and ap["texto"].begins_with("6 damage"), "inglés: las cartas se traducen al cargar")
	var b: Dictionary = Datos.leer("res://data/batallones.json")
	_comprobar(b["britanico"]["nombre_corto"] == "British" and b["britanico"]["unidades"][0]["nombre"] == "Earl Grey",
		"inglés: batallones traducidos, los gatos conservan su nombre")
	var c := Combate.new()
	PartidaScript.iniciar_combate(c, "britanico", "sovietico", 1, false, "recluta")
	_comprobar("== Turn 1 ==" in c.registro, "inglés: el registro de batalla")
	TranslationServer.set_locale("es")
	_comprobar(Datos.leer("res://data/cartas.json")[0]["nombre"] == "Disparo AP",
		"con el inglés cargado, en español sale español (el respaldo es español, no inglés)")
	TranslationServer.set_locale(antes)
	TranslationServer.remove_translation(tr_en)
	_comprobar(Datos.leer("res://data/cartas.json")[0]["nombre"] == "Disparo AP", "y de vuelta en español")


## IA lista: se cubre y se retira si está muy dañada; si alcanza a alguien, dispara.
func _probar_ia_cuidadosa() -> void:
	var c := Combate.new()
	PartidaScript.iniciar_combate(c, "britanico", "sovietico", 4, false, "veterano")
	var kasha: Dictionary = c.enemigos[1]  # Disparo de 85 o Cortina térmica
	var acciones: Array = kasha["acciones"]
	kasha["pos"] = c.aliados[0]["pos"] + Vector2i(3, 0)
	var disparo := c._accion_pensada(kasha, acciones, 1)
	_comprobar(acciones[disparo].has("dano"), "IA: sana y con un blanco a tiro, dispara")
	kasha["casco"] = 3
	var cubre := c._accion_pensada(kasha, acciones, 0)
	_comprobar(acciones[cubre].has("escudo"), "IA: muy dañada y amenazada, se cubre")
	var opciones := c.casillas_de_movimiento(kasha, kasha["movimiento"])
	var segura := c._celda_segura(kasha, opciones)
	_comprobar(c.amenaza_aliada(segura) <= c.amenaza_aliada(kasha["pos"]), "IA: al cubrirse se retira a una casilla menos expuesta")
	c.aliados[1]["casco"] = 0
	c.aliados[2]["casco"] = 0
	_comprobar(c._cautela(c.enemigos[0]) == 0.0, "IA: sana y ganando, no se esconde")
	for e in c.enemigos.slice(1):
		e["casco"] = 0
	c.aliados[1]["casco"] = 10
	_comprobar(c._cautela(c.enemigos[0]) >= 0.5, "IA: si su bando va perdiendo, juega con cautela")

	# Waffles (velocista): si se mueve 4 o más casillas, +1 de cobertura hasta su próximo turno.
	var w := Combate.new()
	PartidaScript.iniciar_combate(w, "estadounidense", "sovietico", 2, false, "recluta")
	var waffles: Dictionary = w.aliados[1]
	var cob_quieto := w.cobertura_de(waffles)
	waffles["pasos_turno"] = 4
	_comprobar(w.cobertura_de(waffles) == cob_quieto + w.COBERTURA_ESQUIVA, "Waffles: moverse 4 lo hace difícil de acertar")
	waffles["pasos_turno"] = 3
	_comprobar(w.cobertura_de(waffles) == cob_quieto, "Waffles: con 3 pasos, no")


func _probar_cartas_de_batallon() -> void:
	var b := _batalla()
	b.energia = 3
	for u in b.aliados:
		u["moral"] = 2
	b.usar("te", _indice(b.aliados, "earl_grey"), 0)
	_comprobar(b.aliados.all(func(u): return u["moral"] == 4), "Hora del té: +2 moral a todo el pelotón")
	_comprobar(b.aliados[0]["mov_restante"] == 0, "y quien la toma ya no se mueve")
	var i_marm := _indice(b.aliados, "marmalade")
	_comprobar(not b.usar("casco_oculto", 0, 0), "Earl Grey no puede usar una carta de Lady Marmalade")
	b.usar("casco_oculto", i_marm, 0)
	_comprobar(b.aliados[i_marm]["escudo"] == 5 and b.aliados[i_marm]["mov_restante"] == 0, "Casco oculto: +5 escudo y quieto")

	var s := _batalla("sovietico", "britanico")
	s.energia = 3
	var antes: Array = s.aliados.map(func(u): return u["mov_restante"])
	s.usar("ura", _indice(s.aliados, "kasha"), 0)
	var despues: Array = s.aliados.map(func(u): return u["mov_restante"])
	_comprobar(range(antes.size()).all(func(i): return despues[i] == antes[i] + 1), "¡Urá!: +1 movimiento a todos")
	var blanco: Dictionary = s.enemigos[0]
	blanco["pos"] = Vector2i(4, 2)
	for i in s.aliados.size():
		s.aliados[i]["pos"] = [Vector2i(1, 2), Vector2i(2, 4), Vector2i(0, 0), Vector2i(11, 6)][i]
	# Andanada desde Boris: Kasha queda a 4 del blanco (cuenta); Mishka a 6 y Pelmeni lejos (no).
	_comprobar(s.bonus_de_ataque(s.aliados[0], s.cartas["andanada"], blanco) == 2, "Andanada: +2 por cada otro tanque cerca")
