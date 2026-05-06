@tool
class_name InheritanceView
extends GraphEdit

# -- Settings (with setter for live refresh) ---------------------------------
@export var settings: InheritanceViewSettings:
	set(v):
		if settings and settings.changed.is_connected(_on_settings_changed):
			settings.changed.disconnect(_on_settings_changed)
		settings = v
		if settings:
			settings.changed.connect(_on_settings_changed)

# -- Settings accessors ------------------------------------------------------
func _call_edge_color() -> Color: return settings.call_edge_color
func _call_edge_out_color() -> Color: return settings.call_edge_out_color
func _override_color() -> Color: return settings.font_override
func _missing_super_color() -> Color: return settings.font_missing_super
func _variable_color() -> Color: return settings.font_variable
func _todo_header_color() -> Color: return settings.font_todo_header
func _todo_item_color() -> Color: return settings.font_todo_item
func _pink_color() -> Color: return settings.highlight_pink_color
func _blue_color() -> Color: return settings.call_edge_color
func _green_color() -> Color: return settings.call_edge_out_color
func _builtin_modulate() -> Color: return settings.builtin_modulate
func _node_h_sep() -> int: return settings.h_sep
func _node_v_sep() -> int: return settings.v_sep

# -- State -------------------------------------------------------------------
var _graph_nodes : Dictionary
var _class_data : Dictionary
var _has_parent : Dictionary
var _has_child : Dictionary
var _green_edges : Dictionary
var _blue_bordered : Dictionary
var _green_bordered : Dictionary
var _dropdown_open_nodes : Dictionary

@export var _toolbar_row : VBoxContainer
@export var spacer : Control
@export var toolbar_margin : MarginContainer
@export var _toolbar : HBoxContainer
@export var reorganise_button : Button
@export var expand_button : Button
@export var _search_bar : LineEdit

var _arrow_overlay : ArrowOverlay
var _selected_node : String = ""
var _editor_sync : bool = true
var _straight_lines : bool = true
var _all_expanded : bool = false
var _first_open : bool = true
var _last_script : String = ""

# -- Ready -------------------------------------------------------------------
func _ready() -> void:
	call_deferred("_apply_line_curve")
	call_deferred("_setup_arrow_overlay")
	visibility_changed.connect(_on_visibility_changed)
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().filesystem_changed.connect(_on_filesystem_changed)

func _apply_line_curve() -> void:
	connection_lines_curvature = 0.0 if _straight_lines else 0.5

func _setup_arrow_overlay() -> void:
	if _arrow_overlay: _arrow_overlay.queue_free()
	_arrow_overlay = ArrowOverlay.new()
	_arrow_overlay.graph = self
	add_child(_arrow_overlay)

# -- Settings live refresh ---------------------------------------------------
func _on_settings_changed() -> void:
	_apply_line_curve()
	_refresh_visuals()

func _refresh_visuals() -> void:
	if _graph_nodes.is_empty():
		return

	for class_name_ in _graph_nodes:
		var graph_node : GraphNode = _graph_nodes[class_name_]
		var data : Dictionary = _class_data.get(class_name_)
		var is_builtin : bool = data.get("builtin")

		if is_builtin:
			graph_node.add_theme_stylebox_override("panel", settings.node_panel_builtin.duplicate())
			graph_node.add_theme_stylebox_override("titlebar", settings.node_titlebar_builtin.duplicate())
			
			graph_node.modulate = _builtin_modulate()
		else:
			if _dropdown_open_nodes.has(class_name_):
				_apply_border(graph_node, Color.WHITE)
			elif _blue_bordered.has(class_name_):
				_apply_blue_border(graph_node)
			elif _green_bordered.has(class_name_):
				_apply_green_border(graph_node)
			else:
				graph_node.remove_theme_stylebox_override("panel")
				graph_node.remove_theme_stylebox_override("titlebar")
			
			var dimmed := graph_node.modulate.a < 0.5
			graph_node.modulate.a = 0.15 if dimmed else 1.0

		_refresh_node_font_colors(graph_node, class_name_, data)
		
		if not _blue_bordered.has(class_name_) and not _green_bordered.has(class_name_):
			_graph_nodes[class_name_].set_slot(0,
				_has_parent.has(class_name_), 0, Color.WHITE,
				_has_child.has(class_name_), 0, Color.WHITE)

	_refresh_call_slots()

	if _selected_node != "" and _graph_nodes.has(_selected_node):
		_on_node_selected(_graph_nodes[_selected_node])

