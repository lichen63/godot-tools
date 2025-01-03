@tool
extends Control

enum ToolMode {
    PACK_IMAGES,
    CROP_TO_CELLS,
    SPLIT_SINGLE_IMAGE,
}

const EXPORT_FILE_NAME_FORMAT: String = "export_%d.png"
const SIZE_X_DEFAULT_VALUE_FOR_PACK: String = "2048"
const SIZE_Y_DEFAULT_VALUE_FOR_PACK: String = "1024"
const SIZE_X_DEFAULT_VALUE_FOR_SPLIT: String = "128"
const SIZE_Y_DEFAULT_VALUE_FOR_SPLIT: String = "128"
const SEPARATION_DEFAULT_VALUE: String = "1"

var cur_mode: ToolMode = ToolMode.PACK_IMAGES
var selected_files_for_pack: PackedStringArray = PackedStringArray()
var selected_file_for_split: String = ""
var preview_viewport_list: Array[SubViewport] = []
var preview_cur_viewport_index: int = 0
var cached_crop_cells: Array[Image] = []

@onready var option_button: OptionButton = $ModeContainer/ModeOption
@onready var select_file_dialog: FileDialog = $SelectFileDialog
@onready var size_x_edit: LineEdit = $PropertyContainer/SizeProperty/SizeValue/X
@onready var size_y_edit: LineEdit = $PropertyContainer/SizeProperty/SizeValue/Y
@onready var separation_x_edit: LineEdit = $PropertyContainer/SeparationProperty/SeparationValue/X
@onready var separation_y_edit: LineEdit = $PropertyContainer/SeparationProperty/SeparationValue/Y
@onready var offset_x_edit: LineEdit = $PropertyContainer/OffsetProperty/OffestValue/X
@onready var offset_y_edit: LineEdit = $PropertyContainer/OffsetProperty/OffestValue/Y
@onready var error_dialog: AcceptDialog = $ErrorDialog
@onready var page_number: LineEdit = $PageSwitchContainer/Number
@onready var save_path_edit: LineEdit = $PropertyContainer/SavePath
@onready var preview_viewport_container: SubViewportContainer = $Preview/PreviewViewportContainer
@onready var save_image_panel: PopupPanel = $SaveImageDialog
@onready var save_image_container: SubViewportContainer = $SaveImageDialog/SubViewportContainer
@onready var progress_panel: PopupPanel = $ProgressPopupPanel
@onready var progress_bar: ProgressBar = $ProgressPopupPanel/ProgressBar
@onready var selected_files_edit: TextEdit = $PropertyContainer/FilePath
@onready var preview_split_grid_container: Control = $Preview/GridContainer


func _on_mode_option_item_selected(index: int) -> void:
    match index:
        0:
            self.cur_mode = ToolMode.PACK_IMAGES
            self.size_x_edit.text = SIZE_X_DEFAULT_VALUE_FOR_PACK
            self.size_y_edit.text = SIZE_Y_DEFAULT_VALUE_FOR_PACK
            self.separation_x_edit.text = SEPARATION_DEFAULT_VALUE
            self.separation_y_edit.text = SEPARATION_DEFAULT_VALUE
        1:
            self.cur_mode = ToolMode.CROP_TO_CELLS
            self.size_x_edit.text = SIZE_X_DEFAULT_VALUE_FOR_SPLIT
            self.size_y_edit.text = SIZE_Y_DEFAULT_VALUE_FOR_SPLIT
            self.separation_x_edit.text = SEPARATION_DEFAULT_VALUE
            self.separation_y_edit.text = SEPARATION_DEFAULT_VALUE
        _:
            self.show_error_with_message("Unknown tool mode selected")

func _on_select_file_pressed() -> void:
    if self.cur_mode == ToolMode.PACK_IMAGES:
        self.select_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
    elif self.cur_mode == ToolMode.CROP_TO_CELLS:
        self.select_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    self.select_file_dialog.show()

func _on_reload_file_pressed() -> void:
    var text_in_edit: String = self.selected_files_edit.text.strip_edges()
    if self.cur_mode == ToolMode.PACK_IMAGES:
        self.selected_files_for_pack.clear()
        for file_path in text_in_edit.split("\n"):
            if FileAccess.file_exists(file_path):
                self.selected_files_for_pack.append(file_path)
    elif self.cur_mode == ToolMode.CROP_TO_CELLS:
        if not FileAccess.file_exists(text_in_edit):
            self.show_error_with_message("File path is not a valid path or file does not exist")
            return
        self.selected_file_for_split = text_in_edit
    self.clear_and_reload()

