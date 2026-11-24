extends RefCounted
## Lógica pura del combate táctico en grilla (estilo Fire Emblem) con mazo de cartas.
## No usa nodos, así que se puede probar sola (ver tests/).
##
## Fase del jugador: cada tanque puede moverse (gasta su movimiento) y el pelotón
## comparte la energía para jugar cartas. Fase enemiga: cada enemigo ejecuta la
## acción que anunció; si es un disparo, se acerca al aliado más cercano buscando
## pegarle por el flanco o la trasera.
##
## Unidades: Dictionary creados desde data/*.json, con "pos" y "orientacion" (Vector2i).

signal cambio
## Algo que se ve o se oye: "mover", "disparo", "explosion", "turno", "victoria", "derrota".
signal evento(nombre: String)
## Cada cosa que pasa, en orden y con sus datos, para que el tablero la anime paso a paso.
## Siempre trae "tipo" y "clave" (la unidad: "a0", "e2"...). Tipos:
##   mover    {camino: [Vector2i], orientacion}
##   girar    {orientacion}
##   disparo  {objetivo: clave, orientacion}
##   golpe    {al_casco, absorbido, casco, escudo, derriba, lado, voz}
##   texto    {texto, color: "escudo"|"moral"|"malo", escudo, moral}
signal accion(datos: Dictionary)

const Mapa := preload("res://scripts/mapa.gd")

const ENERGIA_POR_TURNO := 3
const CARTAS_POR_TURNO := 5
## Un impacto que deja al menos este daño en el casco baja 1 de moral.
const DANO_QUE_BAJA_MORAL := 5
## Un enemigo en pánico pierde su turno y recupera esta moral.
const MORAL_RECUPERADA_EN_PANICO := 3
## Máximo de enemigos que actúan por turno; los demás quedan en reserva. Así un bando
## de 4 tanques (soviético) no tiene más acciones que tus 3 de energía, pero sí más cuerpos.
const ACCIONES_ENEMIGAS_MAX := 3
## Preferencia de la IA por cada lado del blanco.
const PREFERENCIA_LADO := {"frente": 0, "flanco": 1, "trasera": 2}

var mapa := Mapa.new()
var aliados: Array = []
var enemigos: Array = []
var cartas: Dictionary = {}
var mazo: Array = []
var mano: Array = []
var descarte: Array = []
var energia := 0
var turno := 0
var estado := "jugando"  # "jugando" | "victoria" | "derrota"
var registro: Array = []
var rng := RandomNumberGenerator.new()
## Oficial al mando del pelotón (la teniente Michi). Vacío = sin oficial.
## Se asigna antes de iniciar(). Con manía "mandona" da una orden por turno.
var oficial: Dictionary = {}
## Índice del aliado al que el oficial ordenó atacar este turno (-1 = ninguno).
var orden := -1
var orden_cumplida := false
## Energía extra para el próximo turno (premio del oficial).
var energia_extra := 0
## Nivel de dificultad (ver Partida.DIFICULTADES). Vacío = reglas base.
##   acciones_max: cuántos enemigos actúan por turno
##   bonus_dano:   se suma al daño de cada ataque enemigo (mínimo 1)
##   ia_lista:     la IA elige blanco y casilla por daño esperado, remata y busca cobertura
var dificultad: Dictionary = {}


## semilla >= 0 hace la partida reproducible (útil en pruebas).
func iniciar(def_mapa: Dictionary, def_aliados: Array, def_enemigos: Array, def_cartas: Array, mazo_inicial: Array, semilla: int = -1) -> void:
	if semilla >= 0:
		rng.seed = semilla
	else:
		rng.randomize()
	mapa = Mapa.new()
	mapa.cargar(def_mapa)
	aliados.clear()
	for i in def_aliados.size():
		aliados.append(_crear_unidad(def_aliados[i], "aliado", _celda(def_mapa["aliados"][i]), Vector2i.RIGHT))
		aliados[i]["clave"] = "a%d" % i
	enemigos.clear()
	for i in def_enemigos.size():
		enemigos.append(_crear_unidad(def_enemigos[i], "enemigo", _celda(def_mapa["enemigos"][i]), Vector2i.LEFT))
		enemigos[i]["clave"] = "e%d" % i
	cartas.clear()
	for c in def_cartas:
		var carta: Dictionary = c.duplicate(true)
		if carta.has("alcance"):
			carta["alcance"] = _rango(carta["alcance"])
		cartas[carta["id"]] = carta
	mazo = mazo_inicial.duplicate()
	mano.clear()
	descarte.clear()
	_barajar(mazo)
	turno = 0
	estado = "jugando"
	registro.clear()
	orden = -1
	orden_cumplida = false
	energia_extra = 0
	_iniciar_turno()