func _refresh_node_font_colors(graph_node: GraphNode, class_name_: String, data: Dictionary) -> void:
	var overrides : Dictionary = _get_overrides(class_name_)
	var func_meta : Dictionary = {}
	for f in data.get("functions", []):
		var is_ov : bool = overrides.has(f["name"])
		var no_sup : bool = is_ov and not f.get("calls_super", false)
		func_meta[f["name"]] = {"override": is_ov, "missing_super": no_sup}

	for child in graph_node.get_children():
		if not child is Button or not child.get_meta("section_item", false):
			continue
		var raw : String = child.text.strip_edges()
		if ": " in raw and "(" not in raw:
			child.add_theme_color_override("font_color", _variable_color())
			child.add_theme_color_override("font_hover_color", settings.font_hover)
		elif "(" in raw:
			var fname : String = raw.lstrip(" ").split("(")[0]
			var meta : Dictionary = func_meta.get(fname, {})
			var color : Color
			
			if meta.get("missing_super"):
				color = _missing_super_color()
			elif meta.get("override", false):
				color = _override_color()
			else:
				color = _variable_color()
				
			child.add_theme_color_override("font_color", color)
			child.add_theme_color_override("font_hover_color", settings.font_hover)
		elif raw.begins_with("L") and ":" in raw:
			child.add_theme_color_override("font_color", _todo_item_color())
			child.add_theme_color_override("font_hover_color", settings.font_hover)

	for child in graph_node.get_children():
		if not child is Button or child.get_meta("section_item", false):
			continue
		var t : String = child.text
		if "TODOs" in t:
			child.add_theme_color_override("font_color", _todo_header_color())
		elif "Variables" in t or "Functions" in t or "Overrides" in t:
			child.remove_theme_color_override("font_color")
	
func _on_expand_button_pressed():
	_all_expanded = !_all_expanded
	expand_button.text = "Collapse All" if _all_expanded else "Expand All"
	_set_all_dropdowns(_all_expanded)
	
func _on_straight_lines_checked(on: bool):
	_straight_lines = on
	_apply_line_curve()

func _on_sync_selection_changed(on: bool): 
	_editor_sync = on

# -- Visibility / FS events --------------------------------------------------
func _on_visibility_changed() -> void:
	if not is_visible_in_tree(): return
	if _first_open:
		_first_open = false
		_reorganise()

func _on_filesystem_changed() -> void:
	if is_visible_in_tree(): _reorganise()

# -- Per-frame ---------------------------------------------------------------
func _process(_delta: float) -> void:
	if not _editor_sync or not Engine.is_editor_hint(): return
	var current_script : Script = EditorInterface.get_script_editor().get_current_script()
	if not current_script: return
	if current_script.resource_path == _last_script: return
	_last_script = current_script.resource_path
	for class_name_ in _class_data:
		if _class_data[class_name_].get("path", "") == _last_script:
			_select_node(class_name_)
			break

func _select_node(class_name_: String) -> void:
	if not _graph_nodes.has(class_name_): return
	for node in _graph_nodes.values(): node.selected = false
	var target_node : GraphNode = _graph_nodes[class_name_]
	target_node.selected = true
	scroll_offset = (target_node.position_offset + target_node.size / 2.0) * zoom - size / 2.0

# -- Reorganise --------------------------------------------------------------
func _reorganise() -> void:
	_clear_graph()
	_class_data = CodebaseParser.scan_project()
	_create_class_nodes()
	if _toolbar_row: _toolbar_row.move_to_front()
	#await get_tree().process_frame
	_draw_inheritance_connections()
	_apply_layout()
	await get_tree().process_frame
	_zoom_to_fit()
	if _all_expanded: _set_all_dropdowns(true)
	if _search_bar and _search_bar.text != "": _apply_search(_search_bar.text)
	if not node_selected.is_connected(_on_node_selected):
		node_selected.connect(_on_node_selected)
	if not node_deselected.is_connected(_on_node_deselected):
		node_deselected.connect(_on_node_deselected)

func _clear_graph() -> void:
	clear_connections()
	for child in get_children():
		if child is GraphElement: child.free()
	_graph_nodes = {}; _class_data = {}
	_has_parent = {}; _has_child = {}
	_green_edges = {}; _blue_bordered = {}; _green_bordered = {}
	_dropdown_open_nodes = {}

# -- Expand / collapse -------------------------------------------------------
func _set_all_dropdowns(expanded: bool) -> void:
	for graph_node in _graph_nodes.values():
		for dropdown in graph_node.get_meta("dropdowns", []):
			for item in dropdown["items"]: item.visible = expanded
			dropdown["toggle"].text = "%s %s (%d)" % ["▼" if expanded else "▶", dropdown["label"], dropdown["count"]]
		if not expanded: graph_node.reset_size()

	if expanded:
		for class_name_ in _graph_nodes:
			var gn: GraphNode = _graph_nodes[class_name_]
			var has_func_dd := false
			for dd in gn.get_meta("dropdowns", []):
				if dd["label"] != "Variables" and dd["label"] != "TODOs" and dd["items"].size() > 0:
					has_func_dd = true; break
			if has_func_dd:
				_dropdown_open_nodes[class_name_] = true
				_apply_border(gn, Color.WHITE)
	else:
		_dropdown_open_nodes.clear()
		for class_name_ in _graph_nodes:
			_graph_nodes[class_name_].remove_theme_stylebox_override("panel")
			_graph_nodes[class_name_].remove_theme_stylebox_override("titlebar")

	_rebuild_call_edges()
	_apply_layout()
	_zoom_to_fit()

# -- Search ------------------------------------------------------------------
func _apply_search(query: String) -> void:
	for class_name_ in _graph_nodes:
		var base_alpha := _builtin_modulate().a if _class_data.get(class_name_, {}).get("builtin", false) else 1.0
		_graph_nodes[class_name_].modulate.a = base_alpha if _class_matches(class_name_, query) else base_alpha * 0.15