func _on_select_file_dialog_file_selected(path: String) -> void:
    if self.cur_mode == ToolMode.PACK_IMAGES:
        self.selected_files_for_pack.push_back(path)
    elif self.cur_mode == ToolMode.CROP_TO_CELLS:
        self.selected_file_for_split = path

func _on_select_file_dialog_files_selected(paths: PackedStringArray) -> void:
    self.selected_files_for_pack = paths
    
func _on_select_file_dialog_confirmed() -> void:
    self.clear_and_reload()

func _on_select_file_dialog_canceled() -> void:
    pass

func _on_generate_pressed() -> void:
    self.clear_and_reload()

func _on_page_left_pressed() -> void:
    self.show_next_or_prev_viewport(false)

func _on_page_right_pressed() -> void:
    self.show_next_or_prev_viewport(true)

func _on_save_to_file_pressed() -> void:
    var save_path_string: String = self.save_path_edit.text
    if not self.is_save_path_valid(save_path_string):
        self.show_error_with_message("Invalid save path.")
        return
    self.progress_panel.show()
    self.progress_bar.value = 0
    if self.cur_mode == ToolMode.PACK_IMAGES:
        self.save_image_panel.show()
        var index: int = 0
        for viewport in self.preview_viewport_list:
            var file_path: String = self.get_next_savable_file_path(save_path_string)
            if file_path.is_empty():
                break
            for child in self.save_image_container.get_children():
                self.save_image_container.remove_child(child)
                child.queue_free()
            var dup_viewport = viewport.duplicate()
            self.save_image_container.add_child(dup_viewport)
            await self.get_tree().create_timer(1).timeout
            var texture: ViewportTexture = dup_viewport.get_texture()
            var image: Image = texture.get_image()
            var err: Error = image.save_png(file_path)
            print("Save image: %s, err: %d" % [file_path, err])
            self.create_tween().tween_property(self.progress_bar, "value", (index + 1.0) / self.preview_viewport_list.size(), 0.6)
            index += 1
        self.save_image_panel.hide()
    elif self.cur_mode == ToolMode.CROP_TO_CELLS:
        var index: int = 0
        var cached_image_size: int = self.cached_crop_cells.size()
        for image: Image in self.cached_crop_cells:
            var file_path: String = self.get_next_savable_file_path(save_path_string)
            if file_path.is_empty():
                break
            var err: Error = image.save_png(file_path)
            print("Save image: %s, err: %d" % [file_path, err])
            self.progress_bar.value = (index + 1.0) / cached_image_size
            index += 1
    await self.get_tree().create_timer(1).timeout
    self.progress_panel.hide()

func clear_and_reload() -> void:
    self.clear_selected_files_edit()
    self.update_selected_files_edit()
    self.clear_preview_images()
    self.show_images_on_preview()
    if self.cur_mode == ToolMode.CROP_TO_CELLS:
        self.clear_cached_crop_cells()
        self.show_grid_lines()
        self.split_images_to_cache()

func get_next_savable_file_path(save_path: String) -> String:
    var index: int = 0
    while index < 99999:
        var file_path = save_path.path_join(EXPORT_FILE_NAME_FORMAT % index)
        if not FileAccess.file_exists(file_path):
            return file_path
        index += 1
    print("Cannot find savable file path")
    return ""

func is_save_path_valid(save_path: String) -> bool:
    if not save_path.begins_with("user://"):
        print("Save path must begin with 'user://'")
        return false
    if not ensure_directory_exists(save_path):
        print("Failed to prepare the save directory")
        return false
    if not save_path.ends_with("/"):
        print("Save path should end with '/'")
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

func show_next_or_prev_viewport(is_next: bool) -> void:
    var next_index: int = -1
    var list_size: int = self.preview_viewport_list.size()
    if is_next:
        next_index = self.preview_cur_viewport_index + 1 if self.preview_cur_viewport_index < list_size - 1 else 0
    else:
        next_index = self.preview_cur_viewport_index - 1 if self.preview_cur_viewport_index > 0 else list_size - 1
    if next_index == self.preview_cur_viewport_index or next_index < 0 or next_index >= list_size:
        return
    self.preview_cur_viewport_index = next_index
    self.update_preview_num_text()
    self.update_preview_image()

func load_image_as_texture(file_path: String) -> TextureRect:
    var texture_rect: TextureRect = TextureRect.new()
    var image: Image = Image.load_from_file(file_path)
    texture_rect.texture = ImageTexture.create_from_image(image)
    return texture_rect

