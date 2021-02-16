class_name Utility
extends Object

##
## This file contains the translator constans
## Developed by Johannes Witt
## Placed into the Public Domain
##

## Contains virtual functions that are automatically parsed as such
const VIRTUAL_FUNCTIONS = [
	# Object
	"_init",
	"_get",
	"_set",
	"_get_property_list",
	"_notification",
	"_to_string",
	
	# Node
	"_ready",
	"_process",
	"_physics_process",
	"_input",
	"_unhandled_input",
	"_unhandled_key_input",
	"_enter_tree",
	"_exit_tree",
	"_get_configuration_warning",
	
	# Control
	"_clips_input",
	"_get_minimum_size",
	"_gui_input",
	"_make_custom_tooltip",
	
]


## Contains all GDScript math operators
const MATH_OPERATORS = [
	"+",
	"-",
	"*",
	"/",
	"%",
]


## Contains all GDScript assignment operators
const ASSIGNMENT_OPERATORS = [
	"=",
	"+=",
	"-=",
	"*=",
	"/=",
	"%=",
	"&=",
	"|=",
]


## Contains all GDScript comparison operators
const COMPARISON_OPERATORS = [
	"<",
	">",
	"==",
	"!=",
	">=",
	"<=",
]


## Contains all bitwise operators
const BITWISE_OPERATORS = [
	"~",
	"<<",
	">>",
	"&",
	"^",
	"|",
]


## Contains all method remaps (i.e. for methods using a namespace)
const REMAP_METHODS = {
	"assert": "Debug.Assert",
	"print": "GD.Print",
	"prints": "GD.PrintS",
	"printt": "GD.PrintT",
	"load": "GD.Load",
	"preload": "GD.Load",
	"abs": "Mathf.Abs",
	"acos": "Mathf.Acos",
	"asin": "Mathf.Asin",
	"atan": "Mathf.Atan",
	"atan2": "Mathf.Atan2",
	"min": "Mathf.Min",
	"ord": "char.GetNumericValue",
	"push_error": "GD.PushError",
	"push_warning": "GD.PushWarning",
}


## Contains all keyword remaps that are parsed as variables
const REMAP_VARIABLES = {
	"self": "this",
	"event": "@event",
}


## Contains the needed usings, when using the specified method
const METHOD_USINGS = {
	"assert": "System.Diagnostics",
}


## Contains the builtin classes
## value is how it should be handled
## null -> normal
## String -> value is used 1:1 for empty constructor
## [String, String] -> 0: type, 1: not empty
## 
const BUILTIN_CLASSES = {
	"String": null,
	"Vector2": null,
	"Rect2": null,
	"Vector3": null,
	"Transform2D": "Transform2D.Identity",
	"Plane": null,
	"Quat": "Quat.Identity",
	"AABB": null,
	"Basis": "Basis.Identity",
	"Transform": null,
	"Color": null,
	"NodePath": null,
	"RID": null,
	"Array": ["Godot.Collections.Array", "Godot.Collections.Array{%s}"],
	"Dictionary": ["Godot.Collections.Dictionary", "Godot.Collections.Dictionary{%s}"],
	# Maybe convert those to typesafe Godot Arrays?
	"PackedByteArray": ["byte[]", "byte[] {%s}"],
	"PackedInt32Array": ["int[]", "int[] {%s}"],
	"PackedInt64Array": ["Int64[]", "Int64[] {%s}"],
	"PackedFloat32Array": ["float[]", "float[] {%s}"],
	"PackedFloat64Array": ["double[], double[] {%s}"],
	"PackedVector2Array": ["Vector2[]", "Vector2[] {%s}"],
	"PackedVector3Array": ["Vector3[]", "Vector3[] {%s}"],
	"PackedColorArray": ["Color[]", "Color[] {%s}"],
}


### Case Converter ##

## Converts string to PascalCase
##
## @param string
## @param keep_frist_ if true, the first underscore is preserved
static func pascal(string: String, keep_first_ := false) -> String:
	var result = ""
	var strings := string.split(" ")
	for s in strings:
		if s.empty():
			result += " "
			continue
		var first = s[0] == '_'
		var s2 = s.capitalize()
		result += ("_" if first && keep_first_ else "") + s2.replace(" ", "") + " "
	result.erase(result.length() - 1, 1)
	return result


## Converts string to camelCase
##
## @param string
## @param keep_first_ if true, the first underscrore is preserved
static func camelCase(string: String, keep_first_ := false) -> String:
	var first = string[0] == '_'
	string = string.capitalize().replace(" ", "")
	string[0] = string[0].to_lower()
	return ("_" if first && keep_first_ else "") + string


# Utilities

static func find_not_in_string(string: String, character: String, start_offset := 0) -> int:
	var quote := -1
	for i in string.length():
		if string[i] == '"':
			if quote == -1:
				quote = i
			else:
				quote = -1
			continue
		if i < start_offset:
			continue
		var pos = string.find(character, i - character.length())
		if pos != -1 && pos <= i && quote == -1:
			return i
	return -1

## Returns the assignment expression as
## [left side, operator, right side]
static func split_math(string: String) -> Array:
	for op in MATH_OPERATORS:
		var pos = string.find(op)
		if pos != -1:
			return [string.substr(0, pos).strip_edges(), op, string.substr(pos + op.length())]
	assert(false) # Here is no math operation to be split
	return [string, "", ""]


## Returns the assignment expression as
## [left side, operator, right side]
static func split_assignment(string: String) -> Array:
	for op in ASSIGNMENT_OPERATORS:
		var pos = string.find(op)
		if pos != -1:
			return [string.substr(0, pos).strip_edges(), op, string.substr(pos + op.length())]
	assert(false)
	return [string, "", ""]


## Returns the bitwise expression as
## [left side, operator, right side]
static func split_bitwise(string: String) -> Array:
	for op in BITWISE_OPERATORS:
		var pos = string.find(op)
		if pos != -1:
			return [string.substr(0, pos).strip_edges(), op, string.substr(pos + op.length())]
	assert(false)
	return [string, "", ""]


## Returns the comparison expression as
## [left side, operator, right side]
static func split_comparison(string: String) -> Array:
	for op in COMPARISON_OPERATORS:
		var pos = string.find(op)
		if pos != -1:
			return [string.substr(0, pos).strip_edges(), op, string.substr(pos + op.length())]
	assert(false)
	return [string, "", ""]

## Returns the var converted if declared in a local block
## Returns empty array if none found
static func get_var_in_local_vars(string: String, lsv) -> Array:
	for indent in lsv:
		if lsv[indent].has(string):
			return lsv[indent][string]
	return []


## Returns variable name from declaration
static func get_var_name_from_d(string: String, is_const := false) -> String:
	var offset = 5 if is_const else 3
	var end = -1
	if string.count(":=") > 0:
		end = string.find(":=") - offset
	elif find_not_in_string(string, ":") > 0:
		end = find_not_in_string(string, ":") - offset
	elif string.count("=") > 0:
		end = string.find("=") - offset
	return string.substr(offset, end).strip_edges()


## Returns true if method is remapped in C# (i.e. using a namespace)
static func is_remapped_method(method: String) -> bool:
	return method in REMAP_METHODS

## Returns the C# variant of the the method
static func get_remapped_method(method: String) -> String:
	assert(is_remapped_method(method))
	return REMAP_METHODS[method]
