class_name Translator
extends VBoxContainer

##
## This file contains the translator functions and callbacks for the app
## Developed by Johannes Witt
## Placed into the Public Domain
##


const GITHUB_URL = "https://github.com/HaSa1002/codetranslator/"
const VERSION = "0.7-dev (Last Build 2021-01-28 01:30)"


export var bug_report_popup : NodePath
export var about_popup : NodePath
export var paste_bug : NodePath

func _ready():
	get_node(about_popup).dialog_text = get_node(about_popup).dialog_text % VERSION
	$Controls/Paste.visible = OS.has_feature("JavaScript")


### Utility touching Scene ###

## Adds a warning to the warnings TextEdit
func warn(line : int, what : String):
	var warns : TextEdit = $HSplitContainer/VSplitContainer/Warnings/Warnings
	warns.text += "[%d] %s\n" % [line, what]
	($HSplitContainer/Source/Source as TextEdit).set_line_as_safe(line - 1, true);


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
		var generator := CsharpGenerator.new();
		var err = generator.connect("warning_generated", self, "warn")
		assert(err == OK) # Fix the signal above
		output = "[codeblocks]\n[gdscript]\n%s\n[/gdscript]\n[csharp]\n%s\n[/csharp]\n[/codeblocks]" % \
			[source, generator.generate_csharp(source)]
	if $Controls/EscapeXML.pressed:
		output = escape_xml(source)
	var tabs := int($Controls/Indention.value)
	if tabs > 0:
		var tabbed_output := ""
		for line in output.split('\n'):
			if line.empty() || line.strip_edges().empty():
				tabbed_output += "\n"
				continue
			tabbed_output += "\t".repeat(tabs) + line + "\n"
		output = tabbed_output.left(tabbed_output.length() - 1)
	$HSplitContainer/VSplitContainer/Output/Output.text = output
	pass



### Generators ###


## Escapes source code
## Replaces Tabs, &, <, >
func escape_xml(source: String) -> String:
	return source.replace("\t", "    ").replace("&", "&amp;") \
		.replace("<", "&lt;").replace(">", "&gt;")


### Callbacks ###


func _on_Source_text_changed():
	generate_output()
	pass # Replace with function body.


func _on_Regenerate_pressed():
	generate_output()
	pass # Replace with function body.


func _on_CSharp_toggled(_button_pressed):
	generate_output()
	pass # Replace with function body.


func _on_Typeless_toggled(_button_pressed):
	generate_output()
	pass # Replace with function body.


func _on_EscapeXML_toggled(_button_pressed):
	generate_output()
	pass # Replace with function body.


func _on_GDScript_toggled(_button_pressed):
	generate_output()
	pass # Replace with function body.


func _on_BeDumb_toggled(_button_pressed):
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

	if OS.shell_open(GITHUB_URL + "issues/new?body=%s" % body) != OK:
		print("There was no browser opend, i guess?")
	
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


func _on_Paste_pressed():
	get_node(paste_bug).popup_centered()


func _on_About_pressed():
	get_node(about_popup).popup_centered()
	pass # Replace with function body.


func _on_Indention_value_changed(_value):
	generate_output()
