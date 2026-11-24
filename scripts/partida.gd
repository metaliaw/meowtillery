extends Node
## Autoload "Partida": qué batallón eligió la jugadora y contra quién pelea.
## La función estática también la usan las pruebas, sin autoload.

const Datos := preload("res://scripts/datos.gd")

## Oficial al mando de cualquier batallón: la teniente Michi.
const OFICIAL := {
	"id": "michi",
	"nombre": "Teniente Michi",
	"gato": "res://assets/gatos/michi.png",
	"mania": "mandona",
	"mania_texto": "Mandona: cada turno ordena a un tanque que ataque. Si obedece, +1 energía el turno siguiente; si no, ese tanque pierde 1 de moral.",
}

## Michi aparece de inspección sorpresa: con esta probabilidad en cada batalla,
## y segura si lleva BATALLAS_SIN_MICHI_MAX batallas sin venir.
const PROBABILIDAD_MICHI := 1.0 / 3.0
const BATALLAS_SIN_MICHI_MAX := 3

## Niveles de dificultad (ver Combate.dificultad). Calibrados con tools/qa/simular.gd.
const DIFICULTADES := {
	"recluta": {"nombre": "Recluta", "texto": "Para aprender. Actúan 2 enemigos por turno y pegan 2 menos.",
		"acciones_max": 2, "bonus_dano": -2, "ia_lista": false, "salvavidas": true},
	"veterano": {"nombre": "Veterano", "texto": "El enemigo piensa: remata, flanquea, se cubre y pega 2 más. Un tanque sano no cae en un solo turno. De lejos puedes rozar.",
		"acciones_max": 3, "bonus_dano": 2, "ia_lista": true, "salvavidas": true, "punteria": true},
	"as": {"nombre": "As", "texto": "Sin piedad: actúan todos, pegan 2 más y no hay red de seguridad.",
		"acciones_max": 4, "bonus_dano": 2, "ia_lista": true, "punteria": true},
}

## Mapa de las partidas sueltas y mapas de la campaña.
const MAPA_LIBRE := "res://data/mapa.json"
## Campaña: 5 batallas seguidas. El rival alterna entre los otros dos batallones.
const CAMPANA := [
	{"dificultad": "recluta", "mapa": "res://data/mapas/colinas.json"},
	{"dificultad": "recluta", "mapa": "res://data/mapas/bosque.json"},
	{"dificultad": "veterano", "mapa": "res://data/mapas/ciudad.json"},
	{"dificultad": "veterano", "mapa": "res://data/mapas/bosque.json"},
	{"dificultad": "as", "mapa": "res://data/mapas/ciudad.json"},
]
const VIDA_POR_MEDALLA := 2
const ARCHIVO_CAMPANA := "user://campana.json"

## Arsenal: cartas de botín guardadas entre batallas (las que capturaste y no usaste).
## Antes de una batalla se eligen hasta LLEVAR_MAX para llevar; usarlas las gasta.
const ARCHIVO_ARSENAL := "user://arsenal.json"
const ARSENAL_MAX := 12
const LLEVAR_MAX := 2

var jugador := "britanico"
var rival := "sovietico"
## Rival elegido en la pantalla de batallón ("" = al azar entre los demás).
var rival_elegido := ""
var dificultad := "recluta"
var batallas_sin_michi := 0
var arsenal: Array = []
var llevar: Array = []  # posiciones del arsenal elegidas para la próxima batalla
var archivo_arsenal := ARCHIVO_ARSENAL  # las pruebas usan otro archivo
var mapa_actual := MAPA_LIBRE
## Campaña en curso: {"batallon", "batalla" (0..5), "medallas": {id: n}, "recompensa": [ids]}.
## Vacío = no hay campaña. `modo_campana` dice si la batalla que se juega es de campaña.
var campana: Dictionary = {}
var modo_campana := false
var archivo_campana := ARCHIVO_CAMPANA


func _ready() -> void:
	cargar_arsenal()
	cargar_campana()


# ------------------------------------------------------------------ campaña ---

func campana_activa() -> bool:
	return not campana.is_empty()


