extends Node
## The farmer's money. Chapter 32 builds the shop on top of this.

const START_MONEY: int = 100

var money: int = START_MONEY


func add_money(amount: int) -> void:
	if amount <= 0:
		return
	money += amount
	Events.money_changed.emit(money)


## Takes the money and returns true, or returns false and changes nothing when there is too little.
func spend(amount: int) -> bool:
	if amount < 0 or amount > money:
		return false
	money -= amount
	Events.money_changed.emit(money)
	return true