func _class_matches(class_name_: String, query: String) -> bool:
	if query == "": return true
	var query_lower := query.to_lower()
	if class_name_.to_lower().contains(query_lower): return true
	for variable in _class_data.get(class_name_, {}).get("variables", []):
		if (variable["name"] as String).to_lower().contains(query_lower): return true
	for function_ in _class_data.get(class_name_, {}).get("functions", []):
		if (function_["name"] as String).to_lower().contains(query_lower): return true
	return false

# -- Zoom fit ----------------------------------------------------------------
func _zoom_to_fit() -> void:
	if _graph_nodes.is_empty(): return
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for node in _graph_nodes.values():
		min_pos = min_pos.min(node.position_offset)
		max_pos = max_pos.max(node.position_offset + node.size)
	var content_size := max_pos - min_pos
	if content_size.x <= 0 or content_size.y <= 0: return
	const PADDING := 80.0
	var toolbar_height := get_menu_hbox().size.y
	var available_size := size - Vector2(PADDING * 2, PADDING * 2 + toolbar_height)
	zoom = clamp(min(available_size.x / content_size.x, available_size.y / content_size.y), zoom_min, 1.0)
	scroll_offset = ((min_pos + max_pos) / 2.0) * zoom - size / 2.0

# -- Graph build -------------------------------------------------------------
func _create_class_nodes() -> void:
	for class_name_ in _class_data:
		var data : Dictionary = _class_data[class_name_]
		var graph_node := _make_node(class_name_, data["path"],
			data.get("variables", []), data.get("functions", []),
			_get_overrides(class_name_), data.get("builtin", false))
		add_child(graph_node)
		_graph_nodes[class_name_] = graph_node
		var is_builtin : bool = data.get("builtin", false)
		if is_builtin:
			graph_node.add_theme_stylebox_override("panel", settings.node_panel_builtin.duplicate())
			graph_node.add_theme_stylebox_override("titlebar", settings.node_titlebar_builtin.duplicate())

func _draw_inheritance_connections() -> void:
	clear_connections(); _has_parent.clear(); _has_child.clear()
	for class_name_ in _class_data:
		var parent_name : String = _class_data[class_name_]["extends"]
		if _graph_nodes.has(parent_name):
			_has_parent[class_name_] = true
			_has_child[parent_name] = true
	for class_name_ in _graph_nodes:
		_graph_nodes[class_name_].set_slot(0,
			_has_parent.has(class_name_), 0, Color.WHITE,
			_has_child.has(class_name_), 0, Color.WHITE)
	for class_name_ in _class_data:
		var parent_name : String = _class_data[class_name_]["extends"]
		if _graph_nodes.has(parent_name):
			connect_node(parent_name, 0, class_name_, 0)

# -- Call edges --------------------------------------------------------------
func _edge_key(from_class: String, to_class: String) -> String:
	return from_class + "::" + to_class

func _slot_to_in_port(graph_node: GraphNode, slot_idx: int) -> int:
	if slot_idx < 0 or slot_idx >= graph_node.get_child_count(): return -1
	
	var port := 0
	for i in range(slot_idx):
		if graph_node.is_slot_enabled_left(i):
			port += 1

	return port

func _slot_to_out_port(graph_node: GraphNode, slot_idx: int) -> int:
	if slot_idx < 0 or slot_idx >= graph_node.get_child_count(): return -1
	if not graph_node.is_slot_enabled_right(slot_idx): return -1
	var target_child := graph_node.get_child(slot_idx) as Control
	
	# We keep the visibility check here only to refuse connecting to a hidden target
	if not target_child or not target_child.visible: return -1
	
	var port := 0
	for i in range(slot_idx):
		# FIX: Ensure the child is visible before counting it as a port
		if graph_node.is_slot_enabled_right(i) and graph_node.get_child(i).visible:
			port += 1
			
	return port

