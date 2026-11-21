extends Node
const CLS_Enemy := preload("res://scripts/enemy.gd")
const CLS_OpeningShot := preload("res://scripts/opening_shot.gd")
## Headless smoke test for Series-2 Phase 4: the Bullet Ledger. Wallet math
## and entry order, the first gun offer with its bullet price, shots spending
## visible cash, the empty click when broke, the receipt screen content, and
## the test weapon's damage. Not part of the game.

var _main: Node3D
var _player: CharacterBody3D
var _dummy: CharacterBody3D
var _hud: CanvasLayer
var _ledger: CanvasLayer
var _fails := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("SMOKE FAIL: ", what)
	else:
		print("SMOKE ok: ", what)


func _ready() -> void:
	Settings.set_value("first_run_done", true)  # isolated user dir: no first-run picker
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	var opening := get_tree().get_first_node_in_group("opening") as CLS_OpeningShot
	if opening:
		opening.skip()
	_player = _main.get_node("Player") as CharacterBody3D
	_dummy = _main.get_node("Dummy") as CharacterBody3D
	_hud = get_tree().get_first_node_in_group("cash_hud") as CanvasLayer
	_ledger = get_tree().get_first_node_in_group("ledger") as CanvasLayer
	Wallet.call("reset_for_test")
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _wallet_math()
	await _first_offer()
	await _fire()
	await _broke()
	await _receipt()
	_finish()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _wallet_math() -> void:
	_check(Wallet.cash == 150, "wallet starts at $150 (got $%d)" % Wallet.cash)
	Wallet.earn(12, "bout vs brawler")
	_check(Wallet.cash == 162, "earn adds ($%d)" % Wallet.cash)
	_check(Wallet.entries.size() == 1, "one entry after earning")
	Wallet.spend(5, ".38 round", "shot")
	_check(Wallet.cash == 157, "shot spends $5 ($%d)" % Wallet.cash)
	_check(Wallet.entries.size() == 2, "two entries")
	var last: Dictionary = Wallet.entries[1]
	_check(last.kind == "shot" and last.amount == -5 and last.balance == 157,
			"entry records kind/amount/balance")
	_check(not Wallet.spend(10000, "impossible"), "cannot overspend")
	_check(Wallet.entries.size() == 2, "failed spend writes no entry")
	await _wait(0.05)


func _first_offer() -> void:
	# stand by the gun on the car and GRAB: the offer must appear first
	_player.global_position = Vector3(11.4, 0.02, -2.6)
	_player.velocity = Vector3.ZERO
	await _wait(0.05)
	InputBus.queue_grab()
	await _wait(0.2)
	_check(Wallet.gun_offered, "first GRAB at the gun shows the offer")
	_check(not _player.has_gun if "has_gun" in _player else false, "gun not taken yet")
	_check(InputBus.locked, "offer locks gameplay input")
	# TAKE IT
	var modal: PanelContainer = _hud.get("_modal")
	_check(modal != null, "offer modal is on screen")
	if modal:
		var body := _find_label(modal, "BULLET")
		_check(body != null and body.text.contains("$5"), "the offer shows the bullet price")
		var take := _find_button(modal, "TAKE IT")
		_check(take != null, "offer has TAKE IT")
		if take:
			take.emit_signal("pressed")
			await _wait(0.1)
			_check(_player.get("has_gun"), "taking the offer equips the gun")
			_check(Wallet.gun_owned, "gun ownership recorded")
			_check(not InputBus.locked, "offer unlocks input")


func _fire() -> void:
	# dummy in front, punch press = a shot
	_dummy.global_position = _player.global_position + Vector3(-1.2, 0.02, 0.0)
	_dummy.velocity = Vector3.ZERO
	_dummy.state = CLS_Enemy.State.IDLE
	_dummy.set("hp", 12)
	_player.set("_yaw", PI / 2.0)  # face west, toward the dummy
	_player.get_node("Body").rotation.y = PI / 2.0
	var before := Wallet.cash
	var entries := Wallet.entries.size()
	InputBus.queue_punch()
	await _wait(0.3)
	_check(Wallet.cash == before - 5, "firing spends $5 on screen ($%d)" % Wallet.cash)
	_check(Wallet.entries.size() == entries + 1, "the shot is in the ledger")
	_check(Wallet.entries[-1].kind == "shot", "entry kind is shot")
	_check(_dummy.get("hp") == 6, "a shot deals 6 damage (hp 12->%d)" % _dummy.get("hp"))
	var label: Label = _hud.get("_label")
	_check(label.text == "$ %d" % Wallet.cash, "HUD shows the new balance (%s)" % label.text)
	# cooldown: an immediate second press does not double-spend
	before = Wallet.cash
	InputBus.queue_punch()
	await _wait(0.05)
	_check(Wallet.cash == before, "cooldown blocks a double shot")


func _broke() -> void:
	Wallet.cash = 3
	var entries := Wallet.entries.size()
	InputBus.set("_gun_cd", 0.0)  # clear the cooldown for the test
	_player.set("_t", 100.0)
	InputBus.queue_punch()
	await _wait(0.25)
	_check(Wallet.cash == 3, "broke: no shot, no charge ($%d)" % Wallet.cash)
	_check(Wallet.entries.size() == entries, "broke: no ledger entry")
	_check(_dummy.get("hp") == 6, "broke: the dummy is unharmed")
	Wallet.cash = 150


func _receipt() -> void:
	_ledger.toggle()
	await _wait(0.05)
	_check(_ledger.visible, "ledger opens")
	var rows: VBoxContainer = _ledger.get("_rows")
	var text := ""
	for c in rows.get_children():
		if c is Label:
			text += (c as Label).text + "\n"
	for c in _ledger.find_children("*", "Label", true, false):
		text += (c as Label).text + "\n"
	_check(text.contains("THE BULLET LEDGER"), "receipt has a title")
	_check(text.contains("CINDER CITY AMMUNITION"), "receipt header")
	_check(text.contains(".38 round"), "receipt lists the bullets bought")
	_check(text.contains("BALANCE"), "receipt shows the balance")
	_check(text.contains("NO REFUNDS"), "receipt footer")
	_check(text.contains("+$12") or text.contains("+$ 12") or "+$12" in text, "receipt lists earnings")
	_ledger.toggle()
	_check(not _ledger.visible, "ledger closes")
	# entries cap
	for i in 250:
		Wallet.earn(1, "spam %d" % i)
	_check(Wallet.entries.size() == 200, "ledger caps at 200 entries (%d)" % Wallet.entries.size())


func _finish() -> void:
	_check(_hud.get("_pop") != null and _hud.get("_ticker") != null,
			"cash pop and receipt ticker exist")
	if _fails == 0:
		print("SMOKE PASS")
		get_tree().quit(0)
	else:
		print("SMOKE FAIL (%d problems)" % _fails)
		get_tree().quit(1)


func _find_label(n: Node, has: String) -> Label:
	for c in n.find_children("*", "Label", true, false):
		if has in (c as Label).text:
			return c
	return null


func _find_button(n: Node, has: String) -> Button:
	for c in n.find_children("*", "Button", true, false):
		if has in (c as Button).text:
			return c
	return null
