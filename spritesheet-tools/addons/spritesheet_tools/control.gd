@tool
extends Control

enum ToolMode {
    PACK_IMAGES,
    CROP_TO_CELLS,
    SPLIT_SINGLE_IMAGE,
}

const EXPORT_FILE_NAME_FORMAT: String = "export_%d.png"
const SIZE_DEFAULT_VALUE_FOR_PACK: String = "1024"
const SIZE_DEFAULT_VALUE_FOR_SPLIT: String = "128"
const SEPARATION_DEFAULT_VALUE: String = "1"
const OFFSET_DEFAULT_VALUE: String = "0"
const SAVE_IMAGE_COUNT_LIMIT: int = 99999

var cur_mode: ToolMode = ToolMode.PACK_IMAGES
var selected_files_for_pack: PackedStringArray = PackedStringArray()
var selected_file_for_split: String = ""
var preview_viewport_list: Array[SubViewport] = []
var preview_cur_viewport_index: int = 0
var cached_crop_cells: Array[Image] = []
var select_rect_start_pos: Vector2 = Vector2()
var select_rect_end_pos: Vector2 = Vector2()
var is_selecting: bool = false
var select_rect_final_rect: Rect2 = Rect2()

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
@onready var save_spritesheet_panel: PopupPanel = $SaveSpritesheetDialog
@onready var save_spritesheet_container: SubViewportContainer = $SaveSpritesheetDialog/SubViewportContainer
@onready var progress_panel: PopupPanel = $ProgressPopupPanel
@onready var progress_bar: ProgressBar = $ProgressPopupPanel/ProgressBar
@onready var selected_files_edit: TextEdit = $PropertyContainer/FilePath
@onready var preview_split_grid_container: Control = $Preview/GridContainer
@onready var select_color_rect: ColorRect = $Preview/PreviewViewportContainer/SelectColorRect
@onready var select_color_rect_label: Label = $Preview/PreviewViewportContainer/SelectColorRect/RectSize
@onready var test_1_button: Button = $Test1
@onready var test_2_button: Button = $Test2
@onready var test_3_button: Button = $Test3

func _ready() -> void:
    if not OS.is_debug_build():
        self.test_1_button.show()
        self.test_2_button.show()
        self.test_3_button.show()
    else:
        self.test_1_button.hide()
        self.test_2_button.hide()
        self.test_3_button.hide()

func _input(event: InputEvent) -> void:
    if self.cur_mode != ToolMode.SPLIT_SINGLE_IMAGE:
        return
    if self.preview_viewport_list.is_empty():
        return
    var cur_viewport: SubViewport = self.preview_viewport_list.front()
    var viewport_texture: ViewportTexture = cur_viewport.get_texture()
    var viewport_rect: Rect2 = self.preview_viewport_container.get_global_rect()
    if event is InputEventMouseButton:
        var global_mouse_pos: Vector2 = event.global_position
        if viewport_rect.has_point(global_mouse_pos):
            if event.button_index == MOUSE_BUTTON_LEFT:
                if event.pressed:
                    self.is_selecting = true
                    self.select_rect_start_pos = self.preview_viewport_container.get_local_mouse_position()
                    self.select_color_rect.show()
                    self.select_color_rect_label.show()
                    self.select_rect_final_rect = Rect2()
                else:
                    self.is_selecting = false
                    self.select_rect_end_pos = self.preview_viewport_container.get_local_mouse_position()
                    var select_rect: Rect2 = Rect2(self.select_rect_start_pos, self.select_rect_end_pos - self.select_rect_start_pos).abs()
                    self.select_color_rect_label.text = "%d x %d" % [select_rect.size.x, select_rect.size.y]
                    self.select_color_rect.set_position(select_rect.position)
                    self.select_color_rect.set_size(select_rect.size)
                    self.select_rect_final_rect = select_rect
    elif event is InputEventMouseMotion and self.is_selecting:
        self.select_rect_end_pos = self.preview_viewport_container.get_local_mouse_position()
        var select_rect: Rect2 = Rect2(self.select_rect_start_pos, self.select_rect_end_pos - self.select_rect_start_pos).abs()
        self.select_color_rect_label.text = "%d x %d" % [select_rect.size.x, select_rect.size.y]
        self.select_color_rect.position = select_rect.position
        self.select_color_rect.size = select_rect.size

