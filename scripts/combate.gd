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
## Algo digno de un trofeo (ids de data/trofeos.json). La escena se lo pasa al autoload Trofeos.
signal hazana(id: String)

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
## Daño que se pierde al disparar a un blanco fuera del frente propio (ver penalizacion_punteria).
const BONUS_EMBOSCADA := 2
const TURNO_AVION_ENEMIGO := 3
const GOLPE_QUE_SALTA_REMACHES := 7
const DISTANCIA_CAMUFLAJE := 3
const PENALIZACION_FUERA_DEL_FRENTE := 2
## Dado de eventos del frente: al empezar el turno TURNO_DADO se tira un dado de 6 y pasa
## algo que dura ese turno (el tuyo y la fase enemiga que le sigue).
## Minas (mapa del desierto): al pasar por una se tira un dado; con 1 o 2, explota.
const DANO_MINA := 5
const MINA_EXPLOTA_HASTA := 2
const TURNO_DADO := 3
const ALCANCE_NIEBLA := 2
const EVENTOS_FRENTE := {
	1: {"id": "lluvia", "nombre": "Lluvia", "texto": "Barro por todas partes: todos se mueven 1 casilla menos este turno."},
	2: {"id": "niebla", "nombre": "Niebla", "texto": "No se ve nada: nadie dispara a más de 2 casillas este turno."},
	3: {"id": "suministros", "nombre": "Suministros", "texto": "¡Llegó un camión! +1 de energía este turno."},
	4: {"id": "cartas", "nombre": "Cartas de casa", "texto": "Correo desde casa: +1 de moral a tus gatos."},
	5: {"id": "averia", "nombre": "Avería", "texto": "Un tanque enemigo se avería y no actúa este turno."},
	6: {"id": "pescado", "nombre": "¡Pescado para todos!", "texto": "Banquete: tus tanques reparan 2 de vida."},
}

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
##   salvavidas:   un tanque propio sano no cae en una sola fase enemiga (queda con 1)
var dificultad: Dictionary = {}
## Botín: cartas de un solo uso, compartidas por todo el pelotón. Se capturan al derribar
## enemigos (una de sus dos cartas propias) o se traen del Arsenal (Partida).
var botin: Array = []
## Capturas por elegir: [{"de": nombre del derribado, "opciones": [id, id]}]. La interfaz
## pregunta cuál quedarse; el bot elige solo.
var capturas: Array = []
## Claves de los tanques propios que empezaron sanos la fase enemiga en curso (salvavidas).
var _sanos_en_fase: Dictionary = {}
## Tanque que llega con la carta "¡Refuerzos!" (definición de la unidad; vacío = no hay).
var refuerzo: Dictionary = {}
var refuerzo_usado := false
## Apoyo aéreo: id de la carta del avión propio y del rival ("" = no hay en esta dificultad).
var aereo := ""
var aereo_rival := ""
var aereo_usado := false
var aereo_rival_usado := false
## Ataques aéreos anunciados: {"carta": id, "celda": Vector2i}. El propio cae al empezar tu
## próximo turno; el enemigo, al empezar su fase (tienes un turno para salir de ahí).
var aereo_pendiente: Dictionary = {}
var aereo_enemigo_plan: Dictionary = {}
## Para las pruebas: si es >= 0, reemplaza la tirada de puntería (0.0 acierta, 0.99 roza).
var forzar_tirada := -1.0
## Dado del frente: activado por Partida en las batallas de verdad (las pruebas lo prenden a mano).
var eventos_frente := false
## Lo que salió: {"valor", "id", "nombre", "texto", "turno"}; vacío = todavía no se tiró.
var evento_frente: Dictionary = {}
## Para las pruebas: 1..6 fija el dado.
var forzar_dado := 0
## Para las pruebas: 1..6 fija el dado de las minas.
var forzar_mina := 0
## Minas por las que pasaron tus tanques y cuántas les explotaron (trofeo "Pisando huevos").
var minas_pisadas := 0
var minas_explotadas := 0
## Rng aparte para el dado, así no cambia el resto de la partida de una semilla.
var _rng_dado := RandomNumberGenerator.new()
var _spawns_aliados: Array = []
## Quién está atacando ahora (para los trofeos): el tanque propio, o {"aereo": true}.
var _atacante: Dictionary = {}


## semilla >= 0 hace la partida reproducible (útil en pruebas).
func iniciar(def_mapa: Dictionary, def_aliados: Array, def_enemigos: Array, def_cartas: Array, mazo_inicial: Array, semilla: int = -1) -> void:
	if semilla >= 0:
		rng.seed = semilla
	else:
		rng.randomize()
	_rng_dado.seed = rng.seed + 7
	evento_frente = {}
	minas_pisadas = 0
	minas_explotadas = 0
	mapa = Mapa.new()
	mapa.cargar(def_mapa)
	_spawns_aliados = def_mapa["aliados"].map(func(par): return _celda(par))
	refuerzo_usado = false
	aereo_usado = false
	aereo_rival_usado = false
	aereo_pendiente = {}
	aereo_enemigo_plan = {}
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
	botin.clear()
	capturas.clear()
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
	var opciones := mapa.alcanzables(u["pos"], presupuesto, bloqueadas, _tope_coste(u))
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
	_anotar(tr("%s se mueve a (%d, %d).") % [u["nombre"], celda.x, celda.y])
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


## Cartas que puede usar este tanque. Con habilidades propias (batallones): las suyas
## más "girar", que todos tienen. Sin ellas (unidades de prueba): la mano compartida.
func cartas_de(i_actor: int) -> Array:
	if i_actor < 0 or i_actor >= aliados.size():
		return []
	var u: Dictionary = aliados[i_actor]
	if not u.has("habilidades"):
		return mano.duplicate()
	var res: Array = u["habilidades"].duplicate()
	if not res.has("girar"):
		res.append("girar")
	if aereo != "" and cartas.has(aereo):
		res.append(aereo)  # el avión lo puede pedir cualquier tanque (una vez por batalla)
	return res


## Nombres de los tanques propios que todavía pueden jugar alguna carta este turno
## (sin contar Girar). Sirve para avisar antes de terminar el turno.
func tanques_con_acciones() -> Array:
	var res: Array = []
	if estado != "jugando":
		return res
	for i in aliados.size():
		var u: Dictionary = aliados[i]
		if not vivo(u):
			continue
		var puede := false
		for id in cartas_de(i):
			if id == "girar":
				continue
			for o in maxi(enemigos.size(), 1):
				if motivo_uso(id, i, o) == "":
					puede = true
					break
			if puede:
				break
		if puede:
			res.append(u["nombre"])
	return res


## Devuelve "" si la carta de la mano se puede jugar, o el motivo por el que no.
func motivo_no_jugable(i_mano: int, i_actor: int, i_objetivo: int) -> String:
	if i_mano < 0 or i_mano >= mano.size():
		return tr("Carta inválida.")
	return motivo_uso(mano[i_mano], i_actor, i_objetivo)


