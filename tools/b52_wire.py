#!/usr/bin/env python3
"""B5.2 - wire the phone into everything that already ships.

city.gd        district_now() getter (the map's YOU-ARE-HERE)
haptics.gd     the "buzz" pattern: slow low pulse (bible 4C)
tuning.gd      phone_ring_seconds / phone_demand_cost / phone_ambient_s
touch_buttons  PhoneBtn on both schemes (top-right, under the cash)
               -> Phone.toggle_open()
save_game.gd   v5: phone + trust ride the save
debug_panel    RING NOW + CLEAR PHONE jumps
project.godot  Trust + Phone autoloads
"""
P = "/home/z/my-project/bare-hands/"


def patch(path, pairs):
    s = open(P + path).read()
    for old, new in pairs:
        assert s.count(old) == 1, "%s: not unique/found: %r" % (path, old[:70])
        s = s.replace(old, new)
    open(P + path, "w").write(s)
    print("patched", path)


patch("scripts/city.gd", [(
    """func district_at(pos: Vector3) -> String:""",
    """## Where the hero stands right now (the phone map's YOU-ARE-HERE).
func district_now() -> String:
	return _district_now


func district_at(pos: Vector3) -> String:"""
)])

patch("scripts/haptics.gd", [(
    '''	"down": [70],           # the hero is knocked down''',
    '''	"down": [70],           # the hero is knocked down
	"buzz": [150, 110, 150], # a call: slow low pulse-pause-pulse (4C)'''
)])

patch("scripts/tuning.gd", [(
    '''	"autotarget_mult": 1.0,  # soft auto-target strength: reach multiplier''',
    '''	"autotarget_mult": 1.0,  # soft auto-target strength: reach multiplier
	"phone_ring_seconds": 8.0,  # the answer window while enemies swing
	"phone_demand_cost": 40.0,  # a demand call's ask
	"phone_ambient_s": 180.0,  # calm-time minutes between ambient rings'''
)])

# touch_buttons: the button in both schemes + the routing
patch("scripts/touch_buttons.gd", [
    (
        '''	["SuperBtn", "SUPER", "", Color(1.0, 0.62, 0.2, 1.0), 152.0, 428.0, 116.0],''',
        '''	["SuperBtn", "SUPER", "", Color(1.0, 0.62, 0.2, 1.0), 152.0, 428.0, 116.0],
	["PhoneBtn", "PHONE", "", Color(0.45, 0.52, 0.62, 1.0), 24.0, 600.0, 64.0],'''
    ),
    (
        '''	["SuperBtn", "SUPER", "", Color(1.0, 0.62, 0.2, 1.0), 106.0, 330.0, 96.0],''',
        '''	["SuperBtn", "SUPER", "", Color(1.0, 0.62, 0.2, 1.0), 106.0, 330.0, 96.0],
	["PhoneBtn", "PHONE", "", Color(0.45, 0.52, 0.62, 1.0), 24.0, 600.0, 64.0],'''
    ),
    (
        '''		"SuperBtn":
			InputBus.queue_super()''',
        '''		"SuperBtn":
			InputBus.queue_super()
		"PhoneBtn":
			Phone.toggle_open()  # the ring banner answers itself'''
    ),
])

patch("scripts/save_game.gd", [
    (
        """	var d := {
		"version": 4,""",
        """	var d := {
		"version": 5,"""
    ),
    (
        """		"styles": Styles.to_dict(),
	}""",
        """		"styles": Styles.to_dict(),
		"phone": Phone.to_dict(),
		"trust": Trust.to_dict(),
	}"""
    ),
])

patch("scripts/debug_panel.gd", [(
    '''	var style := Button.new()
	style.text = "STYLE WHEEL"
	style.focus_mode = Control.FOCUS_NONE
	style.pressed.connect(_open_style_wheel)
	jumps.add_child(style)''',
    '''	var style := Button.new()
	style.text = "STYLE WHEEL"
	style.focus_mode = Control.FOCUS_NONE
	style.pressed.connect(_open_style_wheel)
	jumps.add_child(style)
	# Batch 5: jump straight into the phone pressure loop
	var ring := Button.new()
	ring.text = "RING NOW"
	ring.focus_mode = Control.FOCUS_NONE
	ring.pressed.connect(_ring_now)
	jumps.add_child(ring)
	var clr := Button.new()
	clr.text = "CLEAR PHONE"
	clr.focus_mode = Control.FOCUS_NONE
	clr.pressed.connect(func(): Phone.reset_for_test())
	jumps.add_child(clr)


## Batch 5: a random friend calls, right now, whatever the hero is doing.
func _ring_now() -> void:
	var options := Trust.callers()
	if options.is_empty():
		return
	Phone.ring(options[randi() % options.size()],
			"demand" if randi() % 2 == 0 else "invitation")'''
)])

patch("project.godot", [(
    '''Dialogue="*res://scripts/dialogue.gd"''',
    '''Dialogue="*res://scripts/dialogue.gd"
Trust="*res://scripts/trust.gd"
Phone="*res://scripts/phone.gd"'''
)])

print("B5.2 wiring complete")
