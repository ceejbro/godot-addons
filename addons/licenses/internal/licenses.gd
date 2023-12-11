@tool
extends MarginContainer

const Licenses := preload("../licenses.gd")
const Component := preload("../component.gd")
const ComponentsTree := preload("components_tree.gd")
const ComponentDetailTree := preload("component_detail_tree.gd")
const Toolbar := preload("toolbar.gd")
const ComponentsContainer := preload("components_container.gd")
const FileSystemWatcher := preload("file_system_watcher.gd")
# handler
const BaseHandler := preload("handler/base.gd")
const ObjectHandler := preload("handler/object.gd")
const ArrayHandler := preload("handler/array.gd")
const StringHandler := preload("handler/string.gd")
const StringFileHandler := preload("handler/string_file.gd")
const StringMultiLineHandler := preload("handler/string_multiline.gd")

@export_node_path("Tree") var _components_tree_path
@onready var _components_tree: ComponentsTree = self.get_node(self._components_tree_path)
@export_node_path("Tree") var _component_detail_tree_path
@onready var _component_detail_tree: ComponentDetailTree = self.get_node(self._component_detail_tree_path)
@export_node_path("HBoxContainer") var _toolbar_path
@onready var _toolbar: Toolbar = self.get_node(self._toolbar_path)
var _item_menu: PopupMenu
@export var _license_file_edit: LineEdit = null
@export var _license_file_load_button: Button = null
@export var _set_license_filepath_button: Button = null

var _components: ComponentsContainer = ComponentsContainer.new()
var _file_watcher: FileSystemWatcher

func _ready() -> void:
    self._license_file_load_button.icon = self.get_theme_icon("Load", "EditorIcons")
    self._license_file_load_button.pressed.connect(self._on_data_file_load_button_clicked)
    self._set_license_filepath_button.icon = self.get_theme_icon("ImportCheck", "EditorIcons")
    self._set_license_filepath_button.pressed.connect(self._on_set_license_filepath_clicked)
    self._license_file_edit.text_submitted.connect(self._on_data_file_edit_changed)
    self._license_file_edit.text = Licenses.get_license_data_filepath()

    self._create_item_menu()
    self._components_tree.gui_input.connect(self._on_gui_input)
    self.add_child(self._components)

    self._components_tree.set_components(self._components)
    self._components_tree.component_selected.connect(self._on_component_tree_selected)
    self._components_tree.component_remove.connect(self._on_component_tree_remove)
    self._components_tree.component_add.connect(self._on_component_tree_add)

    self._component_detail_tree.component_edited.connect(self._on_component_detail_edited)
    self._component_detail_tree.handlers = [ObjectHandler, StringFileHandler, StringMultiLineHandler, StringHandler, ArrayHandler]

    self._toolbar.add_component.connect(self._on_toolbar_add_component)
    self._toolbar.show_engine_components.connect(self._on_toolbar_show_engine_components)

    self.reload()
    self._components.components_changed.connect(self._on_components_changed)
    if Engine.is_editor_hint():
        self._file_watcher = FileSystemWatcher.new(self._components)

func reload() -> void:
    self._update_set_license_filepath_button()
    var res: Licenses.LoadResult = Licenses.load(self._license_file_edit.text)
    if res.err_msg == "":
        self._license_file_edit.right_icon = null
        self._license_file_edit.tooltip_text = ""
    else:
        self._license_file_edit.right_icon = self.get_theme_icon("NodeWarning", "EditorIcons")
        self._license_file_edit.tooltip_text = res.err_msg
    
    self._components.set_components(res.components)
    self._components.sort_custom(Licenses.compare_components_ascending)
    self._components.emit_changed()

