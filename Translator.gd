class_name Translator
extends VBoxContainer

##
## This file contains the translator functions and callbacks for the app
## Developed by Johannes Witt
## Placed into the Public Domain
##


const GITHUB_URL = "https://github.com/HaSa1002/codetranslator/"
const VERSION = "0.5-dev (Last Build 2020-09-10 15:14)"


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
	"&",
	"|",
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


## Contains all method remaps (i.e. for methods using a namespace)
const REMAP_METHODS = {
	"assert": "Debug.Assert",
	"print": "GD.Print",
	"abs": "Mathf.Abs",
	"acos": "Mathf.Acos",
	"asin": "Mathf.Asin",
	"atan": "Mathf.Atan",
	"atan2": "Mathf.Atan2",
	"min": "Mathf.Min",
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
	"PackedVector2Array": ["Vector2[], Vector2[] {%s}"],
	"PackedVector3Array": ["Vector3[]", "Vector3[] {%s}"],
	"PackedColorArray": ["Color[]", "Color[] {%s}"],
}


export var bug_report_popup : NodePath
export var about_popup : NodePath
export var paste_bug : NodePath

func _ready():
	get_node(about_popup).dialog_text = get_node(about_popup).dialog_text % VERSION
	$Controls/Paste.visible = OS.has_feature("JavaScript")
	pass # Replace with function body.



### Utility touching Scene ###

## Adds a warning to the warnings TextEdit
## Todo: Once #40629 is merged and in release, add direct highlighting to the source code
func warn(line : int, what : String):
	var warns : TextEdit = $HSplitContainer/VSplitContainer/Warnings/Warnings
	warns.text += "[%d] %s\n" % [line, what]


## Clears output and warnings
func clear():
	$HSplitContainer/VSplitContainer/Output/Output.text = ""
	$HSplitContainer/VSplitContainer/Warnings/Warnings.text = ""


## Translates input based on the wanted output determined through the buttons
func generate_output():
	clear()
	var output := ""
	var source = $HSplitContainer/Source/Source.text
	if $Controls/CSharp.pressed:
		output = generate_csharp(source)
	if $Controls/EscapeXML.pressed:
		output = escape_xml(source)
	$HSplitContainer/VSplitContainer/Output/Output.text = output
	pass



### Generators ###

## Parses the source code and outputs the resulting C# Code
func generate_csharp(source: String) -> String:
	var output := ""
	var current_line: int = 0
	var comment := ""
	var depth = 0
	var collect_file_scope := true
	var collected_scope = ""
	var is_global_scope := false
	var global_scope_vars := {}
	var local_vars := {0: {}} #contains dict for each indent level, index by indent
	var usings := [
		"Godot",
		"System",
	]
	var braces := 0
	var is_multiline := false
	source = source.replace("    ", "\t")
	for line in source.split("\n"):
		var l: String = line.strip_edges()
		current_line += 1
		var indent = line.length() - line.strip_edges(true, false).length()
		
		if collect_file_scope:
			if indent != 0:
				collect_file_scope = false
			else:
				if _is_file_scope(l):
					collected_scope += l + "\n"
					continue
				elif _is_comment(l):
					pass
				elif l.empty():
					pass
				else:
					collect_file_scope = false
			if !collect_file_scope:
				var f_scope = _convert_file_scope_to_cs(current_line, collected_scope)
				is_global_scope = !f_scope.empty()
				output += f_scope
		if !is_multiline:
			indent += 1 if is_global_scope else 0
			if indent < depth:
				braces -= 1
				output += "\t".repeat(braces) + "}\n"
				local_vars.erase(depth)
			elif indent > depth:
				output += "\t".repeat(braces) + "{\n"
				local_vars[indent] = {}
				braces += 1
			depth = indent
			output += "\t".repeat(indent)
		is_multiline = false
		if l.empty() || _is_pass(l):
			output += "\n"
			continue
		if _is_comment(l):
			# directly convert line into comment and continue
			output += "//" + l.substr(1)
			l = ""
		if _has_comment(l):
			# split comment out of case conversion
			comment = l.split("#")[1]
			l = l.split("#")[0]
		if _is_declaration(l):
			var is_global_var = indent == 1 && is_global_scope
			output += _parse_declaration(current_line, is_global_var, l, \
				global_scope_vars, local_vars[indent], local_vars, usings)
			l = ""
		if _is_function_declaration(l):
			if _is_overriding_virtual_function(l):
				output += "public override "
			elif _is_private_function(l):
				output += "private "
			else:
				output += "public "
			if _is_static_function(l):
				output += "static "
			var retval := _get_function_retval(l)
			if retval.empty():
				warn(current_line, "No return value provided. Assuming void. Use -> RETVAL to specify")
				retval = "void"
			output += retval + " "
			var func_name := _get_function_name_from_d(l)
			if func_name.empty():
				warn(current_line, "Expected function name")
				output += "?NAME?("
			else:
				output += _pascal(func_name, _is_virtual(func_name)) + "("
			for arg in _get_function_arguments(l):
				if arg[1] == null:
					warn(current_line, "No type provided. Consider type hinting with NAME:TYPE")
					output += "?TYPE? "
				elif arg[1].empty():
					warn(current_line, "Expected type")
					output += "?TYPE? "
				else:
					output += arg[1] + " "
				
				if arg[0].empty():
					warn(current_line, "Expected argument name")
					output += "?NAME?"
				else:
					output += arg[0]
					local_vars[indent][arg[0]] = [arg[0], arg[1]]
				
				if arg[2] == null:
					pass # We ensure below is a String... Hacky tho
				elif arg[2].empty():
					warn(current_line, "Expected default value")
					output += " ?VALUE?"
				else:
					output += " = " + arg[2]
				output += ", "
			if output.ends_with(", "):
				output = output.left(output.find_last(", "))
			output += ")"
			l = ""
		if _is_if(l):
			output += _convert_if(l)
			l = ""
		if _is_elif(l):
			output += _convert_elif(l)
			l = ""
		if _is_else(l):
			output += "else"
			l = ""
		if l.ends_with("\\"):
			is_multiline = true
			l = l.left(l.length() - 2).strip_edges()
		if !l.empty():
			output += _convert_statement(current_line, _parse_statement(current_line, l), \
					global_scope_vars, local_vars, usings, !is_multiline)
		if !comment.empty():
			output += " //" + comment
			comment = ""
		
		if !is_multiline:
			output += "\n"
		#print("[%d] " % current_line, l)
	while braces > 0:
		output += "\t".repeat(braces - 1) + "}\n"
		braces -= 1
	var usings_str := ""
	for using in usings:
		usings_str += "using %s;\n" % using
	output = usings_str + "\n" + output.rstrip("\n").replace("\t", "    ")
	#print(output)
	return output


