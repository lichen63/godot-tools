@tool
extends EditorPlugin


func _enter_tree() -> void:
    var editor_file_dialog := EditorFileDialog.new()
    editor_file_dialog.add_filter("*.jpg, *.jpeg, *.png", "Supported Images")


func _exit_tree() -> void:
    # Clean-up of the plugin goes here.
    pass
