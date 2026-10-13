extends Node

const START_MONEY: int = 100
const LEDGER_LIMIT: int = 200

var money: int = START_MONEY
var ledger: Array[Dictionary] = []


func _ready() -> void:
	Events.day_started.connect(_on_day_started)


func add_money(amount: int, reason: String = "") -> void:
	if amount <= 0:
		return
	money += amount
	_record(amount, reason)
	Events.money_changed.emit(money)


func spend(amount: int, reason: String = "") -> bool:
	if amount < 0 or amount > money:
		return false
	money -= amount
	if amount > 0:
		_record(-amount, reason)
	Events.money_changed.emit(money)
	return true


func entries_for(day: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry: Dictionary in ledger:
		if entry["day"] == day:
			found.append(entry)
	return found


func summary_for(day: int) -> Dictionary:
	var earned: int = 0
	var spent: int = 0
	for entry: Dictionary in entries_for(day):
		if entry["amount"] > 0:
			earned += entry["amount"]
		else:
			spent -= entry["amount"]
	return {"day": day, "earned": earned, "spent": spent, "net": earned - spent}


func to_save() -> Dictionary:
	return {"money": money, "ledger": ledger.duplicate(true)}


func from_save(data: Dictionary) -> void:
	ledger.clear()
	for entry: Dictionary in data["ledger"]:
		ledger.append({"day": int(entry["day"]), "amount": int(entry["amount"]), "reason": String(entry["reason"]), "balance": int(entry["balance"])})
	money = int(data["money"])
	Events.money_changed.emit(money)


func _record(amount: int, reason: String) -> void:
	ledger.append({"day": GameClock.day, "amount": amount, "reason": reason, "balance": money})
	if ledger.size() > LEDGER_LIMIT:
		ledger.pop_front()
	Events.money_moved.emit(amount, reason)


func _on_day_started(day: int) -> void:
	var summary: Dictionary = summary_for(day - 1)
	Events.day_summary.emit(day - 1, summary["earned"], summary["spent"])