## Devuelve "" si el tanque puede usar la carta `id` contra el blanco, o el motivo por el que no.
func motivo_uso(id: String, i_actor: int, i_objetivo: int) -> String:
	if estado != "jugando":
		return tr("El combate terminó.")
	if not cartas.has(id):
		return tr("Carta inválida.")
	var c: Dictionary = cartas[id]
	if i_actor < 0 or i_actor >= aliados.size() or not vivo(aliados[i_actor]):
		return tr("Elige un tanque propio en pie.")
	var actor: Dictionary = aliados[i_actor]
	if actor.has("habilidades"):
		if not cartas_de(i_actor).has(id):
			return tr("%s no tiene esa carta.") % actor["nombre"]
		if actor["usadas"].has(id):
			return tr("%s ya la usó este turno.") % actor["nombre"]
		var faltan := int(actor["recargas"].get(id, 0))
		if faltan > 50:
			return tr("Solo se puede usar una vez por batalla.")
		if faltan > 0:
			return tr("Recargando: lista en %d turno%s.") % [faltan, "" if faltan == 1 else "s"]
	return _motivo_comun(c, actor, i_objetivo)


## Chequeos que valen para cualquier carta (propia, de la mano o de botín).
func _motivo_comun(c: Dictionary, actor: Dictionary, i_objetivo: int) -> String:
	if c.get("refuerzo", false) and (refuerzo.is_empty() or refuerzo_usado):
		return tr("Ya no quedan refuerzos.")
	if c.get("aereo", false) and aereo_usado:
		return tr("El avión ya vino en esta batalla.")
	if coste_de(c, actor) > energia:
		return tr("No hay energía suficiente.")
	var hay_objetivo := i_objetivo >= 0 and i_objetivo < enemigos.size() and vivo(enemigos[i_objetivo])
	if c.get("tipo") == "ataque":
		if en_panico(actor):
			return tr("La tripulación está en pánico.")
		if actor.get("mania") == "recarga_lenta" and int(actor.get("ataques_turno", 0)) >= 1:
			return tr("%s recarga lento: un ataque por turno.") % actor["nombre"]
		if not hay_objetivo:
			return tr("Elige un enemigo en pie.")
		var dist := Mapa.distancia(actor["pos"], enemigos[i_objetivo]["pos"])
		var alc: Array = alcance_de(c)
		if evento_activo("niebla") and dist > ALCANCE_NIEBLA:
			return tr("Hay niebla: este turno no se ve a más de %d casillas.") % ALCANCE_NIEBLA
		if dist < alc[0] or dist > alc[1]:
			return tr("Fuera de alcance: distancia %d, alcance %d-%d.") % [dist, alc[0], alc[1]]
		if not ve_a(c, actor["pos"], enemigos[i_objetivo]["pos"]):
			return tr("Sin línea de visión: hay una roca en medio.")
		if actor.get("sin_torreta", false) and penalizacion_punteria(actor, enemigos[i_objetivo]) > 0:
			return tr("Sin torreta: no lo tiene al frente. Usa Encarar primero.")
	if c.get("requiere_objetivo", false) and not hay_objetivo:
		return tr("Elige un enemigo en pie.")
	return ""


## Probabilidad de que un disparo propio pegue de lleno (si no, roza: mitad de daño).
## Solo con dificultad "punteria" (Veterano y As); de cerca siempre se acierta.
func probabilidad_acierto(actor: Dictionary, objetivo: Dictionary) -> float:
	if not dificultad.get("punteria", false):
		return 1.0
	var dist := Mapa.distancia(actor["pos"], objetivo["pos"])
	if dist <= 2:
		return 1.0
	return 0.85 if dist <= 4 else 0.7


## Cobertura de `u` donde está: la del terreno más su perfil bajo (el Semovente, sin
## torreta, es tan bajo que siempre tiene +1).
func cobertura_de(u: Dictionary) -> int:
	return mapa.cobertura(u["pos"]) + int(u.get("perfil_bajo", 0))


## Cobertura de `u` contra este ataque (la artillería ignora la del terreno, no el perfil).
func _cobertura_para(c: Dictionary, u: Dictionary) -> int:
	var terreno := 0 if c.get("ignora_cobertura", false) else mapa.cobertura(u["pos"])
	return terreno + int(u.get("perfil_bajo", 0))


## Repara vida (sin pasar del máximo) y lo avisa con un texto verde.
func _reparar(u: Dictionary, cuanto: int) -> void:
	if not vivo(u):
		return
	var antes: int = u["casco"]
	u["casco"] = mini(u["casco"] + cuanto, u["casco_max"])
	if u["casco"] > antes:
		_avisar(u, tr("+%d vida") % (u["casco"] - antes), "vida")


## "¡Refuerzos!": llega el tanque de refuerzo del batallón por una casilla libre del
## borde propio (las posiciones de inicio sobrantes; si no, cualquier libre en x <= 1).
func _llamar_refuerzo() -> void:
	if refuerzo.is_empty() or refuerzo_usado:
		return
	var libre := Vector2i(-1, -1)
	var candidatas: Array = _spawns_aliados.duplicate()
	for y in mapa.alto:
		for x in 2:
			candidatas.append(Vector2i(x, y))
	for celda in candidatas:
		if mapa.transitable(celda) and unidad_en(celda).is_empty():
			libre = celda
			break
	if libre == Vector2i(-1, -1):
		return
	refuerzo_usado = true
	var u := _crear_unidad(refuerzo, "aliado", libre, Vector2i.RIGHT)
	u["clave"] = "a%d" % aliados.size()
	aliados.append(u)
	_anotar(tr("¡Refuerzos! Llega %s en su %s.") % [u["nombre"], u.get("inspirado_en", "tanque")])
	_avisar(u, tr("¡Refuerzos!"), "moral")


## Al derribar un enemigo con cartas propias, queda pendiente elegir una de ellas como botín.
func _capturar_de(u: Dictionary) -> void:
	if u["bando"] != "enemigo" or not u.has("habilidades"):
		return
	# Sus cartas propias, sin el cañón básico ni ¡Refuerzos! (el tanque es de su batallón).
	var opciones: Array = u["habilidades"].slice(1).filter(func(id): return not cartas[id].get("refuerzo", false))
	if opciones.is_empty():
		return
	capturas.append({"de": u["nombre"], "opciones": opciones})
	_anotar(tr("  ¡Botín! Puedes quedarte con una carta de %s.") % u["nombre"])


## Elige la carta `id` de la primera captura pendiente y la pasa al botín.
func elegir_botin(id: String) -> bool:
	if capturas.is_empty() or not capturas[0]["opciones"].has(id):
		return false
	capturas.pop_front()
	botin.append(id)
	_anotar(tr("Botín: %s. Cualquier tanque puede usarla una vez.") % cartas[id]["nombre"])
	cambio.emit()
	return true