func vivo(u: Dictionary) -> bool:
	return u["casco"] > 0


func en_panico(u: Dictionary) -> bool:
	return u["moral"] <= 0


## {"bando": "aliado"|"enemigo", "indice": i} de la unidad viva en la celda, o {}.
func unidad_en(celda: Vector2i) -> Dictionary:
	for i in aliados.size():
		if vivo(aliados[i]) and aliados[i]["pos"] == celda:
			return {"bando": "aliado", "indice": i}
	for i in enemigos.size():
		if vivo(enemigos[i]) and enemigos[i]["pos"] == celda:
			return {"bando": "enemigo", "indice": i}
	return {}


## Celdas a las que `u` puede llegar con `presupuesto`: {celda: [coste, anterior]}.
## Se atraviesa a los del propio bando pero no a los rivales, y no se termina sobre nadie.
func casillas_de_movimiento(u: Dictionary, presupuesto: int) -> Dictionary:
	var rivales: Array = enemigos if u["bando"] == "aliado" else aliados
	var bloqueadas := {}
	for r in rivales:
		if vivo(r):
			bloqueadas[r["pos"]] = true
	var opciones := mapa.alcanzables(u["pos"], presupuesto, bloqueadas)
	for otro in aliados + enemigos:
		if vivo(otro) and otro["pos"] != u["pos"]:
			opciones.erase(otro["pos"])
	return opciones


func mover(i_aliado: int, celda: Vector2i) -> bool:
	if estado != "jugando" or i_aliado < 0 or i_aliado >= aliados.size():
		return false
	var u: Dictionary = aliados[i_aliado]
	if not vivo(u):
		return false
	var opciones := casillas_de_movimiento(u, u["mov_restante"])
	if celda == u["pos"] or not opciones.has(celda):
		return false
	u["mov_restante"] -= opciones[celda][0]
	_mover_a(u, celda, opciones)
	_anotar("%s se mueve a (%d, %d)." % [u["nombre"], celda.x, celda.y])
	evento.emit("mover")
	cambio.emit()
	return true


## Qué lado de `defensor` recibe un disparo hecho desde la celda `desde`.
## Se compara la dirección del disparo con hacia dónde mira el defensor;
## las diagonales exactas cuentan como flanco.
func lado_de_impacto(defensor: Dictionary, desde: Vector2i) -> String:
	var d: Vector2i = desde - defensor["pos"]
	var o: Vector2i = defensor["orientacion"]
	var adelante := d.x * o.x + d.y * o.y
	var costado := absi(d.x * o.y - d.y * o.x)
	if adelante > costado:
		return "frente"
	if -adelante > costado:
		return "trasera"
	return "flanco"


## Dirección cardinal (eje dominante) para mirar desde una celda hacia otra.
static func direccion_hacia(desde: Vector2i, hacia: Vector2i) -> Vector2i:
	var d := hacia - desde
	if d == Vector2i.ZERO:
		return Vector2i.RIGHT
	if absi(d.x) >= absi(d.y):
		return Vector2i(signi(d.x), 0)
	return Vector2i(0, signi(d.y))


## Devuelve "" si la carta se puede jugar, o el motivo por el que no.
func motivo_no_jugable(i_mano: int, i_actor: int, i_objetivo: int) -> String:
	if estado != "jugando":
		return "El combate terminó."
	if i_mano < 0 or i_mano >= mano.size():
		return "Carta inválida."
	var c: Dictionary = cartas[mano[i_mano]]
	if i_actor < 0 or i_actor >= aliados.size() or not vivo(aliados[i_actor]):
		return "Elige un tanque propio en pie."
	var actor: Dictionary = aliados[i_actor]
	if coste_de(c, actor) > energia:
		return "No hay energía suficiente."
	var hay_objetivo := i_objetivo >= 0 and i_objetivo < enemigos.size() and vivo(enemigos[i_objetivo])
	if c.get("tipo") == "ataque":
		if en_panico(actor):
			return "La tripulación está en pánico."
		if actor.get("mania") == "recarga_lenta" and int(actor.get("ataques_turno", 0)) >= 1:
			return "%s recarga lento: un ataque por turno." % actor["nombre"]
		if not hay_objetivo:
			return "Elige un enemigo en pie."
		var dist := Mapa.distancia(actor["pos"], enemigos[i_objetivo]["pos"])
		var alc: Array = c["alcance"]
		if dist < alc[0] or dist > alc[1]:
			return "Fuera de alcance: distancia %d, alcance %d-%d." % [dist, alc[0], alc[1]]
	if c.get("requiere_objetivo", false) and not hay_objetivo:
		return "Elige un enemigo en pie."
	return ""


