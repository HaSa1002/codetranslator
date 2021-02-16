class_name Parser
extends Object

signal warning_generated(line, string)


func warn(line: int, string: String) -> void:
	emit_signal("warning_generated", line, string)

### 						Get Parser						  ###
# Get Parser take snippets of a line and return them processed	#
# Those parser should not generate complete lines				#


## Returns converison type
static func get_isas(string: String) -> String:
	return string.substr(2).strip_edges()


static func get_in(string: String) -> Array:
	return Array(string.split(" in "))


## Returns position of the first occurrence of [.,<space>,<comma>,[,(]
static func get_end_of_expression(string: String) -> int:
	var position := 0
	for i in string:
		if i in [".", " ", "[", "]", "(", ")", ","]:
			return position
		position += 1
	return -1


## Returns return value of string
static func get_return_value(string: String) -> String:
	return string.substr(6).strip_edges()

## Returns type of variable declaration
static func get_type_from_td(string: String) -> String:
	var is_inferred := string.count(":=") > 0
	if is_inferred:
		return ""
	var colon := Utility.find_not_in_string(string, ":")
	if colon == -1:
		return ""
	return string.right(colon + 1).split("=")[0].strip_edges()


## Returns [name, type, default value] # null: valid | "": invalid
static func get_type_and_default_value(string: String) -> Array:
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


## Returns function name from declaration
static func get_function_name_from_d(string: String) -> String:
	var begin = 12 if Detector.is_static_function(string) else 5
	if string.count("(") == 0:
		return string.substr(begin)
	return string.substr(begin, string.find("(") - begin).strip_edges()


## Returns the return value of function declaration
static func get_function_retval(string: String) -> String:
	var arrow := string.find("->") + 2
	if arrow == 1:
		return ""
	var colon := string.find_last(":")
	if colon == -1:
		colon += arrow
	return string.substr(arrow, colon - arrow).strip_edges()


## Returns a list of the arguments of function declaration
## List structure: [[name, type, default_value], ...]
static func get_function_arguments(string: String) -> Array:
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
		args.push_back(get_type_and_default_value(arg))
	return args


## Returns the right side of an assignment
static func get_assignment(string: String) -> String:
	return Utility.split_assignment(string)[2].strip_edges()


## Returns the math expression
static func get_math(string: String) -> Array:
	assert(false) # Unimplemented
	return []


## Returns the correct comma position after closing brace
static func get_correct_comma(string: String, offset := 0) -> int:
	var braces := 0
	for i in string.length():
		if string[i] == "(":
			braces += 1
			continue
		if string[i] == ")":
			braces -= 1
			continue
		if i < offset:
			continue
		if braces == 0 && string[i] == ",":
			return i
	return -1


static func get_nodepath(string: String) -> String:
	var end = string.find('"', 2)
	if end != -1:
		end -= 2
	return string.substr(2, end)


static func get_getnode(string: String) -> String:
	if string.begins_with("\""):
		return string.substr(0, string.find("\"", 1) + 1)
	var end = get_end_of_expression(string)
	return string.substr(0, end)


static func get_brace_content(string: String) -> String:
	var braces := 0
	var first_brace := -1
	for i in string.length():
		if string[i] == "(":
			if braces == 0:
				first_brace = i + 1
			braces += 1
			continue
		if string[i] == ")":
			braces -= 1
		if braces == 0 && first_brace != -1:
			return string.substr(first_brace, i - first_brace)
	return string.substr(first_brace)


## Adds using to the using dict, if method requires it
static func parse_using(method: String, usings):
	if method in Utility.METHOD_USINGS:
		if !Utility.METHOD_USINGS[method] in usings:
			usings.push_back(Utility.METHOD_USINGS[method])



### 			Parser				  ###
# Parser read complex input and output	#
# the result structured.				#