func clear_preview_images() -> void:
    self.preview_cur_viewport_index = 0
    for viewport: SubViewport in self.preview_viewport_list:
        for child in viewport.get_children():
            viewport.remove_child(child)
            child.queue_free()
    self.preview_viewport_list.clear()
    for child in self.preview_viewport_container.get_children():
        self.preview_viewport_container.remove_child(child)
        child.queue_free()
    self.hide_grid_lines()

func get_and_validate_input(input: LineEdit) -> int:
    var text: String = input.text
    if not text.is_valid_int():
        self.show_error_with_message("[%s] is not a valid integer" % input.get_path())
        return input.placeholder_text.to_int()
    return text.to_int()

func show_error_with_message(message: String) -> void:
    self.error_dialog.dialog_text = message
    self.error_dialog.show()

func show_images_on_preview() -> void:
    var separation_x: int = self.get_and_validate_input(self.separation_x_edit)
    var separation_y: int = self.get_and_validate_input(self.separation_y_edit)
    var max_size_x: int = self.get_and_validate_input(self.size_x_edit)
    var max_size_y: int = self.get_and_validate_input(self.size_y_edit)
    var offset_x: int = self.get_and_validate_input(self.offset_x_edit)
    var offset_y: int = self.get_and_validate_input(self.offset_y_edit)
    if self.cur_mode == ToolMode.PACK_IMAGES:
        var current_x: int = offset_x
        var current_y: int = offset_y
        var max_image_height_in_row: int = 0
        var texture_list: Array[TextureRect] = []
        for file_path: String in self.selected_files_for_pack:
            texture_list.append(self.load_image_as_texture(file_path))
        var cur_index: int = 0
        var cur_viewport: SubViewport = SubViewport.new()
        while cur_index < texture_list.size():
            var texture_rect: TextureRect = texture_list[cur_index]
            var image_size: Vector2 = texture_rect.texture.get_size()
            if current_x + image_size.x > max_size_x:
                current_x = offset_x
                current_y += max_image_height_in_row + separation_y
                max_image_height_in_row = 0
            if current_y + image_size.y > max_size_y:
                self.preview_viewport_list.append(cur_viewport)
                cur_viewport.size = Vector2(max_size_x, current_y + max_image_height_in_row)
                cur_viewport = SubViewport.new()
                current_x = offset_x
                current_y = offset_y
                continue
            texture_rect.position = Vector2(current_x, current_y)
            current_x += image_size.x + separation_x
            max_image_height_in_row = max(max_image_height_in_row, image_size.y)
            cur_viewport.add_child(texture_rect)
            cur_index += 1
        cur_viewport.size = Vector2(max_size_x, current_y + max_image_height_in_row)
        self.preview_viewport_list.append(cur_viewport)
        self.update_preview_num_text()
        self.update_preview_image()
    elif self.cur_mode == ToolMode.CROP_TO_CELLS:
        var texture_rect: TextureRect = self.load_image_as_texture(self.selected_file_for_split)
        var cur_viewport: SubViewport = SubViewport.new()
        cur_viewport.size = texture_rect.texture.get_size()
        cur_viewport.add_child(texture_rect)
        self.preview_viewport_list.append(cur_viewport)
        self.update_preview_num_text()
        self.update_preview_image()

func update_preview_num_text() -> void:
    self.page_number.text = "%d/%d" % [self.preview_cur_viewport_index + 1, self.preview_viewport_list.size()]

func update_preview_image() -> void:
    for child in self.preview_viewport_container.get_children():
        self.preview_viewport_container.remove_child(child)
    self.preview_viewport_container.size = self.preview_viewport_list[self.preview_cur_viewport_index].size
    self.preview_viewport_container.add_child(self.preview_viewport_list[self.preview_cur_viewport_index])

func clear_selected_files_edit() -> void:
    self.selected_files_edit.text = ""

func update_selected_files_edit() -> void:
    var files_str: String = ""
    if self.cur_mode == ToolMode.PACK_IMAGES:
        for file in self.selected_files_for_pack:
            files_str += "%s\n" % file
    elif self.cur_mode == ToolMode.CROP_TO_CELLS:
        files_str = self.selected_file_for_split
    self.selected_files_edit.text = files_str