func jugar_carta(i_mano: int, i_actor: int, i_objetivo: int) -> bool:
	if motivo_no_jugable(i_mano, i_actor, i_objetivo) != "":
		return false
	var id: String = mano[i_mano]
	var c: Dictionary = cartas[id]
	var actor: Dictionary = aliados[i_actor]
	energia -= coste_de(c, actor)
	mano.remove_at(i_mano)
	descarte.append(id)
	_anotar("%s usa %s." % [actor["nombre"], c["nombre"]])

	if c.has("dano"):
		evento.emit("disparo")
		actor["ataques_turno"] = int(actor.get("ataques_turno", 0)) + 1
		if i_actor == orden:
			orden_cumplida = true
		var objetivo: Dictionary = enemigos[i_objetivo]
		accion.emit({"tipo": "disparo", "clave": actor["clave"], "objetivo": objetivo["clave"],
			"orientacion": actor["orientacion"]})
		var lado := lado_de_impacto(objetivo, actor["pos"])
		var dano := dano_de_carta(c, lado) + bonus_de_ataque(actor, c, objetivo)
		golpear(objetivo, dano, int(c.get("penetracion", 0)), lado, mapa.cobertura(objetivo["pos"]))
		var salpicadura := int(c.get("salpicadura", 0))
		if salpicadura > 0:
			for d in Mapa.DIRECCIONES:
				var vecino := unidad_en(objetivo["pos"] + d)
				if vecino.get("bando") == "enemigo":
					var e: Dictionary = enemigos[vecino["indice"]]
					golpear(e, salpicadura, 0, lado_de_impacto(e, actor["pos"]), mapa.cobertura(e["pos"]))

	var radio := int(c.get("radio", 0))
	var receptores := aliados.filter(func(a): return vivo(a) and Mapa.distancia(a["pos"], actor["pos"]) <= radio)
	if c.has("escudo"):
		for u in receptores:
			u["escudo"] += int(c["escudo"])
			_avisar(u, "+%d escudo" % int(c["escudo"]), "escudo")
	if c.has("moral"):
		for u in receptores:
			u["moral"] = clampi(u["moral"] + int(c["moral"]), 0, u["moral_max"])
			var m := int(c["moral"])
			_avisar(u, ("+%d moral" if m > 0 else "%d moral") % m, "moral" if m > 0 else "malo")
	if c.get("encarar", false):
		actor["orientacion"] = direccion_hacia(actor["pos"], enemigos[i_objetivo]["pos"])
		accion.emit({"tipo": "girar", "clave": actor["clave"], "orientacion": actor["orientacion"]})
	if c.has("movimiento"):
		for u in receptores:
			u["mov_restante"] += int(c["movimiento"])
	if c.get("quieto", false):
		actor["mov_restante"] = 0
	if c.has("energia"):
		energia += int(c["energia"])

	_comprobar_fin()
	cambio.emit()
	return true


func terminar_turno() -> void:
	if estado != "jugando":
		return
	descarte.append_array(mano)
	mano.clear()
	_cerrar_turno_de(aliados)
	_revisar_orden()
	evento.emit("turno")
	_turno_enemigo()
	_comprobar_fin()
	if estado == "jugando":
		_iniciar_turno()
	cambio.emit()


