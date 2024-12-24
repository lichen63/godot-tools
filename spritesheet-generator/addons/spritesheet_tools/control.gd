@tool
extends Control

var selected_files: PackedStringArray = PackedStringArray()
var thumbnail_size: Vector2 = Vector2(64, 64)
var rows: int = 2
var columns: int = 3
var margin: int = 10

@onready var select_file_dialog: FileDialog = $SelectFileDialog
@onready var spritesheet_preview: Control = $SpritesheetPreview

func _on_select_file_pressed() -> void:
    self.select_file_dialog.show()

func _on_select_file_dialog_file_selected(path: String) -> void:
    self.selected_files.push_back(path)

func _on_select_file_dialog_files_selected(paths: PackedStringArray) -> void:
    self.selected_files = paths

func _on_select_file_dialog_confirmed() -> void:
    for file_path in selected_files:
        self.spritesheet_preview.add_child(self.load_image_as_texture(file_path))

func _on_select_file_dialog_canceled() -> void:
    self.selected_files.clear()

func load_image_as_texture(file_path: String) -> TextureRect:
    var texture_rect := TextureRect.new()
    texture_rect.texture = ImageTexture.create_from_image(Image.load_from_file(file_path))
    return texture_rect