## Parses ordinary code and tokenizes it
func parse_statement(line: int, string: String) -> Array:
	var res := []
	var i := 0
	var skip_math := false
	while !string.empty():
		string = string.strip_edges()
		i += 1
		#print("[%d] " % i, string)
		if Detector.is_string(string):
			res.push_back(["string", string])
			string = ""
		elif string.is_valid_integer():
			res.push_back(["int", string])
			string = ""
		elif string.is_valid_float():
			res.push_back(["float", string])
			string = ""
		elif Detector.is_bool_exp(string):
			res.push_back(["bool", string])
			string = ""
		elif Detector.is_return(string):
			res.push_back(["return", parse_statement(line, get_return_value(string))])
			string = ""
		elif Detector.is_pass(string):
			res.push_back(["pass"])
			string = ""
		elif Detector.is_probably_property_string(string):
			var end = string.find("]")
			end -= 1 if end != -1 else 0
			res.push_back(["property", string.substr(1, end)])
			warn(line, "Possible Property. Please use .get or .set instead")
			if end == -1:
				string = ""
			else:
				string.erase(0, end + 3)
		elif Detector.is_subscription(string):
			var end = string.find("]")
			end -= 1 if end != -1 else 0
			res.push_back(["subscription", parse_statement(line, string.substr(1, end))])
			if end == -1:
				string = ""
			else:
				string.erase(0, end + 3)
		elif Detector.is_array(string):
			var end = string.find("]")
			var last_comma := 1
			var comma := string.find(",")
			var elements := []
			while comma != -1:
				var debug := string.substr(last_comma, comma - last_comma)
				elements.push_back(parse_statement(line, string.substr(last_comma, comma - last_comma)))
				last_comma = comma + 1
				comma = string.find(",", last_comma)
			elements.push_back(parse_statement(line, string.substr(last_comma, end - last_comma)))
			res.push_back(["array", elements])
			if end == -1:
				string = ""
			else:
				string.erase(0, end + 1)
		elif Detector.is_getnode(string):
			var node_path = get_getnode(string.right(1))
			if node_path.begins_with('"'):
				node_path.erase(0, 1)
				node_path.erase(node_path.length() - 1, 1)
				res.push_back(["get_node", node_path])
				string = string.substr(node_path.length() + 3)
			else:
				res.push_back(["get_node", node_path])
				string = string.substr(node_path.length() + 1)
		elif Detector.is_nodepath(string):
			var nodepath = get_nodepath(string)
			res.push_back(["nodepath", nodepath])
			string = string.substr(nodepath.length() + 3)
		elif Detector.is_constructor(string):
			var dot = string.find(".")
			var brace_content = get_brace_content(string)
			var end = brace_content.length()
			res.push_back([
				"constructor",
				string.substr(0, dot).strip_edges(),
				parse_statement(line, "new(%s)" % brace_content)
				])
			string = string.substr(dot + end + 6)
		elif Detector.is_method(string):
			var m := ["method", string.substr(0, string.find("(")), []]
			var brace_content := get_brace_content(string)
			var last_comma := 0
			var comma := Utility.find_not_in_string(brace_content, ",")
			while comma != -1:
				var s: String = brace_content.substr(last_comma, comma - last_comma).strip_edges()
				if s.find("(") != -1:
					var correct = get_correct_comma(brace_content.substr(last_comma))
					if correct != -1:
						s = brace_content.substr(last_comma, correct).strip_edges()
						comma = last_comma + correct
					else:
						comma = -1
				if !s.empty():
					m[2].push_back(parse_statement(line, s))
				last_comma = comma + 1
				comma = get_correct_comma(brace_content, last_comma)
			
			var s = brace_content.substr(last_comma).strip_edges()
			if !s.empty():
				m[2].push_back(parse_statement(line, s))
			string = string.substr(m[1].length() + brace_content.length() + 2)
			res.push_back(m)
		elif Detector.is_group(string):
			var position := 0
			var braces := 0
			for character in string:
				if character == "(":
					braces += 1
				elif character == ")":
					braces -= 1
				if braces == 0:
					break
				position += 1
			res.push_back(["group", parse_statement(line, string.substr(1, position - 1))])
			string.erase(0, position + 1)
		elif Detector.is_is(string):
			res.push_back(["is", get_isas(string)])
			string = ""
		elif !skip_math && Detector.is_math(string):
			var math = Utility.split_math(string)
			var data = ["math", parse_statement(line, math[0]),
				math[1], parse_statement(line, math[2])]
			for d in data[1]:
				if d[0] == "subscription":
					skip_math = true;
					break
			if skip_math:
				continue
			res.push_back(data)
			print(res[-1])
			string = ""
		elif Detector.is_comparison(string):
			var comparison = Utility.split_comparison(string)
			res.push_back(["comparison", parse_statement(line, comparison[0]),
				comparison[1], parse_statement(line, comparison[2])])
			string = ""
		elif Detector.is_negation(string):
			res.push_back(["negation"])
			if string[0] == "!":
				string.erase(0, 1)
			else:
				string.erase(0, 3)
		elif Detector.is_as(string):
			res.push_back(["as", get_isas(string)])
			string = ""
		elif Detector.is_in(string):
			var sides := get_in(string)
			res.push_back(["in", parse_statement(line, sides[0]), parse_statement(line, sides[1] if sides.size() > 1 else [])])
			string = ""
		elif Detector.is_assignment(string):
			var assignment = Utility.split_assignment(string)
			res.push_back(["assignment", parse_statement(line, assignment[0]),
				assignment[1], parse_statement(line, assignment[2])])
			string = ""
		elif Detector.is_constant(string):
			res.push_back(["const", string])
			string = ""
		elif Detector.is_var(string):
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
		if string.begins_with("."):
			# Workaround. Maybe put into attribute?
			string.erase(0, 1)
		skip_math = false
	if !string.empty():
		# Something unspecified is left (Likely a problem of this func not parsing everything)
		res.push_back(["?", string])
	return res


## Parses variable declaration and does basic type guessing
## Structure: [name, type, default_value, type_unsafe:bool]
static func parse_variable_d(string: String, gsv, lsv, is_const := false) -> Array:
	var result = [null, null, null, false]
	if Detector.is_typed_declaration(string) && !get_type_from_td(string).empty():
		result[1] = get_type_from_td(string)
	var vname = Utility.get_var_name_from_d(string, is_const)
	if !vname.empty():
		result[0] = vname
	if Detector.is_initialization(string):
		var val := get_assignment(string)
		if !val.empty():
			if result[1] == null:
				# We try to deduct the type of the assignment
				if val.is_valid_integer():
					result[1] = "int"
					result[3] = 1
				elif val.is_valid_float():
					result[1] = "float"
					result[3] = 1
				elif Detector.is_string(val) || Detector.is_constructor(val) || Detector.is_builtin(val):
					result[1] = "var" # We use var here, since a string is safely deducted
				elif Detector.is_local_var(val, lsv):
					result[1] = Utility.get_var_in_local_vars(val, lsv)[1]
					result[3] = 2
				elif Detector.is_global_var(val, gsv):
					result[2] = gsv[val][1]
					result[3] = 2
		result[2] = val
	return result