func motivo_botin(i_botin: int, i_actor: int, i_objetivo: int) -> String:
	if estado != "jugando":
		return tr("El combate terminó.")
	if i_botin < 0 or i_botin >= botin.size():
		return tr("Carta inválida.")
	if i_actor < 0 or i_actor >= aliados.size() or not vivo(aliados[i_actor]):
		return tr("Elige un tanque propio en pie.")
	return _motivo_comun(cartas[botin[i_botin]], aliados[i_actor], i_objetivo)


## Usa una carta del botín con el tanque elegido; se gasta.
func usar_botin(i_botin: int, i_actor: int, i_objetivo: int) -> bool:
	if motivo_botin(i_botin, i_actor, i_objetivo) != "":
		return false
	var id: String = botin[i_botin]
	botin.remove_at(i_botin)
	_aplicar(id, i_actor, i_objetivo)
	return true


## Juega una carta de la mano compartida (modo con mazo, el de las pruebas).
func jugar_carta(i_mano: int, i_actor: int, i_objetivo: int) -> bool:
	if motivo_no_jugable(i_mano, i_actor, i_objetivo) != "":
		return false
	var id: String = mano[i_mano]
	mano.remove_at(i_mano)
	descarte.append(id)
	_aplicar(id, i_actor, i_objetivo)
	return true


## Usa una carta del tanque (habilidades propias) o, sin habilidades, la busca en la mano.
func usar(id: String, i_actor: int, i_objetivo: int) -> bool:
	if i_actor >= 0 and i_actor < aliados.size() and not aliados[i_actor].has("habilidades"):
		return jugar_carta(mano.find(id), i_actor, i_objetivo)
	if motivo_uso(id, i_actor, i_objetivo) != "":
		return false
	var actor: Dictionary = aliados[i_actor]
	actor["usadas"][id] = true
	# "recarga": turnos que se salta después de usarla (+1 porque el inicio del próximo
	# turno ya descuenta uno). Además, cada carta se usa como máximo una vez por turno.
	var recarga := int(cartas[id].get("recarga", 0))
	if recarga > 0:
		actor["recargas"][id] = recarga + 1
	_aplicar(id, i_actor, i_objetivo)
	return true


## Cuánto se le resta al daño por disparar a un blanco que no está en tu frente
## (la torreta apunta a destiempo). Girar hacia el blanco lo evita.
## El frente para disparar incluye las diagonales exactas (la torreta gira hasta ahí).
func penalizacion_punteria(atacante: Dictionary, objetivo: Dictionary) -> int:
	var d: Vector2i = objetivo["pos"] - atacante["pos"]
	var o: Vector2i = atacante["orientacion"]
	var adelante := d.x * o.x + d.y * o.y
	var costado := absi(d.x * o.y - d.y * o.x)
	return 0 if adelante > 0 and adelante >= costado else PENALIZACION_FUERA_DEL_FRENTE


func _aplicar(id: String, i_actor: int, i_objetivo: int) -> void:
	var c: Dictionary = cartas[id]
	var actor: Dictionary = aliados[i_actor]
	energia -= coste_de(c, actor)
	_anotar(tr("%s usa %s.") % [actor["nombre"], c["nombre"]])
	if c.get("aereo", false):
		_pedir_aereo(id, i_objetivo)
		_comprobar_fin()
		cambio.emit()
		return

	if c.has("dano"):
		evento.emit("disparo")
		actor["ataques_turno"] = int(actor.get("ataques_turno", 0)) + 1
		_descamuflar(actor)
		if i_actor == orden:
			orden_cumplida = true
		var objetivo: Dictionary = enemigos[i_objetivo]
		accion.emit({"tipo": "disparo", "clave": actor["clave"], "objetivo": objetivo["clave"],
			"orientacion": actor["orientacion"]})
		var lado := lado_de_impacto(objetivo, actor["pos"])
		var penal := penalizacion_punteria(actor, objetivo)
		if penal > 0:
			_anotar(tr("  (dispara sin encarar: -%d de daño)") % penal)
		var dano := maxi(dano_de_carta(c, lado) + bonus_de_ataque(actor, c, objetivo) - penal, 1)
		# Puntería (Veterano y As): de lejos el disparo puede rozar y hacer la mitad.
		var prob := 1.0 if c.get("sin_roce", false) else probabilidad_acierto(actor, objetivo)
		var tirada: float = forzar_tirada if forzar_tirada >= 0.0 else rng.randf()
		if tirada >= prob:
			dano = maxi(dano / 2, 1)
			_anotar(tr("  ¡Roce! El disparo apenas lo toca (mitad de daño)."))
			_avisar(objetivo, tr("¡Roce!"), "malo")
		_atacante = actor
		golpear(objetivo, dano, int(c.get("penetracion", 0)), lado, _cobertura_para(c, objetivo))
		var salpicadura := int(c.get("salpicadura", 0))
		if salpicadura > 0:
			for d in Mapa.DIRECCIONES:
				var vecino := unidad_en(objetivo["pos"] + d)
				if vecino.get("bando") == "enemigo":
					var e: Dictionary = enemigos[vecino["indice"]]
					golpear(e, salpicadura, 0, lado_de_impacto(e, actor["pos"]), _cobertura_para(c, e))
		_atacante = {}

	var radio := int(c.get("radio", 0))
	var receptores := aliados.filter(func(a): return vivo(a) and Mapa.distancia(a["pos"], actor["pos"]) <= radio)
	if c.has("escudo"):
		for u in receptores:
			u["escudo"] += int(c["escudo"])
			_avisar(u, tr("+%d escudo") % int(c["escudo"]), "escudo")
	if c.has("moral"):
		for u in receptores:
			u["moral"] = clampi(u["moral"] + int(c["moral"]), 0, u["moral_max"])
			var m := int(c["moral"])
			_avisar(u, (tr("+%d moral") if m > 0 else tr("%d moral")) % m, "moral" if m > 0 else "malo")
	if c.get("camuflaje", false):
		actor["camuflado"] = true
		_avisar(actor, tr("Camuflado"), "escudo")
	if c.get("encarar", false):
		actor["orientacion"] = direccion_hacia(actor["pos"], enemigos[i_objetivo]["pos"])
		accion.emit({"tipo": "girar", "clave": actor["clave"], "orientacion": actor["orientacion"]})
	if c.has("repara"):
		for u in receptores:
			_reparar(u, int(c["repara"]))
	if c.get("refuerzo", false):
		_llamar_refuerzo()
	if c.has("movimiento"):
		for u in receptores:
			u["mov_restante"] += int(c["movimiento"])
	if c.get("quieto", false):
		actor["mov_restante"] = 0
	if c.has("energia"):
		energia += int(c["energia"])

	_comprobar_fin()
	cambio.emit()