func _on_mode_option_item_selected(index: ToolMode) -> void:
    var tool_mode_settings: Dictionary = {
        ToolMode.PACK_IMAGES: { "size_value": SIZE_DEFAULT_VALUE_FOR_PACK, "editable": true },
        ToolMode.CROP_TO_CELLS: { "size_value": SIZE_DEFAULT_VALUE_FOR_SPLIT, "editable": true },
        ToolMode.SPLIT_SINGLE_IMAGE: { "size_value": SIZE_DEFAULT_VALUE_FOR_SPLIT, "editable": false },
    }
    var set_tool_mode: Callable = func(mode: ToolMode, size_value: String, editable: bool) -> void:
        self.cur_mode = mode
        self.size_x_edit.text = size_value
        self.size_y_edit.text = size_value
        self.separation_x_edit.text = SEPARATION_DEFAULT_VALUE
        self.separation_y_edit.text = SEPARATION_DEFAULT_VALUE
        self.offset_x_edit.text = OFFSET_DEFAULT_VALUE
        self.offset_y_edit.text = OFFSET_DEFAULT_VALUE
        for edit in [self.size_x_edit, self.size_y_edit, self.offset_x_edit, self.offset_y_edit, self.separation_x_edit, self.separation_y_edit]:
            edit.editable = editable
        self.selected_files_edit.text = ""
        self.clear_preview_viewport_images()
        self.select_color_rect.hide()
        self.select_color_rect_label.hide()
    if not tool_mode_settings.has(index):
        self.show_error_dialog("Unknown tool mode [%d] selected." % [index])
        return
    var settings = tool_mode_settings[index]
    set_tool_mode.call(index, settings.size_value, settings.editable)

func _on_select_file_pressed() -> void:
    self.select_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES if self.cur_mode == ToolMode.PACK_IMAGES else FileDialog.FILE_MODE_OPEN_FILE
    self.select_file_dialog.show()

func _on_reload_file_pressed() -> void:
    var selected_files_string: String = self.selected_files_edit.text.strip_edges()
    match self.cur_mode:
        ToolMode.PACK_IMAGES:
            self.selected_files_for_pack.clear()
            for file_path in selected_files_string.split("\n"):
                if self.check_is_valid_image_file_path(file_path):
                    self.selected_files_for_pack.append(file_path)
        ToolMode.CROP_TO_CELLS, ToolMode.SPLIT_SINGLE_IMAGE:
            if self.check_is_valid_image_file_path(selected_files_string):
                self.selected_file_for_split = selected_files_string
    self.clear_and_reload_preview()

func _on_select_file_dialog_file_selected(file_path: String) -> void:
    if not self.check_is_valid_image_file_path(file_path):
        return
    match self.cur_mode:
        ToolMode.PACK_IMAGES:
            self.selected_files_for_pack.clear()
            self.selected_files_for_pack.push_back(file_path)
        ToolMode.CROP_TO_CELLS, ToolMode.SPLIT_SINGLE_IMAGE:
            self.selected_file_for_split = file_path

func _on_select_file_dialog_files_selected(paths: PackedStringArray) -> void:
    var valid_files: PackedStringArray = PackedStringArray()
    for file_path in paths:
        if self.check_is_valid_image_file_path(file_path):
            valid_files.append(file_path)
    self.selected_files_for_pack = valid_files
    
func _on_select_file_dialog_confirmed() -> void:
    self.clear_and_reload_preview()

func _on_select_file_dialog_canceled() -> void:
    pass

func _on_generate_pressed() -> void:
    self.clear_and_reload_preview()

func _on_page_left_pressed() -> void:
    self.show_next_or_prev_preview(false)

func _on_page_right_pressed() -> void:
    self.show_next_or_prev_preview(true)

func _on_save_to_file_pressed() -> void:
    var save_path: String = self.save_path_edit.text
    if not self.check_is_valid_savable_path(save_path):
        return
    self.progress_panel.show()
    self.progress_bar.value = 0
    match self.cur_mode:
        ToolMode.PACK_IMAGES:
            self.save_images_in_pack_mode(save_path)
        ToolMode.CROP_TO_CELLS:
            self.save_images_in_crop_mode(save_path)
        ToolMode.SPLIT_SINGLE_IMAGE:
            self.save_images_in_split_mode(save_path)
    await self.get_tree().create_timer(1).timeout
    self.progress_panel.hide()