## Escapes source code
## Replaces Tabs, &, <, >
func escape_xml(source: String) -> String:
	return source.replace("\t", "    ").replace("&", "&amp;") \
			.replace("<", "&lt;").replace(">", "&gt;")



### Case Converter ##

## Converts string to PascalCase
##
## @param string
## @param keep_frist_ if true, the first underscore is preserved
func _pascal(string : String, keep_first_ := false) -> String:
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
func _camelCase(string: String, keep_first_ := false) -> String:
	var first = string[0] == '_'
	string = string.capitalize().replace(" ", "")
	string[0] = string[0].to_lower()
	return ("_" if first && keep_first_ else "") + string



### 				Detectors 				  ###
# Detectors are only meant to return a bool,	#
# depending on the detected content.			#
# Detectors may be used on complete lines		#

## Returns true if string is a built-in class
func _is_builtin(string: String) -> bool:
	return string.substr(0, string.find("(")).strip_edges() in BUILTIN_CLASSES


func _is_get_node(string: String) -> bool:
	return string.begins_with("$")


## Returns true on pass
func _is_pass(string: String) -> bool:
	return string.begins_with("pass")


## Returns true if complete line is a comment
## # Comment
func _is_comment(string: String) -> bool:
	return string.begins_with("#")


## Returns true if line contains a comment
## code() # Comment
func _has_comment(string: String) -> bool:
	return string.count("#") > 0


## Returns true if line is a declaration
## var x
func _is_declaration(string: String) -> bool:
	return string.begins_with("var")


## Returns true if line is if
## if x:
func _is_if(string: String) -> bool:
	return string.begins_with("if")


## Returns true if line is elif
## elif y:
func _is_elif(string: String) -> bool:
	return string.begins_with("elif")


## Returns true if line is else
## else:
func _is_else(string: String) -> bool:
	return string.begins_with("else:")


## Returns true if line is initialization
## var x = 10
func _is_initialization(string: String) -> bool:
	return _is_declaration(string) && string.count("=") > 0


## Returns true if variable declared in line is private
## var _private
func _is_private_var(string: String) -> bool:
	return _is_private(_get_var_name_from_d(string))


## Returns true, if string starts with underscore
func _is_private(string: String) -> bool:
	return string.begins_with("_")


## Returns true, if a variable declaration is typed
## var x : Node
## var y := ""
func _is_typed_declaration(string: String) -> bool:
	return _is_declaration(string) && string.count(":") > 0


## Returns true if string starts with func
func _is_function_declaration(string: String) -> bool:
	return string.begins_with("func") || string.begins_with("static")


