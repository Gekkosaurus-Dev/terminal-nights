extends Node
class_name TreeLayout
#Organises the hierarchy into a tree-like data structure

const H_SEP = 250  # horizontal space between nodes
const V_SEP = 150  # vertical space between layers

static func compute(nodes: Dictionary) -> Dictionary:
	# nodes: { "ClassName": "ParentClass" }
	# returns: { "ClassName": Vector2 }

	# 1. Build children map
	var children = {}
	var roots = []
	for cname in nodes:
		var parent = nodes[cname]
		if parent == "" or not nodes.has(parent):
			roots.append(cname)
		else:
			if not children.has(parent):
				children[parent] = []
			children[parent].append(cname)

	# 2. Assign layers (BFS from roots)
	var layers = {}  # { "ClassName": layer_index }
	var queue = []
	for r in roots:
		queue.append([r, 0])
	while queue.size() > 0:
		var item = queue.pop_front()
		var node = item[0]
		var layer = item[1]
		layers[node] = layer
		for child in children.get(node, []):
			queue.append([child, layer + 1])

	# 3. Group by layer
	var by_layer = {}
	for cname in layers:
		var l = layers[cname]
		if not by_layer.has(l):
			by_layer[l] = []
		by_layer[l].append(cname)

	# 4. Assign positions
	var positions = {}
	for layer in by_layer:
		var members = by_layer[layer]
		for i in members.size():
			positions[members[i]] = Vector2(
				i * H_SEP - (members.size() - 1) * H_SEP / 2.0,
				layer * V_SEP
			)

	return positions
