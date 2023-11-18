class_name SceneFileUpdater
extends RefCounted
## Updates a scene file with the given node paths, properties and values
##
## This is used instead of PackedScene/ResourceSaver because these classes can
## update much more than just property values. (e.g. uuid's, resource references)
## Instead, this class only adds, updates or removes property assignments.
## (If a given property value matches the property's default value, then it is removed.)

const _SKIP_LINE_TOKEN = '!%#SKIP#%!'

## Error message if update_scene_file() returns false
var error_message := ""

var _node_type_properties := {}
var _node_type_objects := {}


func _get_assigned_value(s: String) -> String:
	var index = s.find("=")
	assert(index > -1)
	return s.substr(index + 1).trim_prefix("&").trim_prefix("\"").trim_suffix("\"")


func _get_node_line_path_and_type(line:String) -> Array[String]:
	var tmp := line.trim_prefix("[").trim_suffix("]")
	var parts = tmp.split(" ", false)
	var node_type = ""
	var node_parent = ""
	var node_name = ""
	for part in parts:
		if part.begins_with("type="):
			node_type = _get_assigned_value(part)
		elif part.begins_with("name="):
			node_name = _get_assigned_value(part)
		elif part.begins_with("parent="):
			node_parent = _get_assigned_value(part)
	if node_parent.is_empty():
		return [node_name, node_type]
	return ["%s/%s" % [node_parent, node_name], node_type]


func _get_property_type(node_type:String, prop_name: String) -> int:
	var prop_dictionary:Dictionary = {}
	if !_node_type_properties.has(node_type):
		if ClassDB.class_exists(node_type):
			var prop_array := ClassDB.class_get_property_list(node_type)
			for prop in prop_array:
				prop_dictionary[prop.name] = prop
			_node_type_properties[node_type] = prop_dictionary
		else:
			printerr("SceneFileUpdater: type '%s' not found in ClassDB - can't get property types for it" % node_type)
			return TYPE_STRING
	else:
		prop_dictionary = _node_type_properties[node_type]
	
	if !prop_dictionary.has(prop_name):
		printerr("SceneFileUpdater: could not get type for property '%s' of node type '%s'" % [prop_name, node_type])
		return TYPE_STRING
	
	return prop_dictionary[prop_name].type


func _format_property_value(node_type:String, prop_name: String, prop_value) -> String:
	var prop_type = _get_property_type(node_type, prop_name)
	match prop_type:
		TYPE_STRING:
			return "\"%s\"" % str(prop_value)
		TYPE_STRING_NAME:
			return "&\"%s\"" % str(prop_value)
	
	return str(prop_value)


func _is_default_value(node_type:String, prop_name: String, prop_value) -> bool:
	var obj
	if !_node_type_objects.has(node_type):
		if ClassDB.class_exists(node_type):
			obj = ClassDB.instantiate(node_type)
			_node_type_objects[node_type] = obj
		else:
			printerr("SceneFileUpdater: type '%s' does not exist in ClassDB - can't determine default value for property '%s'" % [node_type, prop_name])
	else:
		obj = _node_type_objects[node_type]
	if !obj:
		return false
	return obj.get(prop_name) == prop_value

func _open_scene_file(path:String) -> FileAccess:
	if !FileAccess.file_exists(path):
		error_message = "Scene file '%s' does not exist" % path
	if path.get_extension() != "tscn":
		error_message = "Scene file '%s' is not a tscn file"
	
	var f = FileAccess.open(path, FileAccess.READ)
	if !f:
		error_message = "Could not open scene file '%s'.  error: %s" % [path, error_string(FileAccess.get_open_error())]
	return f


func _save_scene_file(path:String, new_file_contents:Array, dry_run: bool) -> bool:
	var file_path = "%s.tmp" % path if dry_run else path
	#if dry_run and FileAccess.file_exists(file_path):
		#DirAccess.remove_absolute(file_path)
	var temp_file = FileAccess.open(file_path,FileAccess.WRITE)
	if !temp_file:
		#printerr("SceneFileUpdater: couldn't open temp file '%s'" % temp_file_path)
		error_message = "could not open temp file '%s'.  error: %s" % [file_path, error_string(FileAccess.get_open_error())]
		return false
	temp_file.store_string("\n".join(new_file_contents))
	temp_file.close()
	return true

## Updates a scene file with the given node property values.
## The [param node_property_values] parameter is a dictionary of a node path to a dictionary of 
## property names to property values.  Returns true if successful.
## The [param dry_run] is used to perform a dry run instead of actually updating the file.  In the
## case of a dry run, the results are saved to a file named the same as the given file but ends in ".tmp"
func update_scene_file(path: String, node_property_values:Dictionary, dry_run: bool = false) -> bool:
	error_message = ""
	
	if node_property_values.is_empty():
		error_message = "node property values is empty - nothing to update"
		return false
	
	var f = _open_scene_file(path)
	if !f:
		return false
	
	var new_file_contents := []
	var line := ""
	var current_node_path := ""
	var current_node_type := ""
	var current_update_values := {}
	var update_made := false
	while !f.eof_reached():
		line = f.get_line()
		if line.begins_with("[node"):
			var path_and_type = _get_node_line_path_and_type(line)
			current_node_path = path_and_type[0]
			current_node_type = path_and_type[1]
			if node_property_values.has(current_node_path):
				current_update_values = node_property_values[current_node_path]
			else:
				current_update_values = {}
		# section (not a node)
		elif line.begins_with("["):
			current_node_path = ""
			current_node_type = ""
			current_update_values = {}
		#blank line at end of node section
		elif !current_node_path.is_empty() and line.is_empty():
			# add any remaining property assignment to result
			for property_name in current_update_values.keys():
				var property_value = current_update_values[property_name]
				if !_is_default_value(current_node_type, property_name, property_value):
					new_file_contents.append("%s = %s" % [property_name, _format_property_value(current_node_type, property_name, property_value)])
					update_made = true
		# assignment for a node section
		elif !current_node_path.is_empty():
			var equals_index := line.find(" = ")
			if equals_index > -1:
				var property_name = line.substr(0, equals_index)
				# see if we want to replace it
				if current_update_values.has(property_name):
					var property_value = current_update_values[property_name]
					update_made = true
					if _is_default_value(current_node_type, property_name, property_value):
						line = _SKIP_LINE_TOKEN
					else:
						line = "%s = %s" % [property_name, _format_property_value(current_node_type, property_name, property_value)]
				current_update_values.erase(property_name)
			
		if line != _SKIP_LINE_TOKEN:
			new_file_contents.append(line)

	
	if !update_made:
		error_message = "No actual updates made to/for scene file '%s'" % path
		return false
	
	return _save_scene_file(path, new_file_contents, dry_run)