## Returns true if function does not start with an underscore
func _is_public_function(string: String) -> bool:
	return _is_function_declaration(string) && !string.substr(5).begins_with("_")


## Returns true if functions starts with an underscore
func _is_private_function(string: String) -> bool:
	return _is_function_declaration(string) && string.substr(5).begins_with("_")


## Returns true if function is static func
func _is_static_function(string: String):
	return _is_function_declaration(string) && string.begins_with("static")


## Returns true if function is a virtual function in Godot
## like _ready, _process, etc.
func _is_overriding_virtual_function(string: String) -> bool:
	return _is_private_function(string) && string.substr(5, string.find("(") - 5) in VIRTUAL_FUNCTIONS


## Returns true if string is a virtual function name
func _is_virtual(string: String) -> bool:
	return _is_private(string) && string in VIRTUAL_FUNCTIONS


## Returns true if string has an opening brace "("
func _is_function(string: String) -> bool:
	return string.count("(") > 0


## Returns true if string begins with extends, class_name, or tool
func _is_file_scope(string: String) -> bool:
	return (string.begins_with("extends")
			|| string.begins_with("class_name")
			|| string.begins_with("tool"))


## Returns true, if string is a string
## "..." -> true
func _is_string(string: String) -> bool:
	return string[0] == "\"" && string[string.length() - 1] == "\""


## Returns true if next method is .new(
func _is_constructor(string: String) -> bool:
	var new_pos = string.find(".new(")
	return new_pos != -1 && new_pos <= string.find(".")


## Returns true if string is a method
## ABC -> false
## ABC( -> true
## ABC. -> false
## ABC(. -> true
## ABC.( -> false
func _is_method(string: String) -> bool:
	var brace = string.find("(")
	var dot = string.find(".")
	return (brace != -1 && brace < dot) || (brace != -1 && dot == -1)


## Returns true if string is potentially a variable or property
## ABC -> true
## ABC( -> false
## ABC. -> true
## ABC(. -> false
## ABC.( -> true
func _is_var(string: String) -> bool:
	var brace = string.find("(")
	var dot = string.find(".")
	return (dot < brace && dot != -1) || brace == -1


## Returns true if string was declared in local scope
func _is_local_var(string: String, local_vars) -> bool:
	for i in local_vars:
		if local_vars[i].has(string):
			return true
	return false


## Returns true if string was declared in global scope
func _is_global_var(string: String, global_vars) -> bool:
	return global_vars.has(string)


## Returns true if string contains an assignment
func _is_assignment(string: String) -> bool:
	for op in ASSIGNMENT_OPERATORS:
		var pos = string.find(op)
		if pos != -1:
			return true
	return false


## Returns true if string contains a mathematical expression
func _is_math(string: String) -> bool:
	for op in MATH_OPERATORS:
		var pos = string.find(op)
		if pos != -1:
			return true
	return false


## Returns true if string contains an comparison
func _is_comparison(string: String) -> bool:
	for op in COMPARISON_OPERATORS:
		var pos = string.find(op)
		if pos != -1:
			return true
	return false


## Returns true if variable is declared local scope
func _var_in_local_vars(string: String, lsv) -> bool:
	return !_get_var_in_local_vars(string, lsv).empty()


## Returns true if method is remapped in C# (i.e. using a namespace)
func _is_remapped_method(method: String) -> bool:
	return method in REMAP_METHODS

## Returns true if string is presumably a constant
## THIS_IS_A_CONSTANT
func _is_constant(string: String) -> bool:
	return string.casecmp_to(string.to_upper()) == 0


## Returns true if string is "true" or "false"
func _is_bool_exp(string: String) -> bool:
	return string in ["true", "false"]

## Return true if string begins with "return"
func _is_return(string: String) -> bool:
	return string.begins_with("return")


## Returns true if string begins with [ and has no commas
func _is_subscription(string: String) -> bool:
	return string.begins_with("[") and string.find(",") == -1


## Returns true if string begins with [
func _is_array(string: String) -> bool:
	return string.begins_with("[")


## Returns true if there is a slash in the string
## We really don't have any chance to securly distingish a property
## string from a normal subscription string
func _is_probably_property_string(string: String) -> bool:
	return string.begins_with("[") && string.find("/") != -1


## Returns true if string begins with class
func _is_class(string: String) -> bool:
	return string.begins_with("class")






### 						Get Parser						  ###
# Get Parser take snippets of a line and return them processed	#
# Those parser should not generate complete lines				#


## Returns return value of string
func _get_return_value(string: String) -> String:
	return string.substr(6).strip_edges()

