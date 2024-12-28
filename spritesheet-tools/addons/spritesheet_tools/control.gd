@tool
extends Control

var selected_files: PackedStringArray = PackedStringArray()
var preview_control_list: Array[Control] = []
var preview_cur_control_index: int = 0

@onready var select_file_dialog: FileDialog = $SelectFileDialog
@onready var size_x_edit: LineEdit = $PropertyContainer/SpritesheetProperty/SizeProperty/SizeValue/X
@onready var size_y_edit: LineEdit = $PropertyContainer/SpritesheetProperty/SizeProperty/SizeValue/Y
@onready var margin_edit: LineEdit = $PropertyContainer/SpritesheetProperty/MarginProperty/Value
@onready var error_dialog: AcceptDialog = $ErrorDialog
@onready var page_number: LineEdit = $PageSwitchContainer/Number
@onready var save_path_edit: LineEdit = $PropertyContainer/SpritesheetProperty/SavePath
@onready var preview_viewport: SubViewport = $Preview/PreviewViewportContainer/PreviewViewport

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

func _on_save_to_file_pressed() -> void:
    var save_path_string: String = self.save_path_edit.text
    if not self.is_save_path_valid(save_path_string):
        self.show_error_with_message("Invalid save path, it should begin with 'user://'")
        return
    var texture: ViewportTexture = self.preview_viewport.get_texture()
    if not texture:
        print("Failed to get texture")
        return
    var image: Image = texture.get_image()
    if image:
        var err = image.save_png(save_path_string)
        if err == OK:
            print("Image saved successfully at: ", save_path_string)
        else:
            print("Failed to save image, Error: ", err)
    else:
        print("Failed to convert texture to image")

func is_save_path_valid(save_path: String) -> bool:
    if not save_path.begins_with("user://"):
        print("Save path must begin with 'user://'")
        return false
    if not ensure_directory_exists(save_path):
        print("Failed to prepare the save directory.")
        return false
    return true

func ensure_directory_exists(save_path: String) -> bool:
    var directory_path = save_path.get_base_dir()
    if not DirAccess.dir_exists_absolute(directory_path):
        var error: Error = DirAccess.make_dir_absolute(directory_path)
        if error != OK:
            print("Failed to create directory: ", directory_path, " Error code: ", error)
            return false
    return true

func show_next_preview_control(is_next: bool) -> void:
    var next_index: int = -1
    var control_size: int = self.preview_control_list.size()
    if is_next:
        next_index = self.preview_cur_control_index + 1 if self.preview_cur_control_index < control_size - 1 else 0
    else:
        next_index = self.preview_cur_control_index - 1 if self.preview_cur_control_index > 0 else control_size - 1
    if next_index == self.preview_cur_control_index or next_index < 0 or next_index >= control_size:
        return
    self.preview_cur_control_index = next_index
    self.update_preview_num_text()
    self.update_preview_image()

func load_image_as_texture(file_path: String) -> TextureRect:
    var texture_rect: TextureRect = TextureRect.new()
    var image:Image = Image.load_from_file(file_path)
    texture_rect.texture = ImageTexture.create_from_image(image)
    return texture_rect

func clear_preview_images() -> void:
    self.preview_control_list.clear()
    self.preview_cur_control_index = 0
    for child in self.preview_viewport.get_children():
        self.preview_viewport.remove_child(child)
        child.queue_free()

func get_and_validate_input(input: LineEdit) -> int:
    var text:String = input.text
    if not text.is_valid_int():
        self.show_error_with_message("[%s] is not a valid integer" % input.get_path())
        return input.placeholder_text.to_int()
    return text.to_int()

func show_error_with_message(message: String) -> void:
    self.error_dialog.dialog_text = message
    self.error_dialog.show()

func show_images_on_preview(files: PackedStringArray) -> void:
    var margin_value: int = self.get_and_validate_input(self.margin_edit)
    var max_size_x: int = self.get_and_validate_input(self.size_x_edit)
    var max_size_y: int= self.get_and_validate_input(self.size_y_edit)
    var current_x: int= 0
    var current_y: int = 0
    var max_image_height_in_row: int = 0
    var texture_list: Array[TextureRect] = []
    for file_path: String in files:
        var texture_rect: TextureRect = self.load_image_as_texture(file_path)
        texture_list.append(texture_rect)
    var cur_index: int = 0
    var cur_control: Control = Control.new()
    while cur_index < texture_list.size():
        var texture_rect: TextureRect = texture_list[cur_index]
        var image_size: Vector2 = texture_rect.texture.get_size()
        if current_x + image_size.x + margin_value > max_size_x:
            current_x = 0
            current_y += max_image_height_in_row + margin_value
            max_image_height_in_row = 0
        if current_y + image_size.y > max_size_y:
            self.preview_control_list.append(cur_control)
            cur_control.size = Vector2(max_size_x, current_y + max_image_height_in_row)
            cur_control = Control.new()
            current_x = 0
            current_y = 0
            continue
        texture_rect.position = Vector2(current_x, current_y)
        current_x += image_size.x + margin_value
        max_image_height_in_row = max(max_image_height_in_row, image_size.y)
        cur_control.add_child(texture_rect)
        cur_index += 1
    cur_control.size = Vector2(max_size_x, current_y + max_image_height_in_row)
    self.preview_control_list.append(cur_control)
    print("Control size: [%d, %d]" % [cur_control.size.x, cur_control.size.y])
    self.update_preview_num_text()
    self.update_preview_image()

func update_preview_num_text() -> void:
    self.page_number.text = "%d/%d" % [self.preview_cur_control_index + 1, self.preview_control_list.size()]

func update_preview_image() -> void:
    for child in self.preview_viewport.get_children():
        self.preview_viewport.remove_child(child)
    self.preview_viewport.size = self.preview_control_list[self.preview_cur_control_index].size
    self.preview_viewport.add_child(self.preview_control_list[self.preview_cur_control_index])

func _on_test_1_pressed() -> void:
    self.clear_preview_images()
    var files: PackedStringArray = PackedStringArray()
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