## Calcula un impacto sin aplicarlo. Es la única fórmula de daño del juego:
## la usan golpear() y la vista previa, así nunca se contradicen.
## Reducción = blindaje del lado + cobertura del terreno - penetración (mínimo 0).
## Siempre entra al menos 1; después el escudo absorbe lo que pueda.
static func calcular_impacto(u: Dictionary, dano: int, penetracion: int, lado: String, cobertura: int = 0) -> Dictionary:
	var blindaje := int(u["blindaje"].get(lado, 0))
	var reduccion := maxi(blindaje + cobertura - penetracion, 0)
	var efectivo := maxi(dano - reduccion, 1)
	var absorbido := mini(int(u["escudo"]), efectivo)
	var al_casco := efectivo - absorbido
	var casco_final := maxi(int(u["casco"]) - al_casco, 0)
	# Moral: un golpe fuerte baja 1. Manías: el asustadizo pierde 2 si le pegan por
	# detrás (aunque sea flojo) y el valiente nunca baja de 1 por golpes.
	var moral_perdida := 1 if al_casco >= DANO_QUE_BAJA_MORAL else 0
	if u.get("mania") == "asustadizo" and lado == "trasera":
		moral_perdida = 2
	if u.get("mania") == "valiente":
		moral_perdida = clampi(mini(moral_perdida, int(u["moral"]) - 1), 0, moral_perdida)
	return {
		"lado": lado, "dano": dano, "blindaje": blindaje, "cobertura": cobertura,
		"penetracion": penetracion, "reduccion": reduccion, "absorbido": absorbido,
		"al_casco": al_casco, "casco_final": casco_final, "derriba": casco_final == 0,
		"moral_perdida": moral_perdida, "baja_moral": moral_perdida > 0,
	}


## Aplica un impacto y devuelve el daño que llegó al casco.
func golpear(u: Dictionary, dano: int, penetracion: int, lado: String, cobertura: int = 0) -> int:
	var i := calcular_impacto(u, dano, penetracion, lado, cobertura)
	var moral_antes: int = u["moral"]
	u["escudo"] -= i["absorbido"]
	u["casco"] = i["casco_final"]
	u["moral"] = maxi(u["moral"] - i["moral_perdida"], 0)
	var entra_en_panico: bool = moral_antes > 0 and u["moral"] == 0 and vivo(u)
	var texto := "  %s recibe %d en %s" % [u["nombre"], i["al_casco"], _nombre_lado(lado)]
	if i["absorbido"] > 0:
		texto += " (%d absorbido)" % i["absorbido"]
	if not vivo(u):
		texto += ". ¡Fuera de combate! El gato escapa a salvo."
		evento.emit("explosion")
	_anotar(texto)
	accion.emit({"tipo": "golpe", "clave": u.get("clave", ""), "al_casco": i["al_casco"],
		"absorbido": i["absorbido"], "casco": u["casco"], "escudo": u["escudo"], "moral": u["moral"],
		"derriba": not vivo(u), "voz": "susto" if entra_en_panico else "", "lado": lado})
	return i["al_casco"]


## Texto flotante sobre una unidad (escudo, moral...), con su estado ya actualizado.
## `voz`: sonido de gato que acompaña al texto ("" = ninguno).
func _avisar(u: Dictionary, texto: String, color: String, voz: String = "") -> void:
	accion.emit({"tipo": "texto", "clave": u.get("clave", ""), "texto": texto, "color": color,
		"escudo": u["escudo"], "moral": u["moral"], "voz": voz})


## Daño base de una carta según el lado por el que pega.
static func dano_de_carta(c: Dictionary, lado: String) -> int:
	var dano := int(c.get("dano", 0))
	if lado != "frente":
		dano += int(c.get("bonus_flanco", 0))
	return dano


## Daño extra que depende de quién ataca y de dónde están los demás (no del lado).
## `c` es la carta o la acción enemiga.
func bonus_de_ataque(atacante: Dictionary, c: Dictionary, objetivo: Dictionary) -> int:
	var bonus := 0
	var propios: Array = aliados if atacante["bando"] == "aliado" else enemigos
	if atacante.get("mania") == "camarada":
		for d in Mapa.DIRECCIONES:
			var vecino := unidad_en(atacante["pos"] + d)
			if vecino.get("bando") == atacante["bando"]:
				bonus += 1
				break
	var por_aliado := int(c.get("bonus_por_aliado", 0))
	if por_aliado > 0:
		for otro in propios:
			if not is_same(otro, atacante) and vivo(otro) and Mapa.distancia(otro["pos"], objetivo["pos"]) <= 4:
				bonus += por_aliado
	return bonus


## Energía que cuesta la carta para este tanque (la manía "terca" encarece girar).
func coste_de(c: Dictionary, actor: Dictionary) -> int:
	var coste := int(c["coste"])
	if actor.get("mania") == "terca" and c.get("encarar", false):
		coste += 1
	return coste