## Returns type of variable declaration
func _get_type_from_td(string: String) -> String:
	var is_inferred := string.count(":=") > 0
	if is_inferred:
		return ""
	return string.split(":")[1].split("=")[0].strip_edges()


## Returns [name, type, default value] # null: valid | "": invalid
func _get_type_and_default_value(string: String) -> Array:
	var arg_name = ""
	var type = null
	var default_value = null
	if string.count(":=") > 0:
		var default_split := string.split(":=")
		if default_split.size() > 1:
			default_value = default_split[1].strip_edges()
			arg_name = default_split[0].strip_edges()
		else:
			arg_name = default_split[0]
			default_value = ""
	elif string.count(":") > 0:
		var split := string.split(":")
		if split.size() > 1:
			arg_name = split[0]
			if split[1].count("=") > 0:
				var default_split = (split[1] as String).split("=")
				if default_split.size() > 1:
					type = default_split[0]
					default_value = default_split[1]
				else:
					type = default_split[0]
					default_value = ""
			else:
				type = split[1].strip_edges()
	elif string.count("=") > 0:
		var split := string.split("=")
		if split.size() > 1:
			arg_name = split[0]
			default_value = split[1]
		else:
			arg_name = split[0]
			default_value = ""
	else:
		arg_name = string
	if type != null:
		type = type.strip_edges()
	if default_value != null:
		default_value = default_value.strip_edges()
	return [arg_name.strip_edges(), type, default_value]


## Returns variable name from declaration
func _get_var_name_from_d(string: String) -> String:
	var end = -1
	if string.count(":=") > 0:
		end = string.find(":=") - 3
	elif string.count(":") > 0:
		end = string.find(":") - 3
	elif string.count("=") > 0:
		end = string.find("=") - 3
	return string.substr(3, end).strip_edges()


## Returns function name from declaration
func _get_function_name_from_d(string: String) -> String:
	var begin = 12 if _is_static_function(string) else 5
	if string.count("(") == 0:
		return string.substr(begin)
	return string.substr(begin, string.find("(") - begin).strip_edges()


## Returns the return value of function declaration
func _get_function_retval(string: String) -> String:
	var arrow := string.find("->") + 2
	if arrow == 1:
		return ""
	var colon := string.find_last(":")
	if colon == -1:
		colon += arrow
	return string.substr(arrow, colon - arrow).strip_edges()


## Returns a list of the arguments of function declaration
## List structure: [[name, type, default_value], ...]
func _get_function_arguments(string: String) -> Array:
	var begin = string.find("(") + 1
	if begin == 0:
		return []
	var end = string.find(")")
	if end < begin:
		end = begin - 1
	var args := []
	var argstr := string.substr(begin, end - begin)
	if argstr.empty():
		return []
	for arg in argstr.split(","):
		args.push_back(_get_type_and_default_value(arg))
	return args


## Returns the var converted if declared in a local block
## Returns empty string if not found
func _get_var_in_local_vars(string: String, lsv) -> Array:
	for indent in lsv:
		if lsv[indent].has(string):
			return lsv[indent][string]
	return []


## Returns the right side of an assignment
func _get_assignment(string: String) -> String:
	return _split_assignment(string)[2].strip_edges()


## Returns the math expression
func _get_math(string: String) -> Array:
	assert(false) # Unimplemented
	return []


## Returns the C# variant of the the method
func _get_remapped_method(method: String) -> String:
	assert(_is_remapped_method(method))
	return REMAP_METHODS[method]


## Returns the correct comma position after closing brace
func _get_correct_comma(argstr: String) -> int:
	var brace_stack := [true]
	var end_brace := -1
	var search_pos := argstr.find("(") + 1
	while !brace_stack.empty():
		var bl = argstr.find("(", search_pos)
		var br = argstr.find(")", search_pos)
		if bl != -1 && (bl < br || br == -1):
			brace_stack.push_back(true)
			search_pos = bl + 1
		elif br != -1 && (br < bl || bl == -1):
			brace_stack.pop_back()
			search_pos = br + 1
			end_brace = br
		else: break
	var comma = argstr.find(",", end_brace)
	if comma == -1:
		return argstr.length()
	return comma


func _get_get_node(string: String) -> String:
	print(string)
	if string.begins_with("\""):
		return string.substr(0, string.find("\"", 1) + 1)
	var dot := string.find(".", 0)
	var space := string.find(" ", 0)
	var end = dot if (dot < space && dot != -1) || space == -1 else space
	return string.substr(0, end)


### 			Converters 				  ###
# Converters take input and output Strings! #

## Returns C# "if"
func _convert_if(string: String) -> String:
	return "if (" + string.substr(3, string.find(":") - (3 if string.find(":") != -1 else 0)).strip_edges() + ")"


