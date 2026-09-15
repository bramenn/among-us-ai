class_name VoteLogic
extends RefCounted
## Lógica pura de votación (sin nodos) para poder testearla.

const SKIP := -1
const CONFIDENT_THRESHOLD := 35.0
const SKIP_WEIGHT := 2.0


## Voto de un NPC. suspicion: id -> float. candidates: ids vivos.
static func npc_choose(voter: int, suspicion: Dictionary, candidates: Array[int], voter_is_impostor: bool,
		public_suspicion: Dictionary, rng: RandomNumberGenerator) -> int:
	var others: Array[int] = []
	for c in candidates:
		if c != voter:
			others.append(c)
	if others.is_empty():
		return SKIP
	if voter_is_impostor:
		# Se suma a la sospecha pública para no destacar; si no hay, vota al azar.
		var best := argmax(public_suspicion, others)
		if best != SKIP and float(public_suspicion[best]) >= CONFIDENT_THRESHOLD * 0.5:
			return best
		return others[rng.randi_range(0, others.size() - 1)] if rng.randf() < 0.6 else SKIP
	var top := argmax(suspicion, others)
	if top != SKIP and float(suspicion[top]) >= CONFIDENT_THRESHOLD:
		return top
	# Sin información clara: aleatorio ponderado por sospecha, con opción de saltar.
	var total := SKIP_WEIGHT
	for c in others:
		total += 1.0 + float(suspicion.get(c, 0.0))
	var r := rng.randf() * total
	for c in others:
		r -= 1.0 + float(suspicion.get(c, 0.0))
		if r <= 0.0:
			return c
	return SKIP


## votes: voter -> target (o SKIP). Devuelve expulsado o SKIP si empate/salto.
static func tally(votes: Dictionary) -> int:
	var counts := count(votes)
	var best := SKIP
	var best_n := 0
	var tie := false
	for target: int in counts:
		var n: int = counts[target]
		if n > best_n:
			best = target
			best_n = n
			tie = false
		elif n == best_n:
			tie = true
	if tie or best_n == 0:
		return SKIP
	return best


static func count(votes: Dictionary) -> Dictionary:
	var counts := {}
	for voter: int in votes:
		var t: int = votes[voter]
		counts[t] = int(counts.get(t, 0)) + 1
	return counts


static func argmax(d: Dictionary, among: Array[int]) -> int:
	var best := SKIP
	var best_v := 0.0
	for c in among:
		var v := float(d.get(c, 0.0))
		if v > best_v:
			best_v = v
			best = c
	return best