func empezar_campana(id_batallon: String) -> void:
	campana = {"batallon": id_batallon, "batalla": 0, "medallas": {}, "recompensa": []}
	guardar_campana()


func abandonar_campana() -> void:
	campana = {}
	modo_campana = false
	guardar_campana()


## Rival de la batalla `n` de la campaña: alterna entre los otros dos batallones.
## Rival de cada batalla de la campaña por batallón, elegido simulando (tools/qa/simular.gd
## -- --campana) para que la dificultad suba de a poco y la última sea la más dura.
const RIVALES_CAMPANA := {
	"britanico": ["sovietico", "estadounidense", "sovietico", "estadounidense", "sovietico"],
	"sovietico": ["britanico", "estadounidense", "estadounidense", "britanico", "britanico"],
	"estadounidense": ["britanico", "sovietico", "britanico", "sovietico", "sovietico"],
}


func rival_de_campana(n: int) -> String:
	if RIVALES_CAMPANA.has(campana["batallon"]):
		return RIVALES_CAMPANA[campana["batallon"]][n]
	var otros: Array = batallones().keys().filter(func(id): return id != campana["batallon"])
	return otros[n % otros.size()]


## Deja todo listo para jugar la próxima batalla de la campaña (escena de combate).
func preparar_batalla_campana() -> void:
	var n: int = campana["batalla"]
	var paso: Dictionary = CAMPANA[mini(n, CAMPANA.size() - 1)]
	modo_campana = true
	jugador = campana["batallon"]
	rival = rival_de_campana(n)
	dificultad = paso["dificultad"]
	mapa_actual = paso["mapa"]


## Partida suelta (no campaña): mapa normal.
func preparar_partida_libre() -> void:
	modo_campana = false
	mapa_actual = MAPA_LIBRE


## Victoria en campaña: medalla a cada gato que sigue en pie, avanza a la próxima batalla
## y deja 3 cartas para elegir como recompensa. Devuelve si terminó la campaña.
func campana_ganada(combate) -> bool:
	if not modo_campana or campana.is_empty():
		return false
	for u in combate.aliados:
		if combate.vivo(u) and u.has("id") and u["id"] in batallones()[campana["batallon"]]["unidades"].map(func(x): return x["id"]):
			campana["medallas"][u["id"]] = int(campana["medallas"].get(u["id"], 0)) + 1
	campana["batalla"] = int(campana["batalla"]) + 1
	campana["recompensa"] = _opciones_recompensa()
	guardar_campana()
	return campana["batalla"] >= CAMPANA.size()


## 3 cartas al azar entre las cartas propias de todos los gatos (sin los cañones básicos).
func _opciones_recompensa() -> Array:
	var pozo: Array = []
	var de_refuerzo: Array = []
	for c in Datos.leer("res://data/cartas.json"):
		if c.get("refuerzo", false):
			de_refuerzo.append(c["id"])
	for b in batallones().values():
		for u in b["unidades"]:
			for id in u.get("habilidades", []).slice(1):
				# ¡Refuerzos! solo sirve al batallón que tiene tanque de refuerzo.
				if id in de_refuerzo:
					continue
				if not pozo.has(id):
					pozo.append(id)
	pozo.shuffle()
	return pozo.slice(0, 3)


## Elige la recompensa: va al Arsenal.
func elegir_recompensa(id: String) -> void:
	if not campana.get("recompensa", []).has(id):
		return
	arsenal.append(id)
	while arsenal.size() > ARSENAL_MAX:
		arsenal.pop_front()
	campana["recompensa"] = []
	guardar_arsenal()
	guardar_campana()


func cargar_campana() -> void:
	campana = {}
	if FileAccess.file_exists(archivo_campana):
		var datos = JSON.parse_string(FileAccess.get_file_as_string(archivo_campana))
		if datos is Dictionary and datos.has("batallon"):
			campana = datos
			campana["batalla"] = int(campana.get("batalla", 0))


func guardar_campana() -> void:
	var f := FileAccess.open(archivo_campana, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(campana))