func save_images_in_pack_mode(save_path: String) -> void:
    self.save_spritesheet_panel.show()
    var index: int = 0
    var spritesheet_count: int = self.preview_viewport_list.size()
    for viewport in self.preview_viewport_list:
        var file_path: String = self.get_next_savable_file_path(save_path)
        if file_path.is_empty():
            break
        for child in self.save_spritesheet_container.get_children():
            self.save_spritesheet_container.remove_child(child)
            child.queue_free()
        var dup_viewport = viewport.duplicate()
        self.save_spritesheet_container.add_child(dup_viewport)
        await self.get_tree().create_timer(1).timeout
        var texture: ViewportTexture = dup_viewport.get_texture()
        var image: Image = texture.get_image()
        var err: Error = image.save_png(file_path)
        print("Save spritesheet image: %s, err: %d." % [file_path, err])
        self.create_tween().tween_property(self.progress_bar, "value", (index + 1.0) / spritesheet_count, 0.6)
        index += 1
    self.save_spritesheet_panel.hide()

func save_images_in_crop_mode(save_path: String) -> void:
    var index: int = 0
    var cached_cell_count: int = self.cached_crop_cells.size()
    for image: Image in self.cached_crop_cells:
        var file_path: String = self.get_next_savable_file_path(save_path)
        if file_path.is_empty():
            break
        var err: Error = image.save_png(file_path)
        print("Save cell image: %s, err: %d." % [file_path, err])
        self.progress_bar.value = (index + 1.0) / cached_cell_count
        index += 1

func save_images_in_split_mode(save_path: String) -> void:
    var file_path: String = self.get_next_savable_file_path(save_path)
    if file_path.is_empty():
        return
    if self.preview_viewport_list.is_empty():
        return
    if is_zero_approx(self.select_rect_final_rect.size.x) or is_zero_approx(self.select_rect_final_rect.size.y):
        self.show_error_dialog("Invalid rectangle size from selection: [%s]." % [self.select_rect_final_rect.size])
        return
    var cur_viewport: SubViewport = self.preview_viewport_list[self.preview_cur_viewport_index]
    var viewport_texture: ViewportTexture = cur_viewport.get_texture()
    var viewport_image: Image = viewport_texture.get_image()
    var sub_image = Image.create_empty(self.select_rect_final_rect.size.x, self.select_rect_final_rect.size.y, false, viewport_image.get_format())
    sub_image.blit_rect(viewport_image, self.select_rect_final_rect, Vector2.ZERO)
    var err: Error = sub_image.save_png(file_path)
    print("Save split image: %s, err: %d." % [file_path, err])
    self.select_color_rect.hide()

func check_is_valid_image_file_path(file_path: String) -> bool:
    var supported_image_format: Array = ["png", "jpg", "jpeg"]
    if FileAccess.file_exists(file_path):
        if file_path.get_extension() in supported_image_format:
            return true
    self.show_error_dialog("File [%s] is not a valid image file path, please check." % [file_path])
    return false

func clear_and_reload_preview() -> void:
    self.update_selected_files_edit()
    self.clear_preview_viewport_images()
    self.show_images_on_preview()
    if self.cur_mode == ToolMode.CROP_TO_CELLS:
        self.show_grid_lines()
        self.crop_to_cache_cells()

func get_next_savable_file_path(save_path: String) -> String:
    if not self.check_is_valid_savable_path(save_path):
        return ""
    var index: int = 0
    while index < SAVE_IMAGE_COUNT_LIMIT:
        var file_path: String = save_path.path_join(EXPORT_FILE_NAME_FORMAT % [index])
        if not FileAccess.file_exists(file_path):
            return file_path
        index += 1
    self.show_error_dialog("Unable to generate a valid save path. The limit of [%d] files may have been reached. Please clean up the folder or choose another save location." % [SAVE_IMAGE_COUNT_LIMIT])
    return ""