## Returns C# "else if" from "elif"
func _convert_elif(string: String) -> String:
	return "else if (" + string.substr(5, string.find(":") - (5 if string.find(":") != -1 else 0)).strip_edges() + ")"


## Converts Class.new(...) to new Class(...)
func _convert_constructor(string: String) -> String:
	string = string.strip_edges().replace(".new(", "(")
	return "new " + string


## Converts extends and class_name to a proper class header
func _convert_file_scope_to_cs(line: int, string: String) -> String:
	var lines := string.split("\n", false)
	var is_tool := false
	var classname_line := ""
	var extends_line := ""
	for l in lines:
		var st: String = l
		if st.begins_with("tool"):
			is_tool = true
		elif st.begins_with("class_name"):
			classname_line = st
		elif st.begins_with("extends"):
			extends_line = st
		else:
			print("[]",l,"[]")
			assert(false) # Cached garbage. FIX ME
	if extends_line.empty() && classname_line.empty():
		return "" # We don't have a global scope script
	var cname := "?CLASS_NAME?"
	if classname_line.empty():
		warn(line, "C# needs a class name.")
	else:
		cname = classname_line.substr(11)
		cname = cname.substr(0, cname.find(",")).strip_edges()
	var extends_class := ""
	if extends_line.empty():
		extends_class = "?BASECLASS?"
		warn(line, "Expected a base class")
	else:
		extends_class = extends_line.substr(8).strip_edges()
	var tool_line = "[Tool]\n" if is_tool else ""
	return tool_line + "public class " + cname + " : " + extends_class + "\n"


## Converts the output of _parse_statement into C# Code
func _convert_statement(line: int, statement: Array, gsv, lsv, usings, place_semicolon := true) -> String:
	var place_dot := [
		"var",
		"method",
		"string",
		"get_node",
	]
	var result := ""
	var previous = ""
	var i := 0
	for s in statement:
		match s[0]:
			"pass":
				place_semicolon = false
				pass
			"var":
				if previous in place_dot:
					result += "."
				if s[1] in gsv:
					result += gsv[s[1]][0]
				elif _var_in_local_vars(s[1], lsv):
					result += _get_var_in_local_vars(s[1], lsv)[0]
				elif s[1] == "self":
					result += "this"
				else:
					# We have to assume, that the variable is declared in a parent class
					var is_private := _is_private(s[1])
					if is_private:
						warn(line, "Variable %s looks private, but is not declared in this file" % s[1])
					result += _pascal(s[1], is_private)
				previous = "var"
				pass
			"constructor":
				if previous in place_dot:
					result += "."
				result += "new %s(" % s[1]
				var j = 0
				for args in s[2][0][2]:
					j += 1
					result += _convert_statement(line, args, gsv, lsv, usings, false)
					if j < s[2][0][2].size():
						result += ", "
				result += ")"
			"method":
				if previous in place_dot:
					result += "."
				var method = ""
				if _is_remapped_method(s[1]):
					method = _get_remapped_method(s[1]) + "(%s)"
				elif _is_builtin(s[1]):
					# We have a constructor
					method = _convert_builtin(s[1], !s[2].empty())
				else:
					method = _pascal(s[1], _is_private(s[1])) + "(%s)"
				_parse_using(s[1], usings)
				var is_connect = s[1].begins_with("connect")
				var connect_same_method = false
				var j = 0
				var arg_str = ""
				for args in s[2]:
					j += 1
					var part = _convert_statement(line, args, gsv, lsv, usings, false)
					if is_connect:
						if j == 2:
							connect_same_method = part.begins_with("this");
						elif j == 3 && connect_same_method:
							part = "nameof(%s)" % _pascal(part.substr(1, part.length() - 2))
					arg_str += part
					if j < s[2].size():
						arg_str += ", "
				if method.find("%s") == -1:
					result += method
				else:
					result += method % arg_str
				
				previous = "method"
				pass
			"assignment", "comparison", "math":
				result += _convert_statement(line, s[1], gsv, lsv, usings, false) + " %s " % s[2] + \
						_convert_statement(line, s[3], gsv, lsv, usings, false)
				previous = "assignment/comparison"
			"get_node":
				result += "GetNode(\"%s\")" % s[1]
				previous = "get_node"
			"string":
				result += s[1]
				previous = "string"
				pass
			"int", "float", "bool":
				result += s[1]
				previous = "int/float/bool"
			"const":
				if previous in place_dot:
					result += "."
				result += s[1]
				warn(line, "If constant is enum refer to documentation for correct syntax.")
				previous = "const"
			"return":
				result += "return " + _convert_statement(line, s[1], gsv, lsv, usings, false)
				previous = "return"
			"array":
				var elements := ""
				for e in s[1]:
					elements += _convert_statement(line, e, gsv, lsv, usings, false) + ", "
				elements.erase(elements.length() - 2, 2)
				result += BUILTIN_CLASSES["Array"][1] % elements
			"property":
				result += "[%s]" % s[1]
				previous = "property"
			"subscription":
				var type = s[1][0][0] if !s[1].empty() else ""
				match type:
					"int":
						if int(s[1][0][1]) < 0:
							result += "[%s.Count %s]" % [result, s[1][0][1]]
						else:
							result += "[%s]" % s[1][0][1]
					_:
						result += "[%s]" % _convert_statement(line, s[1], gsv, lsv, usings, false)
				previous = "subscription"
			"?":
				warn(line, "Expression %s is unrecognized!" % s[1])
				pass
			var other:
				print("type '%s' is unrecognized! Content:" % other, s)
				warn(line, "type '%s' is unrecognized! This is a Bug and should be reported" % other)
		i += 1
	if place_semicolon:
		result += ";"
	return result