func terminar_turno() -> void:
	if estado != "jugando":
		return
	descarte.append_array(mano)
	mano.clear()
	_cerrar_turno_de(aliados)
	_revisar_orden()
	evento.emit("turno")
	_turno_enemigo()
	if not aereo_pendiente.is_empty() and _primer_vivo(enemigos) >= 0:
		var marcado: Dictionary = enemigos[aereo_pendiente["indice"]]
		if vivo(marcado):
			_ataque_aereo(aereo_pendiente["carta"], marcado["pos"], "aliado")
		else:
			_anotar(tr("El %s llega, pero %s ya estaba fuera de combate.") % [cartas[aereo_pendiente["carta"]]["nombre"], marcado["nombre"]])
	aereo_pendiente = {}
	_comprobar_fin()
	if estado == "jugando":
		_iniciar_turno()
	cambio.emit()


## Calcula un impacto sin aplicarlo. Es la única fórmula de daño del juego:
## la usan golpear() y la vista previa, así nunca se contradicen.
## Reducción = blindaje del lado + cobertura del terreno - penetración (mínimo 0).
## Siempre entra al menos 1; después el escudo absorbe lo que pueda.
static func calcular_impacto(u: Dictionary, dano: int, penetracion: int, lado: String, cobertura: int = 0) -> Dictionary:
	var blindaje := int(u["blindaje"].get(lado, u["blindaje"].get("trasera", 0)))  # techo = como la trasera
	var reduccion := maxi(blindaje + cobertura - penetracion, 0)
	var efectivo := maxi(dano - reduccion, 1)
	if u.get("mania") == "remachado" and efectivo >= GOLPE_QUE_SALTA_REMACHES:
		efectivo += 1  # saltan los remaches
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
	# Red de seguridad (Recluta y Veterano): un tanque propio que empezó la fase enemiga
	# sano no cae en esa misma fase; queda con 1 de casco.
	var salvado := false
	if u["casco"] == 0 and _sanos_en_fase.has(u.get("clave", "")):
		u["casco"] = 1
		salvado = true
	u["moral"] = maxi(u["moral"] - i["moral_perdida"], 0)
	var entra_en_panico: bool = moral_antes > 0 and u["moral"] == 0 and vivo(u)
	var texto := tr("  %s recibe %d en %s") % [u["nombre"], i["al_casco"], _nombre_lado(lado)]
	if i["absorbido"] > 0:
		texto += tr(" (%d absorbido)") % i["absorbido"]
	if not vivo(u):
		texto += tr(". ¡Fuera de combate! El gato escapa a salvo.")
		evento.emit("explosion")
		_capturar_de(u)
		if u["bando"] == "enemigo":
			_hazanas_de_derribo(u, lado)
	_anotar(texto)
	if salvado:
		_anotar(tr("  ¡%s se salva por los bigotes! Queda con 1 de vida.") % u["nombre"])
	if u.get("mania") == "dramatico" and vivo(u) and i["al_casco"] >= DANO_QUE_BAJA_MORAL:
		_drama(u)
	accion.emit({"tipo": "golpe", "clave": u.get("clave", ""), "al_casco": i["al_casco"],
		"absorbido": i["absorbido"], "casco": u["casco"], "escudo": u["escudo"], "moral": u["moral"],
		"derriba": not vivo(u), "voz": "susto" if entra_en_panico or salvado else "", "lado": lado})
	if salvado:
		_avisar(u, tr("¡Salvado por los bigotes!"), "moral")
		hazana.emit("por_los_bigotes")
	return i["al_casco"]


## Trofeos que se ganan al derribar a un enemigo (según quién y cómo).
func _hazanas_de_derribo(u: Dictionary, lado: String) -> void:
	if _atacante.get("aereo", false):
		hazana.emit("desde_el_cielo")
		return
	if _atacante.is_empty():
		return
	if lado == "trasera":
		hazana.emit("por_la_espalda")
	if _atacante.get("mania") == "emboscador" and not _atacante.get("se_movio", false):
		hazana.emit("emboscada_perfecta")
	var menos_vida: int = aliados.map(func(a): return int(a["casco_max"])).min()
	var mas_vida: int = enemigos.map(func(e): return int(e["casco_max"])).max()
	if menos_vida < mas_vida and int(_atacante["casco_max"]) == menos_vida and int(u["casco_max"]) == mas_vida:
		hazana.emit("david_goliat")


## Manía "dramático": tras un golpe fuerte grita y el resto de su bando gana 1 de moral.
func _drama(u: Dictionary) -> void:
	var propios: Array = aliados if u["bando"] == "aliado" else enemigos
	_anotar(tr("  ¡%s grita «¡Avanti!»! Su pelotón gana 1 de moral.") % u["nombre"])
	_avisar(u, tr("¡Avanti!"), "moral")
	for otro in propios:
		if not is_same(otro, u) and vivo(otro) and otro["moral"] < otro["moral_max"]:
			otro["moral"] += 1
			_avisar(otro, tr("+1 moral"), "moral")


## Texto flotante sobre una unidad (escudo, moral...), con su estado ya actualizado.
## `voz`: sonido de gato que acompaña al texto ("" = ninguno).
func _avisar(u: Dictionary, texto: String, color: String, voz: String = "") -> void:
	accion.emit({"tipo": "texto", "clave": u.get("clave", ""), "texto": texto, "color": color,
		"escudo": u["escudo"], "moral": u["moral"], "casco": u["casco"], "voz": voz})


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
	if atacante.get("mania") == "emboscador" and not atacante.get("se_movio", false):
		bonus += BONUS_EMBOSCADA
	var por_aliado := int(c.get("bonus_por_aliado", 0))
	if por_aliado > 0:
		for otro in propios:
			if not is_same(otro, atacante) and vivo(otro) and Mapa.distancia(otro["pos"], objetivo["pos"]) <= 4:
				bonus += por_aliado
	return bonus


## Energía que cuesta la carta para este tanque (hoy no hay manías que la cambien, pero
## queda el gancho para cartas o manías futuras).
func coste_de(c: Dictionary, actor: Dictionary) -> int:
	var coste := int(c["coste"])
	return coste


## Qué pasaría si `actor` juega esta carta contra el enemigo elegido, sin cambiar nada.
## Devuelve [] si la carta no hace daño o no hay blanco. Si no, una lista de impactos
## (calcular_impacto + "indice" del enemigo y "principal"); el primero es el blanco.
## El principal trae además "por_lado": el daño que pegaría por frente, flanco y trasera
## (antes del escudo, que es igual para cualquier lado).
func prever_carta(i_mano: int, i_actor: int, i_objetivo: int) -> Array:
	if i_mano < 0 or i_mano >= mano.size():
		return []
	return prever_uso(mano[i_mano], i_actor, i_objetivo)


