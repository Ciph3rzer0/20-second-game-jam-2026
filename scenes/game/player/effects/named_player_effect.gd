@tool
class_name NamedPlayerEffect
extends PlayerEffect

const PlayerScript: GDScript  = preload("uid://bbm5sxfbhkypq")

@export var method_name : String

func apply_effect(player: Player):
	assert(player.has_method(method_name))
	player.call(method_name)

func _validate_property(property: Dictionary) -> void:
	if property.name == "method_name":
		var method_names: PackedStringArray = []
		
		# Inspect methods defined on this Resource itself
		for method_info in PlayerScript.get_script_method_list():
			var m_name: String = method_info["name"]
			
			# Filter out private (_) methods and built-in Resource methods
			if m_name.begins_with("become_"):
				method_names.append(m_name)
		
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(method_names)