func _convert_builtin(type: String, has_args := false, as_type := false) -> String:
	type = type.substr(0, type.find("(")).strip_edges()
	if BUILTIN_CLASSES[type] == null:
		return type if as_type else "new "+type+"(%s)"
	elif BUILTIN_CLASSES[type] is Array:
		if as_type:
			return BUILTIN_CLASSES[type][0]
		elif has_args:
			return "new " + BUILTIN_CLASSES[type][1]
		else:
			return "new " + BUILTIN_CLASSES[type][1] % ""
	else:
		if has_args:
			return type if as_type else "new "+type+"(%s)"
		else:
			return BUILTIN_CLASSES[type]


### 			Parser				  ###
# Parser read complex input and output	#
# the result structured.				#

## Parses a variable declaration and output converted code
func _parse_declaration(line: int, global_scope: bool, string: String, gsv, lsvi, lsv, usings) -> String:
	var result := ""
	if global_scope: # Include access modifier in global scope
		result += "private " if _is_private_var(string) else "public "
	var info := _parse_variable_d(string, gsv, lsv)
	if info[1] == null:
		info[1] = "?VAR?"
		warn(line, "Type of declaration is unknown")
	if info[3]:
		if info[3] == 1:
			warn(line, "Type is inferred from a number. This is error-prone. Set the type explicit!")
		elif info[3] == 2:
			warn(line, "Type is dependent on a variable. This is can lead to unexpected changes.")
	if info[0] == null:
		warn(line, "Expected variable name")
		info[0] = "?NAME?"
	else:
		if global_scope:
			var vname = _pascal(info[0], _is_private(info[0]))
			gsv[info[0]] = [vname, info[1]]
			info[0] = vname
		else:
			var vname =  _camelCase(info[0], false)
			lsvi[info[0]] = [vname, info[1]]
			info[0] = vname
	if _is_builtin(info[1]):
		info[1] = _convert_builtin(info[1], false, true)
	result += info[1] + " " + info[0]
	if info[2] != null:
		result += " = "
		if info[2].empty():
			warn(line, "Expected assignment")
			result += "?ASSIGNMENT?"
		else:
			if _is_constructor(info[2]):
				result += _convert_constructor(info[2])
			else:
				result += _convert_statement(line, _parse_statement(line, info[2]), gsv, lsv, usings, false)
	result += ";"
	return result