func _rebuild_call_edges() -> void:
	# Remove all non-inheritance connections
	for conn in get_connection_list().duplicate():
		var is_inheritance = (conn["from_port"] == 0 and conn["to_port"] == 0
			and _has_child.has(conn["from_node"])
			and _class_data.get(conn["to_node"], {}).get("extends", "") == conn["from_node"])
		if not is_inheritance:
			disconnect_node(conn["from_node"], conn["from_port"], conn["to_node"], conn["to_port"])

	_green_edges.clear()
	_blue_bordered.clear()
	_green_bordered.clear()

	# Reset extra slots (1+) and borders on all nodes
	for class_name_ in _graph_nodes:
		var gn: GraphNode = _graph_nodes[class_name_]
		for i in range(1, gn.get_child_count()):
			gn.set_slot(i, false, 0, Color.WHITE, false, 0, Color.WHITE)
		if _dropdown_open_nodes.has(class_name_):
			_apply_border(gn, Color.WHITE)
		else:
			gn.remove_theme_stylebox_override("panel")
			gn.remove_theme_stylebox_override("titlebar")

	if _dropdown_open_nodes.is_empty():
		_refresh_call_slots()
		return

	# Gather visible function set for each open node
	var open_func_sets: Dictionary = {}
	for target_class in _dropdown_open_nodes:
		if not _graph_nodes.has(target_class): continue
		var gn: GraphNode = _graph_nodes[target_class]
		var combined: Array = []
		for dd in gn.get_meta("dropdowns", []):
			if dd["label"] == "Variables" or dd["label"] == "TODOs": continue
			if dd["items"].size() > 0 and dd["items"][0].visible:
				combined += dd.get("funcs", [])
		open_func_sets[target_class] = combined

	# Track which nodes already have a blue right-port assigned (and at which slot)
	var node_blue_out_slot: Dictionary = {}

	# Phase 1: Incoming blue edges — callers → open target function slots
	for target_class in open_func_sets:
		var func_arr: Array = open_func_sets[target_class]
		if func_arr.is_empty(): continue
		var target_node: GraphNode = _graph_nodes[target_class]
		var target_slot_map: Dictionary = target_node.get_meta("func_slot_map", {})

		var method_names: Dictionary = {}
		for f in func_arr: method_names[f["name"]] = true

		for caller_class in _class_data:
			if caller_class == target_class or not _graph_nodes.has(caller_class): continue
			var called_methods: Dictionary = {}
			for call in _class_data[caller_class].get("outbound_calls", []):
				if call["target"] == target_class and method_names.has(call["method"]):
					called_methods[call["method"]] = true
			if called_methods.is_empty(): continue

			# If the caller also has an open dropdown, Phase 2 will draw the connection
			# from its per-function green slot (gradient), so skip the blue port here.
			if open_func_sets.has(caller_class): continue

			var caller_node: GraphNode = _graph_nodes[caller_class]
			# Assign slot 1 for blue outgoing on this caller (shared across all targets it calls)
			var blue_slot: int = node_blue_out_slot.get(caller_class, 1)
			node_blue_out_slot[caller_class] = blue_slot
			caller_node.set_slot(blue_slot,
				caller_node.is_slot_enabled_left(blue_slot), 2, _call_edge_color(),
				true, 2, _call_edge_color())
			var caller_out_port := _slot_to_out_port(caller_node, blue_slot)

			var our_min_slot := INF
			for f in func_arr:
				var s: int = target_slot_map.get(f["name"], -1)
				if s >= 0 and s < our_min_slot: our_min_slot = s

			var slot_offset := 0
			for dd in target_node.get_meta("dropdowns", []):
				if dd["items"].is_empty() or dd["items"][0].visible: continue
				var dd_first_idx := target_node.get_children().find(dd["items"][0])
				if dd_first_idx >= 0 and dd_first_idx < our_min_slot:
					slot_offset += dd["items"].size()

			for f in func_arr:
				if not called_methods.has(f["name"]): continue
				var tslot: int = target_slot_map.get(f["name"], -1) - slot_offset
				if tslot < 0: continue
				target_node.set_slot(tslot, true, 2, _call_edge_color(), false, 0, Color.WHITE)
				var to_port := _slot_to_in_port(target_node, tslot)
				if to_port < 0 or caller_out_port < 0: continue
				var already := false
				for conn in get_connection_list():
					if conn["from_node"] == caller_class and conn["to_node"] == target_class \
							and conn["to_port"] == to_port and conn["from_port"] == caller_out_port:
						already = true; break
				if not already:
					connect_node(caller_class, caller_out_port, target_class, to_port)

			if not _dropdown_open_nodes.has(caller_class):
				_apply_blue_border(caller_node)

	# Phase 2: Outgoing green edges — open nodes → callees
	# Each right-side green slot is placed at the height of the function making the call,
	# mirroring how Phase 1 places blue input slots at the height of the called function.
	for target_class in open_func_sets:
		var target_node: GraphNode = _graph_nodes[target_class]
		var target_slot_map: Dictionary = target_node.get_meta("func_slot_map", {})

		# Compute our_slot_min once across all visible outbound calls for this node,
		# mirroring how Phase 1 computes our_min_slot across all target functions before
		# the per-function loop. This gives a single consistent slot_offset for all calls.
		var our_slot_min := INF
		for c in _class_data[target_class].get("outbound_calls", []):
			if c["target"] == target_class or not _graph_nodes.has(c["target"]): continue
			var s: int = target_slot_map.get(c.get("caller", ""), -1)
			if s < 0: continue
			var _c := target_node.get_child(s) as Control
			if not _c or not _c.visible: continue
			if s < our_slot_min: our_slot_min = s

		var slot_offset := 0
		if our_slot_min < INF:
			for dd in target_node.get_meta("dropdowns", []):
				if dd["items"].is_empty() or dd["items"][0].visible: continue
				var dd_first_idx := target_node.get_children().find(dd["items"][0])
				if dd_first_idx >= 0 and dd_first_idx < our_slot_min:
					slot_offset += dd["items"].size()

		for call in _class_data[target_class].get("outbound_calls", []):
			var callee_class: String = call["target"]
			if callee_class == target_class or not _graph_nodes.has(callee_class): continue
			var callee_node: GraphNode = _graph_nodes[callee_class]
			var callee_slot_map: Dictionary = callee_node.get_meta("func_slot_map", {})

			# Find the slot of the function in the open node that makes this call
			var raw_caller_slot: int = target_slot_map.get(call.get("caller", ""), -1)
			if raw_caller_slot < 0: continue
			var caller_child := target_node.get_child(raw_caller_slot) as Control
			if not caller_child or not caller_child.visible: continue

			# Use green_slot (adjusted by the shared offset) for set_slot and port counting,
			# exactly mirroring how Phase 1 uses tslot with _slot_to_in_port. Port is counted
			# without a visibility check so it stays consistent with hidden-child slots.
			var green_slot := raw_caller_slot - slot_offset
			if green_slot < 0: continue

			target_node.set_slot(green_slot,
				target_node.is_slot_enabled_left(green_slot), 2, _call_edge_color(),
				true, 3, _call_edge_out_color())
			target_node.update_minimum_size()
			var target_out_port := 0
			for i in range(green_slot):
				if target_node.is_slot_enabled_right(i):
					target_out_port += 1

			var cslot: int = -1
			if _dropdown_open_nodes.has(callee_class) and callee_slot_map.has(call["method"]):
				var candidate: int = callee_slot_map[call["method"]]
				if callee_node.get_child(candidate).visible:
					cslot = candidate
				else:
					# Function is in a closed dropdown; anchor to that section's toggle instead
					for dd in callee_node.get_meta("dropdowns", []):
						if dd.get("label") == "Variables" or dd.get("label") == "TODOs": continue
						for f in dd.get("funcs", []):
							if f["name"] == call["method"]:
								cslot = callee_node.get_children().find(dd["toggle"])
								break
						if cslot >= 0: break

			if cslot >= 0:
				var callee_min_slot := cslot
				var callee_slot_offset := 0
				for dd in callee_node.get_meta("dropdowns", []):
					if dd["items"].is_empty() or dd["items"][0].visible: continue
					var dd_first_idx := callee_node.get_children().find(dd["items"][0])
					if dd_first_idx >= 0 and dd_first_idx < callee_min_slot:
						callee_slot_offset += dd["items"].size()
				cslot -= callee_slot_offset
				# Blue input (type 2) on the open callee creates a green→blue gradient
				# with the green output (type 3) on the open caller's side.
				# Preserve any right port already placed on this slot by a prior Phase 2 iteration.
				callee_node.set_slot(cslot, true, 2, _call_edge_color(),
					callee_node.is_slot_enabled_right(cslot),
					callee_node.get_slot_type_right(cslot),
					callee_node.get_slot_color_right(cslot))
			else:
				callee_node.set_slot(1, true, 3, _call_edge_out_color(),
					callee_node.is_slot_enabled_right(1), 2, _call_edge_color())

			callee_node.update_minimum_size()
			var callee_in_slot := cslot if cslot >= 0 else 1
			var to_port := _slot_to_in_port(callee_node, callee_in_slot)
			if to_port < 0 or target_out_port < 0: continue
			var already := false
			for conn in get_connection_list():
				if conn["from_node"] == target_class and conn["to_node"] == callee_class \
						and conn["from_port"] == target_out_port and conn["to_port"] == to_port:
					already = true; break
			if not already:
				connect_node(target_class, target_out_port, callee_class, to_port)

			_green_edges[_edge_key(target_class, callee_class)] = true
			if not _dropdown_open_nodes.has(callee_class):
				_apply_green_border(callee_node)