func _create_item_menu() -> void:
    self._item_menu = PopupMenu.new()
    self._item_menu.name = "item_menu"
    self._item_menu.id_pressed.connect(self._on_item_menu_pressed)
    self._item_menu.add_icon_item(self.get_theme_icon("Duplicate", "EditorIcons"), "Duplicate")
    self._item_menu.add_icon_item(self.get_theme_icon("Remove", "EditorIcons"), "Delete")
    self._item_menu.size = self._item_menu.get_contents_minimum_size()
    self.add_child(self._item_menu)

func _update_set_license_filepath_button() -> void:
    if Licenses.get_license_data_filepath() == self._license_file_edit.text:
        self._set_license_filepath_button.icon = self.get_theme_icon("ImportCheck", "EditorIcons")
        self._set_license_filepath_button.tooltip_text = "Selected file is set as the project license file."
        self._set_license_filepath_button.disabled = true
    else:
        self._set_license_filepath_button.icon = self.get_theme_icon("ImportFail", "EditorIcons")
        self._set_license_filepath_button.tooltip_text = "Set the current file as project license file."
        self._set_license_filepath_button.disabled = false

func _on_data_file_load_button_clicked() -> void:
    var dialog: FileDialog = FileDialog.new()
    dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    dialog.current_path = self._license_file_edit.text
    self.add_child(dialog)
    dialog.popup_centered_ratio(0.4)
    dialog.close_requested.connect(dialog.queue_free)
    dialog.file_selected.connect(self._on_data_file_selected)

func _on_data_file_edit_changed(new_text: String) -> void:
    self._on_data_file_selected(new_text)

func _on_data_file_selected(path: String) -> void:
    self._license_file_edit.text = path
    self.reload()

func _on_set_license_filepath_clicked() -> void:
    Licenses.set_license_data_filepath(self._license_file_edit.text)
    self._update_set_license_filepath_button()

func _on_component_tree_selected(comp: Component) -> void:
    self._component_detail_tree.set_component(comp)

func _on_component_tree_add(comp: Component) -> void:
    self._components.add_component(comp)
    self._component_detail_tree.set_component(comp)
    self._components.emit_changed()

func _on_component_tree_remove(comp: Component) -> void:
    self._components.remove_component(comp)
    self._components.sort_custom(Licenses.compare_components_ascending)
    # refresh detail view if the current component was removed
    if comp == self._component_detail_tree.get_component():
        self._component_detail_tree.set_component(null)
    self._components.emit_changed()

func _on_toolbar_add_component(comp: Component) -> void:
    self._on_component_tree_add(comp)

func _on_toolbar_show_engine_components(show: bool) -> void:
    self._components_tree.show_readonly_components = show

# callback from component detail tree
func _on_component_detail_edited(component: Component) -> void:
    self._components.sort_custom(Licenses.compare_components_ascending)
    # we cannot reload the tree while it is processing any kind of input/signals
    # https://github.com/godotengine/godot/issues/50084
    call_deferred("_emit_changed")

func _on_components_changed() -> void:
    Licenses.save(self._components.components(), self._license_file_edit.text)
    self._component_detail_tree.reload()
    self._components_tree.reload(self._component_detail_tree.get_component())

func _on_gui_input(event: InputEvent) -> void:
    if !(event is InputEventMouseButton) || !event.pressed || event.button_index != MOUSE_BUTTON_RIGHT:
        return
    var item: TreeItem = self._components_tree.get_item_at_position(event.position)
    if item == null || !item.has_meta("idx") || !item.has_meta("readonly") || (item.get_meta("readonly") as bool):
        return

    self._item_menu.popup_on_parent(Rect2(self.get_local_mouse_position(), self._item_menu.size))

func _on_item_menu_pressed(btn_idx: int) -> void:
    var idx: int = self._components_tree.get_selected().get_meta("idx") as int
    match btn_idx:
        0:
            var new_comp: Component = self._components.get_at(idx).duplicate()
            new_comp.name = new_comp.name + " Copy"
            self._on_component_tree_add(new_comp)
        1:
            self._on_component_tree_remove(self._components.get_at(idx))

func _emit_changed():
    self._components.emit_changed()
