extends RefCounted
## Mapa en grilla: terreno, costes de movimiento y búsqueda de caminos.
## El terreno se define en data/mapa.json como filas de letras.

const DIRECCIONES: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

var ancho := 0
var alto := 0
var _filas: Array = []
var _tipos: Dictionary = {}


func cargar(def: Dictionary) -> void:
	_filas = def["filas"]
	_tipos = def["terreno"]
	alto = _filas.size()
	ancho = (_filas[0] as String).length()


func dentro(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < ancho and c.y < alto


func terreno(c: Vector2i) -> Dictionary:
	return _tipos[(_filas[c.y] as String)[c.x]]


## Coste de entrar en la celda; -1 = intransitable.
func coste(c: Vector2i) -> int:
	return int(terreno(c)["coste"])


func transitable(c: Vector2i) -> bool:
	return dentro(c) and coste(c) > 0


## Blindaje extra que da el terreno a quien está en la celda.
func cobertura(c: Vector2i) -> int:
	return int(terreno(c).get("cobertura", 0))


static func distancia(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Dijkstra desde `origen` con un presupuesto de movimiento `mov`.
## `bloqueadas` son celdas que no se pueden atravesar (unidades rivales).
## Devuelve {celda: [coste, celda_anterior]}, incluido el origen con coste 0.
func alcanzables(origen: Vector2i, mov: int, bloqueadas: Dictionary) -> Dictionary:
	var mejor := {origen: [0, origen]}
	var frontera: Array[Vector2i] = [origen]
	while not frontera.is_empty():
		# Mapas chicos: buscar el mínimo a mano basta y evita una cola de prioridad.
		var k := 0
		for i in frontera.size():
			if mejor[frontera[i]][0] < mejor[frontera[k]][0]:
				k = i
		var actual: Vector2i = frontera.pop_at(k)
		for d in DIRECCIONES:
			var sig: Vector2i = actual + d
			if not transitable(sig) or bloqueadas.has(sig):
				continue
			var c: int = mejor[actual][0] + coste(sig)
			if c > mov:
				continue
			if not mejor.has(sig) or c < mejor[sig][0]:
				mejor[sig] = [c, actual]
				frontera.append(sig)
	return mejor