func _refresh_call_slots() -> void:
	var connections := get_connection_list()
	var needs_input : Dictionary = {}
	var needs_output : Dictionary = {}
	for conn in connections:
		# Inheritance edges are always port 0→0 where the target has a known parent.
		# Every other connection is a call edge and needs both sides marked.
		var is_inheritance = conn["to_port"] == 0 and _has_parent.has(conn["to_node"])
		if not is_inheritance:
			needs_input[conn["to_node"]] = true
			needs_output[conn["from_node"]] = true

	for class_name_ in _graph_nodes:
		var graph_node : GraphNode = _graph_nodes[class_name_]
		var has_input := needs_input.get(class_name_, false)
		var has_output := needs_output.get(class_name_, false)
		if not has_input and not has_output:
			graph_node.set_slot(1, false, 0, Color.WHITE, false, 0, Color.WHITE)
			graph_node.set_slot(2, graph_node.is_slot_enabled_left(2), 0, Color.WHITE, false, 0, Color.WHITE)
			if not _dropdown_open_nodes.has(class_name_):
				if _blue_bordered.has(class_name_) or _green_bordered.has(class_name_):
					graph_node.remove_theme_stylebox_override("panel")
					graph_node.remove_theme_stylebox_override("titlebar")
					_blue_bordered.erase(class_name_); _green_bordered.erase(class_name_)
			continue
		var has_blue_outbound : bool = false
		var has_green_outbound : bool = false
		var has_green_inbound : bool = false
		for conn in connections:
			if conn["from_node"] == class_name_:
				var is_child_inherit = conn["from_port"] == 0 and conn["to_port"] == 0 and _has_child.has(class_name_)
				if not is_child_inherit:
					if _green_edges.has(_edge_key(class_name_, conn["to_node"])): has_green_outbound = true
					else: has_blue_outbound = true
			if conn["to_node"] == class_name_ and conn["to_port"] != 0:
				if _green_edges.has(_edge_key(conn["from_node"], class_name_)): has_green_inbound = true
		var in_type := 3 if has_green_inbound else 2
		var in_color := _call_edge_out_color() if has_green_inbound else _call_edge_color()
		if has_blue_outbound and has_green_outbound:
			graph_node.set_slot(1, has_input, in_type, in_color, true, 2, _call_edge_color())
			graph_node.set_slot(2, graph_node.is_slot_enabled_left(2), 0, Color.WHITE, true, 3, _call_edge_out_color())
		elif has_blue_outbound:
			graph_node.set_slot(1, has_input, in_type, in_color, true, 2, _call_edge_color())
			graph_node.set_slot(2, graph_node.is_slot_enabled_left(2), 0, Color.WHITE, false, 0, Color.WHITE)
		elif has_green_outbound:
			graph_node.set_slot(1, has_input, in_type, in_color, true, 3, _call_edge_out_color())
			graph_node.set_slot(2, graph_node.is_slot_enabled_left(2), 0, Color.WHITE, false, 0, Color.WHITE)
		else:
			graph_node.set_slot(1, has_input, in_type, in_color, false, 0, Color.WHITE)
			graph_node.set_slot(2, graph_node.is_slot_enabled_left(2), 0, Color.WHITE, false, 0, Color.WHITE)
		if not _dropdown_open_nodes.has(class_name_):
			if has_blue_outbound or has_green_outbound: _apply_blue_border(graph_node)
			elif has_green_inbound: _apply_green_border(graph_node)
			elif _blue_bordered.has(class_name_) or _green_bordered.has(class_name_):
				graph_node.remove_theme_stylebox_override("panel")
				graph_node.remove_theme_stylebox_override("titlebar")
				_blue_bordered.erase(class_name_); _green_bordered.erase(class_name_)