func check_is_valid_savable_path(save_path: String) -> bool:
    if not save_path.begins_with("user://"):
        self.show_error_dialog("Save path [%s] must begin with 'user://'." % [save_path])
        return false
    var base_dir: String = save_path.get_base_dir()
    if not DirAccess.dir_exists_absolute(base_dir):
        var err: Error = DirAccess.make_dir_absolute(base_dir)
        if err != Error.OK:
            self.show_error_dialog("Failed to create save path [%s], err: [%d]." % [save_path, err])
            return false
    return true

func show_next_or_prev_preview(is_next: bool) -> void:
    var list_size: int = self.preview_viewport_list.size()
    if list_size <= 0: 
        return
    var next_index: int = (self.preview_cur_viewport_index + (1 if is_next else -1)) % list_size
    if next_index < 0:
        next_index += list_size
    if next_index == self.preview_cur_viewport_index:
        return
    self.preview_cur_viewport_index = next_index
    self.update_preview_page_text()
    self.update_preview_image()

func load_image_as_texture(file_path: String) -> TextureRect:
    if not self.check_is_valid_image_file_path(file_path):
        return null
    var image: Image = Image.load_from_file(file_path)
    var texture_rect: TextureRect = TextureRect.new()
    texture_rect.texture = ImageTexture.create_from_image(image)
    return texture_rect

func clear_preview_viewport_images() -> void:
    self.preview_cur_viewport_index = 0
    for container_child in self.preview_viewport_container.get_children():
        if container_child is SubViewport:
            for viewport_child in container_child.get_children():
                container_child.remove_child(viewport_child)
                viewport_child.queue_free()
            self.preview_viewport_container.remove_child(container_child)
            container_child.queue_free()
    self.preview_viewport_list.clear()
    self.hide_preview_grid_lines()

func get_and_validate_input_is_int(input: LineEdit) -> int:
    var text: String = input.text
    if not text.is_valid_int():
        self.show_error_dialog("[%s] is not a valid integer value: [%s]" % [input.get_path(), text])
        return input.placeholder_text.to_int()
    return text.to_int()

func show_error_dialog(message: String) -> void:
    if not message:
        return
    push_error(message)
    self.error_dialog.dialog_text = message
    self.error_dialog.show()

func show_images_on_preview() -> void:
    var separation_x: int = self.get_and_validate_input_is_int(self.separation_x_edit)
    var separation_y: int = self.get_and_validate_input_is_int(self.separation_y_edit)
    var max_size_x: int = self.get_and_validate_input_is_int(self.size_x_edit)
    var max_size_y: int = self.get_and_validate_input_is_int(self.size_y_edit)
    var offset_x: int = self.get_and_validate_input_is_int(self.offset_x_edit)
    var offset_y: int = self.get_and_validate_input_is_int(self.offset_y_edit)
    match self.cur_mode:
        ToolMode.PACK_IMAGES:
            if self.selected_files_for_pack.size() == 0:
                return
            var current_x: int = offset_x
            var current_y: int = offset_y
            var max_image_height_in_row: int = 0
            var texture_list: Array[TextureRect] = []
            for file_path: String in self.selected_files_for_pack:
                var texture_rect: TextureRect = self.load_image_as_texture(file_path)
                if texture_rect:
                    texture_list.append(texture_rect)
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
                    cur_viewport.size = Vector2(max_size_x, current_y + max_image_height_in_row)
                    self.preview_viewport_list.append(cur_viewport)
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
            self.update_preview_page_text()
            self.update_preview_image()
        ToolMode.CROP_TO_CELLS, ToolMode.SPLIT_SINGLE_IMAGE:
            var texture_rect: TextureRect = self.load_image_as_texture(self.selected_file_for_split)
            if not texture_rect:
                return
            var cur_viewport: SubViewport = SubViewport.new()
            cur_viewport.size = texture_rect.texture.get_size()
            cur_viewport.add_child(texture_rect)
            self.preview_viewport_list.append(cur_viewport)
            self.update_preview_page_text()
            self.update_preview_image()

func update_preview_page_text() -> void:
    self.page_number.text = "%d/%d" % [self.preview_cur_viewport_index + 1, self.preview_viewport_list.size()]