## Arma la batalla elegida y decide si esta vez viene Michi. Devuelve si vino.
## Las cartas elegidas del Arsenal salen de él y entran como botín inicial.
func nueva_batalla(combate) -> bool:
	var viene := batallas_sin_michi >= BATALLAS_SIN_MICHI_MAX or randf() < PROBABILIDAD_MICHI
	batallas_sin_michi = 0 if viene else batallas_sin_michi + 1
	iniciar_combate(combate, jugador, rival, -1, viene, dificultad, mapa_actual,
		campana.get("medallas", {}) if modo_campana else {})
	var posiciones := llevar.filter(func(i): return i >= 0 and i < arsenal.size())
	posiciones.sort()
	for i in posiciones:
		combate.botin.append(arsenal[i])
	posiciones.reverse()
	for i in posiciones:
		arsenal.remove_at(i)
	llevar.clear()
	combate.set_meta("arsenal_cerrado", false)
	guardar_arsenal()
	return viene


## Al terminar o abandonar una batalla: el botín sin usar vuelve al Arsenal (y las capturas
## que quedaron sin elegir, con su primera opción). Se puede llamar más de una vez.
func cerrar_batalla(combate) -> void:
	if combate == null or combate.get_meta("arsenal_cerrado", true):
		return
	combate.set_meta("arsenal_cerrado", true)
	for captura in combate.capturas:
		combate.botin.append(captura["opciones"][0])
	combate.capturas.clear()
	arsenal.append_array(combate.botin)
	while arsenal.size() > ARSENAL_MAX:
		arsenal.pop_front()  # se descartan las más antiguas
	guardar_arsenal()


## Marca o desmarca la carta en la posición `i` del Arsenal. Devuelve si quedó elegida.
func alternar_llevar(i: int) -> bool:
	if llevar.has(i):
		llevar.erase(i)
		return false
	if llevar.size() >= LLEVAR_MAX or i < 0 or i >= arsenal.size():
		return false
	llevar.append(i)
	return true


func cargar_arsenal() -> void:
	arsenal = []
	if FileAccess.file_exists(archivo_arsenal):
		var datos = JSON.parse_string(FileAccess.get_file_as_string(archivo_arsenal))
		if datos is Array:
			arsenal = datos.filter(func(x): return x is String)
	llevar = llevar.filter(func(i): return i < arsenal.size())


func guardar_arsenal() -> void:
	var f := FileAccess.open(archivo_arsenal, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(arsenal))


static func batallones() -> Dictionary:
	return Datos.leer("res://data/batallones.json")


## El rival es el elegido o, si es "al azar" (o el mismo batallón), uno de los demás.
func elegir(id_batallon: String) -> void:
	jugador = id_batallon
	var otros: Array = batallones().keys().filter(func(id): return id != id_batallon)
	rival = rival_elegido if otros.has(rival_elegido) else otros[randi() % otros.size()]


## Arma el combate. No hay mazo compartido: cada gato trae sus propias cartas
## ("habilidades" en data/batallones.json). Con `con_michi`, la teniente Michi está al
## mando y da órdenes.
static func iniciar_combate(combate, id_jugador: String, id_rival: String, semilla: int = -1,
		con_michi: bool = false, id_dificultad: String = "", ruta_mapa: String = MAPA_LIBRE,
		medallas: Dictionary = {}) -> void:
	var b := batallones()
	var mazo: Array = []
	combate.oficial = OFICIAL if con_michi else {}
	combate.dificultad = DIFICULTADES.get(id_dificultad, {})
	combate.refuerzo = b[id_jugador].get("refuerzo", {})
	# Medallas de campaña: +VIDA_POR_MEDALLA de vida cada una, y una estrella en el nombre.
	var propios: Array = []
	for def in b[id_jugador]["unidades"]:
		var u: Dictionary = def.duplicate(true)
		var n := int(medallas.get(u["id"], 0))
		if n > 0:
			u["casco"] = int(u["casco"]) + VIDA_POR_MEDALLA * n
			u["nombre"] = "%s %s" % [u["nombre"], "★".repeat(n)]
		propios.append(u)
	combate.iniciar(
		Datos.leer(ruta_mapa),
		propios,
		b[id_rival]["unidades"],
		Datos.leer("res://data/cartas.json"),
		mazo,
		semilla)