## Parses ordinary code and tokenizes it
func _parse_statement(line: int, string: String) -> Array:
	var res := []
	var i := 0
	var skip_math := false
	while !string.empty():
		string = string.strip_edges()
		i += 1
		#print("[%d] " % i, string)
		if _is_string(string):
			res.push_back(["string", string])
			string = ""
		elif string.is_valid_integer():
			res.push_back(["int", string])
			string = ""
		elif string.is_valid_float():
			res.push_back(["float", string])
			string = ""
		elif _is_bool_exp(string):
			res.push_back(["bool", string])
			string = ""
		elif _is_return(string):
			res.push_back(["return", _parse_statement(line, _get_return_value(string))])
			string = ""
		elif _is_pass(string):
			res.push_back(["pass"])
			string = ""
		elif _is_probably_property_string(string):
			var end = string.find("]")
			end -= 1 if end != -1 else 0
			res.push_back(["property", string.substr(1, end)])
			warn(line, "Possible Property. Please use .get or .set instead")
			if end == -1:
				string = ""
			else:
				string.erase(0, end + 3)
		elif _is_subscription(string):
			var end = string.find("]")
			end -= 1 if end != -1 else 0
			res.push_back(["subscription", _parse_statement(line, string.substr(1, end))])
			if end == -1:
				string = ""
			else:
				string.erase(0, end + 3)
		elif _is_array(string):
			var end = string.find("]")
			var last_comma := 1
			var comma := string.find(",")
			var elements := []
			while comma != -1:
				var debug := string.substr(last_comma, comma - last_comma)
				elements.push_back(_parse_statement(line, string.substr(last_comma, comma - last_comma)))
				last_comma = comma + 1
				comma = string.find(",", last_comma)
			elements.push_back(_parse_statement(line, string.substr(last_comma, end - last_comma)))
			res.push_back(["array", elements])
			if end == -1:
				string = ""
			else:
				string.erase(0, end + 1)
		elif _is_get_node(string):
			var node_path = _get_get_node(string.right(1))
			res.push_back(["get_node", node_path])
			string = string.substr(node_path.length() + 2)
		elif _is_constructor(string):
			var dot = string.find(".")
			var end = _get_correct_comma(string.substr(dot + 4))
			res.push_back([
				"constructor",
				string.substr(0, dot).strip_edges(),
				_parse_statement(line, string.substr(dot + 4, end))
				])
			if string.length() == dot + end + 6:
				string = ""
			else:
				string = string.substr(dot + end + 6)
		elif _is_method(string):
			var method_brace_l = string.find("(")
			var method_brace_r = string.find_last(")")
			var m = ["method", string.substr(0, method_brace_l), []]
			var last_comma = method_brace_l + 1
			var comma = string.find(",", last_comma)
			
			while comma != -1:
				var s := string.substr(last_comma, comma - last_comma).strip_edges()
				if s.find("(") != -1:
					var correct = _get_correct_comma(string.substr(last_comma))
					if correct != -1:
						s = string.substr(last_comma, correct).strip_edges()
						comma = last_comma + correct
				if !s.empty():
					m[2].push_back(_parse_statement(line, s))
				last_comma = comma + 1
				comma = string.find(",", last_comma)
				if comma < method_brace_r:
					method_brace_r = string.find(")", comma)
			
			var length = method_brace_r
			if length != -1:
				length -= last_comma
			var s = string.substr(last_comma, length).strip_edges().rstrip(")")
			if !s.empty():
				m[2].push_back(_parse_statement(line, s))
			if method_brace_r != -1:
				method_brace_r += 2
			string.erase(0, method_brace_r)
			res.push_back(m)
		elif !skip_math && _is_math(string):
			var math = _split_math(string)
			var data = ["math", _parse_statement(line, math[0]),
					 math[1], _parse_statement(line, math[2])]
			for d in data[1]:
				if d[0] == "subscription":
					skip_math = true;
					break
			if skip_math:
				continue
			res.push_back(data)
			print(res[-1])
			string = ""
		elif _is_comparison(string):
			var comparison = _split_comparison(string)
			res.push_back(["comparison", _parse_statement(line, comparison[0]),
					 comparison[1], _parse_statement(line, comparison[2])])
			string = ""
		elif _is_assignment(string):
			var assignment = _split_assignment(string)
			res.push_back(["assignment", _parse_statement(line, assignment[0]),
					 assignment[1], _parse_statement(line, assignment[2])])
			string = ""
		elif _is_constant(string):
			res.push_back(["const", string])
			string = ""
		elif _is_var(string):
			var dot = string.find(".")
			var bracket = string.find("[")
			#var space = string.find (" ")
			var use_dot = (dot < bracket && dot != -1) || (bracket == -1)
			var var_end = dot if use_dot else bracket
			#var_end = space if space < var_end && space != -1 else var_end
			res.push_back(["var", string.substr(0, var_end)])
			if var_end != -1:
				string = string.substr(var_end + (1 if use_dot else 0))
			else:
				string = ""
		# Reset skipper
		skip_math = false
	if !string.empty():
		# Something unspecified is left (Likely a problem of this func not parsing everything)
		res.push_back(["?", string])
	return res


## Parses variable declaration and does basic type guessing
## Structure: [name, type, default_value, type_unsafe:bool]
func _parse_variable_d(string: String, gsv, lsv) -> Array:
	var result = [null, null, null, false]
	if _is_typed_declaration(string) && !_get_type_from_td(string).empty():
		result[1] = _get_type_from_td(string)
	var vname = _get_var_name_from_d(string)
	if !vname.empty():
		result[0] = vname
	if _is_initialization(string):
		var val := _get_assignment(string)
		if !val.empty():
			if result[1] == null:
				# We try to deduct the type of the assignment
				if val.is_valid_integer():
					result[1] = "int"
					result[3] = 1
				elif val.is_valid_float():
					result[1] = "float"
					result[3] = 1
				elif _is_string(val) || _is_constructor(val) || _is_builtin(val):
					result[1] = "var" # We use var here, since a string is safely deducted
				elif _is_local_var(val, lsv):
					result[1] = _get_var_in_local_vars(val, lsv)[1]
					result[3] = 2
				elif _is_global_var(val, gsv):
					result[2] = gsv[val][1]
					result[3] = 2
		result[2] = val
	return result


