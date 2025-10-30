extends Control
class_name WorldMarketChart

enum ChartMode { LINE, CANDLE }

const BACKGROUND_COLOR = Color(0.08, 0.09, 0.12, 1.0)
const GRID_COLOR = Color(1.0, 1.0, 1.0, 0.06)
const LINE_COLOR = Color(0.25, 0.60, 0.95, 1.0)
const POSITIVE_COLOR = Color(0.22, 0.72, 0.32, 1.0)
const NEGATIVE_COLOR = Color(0.82, 0.30, 0.30, 1.0)
const TEXT_COLOR = Color(0.85, 0.88, 0.90, 0.9)
const EMPTY_TEXT = "Noch keine Preisverlaeufe."
const MAX_GUIDE_LINES = 4

var mode = ChartMode.LINE

var _history = []
var _candles = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_history(history: Array) -> void:
	_history.clear()
	for point_variant in history:
		if point_variant is Dictionary:
			var point: Dictionary = point_variant
			_history.append(point.duplicate(true))
	if _history.size() > 1:
		_history.sort_custom(Callable(self, "_sort_points_by_time"))
	_rebuild_candles()
	queue_redraw()

func set_mode(new_mode: int) -> void:
	if mode == new_mode:
		return
	mode = new_mode
	if mode == ChartMode.CANDLE:
		_rebuild_candles()
	queue_redraw()

func _sort_points_by_time(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("timestamp", 0)) < int(b.get("timestamp", 0))

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if mode == ChartMode.CANDLE:
			_rebuild_candles()
		queue_redraw()

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	draw_rect(rect, BACKGROUND_COLOR, true)
	var left_margin = 48.0
	var right_margin = 12.0
	var top_margin = 12.0
	var bottom_margin = 28.0
	var chart_size = Vector2(
		max(size.x - left_margin - right_margin, 1.0),
		max(size.y - top_margin - bottom_margin, 1.0)
	)
	var chart_rect = Rect2(Vector2(left_margin, top_margin), chart_size)
	var font = get_theme_default_font()
	var font_size = get_theme_default_font_size()
	if _history.is_empty():
		if font != null:
			var text_size = font.get_string_size(EMPTY_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var pos = Vector2(size.x * 0.5 - text_size.x * 0.5, size.y * 0.5 + text_size.y * 0.5)
			draw_string(font, pos, EMPTY_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TEXT_COLOR)
		return
	_draw_grid(chart_rect, font, font_size)
	if mode == ChartMode.CANDLE and _candles.size() > 0:
		_draw_candles(chart_rect)
	else:
		_draw_line(chart_rect)

func _draw_grid(chart_rect: Rect2, font: Font, font_size: int) -> void:
	var price_range = _get_price_range()
	var min_price = price_range.x
	var max_price = price_range.y
	for i in range(MAX_GUIDE_LINES + 1):
		var t = float(i) / float(MAX_GUIDE_LINES)
		var y = chart_rect.position.y + chart_rect.size.y - chart_rect.size.y * t
		var from = Vector2(chart_rect.position.x, y)
		var to = Vector2(chart_rect.position.x + chart_rect.size.x, y)
		draw_line(from, to, GRID_COLOR, 1.0)
		var price = lerp(min_price, max_price, t)
		var label = "%.2f" % price
		if font != null:
			var text_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var text_pos = Vector2(chart_rect.position.x - 8.0 - text_size.x, y + text_size.y * 0.25)
			draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TEXT_COLOR)

func _draw_line(chart_rect: Rect2) -> void:
	if _history.is_empty():
		return
	var min_timestamp = int(_history.front().get("timestamp", 0))
	var max_timestamp = int(_history.back().get("timestamp", min_timestamp))
	if max_timestamp <= min_timestamp:
		max_timestamp = min_timestamp + 1
	var price_range = _get_price_range()
	var min_price = price_range.x
	var max_price = price_range.y
	var price_delta = max_price - min_price
	if price_delta <= 0.0:
		price_delta = 1.0
	var time_delta = float(max_timestamp - min_timestamp)
	var points = PackedVector2Array()
	for point in _history:
		var timestamp = float(point.get("timestamp", min_timestamp))
		var price = float(point.get("price", min_price))
		var t = clamp((timestamp - float(min_timestamp)) / time_delta, 0.0, 1.0)
		var value = clamp((price - min_price) / price_delta, 0.0, 1.0)
		var x = chart_rect.position.x + chart_rect.size.x * t
		var y = chart_rect.position.y + chart_rect.size.y - chart_rect.size.y * value
		points.append(Vector2(x, y))
	if points.size() >= 2:
		draw_polyline(points, LINE_COLOR, 2.0, true)
	elif points.size() == 1:
		draw_circle(points[0], 3.0, LINE_COLOR)

