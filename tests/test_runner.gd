extends SceneTree
## Minimal headless test harness.  Every test_*.gd suite extends TestCase, which
## extends this class, so `godot --headless --script res://tests/test_x.gd`
## runs one suite and exits with the number of failures.
##
## Usage inside a suite:
##   func _tests() -> void:
##       check(condition, "message")
##       check_eq(actual, expected, "message")

var failures := 0
var checks := 0
var suite_name := "suite"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var started := Time.get_ticks_msec()
	_tests()
	var elapsed := Time.get_ticks_msec() - started
	print("RESULT %s: %d checks, %d failures (%d ms)" % [suite_name, checks, failures, elapsed])
	quit(failures)


## Override in each suite.
func _tests() -> void:
	pass


func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS  " + message)
	else:
		failures += 1
		printerr("FAIL  " + message)


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	check(actual == expected, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func check_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	check(absf(actual - expected) <= tolerance, "%s (expected %f ± %f, got %f)" % [message, expected, tolerance, actual])


func check_true(condition: bool, message: String) -> void:
	check(condition, message)


func check_false(condition: bool, message: String) -> void:
	check(not condition, message)