# -- Selection ---------------------------------------------------------------
func _on_node_selected(node: Node) -> void:
	_selected_node = node.name
	_clear_highlights(); _bring_to_front(node as GraphNode)
	var class_name_ : String = node.name
	var parent_name : String = _class_data.get(class_name_, {}).get("extends", "")
	while _graph_nodes.has(parent_name):
		var parent_node : GraphNode = _graph_nodes[parent_name]
		var child_node : GraphNode = _graph_nodes[class_name_]
		_apply_border(parent_node, _pink_color())
		parent_node.set_slot(0, true, 0, _pink_color(), true, 0, _pink_color())
		child_node.set_slot(0, true, 0, _pink_color(), _has_child.has(class_name_), 0, _pink_color())
		class_name_ = parent_name
		parent_name = _class_data.get(class_name_, {}).get("extends", "") as String

func _on_node_deselected(_node: Node) -> void:
	_selected_node = ""
	_clear_highlights()

func _bring_to_front(graph_node: GraphNode) -> void:
	graph_node.move_to_front()
	if _toolbar_row: _toolbar_row.move_to_front()

func _clear_highlights() -> void:
	for class_name_ in _graph_nodes:
		var graph_node : GraphNode = _graph_nodes[class_name_]
		graph_node.remove_theme_stylebox_override("panel")
		graph_node.remove_theme_stylebox_override("titlebar")
		graph_node.set_slot(0,
			_has_parent.has(class_name_), 0, Color.WHITE,
			_has_child.has(class_name_), 0, Color.WHITE)

# -- Border helpers ----------------------------------------------------------
func _apply_border(graph_node: GraphNode, border_color: Color) -> void:
	for theme_type in ["panel", "titlebar"]:
		var sb : StyleBoxFlat = graph_node.get_theme_stylebox(theme_type).duplicate()
		sb.border_color = border_color
		sb.set_border_width_all(2)
		graph_node.add_theme_stylebox_override(theme_type, sb)

func _apply_pink_border(graph_node: GraphNode) -> void: _apply_border(graph_node, _pink_color())
func _apply_blue_border(graph_node: GraphNode) -> void: _apply_border(graph_node, _blue_color()); _blue_bordered[graph_node.name] = true
func _apply_green_border(graph_node: GraphNode) -> void: _apply_border(graph_node, _green_color()); _green_bordered[graph_node.name] = true

