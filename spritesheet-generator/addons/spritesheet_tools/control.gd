@tool
extends Control

var selected_files: PackedStringArray

@onready var select_file_dialog: FileDialog = $SelectFileDialog
@onready var spritesheet_preview: TextureRect = $SpritesheetPreview

func _on_select_file_pressed() -> void:
    self.select_file_dialog.show()

func _on_select_file_dialog_file_selected(path: String) -> void:
    self.selected_files.push_back(path)

func _on_select_file_dialog_files_selected(paths: PackedStringArray) -> void:
    self.selected_files = paths

func _on_select_file_dialog_confirmed() -> void:
    pass # Replace with function body.

func _on_select_file_dialog_canceled() -> void:
    self.selected_files.clear()