## Returns the assignment expression as
## [left side, operator, right side]
func _split_math(string: String) -> Array:
	for op in MATH_OPERATORS:
		var pos = string.find(op)
		if pos != -1:
			return [string.substr(0, pos).strip_edges(), op, string.substr(pos + op.length())]
	assert(false)
	return []


## Returns the assignment expression as
## [left side, operator, right side]
func _split_assignment(string: String) -> Array:
	for op in ASSIGNMENT_OPERATORS:
		var pos = string.find(op)
		if pos != -1:
			return [string.substr(0, pos).strip_edges(), op, string.substr(pos + op.length())]
	assert(false)
	return []


## Returns the comparison expression as
## [left side, operator, right side]
func _split_comparison(string: String) -> Array:
	for op in COMPARISON_OPERATORS:
		var pos = string.find(op)
		if pos != -1:
			return [string.substr(0, pos).strip_edges(), op, string.substr(pos + op.length())]
	assert(false)
	return []


## Adds using to the using dict, if method requires it
func _parse_using(method: String, usings):
	if method in METHOD_USINGS:
		if !METHOD_USINGS[method] in usings:
			usings.push_back(METHOD_USINGS[method])





### Callbacks ###


func _on_Source_text_changed():
	generate_output()
	pass # Replace with function body.


func _on_Regenerate_pressed():
	generate_output()
	pass # Replace with function body.


func _on_CSharp_toggled(button_pressed):
	generate_output()
	pass # Replace with function body.


func _on_Typeless_toggled(button_pressed):
	generate_output()
	pass # Replace with function body.


func _on_EscapeXML_toggled(button_pressed):
	generate_output()
	pass # Replace with function body.


func _on_GDScript_toggled(button_pressed):
	generate_output()
	pass # Replace with function body.


func _on_BeDumb_toggled(button_pressed):
	generate_output()
	pass # Replace with function body.


func _on_ReportBug_pressed():
	generate_output()
	var source = $HSplitContainer/Source/Source.text
	var output = $HSplitContainer/VSplitContainer/Output/Output.text
	var warnings = $HSplitContainer/VSplitContainer/Warnings/Warnings.text
	
	var body = """**Version:** %s

**Description of the problem:**

**Steps to reproduce:**

**Code:**
<!-- Please fill in the code -->
<details>
<summary>Source Code</summary>

```gdscript
%s
```

</details>
<details>
<summary>Output</summary>

```csharp
%s
```

</details>
<details>
<summary>Expected Output</summary>

```csharp

```

</details>
<details>
<summary>Warnings</summary>

```console
%s
```

</details>"""

	var replaces = {
		"%": "%25",
		"\n":"%0A",
		"#": "%23",
		";": "%3B",
	}
	for r in replaces:
		warnings = warnings.replace(r, replaces[r])
		source = source.replace(r, replaces[r])
		output = output.replace(r, replaces[r])
	

	body = (body % [VERSION, source, output, warnings]).replace("\n", "%0A") 

	OS.shell_open(GITHUB_URL + "issues/new?body=%s" % body)
	
	# Create and open popup with instructions
	var brp : AcceptDialog = get_node(bug_report_popup)
	brp.get_close_button().hide()
	var t = brp.dialog_text
	brp.dialog_text = brp.dialog_text % [GITHUB_URL + "issues", VERSION]
	var btn_copy = brp.add_button("Copy Link", false, "copy")
	var btn_ok = brp.add_button("Browser opend", false, "ok")
	brp.get_ok().hide()
	brp.popup_centered()
	
	# Wait for an answer in the popup
	var action = yield(brp, "custom_action")
	if action == "copy":
		OS.clipboard = GITHUB_URL + "issues/new?body=%s" % body
	btn_copy.queue_free()
	btn_ok.queue_free()
	brp.get_ok().show()
	brp.hide()
	brp.dialog_text = t
	pass # Replace with function body.

func _brp_custom_action(action, link):
	printt(action, link)
	if action == "Copy Link":
		print("copied")
		OS.clipboard = link


func _on_BugReport_custom_action(action, extra_arg_0):
	pass # Replace with function body.


func _on_Paste_pressed():
	get_node(paste_bug).popup_centered()


func _on_About_pressed():
	get_node(about_popup).popup_centered()
	pass # Replace with function body.