## Qué pasaría si `actor` juega esta carta contra el enemigo elegido, sin cambiar nada.
## Devuelve [] si la carta no hace daño o no hay blanco. Si no, una lista de impactos
## (calcular_impacto + "indice" del enemigo y "principal"); el primero es el blanco.
## El principal trae además "por_lado": el daño que pegaría por frente, flanco y trasera
## (antes del escudo, que es igual para cualquier lado).
func prever_carta(i_mano: int, i_actor: int, i_objetivo: int) -> Array:
	if i_mano < 0 or i_mano >= mano.size() or i_actor < 0 or i_actor >= aliados.size():
		return []
	if i_objetivo < 0 or i_objetivo >= enemigos.size() or not vivo(enemigos[i_objetivo]):
		return []
	var c: Dictionary = cartas[mano[i_mano]]
	if not c.has("dano"):
		return []
	var actor: Dictionary = aliados[i_actor]
	var objetivo: Dictionary = enemigos[i_objetivo]
	var pen := int(c.get("penetracion", 0))
	var cob := mapa.cobertura(objetivo["pos"])
	var lado := lado_de_impacto(objetivo, actor["pos"])
	var bonus := bonus_de_ataque(actor, c, objetivo)
	var principal := calcular_impacto(objetivo, dano_de_carta(c, lado) + bonus, pen, lado, cob)
	principal["indice"] = i_objetivo
	principal["principal"] = true
	principal["bonus"] = bonus
	var por_lado := {}
	for l in PREFERENCIA_LADO:
		var i := calcular_impacto(objetivo, dano_de_carta(c, l) + bonus, pen, l, cob)
		por_lado[l] = i["al_casco"] + i["absorbido"]  # antes del escudo: solo compara blindajes
	principal["por_lado"] = por_lado
	var res := [principal]
	var salpicadura := int(c.get("salpicadura", 0))
	if salpicadura > 0:
		for d in Mapa.DIRECCIONES:
			var vecino := unidad_en(objetivo["pos"] + d)
			if vecino.get("bando") == "enemigo":
				var e: Dictionary = enemigos[vecino["indice"]]
				var i := calcular_impacto(e, salpicadura, 0, lado_de_impacto(e, actor["pos"]), mapa.cobertura(e["pos"]))
				i["indice"] = vecino["indice"]
				i["principal"] = false
				res.append(i)
	return res


func texto_intencion(u: Dictionary) -> String:
	var a: Dictionary = u["intencion"]
	if a.is_empty():
		return ""
	if a.get("paralizado", false):
		return "En pánico: pierde el turno"
	if a.get("reserva", false):
		return "En reserva: este turno no actúa (solo actúan %d)" % acciones_max()
	if a.has("dano"):
		return "%s: %d daño, alcance %d-%d, al más cercano" % [a["nombre"], int(a["dano"]), a["alcance"][0], a["alcance"][1]]
	if a.has("moral"):
		return "%s: -%d moral a quien esté a %d o menos" % [a["nombre"], int(a["moral"]), int(a.get("radio", 99))]
	if a.has("escudo"):
		return "%s: +%d escudo" % [a["nombre"], int(a["escudo"])]
	return a["nombre"]


## Celdas que el enemigo puede atacar en su próxima fase (moverse + alcance).
func celdas_amenaza(e: Dictionary) -> Dictionary:
	var res := {}
	var a: Dictionary = e["intencion"]
	if not vivo(e) or not a.has("dano"):
		return res
	var alc: Array = a["alcance"]
	for origen in casillas_de_movimiento(e, e["movimiento"]):
		for dy in range(-alc[1], alc[1] + 1):
			for dx in range(-alc[1], alc[1] + 1):
				var dist := absi(dx) + absi(dy)
				var celda: Vector2i = origen + Vector2i(dx, dy)
				if dist >= alc[0] and dist <= alc[1] and mapa.dentro(celda):
					res[celda] = true
	return res


func _iniciar_turno() -> void:
	turno += 1
	energia = ENERGIA_POR_TURNO + energia_extra
	energia_extra = 0
	for u in aliados:
		u["escudo"] = 0
		u["mov_restante"] = u["movimiento"]
		u["se_movio"] = false
		u["ataques_turno"] = 0
	_robar(CARTAS_POR_TURNO)
	_elegir_intenciones()
	_anotar("== Turno %d ==" % turno)
	_dar_orden()


## Manía "mandona" del oficial: elige un tanque que pueda disparar y le ordena atacar.
func _dar_orden() -> void:
	orden = -1
	orden_cumplida = false
	if oficial.get("mania") != "mandona":
		return
	var candidatos: Array = []
	for i in aliados.size():
		if vivo(aliados[i]) and not en_panico(aliados[i]):
			candidatos.append(i)
	if candidatos.is_empty():
		return
	orden = candidatos[rng.randi_range(0, candidatos.size() - 1)]
	_anotar("%s: «¡%s, dispara este turno!»" % [oficial["nombre"], aliados[orden]["nombre"]])


