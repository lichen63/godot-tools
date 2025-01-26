@tool
extends EditorPlugin


func _enter_tree() -> void:
    add_tool_menu_item("Open Spritesheet Tools", run_generator)
    get_editor_interface().get_command_palette().add_command("Open Spritesheet Tools", "addons/open_spritesheet_tools", run_generator)


func _exit_tree() -> void:
    remove_tool_menu_item("Open Spritesheet Tools")
    get_editor_interface().get_command_palette().remove_command("addons/open_spritesheet_tools")

func run_generator() -> void:
    get_editor_interface().play_custom_scene("res://addons/spritesheet_tools/control.tscn")