# -- Layout ------------------------------------------------------------------
func _apply_layout() -> void:
	if _class_data.is_empty(): return
	
	var children_map : Dictionary = {}
	var root_classes : Array = []
	for class_name_ in _class_data:
		var parent_name : String = _class_data[class_name_]["extends"]
		if parent_name == "" or not _graph_nodes.has(parent_name):
			root_classes.append(class_name_)
		else:
			if not children_map.has(parent_name): children_map[parent_name] = []
			children_map[parent_name].append(class_name_)

	var layer_map : Dictionary = {}
	var bfs_queue : Array = []
	for root in root_classes: bfs_queue.append([root, 0])
	while bfs_queue.size() > 0:
		var item : Array = bfs_queue.pop_front()
		var class_name_: String = item[0]
		var layer : int = item[1]
		if layer_map.has(class_name_): continue
		layer_map[class_name_] = layer
		for child in children_map.get(class_name_, []): bfs_queue.append([child, layer + 1])

	var nodes_by_layer := {}
	for class_name_ in layer_map:
		var layer : int = layer_map[class_name_]
		if not nodes_by_layer.has(layer): nodes_by_layer[layer] = []
		nodes_by_layer[layer].append(class_name_)
	if not nodes_by_layer.has(0): return
	nodes_by_layer[0].sort()

	var node_height_with_sep := func(class_name_: String) -> float:
		return _graph_nodes[class_name_].size.y + _node_h_sep() if _graph_nodes.has(class_name_) else float(_node_h_sep())

	var node_y_positions := {}
	var layer_right_edge := {}
	var layer0_nodes: Array = nodes_by_layer[0]
	var layer0_total_height := 0.0
	for class_name_ in layer0_nodes: layer0_total_height += node_height_with_sep.call(class_name_)
	var max_width := 0.0
	var cursor_y := -layer0_total_height / 2.0
	for class_name_ in layer0_nodes:
		node_y_positions[class_name_] = cursor_y
		if _graph_nodes.has(class_name_):
			_graph_nodes[class_name_].position_offset = Vector2(0, cursor_y)
			max_width = max(max_width, _graph_nodes[class_name_].size.x)
		cursor_y += node_height_with_sep.call(class_name_)
	layer_right_edge[0] = max_width

	for layer in range(1, nodes_by_layer.keys().max() + 1):
		if not nodes_by_layer.has(layer): continue
		var x_offset : float = layer_right_edge.get(layer - 1, 0.0) + _node_v_sep()
		var nodes_by_parent : Dictionary = {}
		var parent_order : Array = []
		for class_name_ in nodes_by_layer[layer]:
			var parent_name : String = _class_data[class_name_]["extends"]
			if not nodes_by_parent.has(parent_name):
				nodes_by_parent[parent_name] = []
				parent_order.append(parent_name)
			nodes_by_parent[parent_name].append(class_name_)
		parent_order.sort_custom(func(a, b): return node_y_positions.get(a, 0.0) < node_y_positions.get(b, 0.0))
		var layer_max_width : float = 0.0
		var next_min_y : float = -INF
		for parent_name in parent_order:
			var group : Array = nodes_by_parent[parent_name]; group.sort()
			var group_height : float = 0.0
			for class_name_ in group: group_height += node_height_with_sep.call(class_name_)
			var start_y : float = max(node_y_positions.get(parent_name, 0.0) - group_height / 2.0 + node_height_with_sep.call(group[0]) / 2.0, next_min_y)
			var slot_cursor : float = start_y
			for class_name_ in group:
				node_y_positions[class_name_] = slot_cursor
				if _graph_nodes.has(class_name_):
					_graph_nodes[class_name_].position_offset = Vector2(x_offset, slot_cursor)
					layer_max_width = max(layer_max_width, _graph_nodes[class_name_].size.x)
				slot_cursor += node_height_with_sep.call(class_name_)
			next_min_y = start_y + group_height
		layer_right_edge[layer] = x_offset + layer_max_width

# -- Override detection ------------------------------------------------------
func _get_overrides(class_name_: String) -> Dictionary:
	var own_functions : Dictionary = {}
	for func_ in _class_data[class_name_].get("functions", []): own_functions[func_["name"]] = true
	var overrides : Dictionary = {}
	var parent_name : String = _class_data[class_name_]["extends"]
	while _class_data.has(parent_name):
		for func_ in _class_data[parent_name].get("functions", []):
			if own_functions.has(func_["name"]): overrides[func_["name"]] = true
		parent_name = _class_data[parent_name]["extends"]
	if ClassDB.class_exists(parent_name):
		for method in ClassDB.class_get_method_list(parent_name, false):
			if own_functions.has(method["name"]): overrides[method["name"]] = true
	return overrides

# -- Node construction -------------------------------------------------------
func _make_separator_line() -> ColorRect:
	var sep := ColorRect.new()
	sep.color = Color(1, 1, 1, 0.1)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sep

func _make_section_toggle(section_label: String, item_count: int) -> Button:
	var toggle := Button.new()
	toggle.text = "▶ %s (%d)" % [section_label, item_count]
	toggle.flat = true
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle.add_theme_font_override("font", settings.bold_font)
	return toggle

