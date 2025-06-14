extends Node
class_name LevelSaver

func collect_save_state() -> Dictionary:
    push_error("Executing base class method for saving state")
    return {}

func get_initial_save_state() -> Dictionary:
    push_warning("Executing base class method for initial state")
    return {}

## When saving and loading indicates the current level
func get_level_name() -> String:
    push_error("Executing base class method for getting level name")
    return "level-name"

## When saving indicates which level to load next time the save is loaded.
## This will be different from its own level if we're exiting for a new one
func get_level_to_load() -> String:
    return get_level_name()

@warning_ignore_start("unused_parameter")
## Only the save data for the particular level
func load_from_save(save_data: Dictionary) -> void:
    push_error("Executing base class method for loading level")
    pass
@warning_ignore_restore("unused_parameter")
