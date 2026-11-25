extends RefCounted
## Bot jugador para QA: juega el bando aliado con reglas simples y razonables.
## No es una IA buena; sirve para medir balance a gran escala (tools/qa/simular.gd).
##
## Cada turno:
##  1. Mueve cada tanque a la celda alcanzable que mejor combina daño posible
##     (busca flanco o trasera), cobertura y poca amenaza enemiga.
##  2. Juega cartas mientras haya energía, eligiendo la de más valor por energía:
##     ataques por daño previsto (más si derriba o cumple la orden de Michi),
##     escudo si el tanque está amenazado, moral si le falta.

const Mapa := preload("res://scripts/mapa.gd")

var cartas_jugadas: Dictionary = {}  # id -> veces
## Bot "torpe": se acerca al azar y juega cualquier carta jugable. Sirve de línea base.
var aleatorio := false
var rng := RandomNumberGenerator.new()


func jugar_turno(c) -> void:
	if aleatorio:
		_jugar_al_azar(c)
		return
	var amenaza := _amenaza(c)
	for i in c.aliados.size():
		_mover(c, i, amenaza)
	while c.estado == "jugando":
		var mejor := _mejor_jugada(c, amenaza)
		if mejor.is_empty():
			break
		var id: String = mejor["id"]
		if mejor.has("botin"):
			if not c.usar_botin(mejor["botin"], mejor["actor"], mejor["objetivo"]):
				break
			cartas_jugadas["botín:" + id] = cartas_jugadas.get("botín:" + id, 0) + 1
		else:
			if not c.usar(id, mejor["actor"], mejor["objetivo"]):
				break
			cartas_jugadas[id] = cartas_jugadas.get(id, 0) + 1
		# Botín: se queda con la primera carta ofrecida.
		while not c.capturas.is_empty():
			c.elegir_botin(c.capturas[0]["opciones"][0])
		if c.cartas[id].has("movimiento"):
			# Con movimiento extra, vuelve a buscar mejor casilla.
			for i in c.aliados.size():
				_mover(c, i, amenaza)
	if c.estado == "jugando":
		c.terminar_turno()


func _jugar_al_azar(c) -> void:
	for i in c.aliados.size():
		var u: Dictionary = c.aliados[i]
		if not c.vivo(u):
			continue
		var celdas: Array = c.casillas_de_movimiento(u, u["mov_restante"]).keys()
		# Entre las que no lo alejan del enemigo, una al azar.
		var d0 := _distancia_enemigo(c, u["pos"])
		celdas = celdas.filter(func(x): return _distancia_enemigo(c, x) <= d0)
		if not celdas.is_empty():
			c.mover(i, celdas[rng.randi_range(0, celdas.size() - 1)])
	while c.estado == "jugando":
		var jugables: Array = []
		for a in c.aliados.size():
			for id_carta in c.cartas_de(a):
				for o in c.enemigos.size():
					if c.motivo_uso(id_carta, a, o) == "":
						jugables.append([id_carta, a, o])
		if jugables.is_empty():
			break
		var j: Array = jugables[rng.randi_range(0, jugables.size() - 1)]
		var id: String = j[0]
		c.usar(j[0], j[1], j[2])
		cartas_jugadas[id] = cartas_jugadas.get(id, 0) + 1
	if c.estado == "jugando":
		c.terminar_turno()


## Cuántos enemigos podrían atacar cada celda en su fase: {celda: n}.
func _amenaza(c) -> Dictionary:
	var res := {}
	for e in c.enemigos:
		for celda in c.celdas_amenaza(e):
			res[celda] = res.get(celda, 0) + 1
	return res


