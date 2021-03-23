class_name Detector
extends Object

##
## This file contains GDScript detection functions
## Developed by Johannes Witt and Hugo Locurcio
## Placed into the Public Domain
##


### 				Detectors 				  ###
# Detectors are only meant to return a bool,	#
# depending on the detected content.			#
# Detectors may be used on complete lines		#

## Returns true if string begins with as
static func is_as(string: String) -> bool:
	return string.begins_with("as ")


## Returns true if string begins with is
static func is_is(string: String) -> bool:
	return string.begins_with("is ")


static func is_in(string: String) -> bool:
	return string.find(" in ") != -1


## Returns true if string is a built-in class
static func is_builtin(string: String) -> bool:
	return string.substr(0, string.find("(")).strip_edges() in Utility.BUILTIN_CLASSES

## Returns true if string begins with $
static func is_getnode(string: String) -> bool:
	return string.begins_with("$")


## Returns true on pass
static func is_pass(string: String) -> bool:
	return string.begins_with("pass")


static func is_negation(string) -> bool:
	return string.begins_with("not") || string.begins_with("!")


## Returns true if string begins with (
static func is_group(string: String) -> bool:
	return string.begins_with("(")


static func is_nodepath(string: String) -> bool:
	return string.begins_with("@")


## Returns true if complete line is a comment
## # Comment
static func is_comment(string: String) -> bool:
	return string.begins_with("#")


## Returns true if line contains a comment
## code() # Comment
static func has_comment(string: String) -> bool:
	return string.count("#") > 0


## Returns true if line is a declaration
## var x
static func is_declaration(string: String) -> bool:
	return string.begins_with("var")


## Returns true if line is a const delcaration
## const MY_CONST
static func is_const_declaration(string: String) -> bool:
	return string.begins_with("const")


## Returns true if line is a while loop
static func is_while(string: String) -> bool:
	return string.begins_with("while")


## Returns true if line is a for or foreach loop
static func is_for(string: String) -> bool:
	return string.begins_with("for")


## Returns true if line is for loop and not has range keyword
static func is_foreach(string: String) -> bool:
	return string.find("range(") == -1


## Returns true if line is if
## if x:
static func is_if(string: String) -> bool:
	return string.begins_with("if")


## Returns true if line is elif
## elif y:
static func is_elif(string: String) -> bool:
	return string.begins_with("elif")


## Returns true if line is else
## else:
static func is_else(string: String) -> bool:
	return string.begins_with("else:")


## Returns true if line is initialization
## var x = 10
static func is_initialization(string: String) -> bool:
	return (is_declaration(string) || is_const_declaration(string)) && string.count("=") > 0


## Returns true if variable declared in line is private
## var _private
static func is_private_var(string: String) -> bool:
	return is_private(Utility.get_var_name_from_d(string, is_const_declaration(string)))


## Returns true, if string starts with underscore
static func is_private(string: String) -> bool:
	return string.begins_with("_")


## Returns true, if a variable declaration is typed
## var x : Node
## var y := ""
static func is_typed_declaration(string: String) -> bool:
	return is_declaration(string) && Utility.find_not_in_string(string, ":") > 0


## Returns true if string starts with func
static func is_function_declaration(string: String) -> bool:
	return string.begins_with("func") || string.begins_with("static")


## Returns true if function does not start with an underscore
static func is_public_function(string: String) -> bool:
	return is_function_declaration(string) && !string.substr(5).begins_with("_")


## Returns true if functions starts with an underscore
static func is_private_function(string: String) -> bool:
	return is_function_declaration(string) && string.substr(5).begins_with("_")


## Returns true if function is static func
static func is_static_function(string: String):
	return is_function_declaration(string) && string.begins_with("static")


## Returns true if function is a virtual function in Godot
## like _ready, _process, etc.
static func is_overriding_virtual_function(string: String) -> bool:
	return is_private_function(string) && string.substr(5, string.find("(") - 5) in Utility.VIRTUAL_FUNCTIONS


