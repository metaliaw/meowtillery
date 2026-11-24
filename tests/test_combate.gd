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
	var de_interfaz := ["tablero", "ficha", "globo", "gato_animado", "sonido"]
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
	_comprobar(c.aliados.size() == 3 and c.enemigos.size() == 4, "3 británicos contra 4 soviéticos")
	_comprobar(c.enemigos[3]["pos"] == Vector2i(9, 6), "el cuarto soviético tiene su lugar en el mapa")
	_comprobar(c.mazo.is_empty() and c.mano.is_empty(), "no hay mazo compartido: cada gato trae sus cartas")
	_comprobar(c.cartas_de(_indice(c.aliados, "earl_grey")) == ["disparo_17lb", "tiro_precision", "te", "girar"],
		"Earl Grey: su cañón, sus 2 cartas y Girar")
	var s := _batalla("sovietico", "britanico")
	_comprobar(s.aliados.size() == 4 and s.cartas_de(0)[0] == "canonazo_122", "también se puede jugar soviético")
	for u in c.aliados + s.aliados:
		for id in u["habilidades"]:
			_comprobar(c.cartas.has(id), "%s: existe su carta %s" % [u["nombre"], id])
	for id in ["te", "tiro_precision", "casco_oculto", "cortina_termica", "ura", "andanada"]:
		_comprobar(c.cartas.has(id), "existe la carta " + id)

	# Con 4 soviéticos de rival, solo actúan 3: queda en reserva el más lejano.
	var en_reserva := c.enemigos.filter(func(e): return e["intencion"].get("reserva", false))
	_comprobar(en_reserva.size() == 1, "de 4 soviéticos, 1 queda en reserva")
	var cerca := func(e) -> int:
		return c.aliados.map(func(u): return Mapa.distancia(u["pos"], e["pos"])).min()
	_comprobar(c.enemigos.all(func(e): return cerca.call(e) <= cerca.call(en_reserva[0])), "el de reserva es el más lejano")
	var pos_reserva: Vector2i = en_reserva[0]["pos"]
	c.terminar_turno()
	_comprobar(en_reserva[0]["pos"] == pos_reserva, "el de reserva no se mueve ni actúa")
	en_reserva[0]["casco"] = 0
	c._elegir_intenciones()
	_comprobar(c.enemigos.all(func(e): return not e["intencion"].get("reserva", false)), "con 3 en pie actúan todos")
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
	_comprobar(b.coste_de(b.cartas["girar"], marmalade) == 1, "terca: girar le cuesta 1")
	_comprobar(b.coste_de(b.cartas["girar"], b.aliados[0]) == 0, "a los demás girar no les cuesta")

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
	blanco["pos"] = c.aliados[0]["pos"] + Vector2i(3, 0)
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
	_comprobar(en_reserva.size() == 2, "Recluta: de 4 soviéticos solo actúan 2")
	var as_ := _con_dificultad("as")
	_comprobar(as_.enemigos.all(func(e): return not e["intencion"].get("reserva", false)), "As: actúan todos")

	# El daño anunciado ya trae el ajuste de la dificultad.
	var base: Dictionary = recluta.enemigos[0]
	for c in [recluta, as_]:
		var e: Dictionary = c.enemigos[0]
		e["acciones"] = [{"nombre": "Prueba", "dano": 6, "alcance": [1, 4]}]
		c._elegir_intenciones()
	_comprobar(recluta.enemigos[0]["intencion"]["dano"] == 4, "Recluta: el enemigo pega 2 menos (y lo anuncia)")
	_comprobar(as_.enemigos[0]["intencion"]["dano"] == 8, "As: el enemigo pega 2 más (y lo anuncia)")

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
	s.usar("ura", 0, 0)
	var despues: Array = s.aliados.map(func(u): return u["mov_restante"])
	_comprobar(range(antes.size()).all(func(i): return despues[i] == antes[i] + 1), "¡Urá!: +1 movimiento a todos")
	var blanco: Dictionary = s.enemigos[0]
	blanco["pos"] = Vector2i(4, 2)
	for i in s.aliados.size():
		s.aliados[i]["pos"] = [Vector2i(1, 2), Vector2i(2, 4), Vector2i(0, 0), Vector2i(11, 6)][i]
	# Andanada desde Boris: Kasha queda a 4 del blanco (cuenta); Mishka a 6 y Pelmeni lejos (no).
	_comprobar(s.bonus_de_ataque(s.aliados[0], s.cartas["andanada"], blanco) == 2, "Andanada: +2 por cada otro tanque cerca")