func _mover(c, i: int, amenaza: Dictionary) -> void:
	var u: Dictionary = c.aliados[i]
	if not c.vivo(u) or c.estado != "jugando":
		return
	var opciones: Dictionary = c.casillas_de_movimiento(u, u["mov_restante"])
	var mejor_celda: Vector2i = u["pos"]
	var mejor := -INF
	var original: Vector2i = u["pos"]
	var se_movio_antes: bool = u.get("se_movio", false)
	for celda in opciones:
		u["pos"] = celda
		u["se_movio"] = se_movio_antes or celda != original  # el emboscador pierde el bono
		var puntaje := _dano_posible(c, u) * 10.0
		puntaje += c.cobertura_de(u) * 3.0
		puntaje -= amenaza.get(celda, 0) * 4.0
		puntaje -= _distancia_enemigo(c, celda) * 0.5
		puntaje -= opciones[celda][0] * 0.1  # a igualdad, moverse menos
		if u.get("mania") == "ritual_te" and celda == original:
			puntaje += 2.0
		if puntaje > mejor:
			mejor = puntaje
			mejor_celda = celda
	u["pos"] = original
	u["se_movio"] = se_movio_antes
	if mejor_celda != original:
		c.mover(i, mejor_celda)


## Mejor daño que haría `u` desde donde está con alguna de sus cartas de ataque disponibles.
## (No resta la puntería: el bot gira antes de disparar si hace falta.)
func _dano_posible(c, u: Dictionary) -> float:
	var mejor := 0.0
	for id in c.cartas_de(c.aliados.find(u)):
		var carta: Dictionary = c.cartas[id]
		if carta.get("tipo") != "ataque" or u.get("usadas", {}).has(id) or u.get("recargas", {}).has(id):
			continue
		for e in c.enemigos:
			if not c.vivo(e):
				continue
			var dist := Mapa.distancia(u["pos"], e["pos"])
			if dist < carta["alcance"][0] or dist > carta["alcance"][1] or not c.ve_a(carta, u["pos"], e["pos"]):
				continue
			var lado: String = c.lado_de_impacto(e, u["pos"])
			var i: Dictionary = c.calcular_impacto(e, c.dano_de_carta(carta, lado) + c.bonus_de_ataque(u, carta, e),
				int(carta.get("penetracion", 0)), lado, c.cobertura_de(e))
			mejor = maxf(mejor, i["al_casco"] + (8.0 if i["derriba"] else 0.0))
	return mejor


func _distancia_enemigo(c, celda: Vector2i) -> int:
	var d := 1 << 20
	for e in c.enemigos:
		if c.vivo(e):
			d = mini(d, Mapa.distancia(celda, e["pos"]))
	return d


func _mejor_jugada(c, amenaza: Dictionary) -> Dictionary:
	var mejor := {}
	var mejor_valor := 0.0
	for a in c.aliados.size():
		for id in c.cartas_de(a):
			var carta: Dictionary = c.cartas[id]
			for o in c.enemigos.size():
				if c.motivo_uso(id, a, o) != "":
					continue
				var valor := _valor(c, carta, id, a, o, amenaza)
				var coste: float = maxf(c.coste_de(carta, c.aliados[a]), 0.5)
				if valor / coste > mejor_valor:
					mejor_valor = valor / coste
					mejor = {"id": id, "actor": a, "objetivo": o}
				if not carta.get("requiere_objetivo", false) and carta.get("tipo") != "ataque":
					break  # el blanco no importa
	# Cartas de botín (un solo uso): se juegan si valen un poco más que lo normal.
	for b in c.botin.size():
		var id: String = c.botin[b]
		var carta: Dictionary = c.cartas[id]
		for a in c.aliados.size():
			for o in c.enemigos.size():
				if c.motivo_botin(b, a, o) != "":
					continue
				var valor := _valor(c, carta, id, a, o, amenaza) * 0.9
				var coste: float = maxf(c.coste_de(carta, c.aliados[a]), 0.5)
				if valor / coste > mejor_valor:
					mejor_valor = valor / coste
					mejor = {"id": id, "botin": b, "actor": a, "objetivo": o}
				if not carta.get("requiere_objetivo", false) and carta.get("tipo") != "ataque":
					break
	return mejor