## Returns true if string is a virtual function name
static func is_virtual(string: String) -> bool:
	return is_private(string) && string in Utility.VIRTUAL_FUNCTIONS


## Returns true if string has an opening brace "("
static func is_function(string: String) -> bool:
	return string.count("(") > 0


## Returns true if string begins with extends, class_name, or tool
static func is_file_scope(string: String) -> bool:
	return (string.begins_with("extends")
		|| string.begins_with("class_name")
		|| string.begins_with("tool"))


## Returns true, if string is a string
## "..." -> true
static func is_string(string: String) -> bool:
	return string[0] == '"' && string[string.length() - 1] == '"'


## Returns true if next method is .new(
static func is_constructor(string: String) -> bool:
	var new_pos = string.find(".new(")
	var brace = string.find("(")
	return brace != 0 && new_pos != -1 && new_pos <= string.find(".")


## Returns true if string is a method
## ABC -> false
## ABC( -> true
## ABC. -> false
## ABC(. -> true
## ABC.( -> false
static func is_method(string: String) -> bool:
	var brace = string.find("(")
	var dot = string.find(".")
	return brace != 0 && (brace != -1 && brace < dot) || (brace != -1 && dot == -1)


## Returns true if string is potentially a variable or property
## ABC -> true
## ABC( -> false
## ABC. -> true
## ABC(. -> false
## ABC.( -> true
static func is_var(string: String) -> bool:
	var brace = string.find("(")
	var dot = string.find(".")
	return (dot < brace && dot != -1) || brace == -1


## Returns true if string was declared in local scope
static func is_local_var(string: String, local_vars) -> bool:
	for i in local_vars:
		if local_vars[i].has(string):
			return true
	return false


## Returns true if string was declared in global scope
static func is_global_var(string: String, global_vars) -> bool:
	return global_vars.has(string)


## Returns true if string contains an assignment
static func is_assignment(string: String) -> bool:
	for op in Utility.ASSIGNMENT_OPERATORS:
		var pos = Utility.find_not_in_string(string, op)
		if pos != -1:
			return true
	return false


## Returns true if string contains a mathematical expression
static func is_math(string: String) -> bool:
	for op in Utility.MATH_OPERATORS:
		var pos = Utility.find_not_in_string(string, op)
		if pos != -1:
			return true
	return false


## Returns true if string contains a bitwise operation
static func is_bitwise(string: String) -> bool:
	for op in Utility.BITWISE_OPERATORS:
		var pos = Utility.find_not_in_string(string, op)
		if pos != -1:
			return true
	return false


## Returns true if string contains an comparison
static func is_comparison(string: String) -> bool:
	for op in Utility.COMPARISON_OPERATORS:
		var pos = string.find(op)
		if pos != -1:
			return true
	return false


## Returns true if variable is declared local scope
static func var_in_local_vars(string: String, lsv) -> bool:
	return !Utility.get_var_in_local_vars(string, lsv).empty()


## Returns true if string is presumably a constant
## THIS_IS_A_CONSTANT
static func is_constant(string: String) -> bool:
	return string.casecmp_to(string.to_upper()) == 0


## Returns true if string is "true" or "false"
static func is_bool_exp(string: String) -> bool:
	return string in ["true", "false"]

## Return true if string begins with "return"
static func is_return(string: String) -> bool:
	return string.begins_with("return")


## Returns true if string begins with [ and has no commas
static func is_subscription(string: String) -> bool:
	return string.begins_with("[") and string.find(",") == -1


## Returns true if string begins with [
static func is_array(string: String) -> bool:
	return string.begins_with("[")


## Returns true if there is a slash in the string
## We really don't have any chance to securly distingish a property
## string from a normal subscription string
static func is_probably_property_string(string: String) -> bool:
	return string.begins_with("[") && string.find("/") != -1


## Returns true if string begins with class
static func _is_class(string: String) -> bool:
	return string.begins_with("class")