## Al terminar el turno: premio si la orden se cumplió, reto si no.
func _revisar_orden() -> void:
	if orden < 0 or not vivo(aliados[orden]):
		return
	var u: Dictionary = aliados[orden]
	if orden_cumplida:
		energia_extra = 1
		_anotar("%s: «Aceptable.» +1 energía el próximo turno." % oficial["nombre"])
	else:
		u["moral"] = maxi(u["moral"] - 1, 0)
		_anotar("%s: «¿Y ese disparo, recluta?» %s pierde 1 de moral." % [oficial["nombre"], u["nombre"]])
		_avisar(u, "Michi: -1 moral", "malo", "grunido")


func _elegir_intenciones() -> void:
	var reserva := _enemigos_en_reserva()
	for i in enemigos.size():
		var e: Dictionary = enemigos[i]
		if not vivo(e):
			e["intencion"] = {}
		elif en_panico(e):
			e["intencion"] = {"nombre": "Pánico", "paralizado": true}
		elif reserva.has(i):
			e["intencion"] = {"nombre": "En reserva", "reserva": true}
		else:
			var acciones: Array = e["acciones"]
			var a: Dictionary = acciones[rng.randi_range(0, acciones.size() - 1)].duplicate(true)
			if a.has("alcance"):
				a["alcance"] = _rango(a["alcance"])
			if a.has("dano"):
				# La dificultad ya va incluida en lo que anuncia, así el ícono no miente.
				a["dano"] = maxi(int(a["dano"]) + int(dificultad.get("bonus_dano", 0)), 1)
			e["intencion"] = a


## Cuántos enemigos actúan por turno con la dificultad actual.
func acciones_max() -> int:
	return int(dificultad.get("acciones_max", ACCIONES_ENEMIGAS_MAX))


## Índices de los enemigos que no actúan este turno: de los que pueden actuar (en pie y
## sin pánico), actúan los acciones_max() más cercanos a algún aliado.
## Los empates los gana el de menor índice, para que sea predecible.
func _enemigos_en_reserva() -> Dictionary:
	var maximo := acciones_max()
	var listos: Array = []
	for i in enemigos.size():
		if vivo(enemigos[i]) and not en_panico(enemigos[i]):
			listos.append(i)
	if listos.size() <= maximo:
		return {}
	var distancia := func(i: int) -> int:
		var mejor := 1 << 30
		for u in aliados:
			if vivo(u):
				mejor = mini(mejor, Mapa.distancia(u["pos"], enemigos[i]["pos"]))
		return mejor
	listos.sort_custom(func(a: int, b: int) -> bool:
		var da: int = distancia.call(a)
		var db: int = distancia.call(b)
		return da < db or (da == db and a < b))
	var reserva := {}
	for i in listos.slice(maximo):
		reserva[i] = true
	return reserva


## Fin de la fase de un bando: manías que dependen de lo que hizo en el turno.
func _cerrar_turno_de(lista: Array) -> void:
	for u in lista:
		if vivo(u) and u.get("mania") == "ritual_te" and not u.get("se_movio", false) and u["moral"] < u["moral_max"]:
			u["moral"] += 1
			_anotar("%s se queda quieto tomando té: +1 moral." % u["nombre"])
			_avisar(u, "té: +1 moral", "moral")


func _turno_enemigo() -> void:
	for e in enemigos:
		e["se_movio"] = false
	_turno_enemigo_acciones()
	_cerrar_turno_de(enemigos)


func _turno_enemigo_acciones() -> void:
	for e in enemigos:
		if not vivo(e):
			continue
		# El escudo enemigo dura desde que lo gana hasta su siguiente fase.
		e["escudo"] = 0
		var a: Dictionary = e["intencion"]
		if a.is_empty():
			continue
		if a.get("paralizado", false):
			e["moral"] = mini(e["moral"] + MORAL_RECUPERADA_EN_PANICO, e["moral_max"])
			_anotar("%s está en pánico y no actúa." % e["nombre"])
			continue
		if a.get("reserva", false):
			_anotar("%s espera en reserva." % e["nombre"])
			continue
		if a.has("dano"):
			_atacar_como_enemigo(e, a)
		if a.has("moral"):
			_anotar("%s usa %s." % [e["nombre"], a["nombre"]])
			_avisar(e, a["nombre"] + "!", "malo")
			for u in aliados:
				if vivo(u) and Mapa.distancia(u["pos"], e["pos"]) <= int(a.get("radio", 99)):
					u["moral"] = maxi(u["moral"] - int(a["moral"]), 0)
					_avisar(u, "-%d moral" % int(a["moral"]), "malo")
		if a.has("escudo"):
			_anotar("%s usa %s." % [e["nombre"], a["nombre"]])
			e["escudo"] += int(a["escudo"])
			_avisar(e, "+%d escudo" % int(a["escudo"]), "escudo")
		if _primer_vivo(aliados) < 0:
			return