func _valor(c, carta: Dictionary, id: String, a: int, o: int, amenaza: Dictionary) -> float:
	var u: Dictionary = c.aliados[a]
	match carta.get("tipo"):
		"ataque":
			var v := 0.0
			for imp in c.prever_uso(id, a, o):
				var p: float = imp.get("acierto", 1.0)
				v += imp["al_casco"] * p + imp.get("roce", imp["al_casco"]) * (1.0 - p) + (10.0 * p if imp["derriba"] else 0.0)
			if a == c.orden and not c.orden_cumplida:
				v += 4.0
			return v
		"defensa":
			var v := 0.0
			var radio := int(carta.get("radio", 0))
			for otro in c.aliados:
				if c.vivo(otro) and Mapa.distancia(otro["pos"], u["pos"]) <= radio and amenaza.has(otro["pos"]):
					v += int(carta.get("escudo", 0)) * 0.7
			if carta.get("camuflaje", false) and not u.get("camuflado", false) and amenaza.has(u["pos"]):
				v += 5.0
			if carta.get("quieto", false) and u["mov_restante"] > 0:
				v *= 0.8
			return v
		"apoyo":
			if carta.has("energia"):
				return 2.5 if c.energia == 0 else 0.0
			var falta := 0
			var radio := int(carta.get("radio", 0))
			for otro in c.aliados:
				if c.vivo(otro) and Mapa.distancia(otro["pos"], u["pos"]) <= radio:
					falta += mini(int(otro["moral_max"]) - int(otro["moral"]), int(carta.get("moral", 0)))
			return falta * 0.8
		"maniobra":
			return _valor_maniobra(c, carta, a, o, amenaza)
	return 0.0


## Maniobras: cuánto daño extra permite el movimiento, o cuánto daño evita o suma girar.
func _valor_maniobra(c, carta: Dictionary, a: int, o: int, amenaza: Dictionary) -> float:
	var u: Dictionary = c.aliados[a]
	if carta.has("movimiento"):
		var bono := int(carta["movimiento"])
		var radio := int(carta.get("radio", 0))
		var ganancia := 0.0
		for otro in c.aliados:
			if not c.vivo(otro) or Mapa.distancia(otro["pos"], u["pos"]) > radio or c.en_panico(otro):
				continue
			var ahora := _mejor_dano_alcanzable(c, otro, otro["mov_restante"])
			var con_bono := _mejor_dano_alcanzable(c, otro, otro["mov_restante"] + bono)
			ganancia += maxf(con_bono - ahora, 0.0)
		return ganancia * 0.9
	if carta.get("encarar", false):
		var e: Dictionary = c.enemigos[o]
		var v := 0.0
		# Ofensivo: si le puede disparar este turno pero no lo encara, girar evita el -2.
		if c.penalizacion_punteria(u, e) > 0:
			for otra in c.cartas_de(a):
				if otra == "girar" or c.cartas[otra].get("tipo") != "ataque":
					continue
				var motivo: String = c.motivo_uso(otra, a, o)
				if motivo == "":
					v = maxf(v, c.PENALIZACION_FUERA_DEL_FRENTE + 0.5)
				elif motivo.begins_with("Sin torreta"):
					v = maxf(v, 6.0)  # sin girar no puede disparar
		# Defensivo: darle el frente (lo más blindado) al que lo va a atacar.
		if e["intencion"].has("dano"):
			var lado: String = c.lado_de_impacto(u, e["pos"])
			if lado != "frente":
				var b: Dictionary = u["blindaje"]
				var ahorro := float(int(b.get("frente", 0)) - int(b.get(lado, 0)))
				v += ahorro * (1.2 if amenaza.has(u["pos"]) else 0.3)
		return v
	return 0.0


## Mejor daño que podría hacer `u` moviéndose con `presupuesto` (sin mover de verdad).
func _mejor_dano_alcanzable(c, u: Dictionary, presupuesto: int) -> float:
	var original: Vector2i = u["pos"]
	var mejor := 0.0
	for celda in c.casillas_de_movimiento(u, presupuesto):
		u["pos"] = celda
		mejor = maxf(mejor, _dano_posible(c, u))
	u["pos"] = original
	return mejor