func _draw_candles(chart_rect: Rect2) -> void:
	if _candles.is_empty():
		return
	var price_range = _get_price_range()
	var min_price = price_range.x
	var max_price = price_range.y
	var price_delta = max_price - min_price
	if price_delta <= 0.0:
		price_delta = 1.0
	var candle_count = _candles.size()
	var segment_width = chart_rect.size.x / float(max(candle_count, 1))
	var candle_width = clamp(segment_width * 0.6, 3.0, 24.0)
	for index in range(_candles.size()):
		var candle: Dictionary = _candles[index]
		var center_x = chart_rect.position.x + segment_width * float(index) + segment_width * 0.5
		var open_price = float(candle.get("open", min_price))
		var close_price = float(candle.get("close", open_price))
		var high_price = float(candle.get("high", max(open_price, close_price)))
		var low_price = float(candle.get("low", min(open_price, close_price)))
		var open_value = clamp((open_price - min_price) / price_delta, 0.0, 1.0)
		var close_value = clamp((close_price - min_price) / price_delta, 0.0, 1.0)
		var high_value = clamp((high_price - min_price) / price_delta, 0.0, 1.0)
		var low_value = clamp((low_price - min_price) / price_delta, 0.0, 1.0)
		var open_y = chart_rect.position.y + chart_rect.size.y - chart_rect.size.y * open_value
		var close_y = chart_rect.position.y + chart_rect.size.y - chart_rect.size.y * close_value
		var high_y = chart_rect.position.y + chart_rect.size.y - chart_rect.size.y * high_value
		var low_y = chart_rect.position.y + chart_rect.size.y - chart_rect.size.y * low_value
		var color = POSITIVE_COLOR if close_price >= open_price else NEGATIVE_COLOR
		draw_line(Vector2(center_x, high_y), Vector2(center_x, low_y), color, 2.0, true)
		var body_top = min(open_y, close_y)
		var body_height = max(abs(close_y - open_y), 2.0)
		var body_rect = Rect2(Vector2(center_x - candle_width * 0.5, body_top), Vector2(candle_width, body_height))
		draw_rect(body_rect, color, true)
		draw_rect(body_rect, color.darkened(0.4), false, 1.2)

func _get_price_range() -> Vector2:
	var min_price = INF
	var max_price = -INF
	if mode == ChartMode.CANDLE and _candles.size() > 0:
		for candle_variant in _candles:
			var candle: Dictionary = candle_variant
			min_price = min(min_price, float(candle.get("low", min_price)))
			max_price = max(max_price, float(candle.get("high", max_price)))
	else:
		for point in _history:
			var price = float(point.get("price", 0.0))
			min_price = min(min_price, price)
			max_price = max(max_price, price)
	if min_price == INF or max_price == -INF:
		min_price = 0.0
		max_price = 1.0
	if is_equal_approx(max_price, min_price):
		var epsilon = max(1.0, abs(min_price) * 0.05 + 0.01)
		max_price = min_price + epsilon
	return Vector2(min_price, max_price)

func _rebuild_candles() -> void:
	_candles.clear()
	if _history.is_empty():
		return
	var candle_capacity = int(max(size.x - 60.0, 60.0) / 12.0)
	candle_capacity = clamp(candle_capacity, 1, _history.size())
	var window_size = int(ceil(_history.size() / float(candle_capacity)))
	window_size = max(window_size, 1)
	var index = 0
	while index < _history.size():
		var end_index = min(index + window_size, _history.size())
		var chunk = _history.slice(index, end_index)
		if chunk.is_empty():
			break
		var open_point: Dictionary = chunk.front()
		var close_point: Dictionary = chunk.back()
		var open_price = float(open_point.get("price", 0.0))
		var close_price = float(close_point.get("price", open_price))
		var high_price = open_price
		var low_price = open_price
		for point in chunk:
			var price = float(point.get("price", open_price))
			high_price = max(high_price, price)
			low_price = min(low_price, price)
		var candle = {
			"open": open_price,
			"close": close_price,
			"high": high_price,
			"low": low_price,
			"timestamp": close_point.get("timestamp", open_point.get("timestamp", 0))
		}
		_candles.append(candle)
		index = end_index