func show_grid_lines() -> void:
    if self.preview_viewport_list.is_empty():
        return
    var offset_x: int = self.get_and_validate_input(self.offset_x_edit)
    var offset_y: int = self.get_and_validate_input(self.offset_y_edit)
    var cell_width: int = self.get_and_validate_input(self.size_x_edit)
    var cell_height: int = self.get_and_validate_input(self.size_y_edit)
    var separation_x: int = self.get_and_validate_input(self.separation_x_edit)
    var separation_y: int = self.get_and_validate_input(self.separation_y_edit)
    var cur_viewport: SubViewport = self.preview_viewport_list.front()
    var viewport_size: Vector2 = cur_viewport.size
    for child in self.preview_split_grid_container.get_children():
        self.preview_split_grid_container.remove_child(child)
        child.queue_free()
    self.preview_split_grid_container.show()
    var grid_width: float = viewport_size.x - 2 * separation_x
    var grid_height: float = viewport_size.y - 2 * separation_y
    var x_pos: float = offset_x
    while x_pos < grid_width:
        var vertical_line: ColorRect = ColorRect.new()
        vertical_line.color = Color(1, 1, 1, 1)
        vertical_line.size = Vector2(1, grid_height)
        vertical_line.position = Vector2(x_pos, 0)
        self.preview_split_grid_container.add_child(vertical_line)
        x_pos += separation_x
        if x_pos < grid_width:
            var vertical_line_cell: ColorRect = ColorRect.new()
            vertical_line_cell.color = Color(1, 1, 1, 1)
            vertical_line_cell.size = Vector2(1, grid_height)
            vertical_line_cell.position = Vector2(x_pos, 0)
            self.preview_split_grid_container.add_child(vertical_line_cell)
        x_pos += cell_width
    var y_pos: float = offset_y
    while y_pos < grid_height:
        var horizontal_line: ColorRect = ColorRect.new()
        horizontal_line.color = Color(1, 1, 1, 1)
        horizontal_line.size = Vector2(grid_width, 1)
        horizontal_line.position = Vector2(0, y_pos)
        self.preview_split_grid_container.add_child(horizontal_line)
        y_pos += separation_y
        if y_pos < grid_height:
            var horizontal_line_cell: ColorRect = ColorRect.new()
            horizontal_line_cell.color = Color(1, 1, 1, 1)
            horizontal_line_cell.size = Vector2(grid_width, 1)
            horizontal_line_cell.position = Vector2(0, y_pos)
            self.preview_split_grid_container.add_child(horizontal_line_cell)
        y_pos += cell_height

func hide_grid_lines() -> void:
    for child in self.preview_split_grid_container.get_children():
        self.preview_split_grid_container.remove_child(child)
        child.queue_free()
    self.preview_split_grid_container.hide()

func clear_cached_crop_cells() -> void:
    self.cached_crop_cells.clear()

func split_images_to_cache() -> void:
    if self.preview_viewport_list.is_empty():
        return
    var offset_x: int = self.get_and_validate_input(self.offset_x_edit)
    var offset_y: int = self.get_and_validate_input(self.offset_y_edit)
    var cell_width: int = self.get_and_validate_input(self.size_x_edit)
    var cell_height: int = self.get_and_validate_input(self.size_y_edit)
    var separation_x: int = self.get_and_validate_input(self.separation_x_edit)
    var separation_y: int = self.get_and_validate_input(self.separation_y_edit)

    await self.get_tree().create_timer(1).timeout # Wait for the preview image to be loaded

    var cur_viewport: SubViewport = self.preview_viewport_list.front()
    var viewport_texture: ViewportTexture = cur_viewport.get_texture()
    var viewport_image: Image = viewport_texture.get_image()
    var x_start: int = offset_x
    var y_start: int = offset_y
    var x_end: int = viewport_image.get_width()
    var y_end: int = viewport_image.get_height()
    var index: int = 0
    var y: int = y_start

    while y + cell_height <= y_end:
        var x = x_start
        while x + cell_width <= x_end:
            var sub_image: Image = Image.create_empty(cell_width, cell_height, false, viewport_image.get_format())
            sub_image.blit_rect(viewport_image, Rect2(Vector2(x, y), Vector2(cell_width, cell_height)), Vector2(0, 0))
            self.cached_crop_cells.append(sub_image)
            x += cell_width + separation_x
            index += 1
        y += cell_height + separation_y

func _on_test_1_pressed() -> void:
    var files: PackedStringArray = PackedStringArray()
    for index in range(0, 5):
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
    self.selected_files_for_pack = files
    self.cur_mode = ToolMode.PACK_IMAGES
    self.clear_and_reload()

func _on_test_2_pressed() -> void:
    self.selected_file_for_split = "res://sample/spritesheet/sheet.png"
    self.cur_mode = ToolMode.CROP_TO_CELLS
    self.size_x_edit.text = SIZE_X_DEFAULT_VALUE_FOR_SPLIT
    self.size_y_edit.text = SIZE_Y_DEFAULT_VALUE_FOR_SPLIT
    self.separation_x_edit.text = SEPARATION_DEFAULT_VALUE
    self.separation_y_edit.text = SEPARATION_DEFAULT_VALUE
    self.clear_and_reload()