## Igual que prever_carta, por id de carta. El principal trae también "penal": lo que
## se resta por disparar sin encarar al blanco.
func prever_uso(id: String, i_actor: int, i_objetivo: int) -> Array:
	if not cartas.has(id) or i_actor < 0 or i_actor >= aliados.size():
		return []
	if i_objetivo < 0 or i_objetivo >= enemigos.size() or not vivo(enemigos[i_objetivo]):
		return []
	var c: Dictionary = cartas[id]
	if not c.has("dano"):
		return []
	var actor: Dictionary = aliados[i_actor]
	var objetivo: Dictionary = enemigos[i_objetivo]
	if c.get("aereo", false):
		return _prever_aereo(c, i_objetivo)
	var pen := int(c.get("penetracion", 0))
	var cob := _cobertura_para(c, objetivo)
	var lado := lado_de_impacto(objetivo, actor["pos"])
	var bonus := bonus_de_ataque(actor, c, objetivo)
	var penal := penalizacion_punteria(actor, objetivo)
	var principal := calcular_impacto(objetivo, maxi(dano_de_carta(c, lado) + bonus - penal, 1), pen, lado, cob)
	principal["indice"] = i_objetivo
	principal["principal"] = true
	principal["bonus"] = bonus
	principal["penal"] = penal
	principal["acierto"] = 1.0 if c.get("sin_roce", false) else probabilidad_acierto(actor, objetivo)
	var dano_lleno := maxi(dano_de_carta(c, lado) + bonus - penal, 1)
	principal["roce"] = calcular_impacto(objetivo, maxi(dano_lleno / 2, 1), pen, lado, cob)["al_casco"]
	var por_lado := {}
	for l in PREFERENCIA_LADO:
		var i := calcular_impacto(objetivo, maxi(dano_de_carta(c, l) + bonus - penal, 1), pen, l, cob)
		por_lado[l] = i["al_casco"] + i["absorbido"]  # antes del escudo: solo compara blindajes
	principal["por_lado"] = por_lado
	var res := [principal]
	var salpicadura := int(c.get("salpicadura", 0))
	if salpicadura > 0:
		for d in Mapa.DIRECCIONES:
			var vecino := unidad_en(objetivo["pos"] + d)
			if vecino.get("bando") == "enemigo":
				var e: Dictionary = enemigos[vecino["indice"]]
				var i := calcular_impacto(e, salpicadura, 0, lado_de_impacto(e, actor["pos"]), _cobertura_para(c, e))
				i["indice"] = vecino["indice"]
				i["principal"] = false
				res.append(i)
	return res


## Vista previa del avión: desde arriba (techo), sin cobertura, sin roces ni penalización.
func _prever_aereo(c: Dictionary, i_objetivo: int) -> Array:
	var objetivo: Dictionary = enemigos[i_objetivo]
	var principal := calcular_impacto(objetivo, int(c["dano"]), int(c.get("penetracion", 0)), "techo", 0)
	principal["indice"] = i_objetivo
	principal["principal"] = true
	principal["bonus"] = 0
	principal["penal"] = 0
	principal["acierto"] = 1.0
	principal["roce"] = principal["al_casco"]
	var v: int = principal["al_casco"] + principal["absorbido"]
	principal["por_lado"] = {"frente": v, "flanco": v, "trasera": v}
	var res := [principal]
	var salpicadura := int(c.get("salpicadura", 0))
	if salpicadura > 0:
		for i in enemigos.size():
			var e: Dictionary = enemigos[i]
			if vivo(e) and Mapa.distancia(e["pos"], objetivo["pos"]) == 1:
				var imp := calcular_impacto(e, salpicadura, 0, "techo", 0)
				imp["indice"] = i
				imp["principal"] = false
				res.append(imp)
	return res


func texto_intencion(u: Dictionary) -> String:
	var a: Dictionary = u["intencion"]
	if a.is_empty():
		return ""
	if a.get("paralizado", false):
		return tr("En pánico: pierde el turno")
	if a.get("averia", false):
		return tr("Avería: este turno no actúa")
	if a.get("reserva", false):
		return tr("En reserva: este turno no actúa (solo actúan %d)") % acciones_max()
	if a.has("dano"):
		var alc: Array = alcance_de(a)
		return tr("%s: %d daño, alcance %d-%d, al más cercano") % [a["nombre"], int(a["dano"]), alc[0], alc[1]]
	if a.has("moral"):
		return tr("%s: -%d moral a quien esté a %d o menos") % [a["nombre"], int(a["moral"]), int(a.get("radio", 99))]
	if a.has("escudo"):
		return tr("%s: +%d escudo") % [a["nombre"], int(a["escudo"])]
	return a["nombre"]


## Celdas que el enemigo puede atacar en su próxima fase (moverse + alcance).
## `alcance_max`: tope de distancia (contra un blanco camuflado, que solo se ve de cerca).
func celdas_amenaza(e: Dictionary, alcance_max: int = 99) -> Dictionary:
	var res := {}
	var a: Dictionary = e["intencion"]
	if not vivo(e) or not a.has("dano"):
		return res
	var alc: Array = alcance_de(a)
	alc[1] = mini(alc[1], alcance_max)
	if alc[1] < alc[0]:
		return res
	for origen in casillas_de_movimiento(e, movimiento_de(e)):
		for dy in range(-alc[1], alc[1] + 1):
			for dx in range(-alc[1], alc[1] + 1):
				var dist := absi(dx) + absi(dy)
				var celda: Vector2i = origen + Vector2i(dx, dy)
				if dist >= alc[0] and dist <= alc[1] and mapa.dentro(celda) and not res.has(celda) 						and ve_a(a, origen, celda):
					res[celda] = true
	return res


## Pide el avión contra el enemigo elegido (queda marcado con humo de color). Si no es
## inmediato, llega al empezar tu próximo turno y lo busca donde esté.
func _pedir_aereo(id: String, i_objetivo: int) -> void:
	aereo_usado = true
	var c: Dictionary = cartas[id]
	var celda: Vector2i = enemigos[i_objetivo]["pos"]
	if c.get("inmediato", false):
		_ataque_aereo(id, celda, "aliado")
		return
	aereo_pendiente = {"carta": id, "indice": i_objetivo, "celda": celda}
	_anotar(tr("  El %s viene en camino: buscará a %s al empezar tu próximo turno.") % [c["nombre"], enemigos[i_objetivo]["nombre"]])
	_avisar(enemigos[i_objetivo], tr("¡Marcado!"), "malo")


