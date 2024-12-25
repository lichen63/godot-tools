@tool
extends Control

var selected_files: PackedStringArray = PackedStringArray()

@onready var select_file_dialog: FileDialog = $SelectFileDialog
@onready var spritesheet_preview: Control = $Preview/SpritesheetPreview
@onready var size_x_edit: LineEdit = $PropertyContainer/SpritesheetProperty/SizeProperty/SizeValue/X
@onready var size_y_edit: LineEdit = $PropertyContainer/SpritesheetProperty/SizeProperty/SizeValue/Y
@onready var margin_edit: LineEdit = $PropertyContainer/SpritesheetProperty/MarginProperty/Value
@onready var error_dialog: AcceptDialog = $ErrorDialog

func _on_select_file_pressed() -> void:
    self.select_file_dialog.show()

func _on_select_file_dialog_file_selected(path: String) -> void:
    self.selected_files.push_back(path)

func _on_select_file_dialog_files_selected(paths: PackedStringArray) -> void:
    self.selected_files = paths
    
func _on_select_file_dialog_confirmed() -> void:
    self.clear_preview_images()
    self.show_images_on_preview(self.selected_files)

func _on_select_file_dialog_canceled() -> void:
    self.selected_files.clear()

func load_image_as_texture(file_path: String) -> TextureRect:
    var texture_rect := TextureRect.new()
    var image:= Image.load_from_file(file_path)
    texture_rect.texture = ImageTexture.create_from_image(image)
    return texture_rect

func clear_preview_images() -> void:
    for child in self.spritesheet_preview.get_children():
        self.spritesheet_preview.remove_child(child)
        child.queue_free()

func get_and_validate_input(input: LineEdit) -> int:
    var text := input.text
    if not text.is_valid_int():
        self.show_error_with_message("[%s] is not a valid integer" % input.get_path())
        return input.placeholder_text.to_int()
    return text.to_int()

func show_error_with_message(message: String) -> void:
    self.error_dialog.dialog_text = message
    self.error_dialog.show()

func show_images_on_preview(files: PackedStringArray) -> void:
    var margin_value := self.get_and_validate_input(self.margin_edit)
    var size_row_value := self.get_and_validate_input(self.size_x_edit)
    var size_col_value := self.get_and_validate_input(self.size_y_edit)
    var current_x := 0
    var current_y := 0
    var column_count := 0
    for file_path in files:
        var texture_rect := self.load_image_as_texture(file_path)
        var image_size := texture_rect.texture.get_size()
        if current_x + image_size.x + margin_value > size_row_value:
            current_x = 0
            current_y += image_size.y + margin_value
            column_count = 0
        texture_rect.position = Vector2(current_x, current_y)
        current_x += image_size.x + margin_value
        column_count += 1
        self.spritesheet_preview.add_child(texture_rect)

func _on_test_1_pressed() -> void:
    self.clear_preview_images()
    var files = PackedStringArray()
    for i in range(1, 11):
        files.append("res://sample/sprite_images/character/Attack_%d.png" % i)
        
    self.show_images_on_preview(files)
