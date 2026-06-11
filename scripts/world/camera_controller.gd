class_name CameraController
extends Camera2D
## CameraController (Weltobjekt)
## =============================
## Steuert die Kamera des City-Builders:
##   - Bewegen: WASD / Pfeiltasten ODER mittlere Maustaste gedrückt halten
##   - Zoomen:  Mausrad
##
## Die Kamera ist bewusst simpel gehalten und hat KEINE Spiellogik.

## Bewegungsgeschwindigkeit in Pixeln pro Sekunde (bei Zoom 1.0).
const PAN_SPEED := 600.0
const ZOOM_MIN := 0.5
const ZOOM_MAX := 4.0          ## Tief hineinzoomen = alle Sprite-Details sehen.
const ZOOM_STEP := 0.15
const ZOOM_START := 1.6        ## Start nah dran, damit die Stadt groß wirkt.

var _middle_mouse_dragging := false


func _ready() -> void:
	## Sanfteres Gefühl beim Bewegen.
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0
	zoom = Vector2(ZOOM_START, ZOOM_START)


func _process(delta: float) -> void:
	## Tastatur-Bewegung. Wir fragen die Tasten direkt ab - das funktioniert
	## ohne eigene Input-Map-Einträge und damit ohne Konfigurationsfehler.
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0

	if direction != Vector2.ZERO:
		## Geteilt durch zoom.x: Bei starkem Heranzoomen bewegt sich die
		## Kamera langsamer - fühlt sich natürlicher an.
		position += direction.normalized() * PAN_SPEED * delta / zoom.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				_middle_mouse_dragging = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_apply_zoom(ZOOM_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_apply_zoom(-ZOOM_STEP)

	elif event is InputEventMouseMotion and _middle_mouse_dragging:
		## relative = Mausbewegung seit dem letzten Frame.
		## Geteilt durch Zoom, damit das Ziehen bei jedem Zoom gleich wirkt.
		position -= event.relative / zoom.x


func _apply_zoom(step: float) -> void:
	var new_zoom: float = clampf(zoom.x + step, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(new_zoom, new_zoom)