## Pasa el avión de `bando` sobre `celda`: pega desde arriba (techo: ignora cobertura y
## línea de visión) al rival que esté ahí y, si la carta salpica, a sus pegados.
func _ataque_aereo(id: String, celda: Vector2i, bando: String) -> void:
	var c: Dictionary = cartas[id]
	var victimas: Array = enemigos if bando == "aliado" else aliados
	accion.emit({"tipo": "avion", "clave": "", "avion": c.get("avion", ""), "celda": celda, "bando": bando})
	evento.emit("avion")
	var blanco := {}
	for u in victimas:
		if vivo(u) and u["pos"] == celda:
			blanco = u
	if blanco.is_empty():
		_anotar(tr("  ¡El %s ataca (%d, %d), pero ahí ya no hay nadie!") % [c["nombre"], celda.x, celda.y])
		if bando == "enemigo":
			hazana.emit("esquivado")
	else:
		_anotar(tr("  ¡El %s ataca a %s desde el aire!") % [c["nombre"], blanco["nombre"]])
		_atacante = {"aereo": true} if bando == "aliado" else {}
		golpear(blanco, int(c["dano"]), int(c.get("penetracion", 0)), "techo", 0)
		if vivo(blanco) and c.has("baja_moral"):
			blanco["moral"] = maxi(blanco["moral"] - int(c["baja_moral"]), 0)
			_avisar(blanco, tr("-%d moral") % int(c["baja_moral"]), "malo")
	var salpicadura := int(c.get("salpicadura", 0))
	if salpicadura > 0:
		for u in victimas:
			if vivo(u) and Mapa.distancia(u["pos"], celda) == 1:
				golpear(u, salpicadura, 0, "techo", 0)
	_atacante = {}


## Avión enemigo (As): desde el turno TURNO_AVION_ENEMIGO, una vez por batalla, marca la
## casilla del tanque propio más dañado. Cae al empezar la fase enemiga.
func _planear_aereo_enemigo() -> void:
	if aereo_rival == "" or aereo_rival_usado or turno < TURNO_AVION_ENEMIGO or not cartas.has(aereo_rival):
		return
	var blanco := {}
	for u in aliados:
		if vivo(u) and (blanco.is_empty() or u["casco"] < blanco["casco"]):
			blanco = u
	if blanco.is_empty():
		return
	aereo_rival_usado = true
	aereo_enemigo_plan = {"carta": aereo_rival, "celda": blanco["pos"]}
	_anotar(tr("¡Avión enemigo a la vista! Atacará (%d, %d) al empezar su fase: ¡saca a %s de ahí!") % [
		blanco["pos"].x, blanco["pos"].y, blanco["nombre"]])
	_avisar(blanco, tr("¡Avión enemigo!"), "malo", "susto")


## Un tanque camuflado solo puede ser blanco desde menos de DISTANCIA_CAMUFLAJE casillas.
func puede_apuntar(blanco: Dictionary, desde: Vector2i) -> bool:
	return not blanco.get("camuflado", false) or Mapa.distancia(desde, blanco["pos"]) < DISTANCIA_CAMUFLAJE


func _descamuflar(u: Dictionary) -> void:
	if u.get("camuflado", false):
		u["camuflado"] = false
		_anotar(tr("  %s deja el camuflaje.") % u["nombre"])


## Línea de visión para esta carta o acción (la artillería dispara por encima: no la necesita).
func ve_a(c: Dictionary, desde: Vector2i, hasta: Vector2i) -> bool:
	return c.get("ignora_vision", false) or mapa.linea_de_vision(desde, hasta)


func _iniciar_turno() -> void:
	turno += 1
	energia = ENERGIA_POR_TURNO + energia_extra
	energia_extra = 0
	for u in aliados:
		u["escudo"] = 0
		u["mov_restante"] = u["movimiento"]
		u["se_movio"] = false
		u["ataques_turno"] = 0
		# Habilidades: se pueden volver a usar y las recargas avanzan un turno.
		u["usadas"] = {}
		for id in u["recargas"].keys():
			u["recargas"][id] -= 1
			if u["recargas"][id] <= 0:
				u["recargas"].erase(id)
	_robar(CARTAS_POR_TURNO)
	_elegir_intenciones()
	_anotar(tr("== Turno %d ==") % turno)
	_tirar_dado()
	_dar_orden()


## Dado del frente (ver EVENTOS_FRENTE). En Recluta solo salen los buenos (3 a 6).
func _tirar_dado() -> void:
	if not eventos_frente or turno != TURNO_DADO or estado != "jugando":
		return
	var minimo := 3 if dificultad.get("dado_amable", false) else 1
	var valor := forzar_dado if forzar_dado > 0 else _rng_dado.randi_range(minimo, 6)
	var ev: Dictionary = EVENTOS_FRENTE[valor].duplicate()
	ev["nombre"] = tr(ev["nombre"])
	ev["texto"] = tr(ev["texto"])
	ev["valor"] = valor
	ev["turno"] = turno
	evento_frente = ev
	_anotar(tr("¡Dado del frente: %d! %s. %s") % [valor, ev["nombre"], ev["texto"]])
	accion.emit({"tipo": "dado", "clave": "", "valor": valor, "nombre": ev["nombre"], "texto": ev["texto"]})
	evento.emit("dado")
	match ev["id"]:
		"lluvia":
			for u in aliados:
				u["mov_restante"] = mini(u["mov_restante"], movimiento_de(u))
		"suministros":
			energia += 1
		"cartas":
			for u in aliados:
				if vivo(u) and u["moral"] < u["moral_max"]:
					u["moral"] += 1
					_avisar(u, tr("+1 moral"), "moral")
		"averia":
			var candidatos: Array = []
			for e in enemigos:
				var a: Dictionary = e["intencion"]
				if vivo(e) and not a.is_empty() and not a.get("reserva", false) and not a.get("paralizado", false):
					candidatos.append(e)
			if candidatos.is_empty():
				_anotar(tr("  Ningún enemigo iba a hacer nada: la avería no cambia nada."))
			else:
				var e: Dictionary = candidatos[_rng_dado.randi_range(0, candidatos.size() - 1)]
				e["intencion"] = {"nombre": tr("Avería"), "averia": true}
				_avisar(e, tr("¡Avería!"), "malo")
		"pescado":
			for u in aliados:
				_reparar(u, 2)
			hazana.emit("banquete")


## ¿Está pasando este evento del dado ahora mismo?
func evento_activo(id: String) -> bool:
	return evento_frente.get("id", "") == id and int(evento_frente.get("turno", -1)) == turno


## Movimiento de este turno (la lluvia quita 1, nunca baja de 1).
func movimiento_de(u: Dictionary) -> int:
	return maxi(int(u["movimiento"]) - (1 if evento_activo("lluvia") else 0), 1)


## Alcance de una carta o acción este turno (con niebla, nada pasa de ALCANCE_NIEBLA).
func alcance_de(c: Dictionary) -> Array:
	var alc: Array = c["alcance"]
	if evento_activo("niebla"):
		return [alc[0], mini(alc[1], ALCANCE_NIEBLA)]
	return [alc[0], alc[1]]


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
	_anotar(tr("%s: «¡%s, dispara este turno!»") % [tr(oficial["nombre"]), aliados[orden]["nombre"]])