## Elige dónde moverse y a quién disparar, y lo hace.
## IA simple: va por el aliado más cercano, prefiriendo flanco/trasera y moverse poco.
## IA lista (Veterano/As): prueba cada casilla y cada blanco y se queda con el mayor
## daño esperado; prefiere rematar, pegarle al más dañado y quedar en cobertura.
func _atacar_como_enemigo(e: Dictionary, a: Dictionary) -> void:
	var opciones := casillas_de_movimiento(e, e["movimiento"])
	var plan := _plan_listo(e, a, opciones) if dificultad.get("ia_lista", false) else _plan_simple(e, a, opciones)
	if plan.is_empty():
		return
	var objetivo: Dictionary = plan["objetivo"]
	var alc: Array = a["alcance"]
	var mejor_celda: Vector2i = plan["celda"]
	if mejor_celda != e["pos"]:
		_mover_a(e, mejor_celda, opciones)
	var dist_final := Mapa.distancia(e["pos"], objetivo["pos"])
	if dist_final < alc[0] or dist_final > alc[1]:
		_anotar("%s avanza." % e["nombre"])
		return
	e["orientacion"] = direccion_hacia(e["pos"], objetivo["pos"])
	_anotar("%s usa %s." % [e["nombre"], a["nombre"]])
	evento.emit("disparo")
	accion.emit({"tipo": "disparo", "clave": e["clave"], "objetivo": objetivo["clave"],
		"orientacion": e["orientacion"]})
	golpear(objetivo, int(a["dano"]) + bonus_de_ataque(e, a, objetivo), int(a.get("penetracion", 0)),
		lado_de_impacto(objetivo, e["pos"]), mapa.cobertura(objetivo["pos"]))


func _plan_simple(e: Dictionary, a: Dictionary, opciones: Dictionary) -> Dictionary:
	var objetivo := _aliado_mas_cercano(e["pos"])
	if objetivo.is_empty():
		return {}
	var alc: Array = a["alcance"]
	var mejor_celda: Vector2i = e["pos"]
	var mejor_puntaje := -INF
	for celda in opciones:
		var dist := Mapa.distancia(celda, objetivo["pos"])
		var coste: int = opciones[celda][0]
		var puntaje: float
		if dist >= alc[0] and dist <= alc[1]:
			puntaje = 1000 + PREFERENCIA_LADO[lado_de_impacto(objetivo, celda)] * 10 - coste
		else:
			puntaje = -dist * 10 - coste
		if puntaje > mejor_puntaje:
			mejor_puntaje = puntaje
			mejor_celda = celda
	return {"celda": mejor_celda, "objetivo": objetivo}


func _plan_listo(e: Dictionary, a: Dictionary, opciones: Dictionary) -> Dictionary:
	var alc: Array = a["alcance"]
	var pen := int(a.get("penetracion", 0))
	var original: Vector2i = e["pos"]
	var mejor := {}
	var mejor_puntaje := -INF
	for celda in opciones:
		var coste: int = opciones[celda][0]
		e["pos"] = celda  # para que el bono de "camarada" mire desde la casilla candidata
		var cerca := 1 << 20
		for u in aliados:
			if not vivo(u):
				continue
			var dist := Mapa.distancia(celda, u["pos"])
			cerca = mini(cerca, dist)
			if dist < alc[0] or dist > alc[1]:
				continue
			var lado := lado_de_impacto(u, celda)
			var imp := calcular_impacto(u, int(a["dano"]) + bonus_de_ataque(e, a, u), pen, lado, mapa.cobertura(u["pos"]))
			var herido := 1.0 - float(u["casco"]) / float(u["casco_max"])
			var puntaje: float = 1000.0 + imp["al_casco"] * 10.0 + (300.0 if imp["derriba"] else 0.0) \
				+ herido * 20.0 + mapa.cobertura(celda) * 4.0 - coste
			if puntaje > mejor_puntaje:
				mejor_puntaje = puntaje
				mejor = {"celda": celda, "objetivo": u}
		# Sin blanco a tiro: acercarse, mejor si es a cubierto.
		var acercarse := -cerca * 10.0 + mapa.cobertura(celda) * 3.0 - coste
		if mejor_puntaje < 1000.0 and acercarse > mejor_puntaje:
			mejor_puntaje = acercarse
			mejor = {"celda": celda, "objetivo": _aliado_mas_cercano(celda)}
	e["pos"] = original
	return mejor if not mejor.is_empty() and not mejor["objetivo"].is_empty() else {}


