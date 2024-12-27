@tool
extends Control

var selected_files: PackedStringArray = PackedStringArray()
var preview_control_list: Array[Control] = []
var preview_cur_control_index: int = 0

@onready var select_file_dialog: FileDialog = $SelectFileDialog
@onready var preview_spritesheet: Control = $Preview/SpritesheetPreview
@onready var size_x_edit: LineEdit = $PropertyContainer/SpritesheetProperty/SizeProperty/SizeValue/X
@onready var size_y_edit: LineEdit = $PropertyContainer/SpritesheetProperty/SizeProperty/SizeValue/Y
@onready var margin_edit: LineEdit = $PropertyContainer/SpritesheetProperty/MarginProperty/Value
@onready var error_dialog: AcceptDialog = $ErrorDialog
@onready var page_number: LineEdit = $PageSwitchContainer/Number

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

func _on_page_left_pressed() -> void:
    self.show_next_preview_control(false)

func _on_page_right_pressed() -> void:
    self.show_next_preview_control(true)

func show_next_preview_control(is_next: bool) -> void:
    var next_index: int = -1
    var control_size: int = self.preview_control_list.size()
    if is_next:
        next_index = self.preview_cur_control_index + 1 if self.preview_cur_control_index < control_size - 1 else 0
    else:
        next_index = self.preview_cur_control_index - 1 if self.preview_cur_control_index > 0 else control_size - 1
    if next_index == self.preview_cur_control_index or next_index < 0 or next_index >= control_size:
        return
    self.preview_spritesheet.remove_child(self.preview_control_list[self.preview_cur_control_index])
    self.preview_spritesheet.add_child(self.preview_control_list[next_index])
    self.preview_cur_control_index = next_index
    self.update_preview_num_text()

func load_image_as_texture(file_path: String) -> TextureRect:
    var texture_rect := TextureRect.new()
    var image:= Image.load_from_file(file_path)
    texture_rect.texture = ImageTexture.create_from_image(image)
    return texture_rect

func clear_preview_images() -> void:
    self.preview_control_list.clear()
    self.preview_cur_control_index = 0
    for child in self.preview_spritesheet.get_children():
        self.preview_spritesheet.remove_child(child)
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
    var max_size_x := self.get_and_validate_input(self.size_x_edit)
    var max_size_y := self.get_and_validate_input(self.size_y_edit)
    var current_x := 0
    var current_y := 0
    var max_image_height_in_row := 0
    
    var texture_arr := []
    for file_path in files:
        var texture_rect := self.load_image_as_texture(file_path)
        texture_arr.append(texture_rect)
    
    var cur_index := 0
    var cur_control := Control.new()
    while cur_index < texture_arr.size():
        var texture_rect: TextureRect = texture_arr[cur_index]
        var image_size := texture_rect.texture.get_size()
        if current_x + image_size.x + margin_value > max_size_x:
            current_x = 0
            current_y += max_image_height_in_row + margin_value
            max_image_height_in_row = 0
        if current_y + image_size.y > max_size_y:
            self.preview_control_list.append(cur_control)
            cur_control = Control.new()
            current_x = 0
            current_y = 0
            continue
        texture_rect.position = Vector2(current_x, current_y)
        current_x += image_size.x + margin_value
        max_image_height_in_row = max(max_image_height_in_row, image_size.y)
        cur_control.add_child(texture_rect)
        cur_index += 1
    self.preview_control_list.append(cur_control)
    self.update_preview_num_text()
    self.preview_spritesheet.add_child(self.preview_control_list[self.preview_cur_control_index])

func update_preview_num_text() -> void:
    self.page_number.text = "%d/%d" % [self.preview_cur_control_index + 1, self.preview_control_list.size()]

func _on_test_1_pressed() -> void:
    self.clear_preview_images()
    var files = PackedStringArray()
    for i in range(1, 11):
        files.append("res://sample/sprite_images/character/Attack_%d.png" % i)
    for i in range(1, 11):
        files.append("res://sample/sprite_images/character/Dead_%d.png" % i)
    for i in range(1, 11):
        files.append("res://sample/sprite_images/character/Idle_%d.png" % i)
    for i in range(1, 11):
        files.append("res://sample/sprite_images/character/Jump_%d.png" % i)
    for i in range(1, 11):
        files.append("res://sample/sprite_images/character/JumpAttack_%d.png" % i)
    for i in range(1, 11):
        files.append("res://sample/sprite_images/character/Run_%d.png" % i)
    for i in range(1, 11):
        files.append("res://sample/sprite_images/character/Walk_%d.png" % i)
        
    self.show_images_on_preview(files)