## Al terminar el turno: premio si la orden se cumplió, reto si no.
func _revisar_orden() -> void:
	if orden < 0 or not vivo(aliados[orden]):
		return
	var u: Dictionary = aliados[orden]
	if orden_cumplida:
		energia_extra = 1
		hazana.emit("a_la_orden")
		_anotar(tr("%s: «Aceptable.» +1 energía el próximo turno.") % tr(oficial["nombre"]))
	else:
		u["moral"] = maxi(u["moral"] - 1, 0)
		_anotar(tr("%s: «¿Y ese disparo, recluta?» %s pierde 1 de moral.") % [tr(oficial["nombre"]), u["nombre"]])
		_avisar(u, tr("Michi: -1 moral"), "malo", "michi_grunido")


func _elegir_intenciones() -> void:
	var reserva := _enemigos_en_reserva()
	for i in enemigos.size():
		var e: Dictionary = enemigos[i]
		if not vivo(e):
			e["intencion"] = {}
		elif en_panico(e):
			e["intencion"] = {"nombre": tr("Pánico"), "paralizado": true}
		elif reserva.has(i):
			e["intencion"] = {"nombre": tr("En reserva"), "reserva": true}
		else:
			var acciones: Array = e["acciones"]
			var a: Dictionary = acciones[rng.randi_range(0, acciones.size() - 1)].duplicate(true)
			if a.has("alcance"):
				a["alcance"] = _rango(a["alcance"])
			if a.has("dano"):
				# La dificultad ya va incluida en lo que anuncia, así el ícono no miente.
				a["dano"] = maxi(int(a["dano"]) + int(dificultad.get("bonus_dano", 0)), 1)
			e["intencion"] = a
	_planear_aereo_enemigo()


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
			_anotar(tr("%s se queda quieto tomando té: +1 moral.") % u["nombre"])
			_avisar(u, tr("té: +1 moral"), "moral")
		if vivo(u) and u.get("mania") == "gloton" and int(u.get("ataques_turno", 0)) == 0 and u["moral"] < u["moral_max"]:
			u["moral"] += 1
			_anotar(tr("%s no atacó y se come algo: +1 moral.") % u["nombre"])
			_avisar(u, tr("ñam: +1 moral"), "moral")
		if vivo(u) and u.get("mania") == "mecanico":
			# Repara al compañero pegado más dañado.
			var mejor := {}
			for d in Mapa.DIRECCIONES:
				var v := unidad_en(u["pos"] + d)
				if v.get("bando") == u["bando"]:
					var otro: Dictionary = (aliados if u["bando"] == "aliado" else enemigos)[v["indice"]]
					if otro["casco"] < otro["casco_max"] and (mejor.is_empty() or otro["casco"] < mejor["casco"]):
						mejor = otro
			if not mejor.is_empty():
				_anotar(tr("%s repara a %s.") % [u["nombre"], mejor["nombre"]])
				_reparar(mejor, 2)


func _turno_enemigo() -> void:
	for e in enemigos:
		e["se_movio"] = false
		e["ataques_turno"] = 0
	_sanos_en_fase.clear()
	if dificultad.get("salvavidas", false):
		for u in aliados:
			if vivo(u) and u["casco"] == u["casco_max"]:
				_sanos_en_fase[u["clave"]] = true
	if not aereo_enemigo_plan.is_empty():
		_ataque_aereo(aereo_enemigo_plan["carta"], aereo_enemigo_plan["celda"], "enemigo")
		aereo_enemigo_plan = {}
	if _primer_vivo(aliados) >= 0:
		_turno_enemigo_acciones()
	_sanos_en_fase.clear()
	_cerrar_turno_de(enemigos)


## Daño que podría recibir `u` en la próxima fase enemiga si todos los que lo alcanzan le
## disparan (estimado por el flanco). Sirve para avisar "peligro" antes de terminar el turno.
func dano_en_peligro(u: Dictionary) -> int:
	if not vivo(u):
		return 0
	var total := 0
	for e in enemigos:
		var a: Dictionary = e.get("intencion", {})
		if not vivo(e) or not a.has("dano") or a.get("reserva", false) or a.get("paralizado", false) \
				or a.get("averia", false):
			continue
		var tope := DISTANCIA_CAMUFLAJE - 1 if u.get("camuflado", false) else 99
		if not celdas_amenaza(e, tope).has(u["pos"]):
			continue
		var i := calcular_impacto(u, int(a["dano"]) + bonus_de_ataque(e, a, u), int(a.get("penetracion", 0)),
			"flanco", cobertura_de(u))
		total += i["al_casco"] + i["absorbido"]
	if not aereo_enemigo_plan.is_empty():
		var ca: Dictionary = cartas[aereo_enemigo_plan["carta"]]
		var dist := Mapa.distancia(u["pos"], aereo_enemigo_plan["celda"])
		var dano_aereo := int(ca["dano"]) if dist == 0 else (int(ca.get("salpicadura", 0)) if dist == 1 else 0)
		if dano_aereo > 0:
			var ia := calcular_impacto(u, dano_aereo, int(ca.get("penetracion", 0)) if dist == 0 else 0, "techo", 0)
			total += ia["al_casco"] + ia["absorbido"]
	return maxi(total - int(u["escudo"]), 0)


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
			_anotar(tr("%s está en pánico y no actúa.") % e["nombre"])
			continue
		if a.get("reserva", false):
			_anotar(tr("%s espera en reserva.") % e["nombre"])
			continue
		if a.get("averia", false):
			_anotar(tr("%s está arreglando su avería y no actúa.") % e["nombre"])
			continue
		if a.has("dano"):
			_atacar_como_enemigo(e, a)
		if a.has("moral"):
			_anotar(tr("%s usa %s.") % [e["nombre"], a["nombre"]])
			_avisar(e, a["nombre"] + "!", "malo")
			for u in aliados:
				if vivo(u) and Mapa.distancia(u["pos"], e["pos"]) <= int(a.get("radio", 99)):
					u["moral"] = maxi(u["moral"] - int(a["moral"]), 0)
					_avisar(u, tr("-%d moral") % int(a["moral"]), "malo")
		if a.has("escudo"):
			_anotar(tr("%s usa %s.") % [e["nombre"], a["nombre"]])
			e["escudo"] += int(a["escudo"])
			_avisar(e, tr("+%d escudo") % int(a["escudo"]), "escudo")
		if _primer_vivo(aliados) < 0:
			return