func update_preview_image() -> void:
    for child in self.preview_viewport_container.get_children():
        if child is SubViewport:
            self.preview_viewport_container.remove_child(child)
    var cur_viewport = self.preview_viewport_list[self.preview_cur_viewport_index]
    self.preview_viewport_container.size = cur_viewport.size
    self.preview_viewport_container.add_child(cur_viewport)

func update_selected_files_edit() -> void:
    var files_str: String = ""
    match self.cur_mode:
        ToolMode.PACK_IMAGES:
            for file in self.selected_files_for_pack:
                files_str += "%s\n" % [file]
        ToolMode.CROP_TO_CELLS, ToolMode.SPLIT_SINGLE_IMAGE:
            files_str = self.selected_file_for_split
    self.selected_files_edit.text = files_str

func show_grid_lines() -> void:
    if self.preview_viewport_list.is_empty() or self.cur_mode != ToolMode.CROP_TO_CELLS:
        return
    var offset_x: int = self.get_and_validate_input_is_int(self.offset_x_edit)
    var offset_y: int = self.get_and_validate_input_is_int(self.offset_y_edit)
    var cell_width: int = self.get_and_validate_input_is_int(self.size_x_edit)
    var cell_height: int = self.get_and_validate_input_is_int(self.size_y_edit)
    var separation_x: int = self.get_and_validate_input_is_int(self.separation_x_edit)
    var separation_y: int = self.get_and_validate_input_is_int(self.separation_y_edit)
    var cur_viewport: SubViewport = self.preview_viewport_list[self.preview_cur_viewport_index]
    var viewport_size: Vector2 = cur_viewport.size
    for child in self.preview_split_grid_container.get_children():
        self.preview_split_grid_container.remove_child(child)
        child.queue_free()
    var grid_width: int = viewport_size.x - 2 * separation_x
    var grid_height: int = viewport_size.y - 2 * separation_y
    var x_pos: int = offset_x
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
    var y_pos: int = offset_y
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
    self.preview_split_grid_container.show()

func hide_preview_grid_lines() -> void:
    for child in self.preview_split_grid_container.get_children():
        self.preview_split_grid_container.remove_child(child)
        child.queue_free()
    self.preview_split_grid_container.hide()

func crop_to_cache_cells() -> void:
    if self.preview_viewport_list.is_empty() or self.cur_mode != ToolMode.CROP_TO_CELLS:
        return
    var offset_x: int = self.get_and_validate_input_is_int(self.offset_x_edit)
    var offset_y: int = self.get_and_validate_input_is_int(self.offset_y_edit)
    var cell_width: int = self.get_and_validate_input_is_int(self.size_x_edit)
    var cell_height: int = self.get_and_validate_input_is_int(self.size_y_edit)
    var separation_x: int = self.get_and_validate_input_is_int(self.separation_x_edit)
    var separation_y: int = self.get_and_validate_input_is_int(self.separation_y_edit)
    await self.get_tree().create_timer(1).timeout # Wait for the preview image to be loaded
    self.cached_crop_cells.clear()
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
        var x: int = x_start
        while x + cell_width <= x_end:
            var sub_image: Image = Image.create_empty(cell_width, cell_height, false, viewport_image.get_format())
            sub_image.blit_rect(viewport_image, Rect2(Vector2(x, y), Vector2(cell_width, cell_height)), Vector2.ZERO)
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
    self.clear_and_reload_preview()

func _on_test_2_pressed() -> void:
    self.selected_file_for_split = "res://sample/spritesheet/sheet_2.png"
    self.cur_mode = ToolMode.CROP_TO_CELLS
    self.size_x_edit.text = SIZE_DEFAULT_VALUE_FOR_SPLIT
    self.size_y_edit.text = SIZE_DEFAULT_VALUE_FOR_SPLIT
    self.separation_x_edit.text = SEPARATION_DEFAULT_VALUE
    self.separation_y_edit.text = SEPARATION_DEFAULT_VALUE
    self.clear_and_reload_preview()

func _on_test_3_pressed() -> void:
    self.selected_file_for_split = "res://sample/spritesheet/sheet_1.png"
    self.cur_mode = ToolMode.SPLIT_SINGLE_IMAGE
    self.clear_and_reload_preview()