func _aliado_mas_cercano(desde: Vector2i) -> Dictionary:
	var mejor := {}
	var mejor_dist := 1 << 30
	for u in aliados:
		if vivo(u):
			var dist := Mapa.distancia(u["pos"], desde)
			if dist < mejor_dist:
				mejor_dist = dist
				mejor = u
	return mejor


## Mueve la unidad y la deja mirando en la dirección de su último paso.
func _mover_a(u: Dictionary, celda: Vector2i, opciones: Dictionary) -> void:
	# Camino completo, del origen al destino, siguiendo los "anterior" de Dijkstra.
	# Se usa la red sin recortar: `opciones` no trae las casillas ocupadas por los
	# propios, y el camino sí puede pasar por encima de ellas.
	var red := _red_de_caminos(u)
	if not red.has(celda):
		red = opciones
	var camino: Array = [celda]
	while camino[0] != u["pos"]:
		camino.push_front(red[camino[0]][1])
	var anterior: Vector2i = camino[-2] if camino.size() > 1 else u["pos"]
	u["orientacion"] = celda - anterior
	u["pos"] = celda
	u["se_movio"] = true
	accion.emit({"tipo": "mover", "clave": u.get("clave", ""), "camino": camino, "orientacion": u["orientacion"]})


## Dijkstra sin límite práctico ni recorte de casillas ocupadas por los propios
## (los rivales sí bloquean): solo para rearmar caminos.
func _red_de_caminos(u: Dictionary) -> Dictionary:
	var rivales: Array = enemigos if u["bando"] == "aliado" else aliados
	var bloqueadas := {}
	for r in rivales:
		if vivo(r):
			bloqueadas[r["pos"]] = true
	return mapa.alcanzables(u["pos"], 999, bloqueadas)


func _primer_vivo(lista: Array) -> int:
	for i in lista.size():
		if vivo(lista[i]):
			return i
	return -1


func _robar(n: int) -> void:
	for i in n:
		if mazo.is_empty():
			if descarte.is_empty():
				return
			mazo = descarte.duplicate()
			descarte.clear()
			_barajar(mazo)
		mano.append(mazo.pop_back())


## Fisher-Yates con el rng propio, para que la semilla haga la partida reproducible.
func _barajar(pila: Array) -> void:
	for i in range(pila.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pila[i]
		pila[i] = pila[j]
		pila[j] = tmp


func _comprobar_fin() -> void:
	if estado != "jugando":
		return
	if _primer_vivo(enemigos) < 0:
		estado = "victoria"
		_anotar("Victoria!")
		evento.emit("victoria")
	elif _primer_vivo(aliados) < 0:
		estado = "derrota"
		_anotar("Derrota...")
		evento.emit("derrota")


func _anotar(texto: String) -> void:
	registro.append(texto)


func _nombre_lado(lado: String) -> String:
	return {"frente": "el frente", "flanco": "el flanco", "trasera": "la trasera"}.get(lado, lado)


## JSON entrega números como float; posiciones y rangos se pasan a int.
func _celda(par: Array) -> Vector2i:
	return Vector2i(int(par[0]), int(par[1]))


func _rango(par: Array) -> Array:
	return [int(par[0]), int(par[1])]


func _crear_unidad(def: Dictionary, bando: String, pos: Vector2i, orientacion: Vector2i) -> Dictionary:
	var u: Dictionary = def.duplicate(true)
	u["bando"] = bando
	u["pos"] = pos
	u["orientacion"] = orientacion
	u["casco_max"] = int(def["casco"])
	u["casco"] = u["casco_max"]
	u["moral_max"] = int(def.get("moral", 10))
	u["moral"] = u["moral_max"]
	u["movimiento"] = int(def.get("movimiento", 3))
	u["mov_restante"] = u["movimiento"]
	u["escudo"] = 0
	u["intencion"] = {}
	u["se_movio"] = false
	u["ataques_turno"] = 0
	return u