## Elige dónde moverse y a quién disparar, y lo hace.
## IA simple: va por el aliado más cercano, prefiriendo flanco/trasera y moverse poco.
## IA lista (Veterano/As): prueba cada casilla y cada blanco y se queda con el mayor
## daño esperado; prefiere rematar, pegarle al más dañado y quedar en cobertura.
func _atacar_como_enemigo(e: Dictionary, a: Dictionary) -> void:
	var opciones := casillas_de_movimiento(e, movimiento_de(e))
	var plan := _plan_listo(e, a, opciones) if dificultad.get("ia_lista", false) else _plan_simple(e, a, opciones)
	if plan.is_empty():
		return
	var objetivo: Dictionary = plan["objetivo"]
	var alc: Array = alcance_de(a)
	var mejor_celda: Vector2i = plan["celda"]
	if mejor_celda != e["pos"]:
		_mover_a(e, mejor_celda, opciones)
	var dist_final := Mapa.distancia(e["pos"], objetivo["pos"])
	if dist_final < alc[0] or dist_final > alc[1] or not ve_a(a, e["pos"], objetivo["pos"]) \
			or not puede_apuntar(objetivo, e["pos"]):
		_anotar(tr("%s avanza.") % e["nombre"])
		return
	e["orientacion"] = direccion_hacia(e["pos"], objetivo["pos"])
	_anotar(tr("%s usa %s.") % [e["nombre"], a["nombre"]])
	evento.emit("disparo")
	e["ataques_turno"] = int(e.get("ataques_turno", 0)) + 1
	accion.emit({"tipo": "disparo", "clave": e["clave"], "objetivo": objetivo["clave"],
		"orientacion": e["orientacion"]})
	golpear(objetivo, int(a["dano"]) + bonus_de_ataque(e, a, objetivo), int(a.get("penetracion", 0)),
		lado_de_impacto(objetivo, e["pos"]), cobertura_de(objetivo))


func _plan_simple(e: Dictionary, a: Dictionary, opciones: Dictionary) -> Dictionary:
	var objetivo := _aliado_mas_cercano(e["pos"])
	if objetivo.is_empty():
		return {}
	var alc: Array = alcance_de(a)
	var mejor_celda: Vector2i = e["pos"]
	var mejor_puntaje := -INF
	for celda in opciones:
		var dist := Mapa.distancia(celda, objetivo["pos"])
		var coste: int = opciones[celda][0]
		var puntaje: float
		if dist >= alc[0] and dist <= alc[1] and ve_a(a, celda, objetivo["pos"]) and puede_apuntar(objetivo, celda):
			puntaje = 1000 + PREFERENCIA_LADO[lado_de_impacto(objetivo, celda)] * 10 - coste
		else:
			puntaje = -dist * 10 - coste
		if puntaje > mejor_puntaje:
			mejor_puntaje = puntaje
			mejor_celda = celda
	return {"celda": mejor_celda, "objetivo": objetivo}


func _plan_listo(e: Dictionary, a: Dictionary, opciones: Dictionary) -> Dictionary:
	var alc: Array = alcance_de(a)
	var pen := int(a.get("penetracion", 0))
	var original: Vector2i = e["pos"]
	var mejor := {}
	var mejor_puntaje := -INF
	for celda in opciones:
		var coste: int = opciones[celda][0]
		e["pos"] = celda  # para que el bono de "camarada" mire desde la casilla candidata
		e["se_movio"] = celda != original  # y el de "emboscador" sepa si se movió
		var cerca := 1 << 20
		for u in aliados:
			if not vivo(u):
				continue
			var dist := Mapa.distancia(celda, u["pos"])
			cerca = mini(cerca, dist)
			if dist < alc[0] or dist > alc[1] or not ve_a(a, celda, u["pos"]) or not puede_apuntar(u, celda):
				continue
			var lado := lado_de_impacto(u, celda)
			var imp := calcular_impacto(u, int(a["dano"]) + bonus_de_ataque(e, a, u), pen, lado, cobertura_de(u))
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
	e["se_movio"] = false
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
	_descamuflar(u)
	accion.emit({"tipo": "mover", "clave": u.get("clave", ""), "camino": camino, "orientacion": u["orientacion"]})
	for paso in camino.slice(1):
		if vivo(u) and mapa.terreno(paso).get("mina", false):
			_pisar_mina(u, paso)


## Pasar por una mina: dado de 6; con 1 o 2 explota (pega por la panza, sin blindaje que
## valga) y la casilla queda como arena removida. Si no, ¡uf!
func _pisar_mina(u: Dictionary, celda: Vector2i) -> void:
	var valor := forzar_mina if forzar_mina > 0 else _rng_dado.randi_range(1, 6)
	if u["bando"] == "aliado":
		minas_pisadas += 1
	if valor > MINA_EXPLOTA_HASTA:
		_anotar(tr("  %s pasa por el campo minado... dado %d: ¡uf, no explota!") % [u["nombre"], valor])
		_avisar(u, tr("¡Uf! (dado %d)") % valor, "moral")
		return
	_anotar(tr("  %s pisa una mina... dado %d: ¡BUM!") % [u["nombre"], valor])
	if u["bando"] == "aliado":
		minas_explotadas += 1
	mapa.cambiar(celda, str(mapa_letra_crater()))
	_avisar(u, tr("¡Mina! (dado %d)") % valor, "malo", "susto")
	golpear(u, DANO_MINA, 99, "panza", 0)


## Letra del terreno en que queda una mina que explotó (la "arena blanda" del mapa, o llano).
func mapa_letra_crater() -> String:
	return "s" if mapa._tipos.has("s") else "."


## Dijkstra sin límite práctico ni recorte de casillas ocupadas por los propios
## (los rivales sí bloquean): solo para rearmar caminos.
func _red_de_caminos(u: Dictionary) -> Dictionary:
	var rivales: Array = enemigos if u["bando"] == "aliado" else aliados
	var bloqueadas := {}
	for r in rivales:
		if vivo(r):
			bloqueadas[r["pos"]] = true
	return mapa.alcanzables(u["pos"], 999, bloqueadas, _tope_coste(u))


## Manía "escaladora" (el Churchill trepaba cualquier terreno): toda casilla transitable
## le cuesta 1 de movimiento, como el llano.
func _tope_coste(u: Dictionary) -> int:
	return 1 if u.get("mania") == "escaladora" else 0


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
		_anotar(tr("Victoria!"))
		evento.emit("victoria")
		hazana.emit("primera_victoria")
		if aliados.all(func(a): return vivo(a)):
			hazana.emit("sin_bajas")
		if minas_pisadas > 0 and minas_explotadas == 0:
			hazana.emit("pisando_huevos")
		if dificultad.get("nombre", "") == "As":
			hazana.emit("as_de_ases")
	elif _primer_vivo(aliados) < 0:
		estado = "derrota"
		_anotar(tr("Derrota..."))
		evento.emit("derrota")


func _anotar(texto: String) -> void:
	registro.append(texto)


func _nombre_lado(lado: String) -> String:
	return {"frente": tr("el frente"), "flanco": tr("el flanco"), "trasera": tr("la trasera"), "techo": tr("el techo"),
		"panza": tr("la panza")}.get(lado, lado)


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
	u["usadas"] = {}    # habilidades usadas este turno
	u["recargas"] = {}  # id -> turnos que faltan para volver a usarla
	return u