func _make_node(class_name_: String, script_path: String, variables: Array, functions: Array,
		overrides: Dictionary, builtin: bool = false) -> GraphNode:
	var graph_node := GraphNode.new()
	graph_node.title = class_name_
	graph_node.name = class_name_
	graph_node.set_meta("dropdowns", [])
	graph_node.set_meta("func_slot_map", {})

	graph_node.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton or event is InputEventMouseMotion: _bring_to_front(graph_node))

	if builtin:
		graph_node.modulate = _builtin_modulate()
		var builtin_label := Label.new(); builtin_label.text = "built-in"
		builtin_label.add_theme_font_size_override("font_size", 10)
		builtin_label.modulate = settings.font_builtin_label
		graph_node.add_child(builtin_label); return graph_node

	var file_button := Button.new()
	file_button.text = script_path.replace("res://", ""); file_button.flat = true
	file_button.mouse_filter = Control.MOUSE_FILTER_STOP
	file_button.pressed.connect(func(): _open_script(script_path, 0))
	graph_node.add_child(file_button)

	var func_slot_map : Dictionary = graph_node.get_meta("func_slot_map")

	# Adds a section with items as direct children of graph_node (not VBoxContainer),
	# so each function button gets its own GraphNode slot for per-function port positioning.
	var add_items_direct := func(items_out: Array, item_arr: Array, make_btn: Callable, track_slots: bool) -> void:
		var sep0 := _make_separator_line(); sep0.visible = false
		graph_node.add_child(sep0); items_out.append(sep0)
		for i in item_arr.size():
			if i > 0:
				var sep := _make_separator_line(); sep.visible = false
				graph_node.add_child(sep); items_out.append(sep)
			var btn : Button = make_btn.call(item_arr[i])
			btn.set_meta("section_item", true)
			btn.visible = false
			graph_node.add_child(btn)
			items_out.append(btn)
			if track_slots:
				func_slot_map[item_arr[i]["name"]] = graph_node.get_child_count() - 1
		var sep_end := _make_separator_line(); sep_end.visible = false
		graph_node.add_child(sep_end); items_out.append(sep_end)

	if variables.size() > 0:
		var toggle := _make_section_toggle("Variables", variables.size()); graph_node.add_child(toggle)
		var items : Array = []
		var make_var_btn := func(v: Dictionary) -> Button:
			var btn := Button.new()
			btn.text = " %s: %s" % [v["name"], v["type"]]; btn.flat = true
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.add_theme_font_size_override("font_size", 20)
			btn.add_theme_color_override("font_color", _variable_color())
			btn.add_theme_color_override("font_hover_color", settings.font_hover)
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			var line: int = v["line"]; btn.pressed.connect(func(): _open_script(script_path, line))
			return btn
		add_items_direct.call(items, variables, make_var_btn, false)
		toggle.pressed.connect(func():
			var expanding = not items[0].visible
			for item in items: item.visible = expanding
			toggle.text = "%s Variables (%d)" % ["▼" if expanding else "▶", variables.size()]
			if _dropdown_open_nodes.has(class_name_):
				call_deferred("_rebuild_call_edges")
			if not expanding: graph_node.reset_size())
		graph_node.get_meta("dropdowns").append({"toggle": toggle, "items": items, "label": "Variables", "count": variables.size()})

	var own_functions : Array = []
	var own_static_functions : Array = []
	var override_functions : Array = []
	for func_ in functions:
		if overrides.has(func_["name"]):
			override_functions.append(func_)
		elif func_.get("static", false):
			own_static_functions.append(func_)
		else:
			own_functions.append(func_)

	var make_function_dropdown := func(section_label: String, func_arr: Array) -> void:
		if func_arr.is_empty(): return
		var toggle := _make_section_toggle(section_label, func_arr.size()); graph_node.add_child(toggle)
		var items : Array = []
		var make_func_btn := func(func_: Dictionary) -> Button:
			var is_override : bool = overrides.has(func_["name"])
			var missing_super : bool = is_override and not func_.get("calls_super", false)
			var btn := Button.new()
			btn.text = " %s(%s): %s%s" % [func_["name"], func_["args"], func_["return"], " ⬆" if is_override else ""]
			btn.flat = true; btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.add_theme_font_size_override("font_size", 20)
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			var font_color := _missing_super_color() if missing_super else (_override_color() if is_override else _variable_color())
			btn.add_theme_color_override("font_color", font_color)
			btn.add_theme_color_override("font_hover_color", settings.font_hover)
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			if missing_super: btn.tooltip_text = "⚠ super() is not called"
			var line: int = func_["line"]; btn.pressed.connect(func(): _open_script(script_path, line))
			return btn
		add_items_direct.call(items, func_arr, make_func_btn, true)
		toggle.pressed.connect(func():
			var expanding = not items[0].visible
			for item in items: item.visible = expanding
			toggle.text = "%s %s (%d)" % ["▼" if expanding else "▶", section_label, func_arr.size()]
			if expanding:
				_dropdown_open_nodes[class_name_] = true
				_apply_border(graph_node, Color.WHITE)
				call_deferred("_rebuild_call_edges")
			else:
				graph_node.reset_size()
				var any_open := false
				for dd in graph_node.get_meta("dropdowns", []):
					if dd["label"] == "Variables" or dd["label"] == "TODOs": continue
					if dd["items"].size() > 0 and dd["items"][0].visible:
						any_open = true; break
				if not any_open:
					_dropdown_open_nodes.erase(class_name_)
				_rebuild_call_edges()
		)
		graph_node.get_meta("dropdowns").append({"toggle": toggle, "items": items, "label": section_label, "count": func_arr.size(), "funcs": func_arr})

	make_function_dropdown.call("Static Functions", own_static_functions)
	make_function_dropdown.call("Functions", own_functions)
	make_function_dropdown.call("Overrides", override_functions)

	var todos: Array = _class_data[class_name_].get("todos", [])
	if todos.size() > 0:
		var toggle := _make_section_toggle("TODOs", todos.size())
		toggle.add_theme_color_override("font_color", _todo_header_color()); graph_node.add_child(toggle)
		var items : Array = []
		var make_todo_btn := func(todo: Dictionary) -> Button:
			var btn := Button.new()
			btn.text = " L%d: %s" % [todo["line"], todo["text"]]
			btn.flat = true
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.add_theme_font_size_override("font_size", 15)
			btn.add_theme_color_override("font_color", _todo_item_color())
			btn.add_theme_color_override("font_hover_color", settings.font_hover)
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			btn.clip_text = true; btn.custom_minimum_size.x = 180
			var line: int = todo["line"]
			btn.pressed.connect(func(): _open_script(script_path, line))
			return btn
		add_items_direct.call(items, todos, make_todo_btn, false)
		toggle.pressed.connect(func():
			var expanding = not items[0].visible
			for item in items: item.visible = expanding
			toggle.text = "%s TODOs (%d)" % ["▼" if expanding else "▶", todos.size()]
			if not expanding: graph_node.reset_size())
		graph_node.get_meta("dropdowns").append({"toggle": toggle, "items": items, "label": "TODOs", "count": todos.size()})

	return graph_node

func _open_script(script_path: String, line: int) -> void:
	var script := load(script_path) as Script
	if script: EditorInterface.edit_script(script, line, 0)
