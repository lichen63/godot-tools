@tool
extends Control

var selected_files: PackedStringArray = PackedStringArray()
var thumbnail_size: Vector2 = Vector2(64, 64)
var rows: int = 2
var columns: int = 3
var margin: int = 10

@onready var select_file_dialog: FileDialog = $SelectFileDialog
@onready var spritesheet_preview: Control = $Preview/SpritesheetPreview
@onready var preview_size_row: LineEdit = $PropertyContainer/SpritesheetProperty/SizeProperty/SizeValue/Row

func _on_select_file_pressed() -> void:
    self.select_file_dialog.show()

func _on_select_file_dialog_file_selected(path: String) -> void:
    self.selected_files.push_back(path)

func _on_select_file_dialog_files_selected(paths: PackedStringArray) -> void:
    self.selected_files = paths
    
func _on_select_file_dialog_confirmed() -> void:
    self.clear_preview_images()
    self.show_images_on_preview()

func _on_select_file_dialog_canceled() -> void:
    self.selected_files.clear()

func load_image_as_texture(file_path: String) -> TextureRect:
    var texture_rect := TextureRect.new()
    texture_rect.texture = ImageTexture.create_from_image(Image.load_from_file(file_path))
    return texture_rect

func clear_preview_images() -> void:
    for child in self.spritesheet_preview.get_children():
        self.spritesheet_preview.remove_child(child)
        child.queue_free()

func show_images_on_preview() -> void:
    var parent_size := self.spritesheet_preview.size
    var margin := 10
    var current_x := 0
    var current_y := 0
    var column_count := 0
    for file_path in self.selected_files:
        var texture_rect := self.load_image_as_texture(file_path)
        var image_size := texture_rect.texture.get_size()
        if current_x + image_size.x + margin > parent_size.x:
            current_x = 0
            current_y += image_size.y + margin
            column_count = 0
        texture_rect.position = Vector2(current_x, current_y)
        current_x += image_size.x + margin
        column_count += 1
        self.spritesheet_preview.add_child(texture_rect)

func _on_test_1_pressed() -> void:
    self.clear_preview_images()
    var files = PackedStringArray()
    for i in range(1, 11):
        files.append("/Users/lichenliu/Assets/Images/freeknight/png/Attack (%d).png" % i)
    var parent_size = self.spritesheet_preview.size
    var margin = 10
    var current_x = 0
    var current_y = 0
    var column_count = 0
    for file_path in files:
        var texture_rect = self.load_image_as_texture(file_path)
        var image_size = texture_rect.texture.get_size()
        if current_x + image_size.x + margin > parent_size.x:
            current_x = 0
            current_y += image_size.y + margin
            column_count = 0
        texture_rect.position = Vector2(current_x, current_y)
        current_x += image_size.x + margin
        column_count += 1
        self.spritesheet_preview.add_child(texture_rect)
