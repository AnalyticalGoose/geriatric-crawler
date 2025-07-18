extends GridNodeFeature
class_name GridEntity

const _LOOK_DIRECTION_KEY: String = "look_direction"
const _DOWN_KEY: String = "down"
const _ANCHOR_KEY: String = "anchor"
const _COORDINATES_KEY: String = "coordinates"

@export
var look_direction: CardinalDirections.CardinalDirection

@export
var down: CardinalDirections.CardinalDirection = CardinalDirections.CardinalDirection.DOWN

@export
var transportation_abilities: TransportationMode

@export
var transportation_mode: TransportationMode

@export
var can_jump_off_walls: bool

@export
var planner: MovementPlanner

@export
var instant_step: bool

@export
var concurrent_turns: bool

@export
var queue_moves: bool = true

var _active_movement: Movement.MovementType = Movement.MovementType.NONE
var _concurrent_movement: Movement.MovementType = Movement.MovementType.NONE
var _next_movement: Movement.MovementType = Movement.MovementType.NONE
var _next_next_movement: Movement.MovementType = Movement.MovementType.NONE

func _ready() -> void:
    super()
    orient()

func is_moving() -> bool:
    return _active_movement != Movement.MovementType.NONE || _concurrent_movement != Movement.MovementType.NONE

var _block_concurrent: bool

func block_concurrent_movement() -> void:
    _block_concurrent = true

func remove_concurrent_movement_block() -> void:
    _block_concurrent = false


func _start_movement(movement: Movement.MovementType, force: bool) -> bool:
    if Movement.MovementType.NONE == movement || falling() && !force:
        print_debug("Movement refused: no accepting movements")
        return false

    if _active_movement == Movement.MovementType.NONE || force:
        _active_movement = movement
        # print_debug("Movement %s accepted as primary" % [Movement.name(movement)])
    elif concurrent_turns && !_block_concurrent && Movement.is_turn(movement) && !Movement.is_turn(_active_movement):
        # print_debug("Movement %s accepted as concurrent" % [Movement.name(movement)])
        _concurrent_movement = movement
    else:
        # print_debug("Movement refused: busy")
        return false

    return true

func end_movement(movement: Movement.MovementType, start_next_from_queue: bool = true) -> void:
    if _active_movement == movement:
        _active_movement = _concurrent_movement
        _concurrent_movement = Movement.MovementType.NONE
    elif _concurrent_movement == movement:
        _concurrent_movement = Movement.MovementType.NONE
    else:
        push_warning("%s was not an active movement (%s / %s)" % [
            Movement.name(movement),
            Movement.name(_active_movement),
            Movement.name(_concurrent_movement),
        ])
        return

    # print_debug("%s ended, active are %s / %s" % [
        # Movement.name(movement),
        # Movement.name(_active_movement),
        # Movement.name(_concurrent_movement),
    # ])

    if start_next_from_queue:
        _attempt_movement_from_queue()

func _attempt_movement_from_queue() -> void:
    if !queue_moves:
        return

    if _next_movement != Movement.MovementType.NONE:
        if attempt_movement(_next_movement, false):
            _next_movement = _next_next_movement
            _next_next_movement = Movement.MovementType.NONE
        else:
            _clear_queue()
            print_debug("Queued movement refused")

        # print_debug("Consumed queue, now %s / %s" % [
            # Movement.name(_active_movement),
            # Movement.name(_concurrent_movement),
        # ])

func falling() -> bool:
    return transportation_mode.mode == TransportationMode.NONE

var _tween: Tween
var _concurrent_tween: Tween

func attempt_movement(
    movement: Movement.MovementType,
    enqueue_if_occupied: bool = true,
    force: bool = false) -> bool:
    if movement == Movement.MovementType.NONE:
        push_error("A none movement cannot be performed")
        print_stack()
        return false

    if !_start_movement(movement, force):
        if enqueue_if_occupied && queue_moves:
            _enqeue_movement(movement)
            return true

        # print_debug("%s & %s are active" % [Movement.name(_active_movement), Movement.name(_concurrent_movement)])
        return false

    if force:
        _clear_queue()

    var primary_tween: bool = movement == _active_movement

    if primary_tween:
        if _tween:
            _active_movement = Movement.MovementType.NONE
            _tween.kill()
    else:
        if _concurrent_tween:
            _concurrent_movement = Movement.MovementType.NONE
            _concurrent_tween.kill()

    var tween: Tween
    if Movement.is_translation(movement):
        tween = planner.move_entity(movement, Movement.to_direction(movement, look_direction, down))
    elif Movement.is_turn(movement):
        tween = planner.rotate_entity(movement, movement == Movement.MovementType.TURN_CLOCKWISE)

    _handle_new_tween(tween, primary_tween)

    if tween == null:
        # This would become a stack overflow if set
        end_movement(movement, false)

    return tween != null

func _enqeue_movement(movement: Movement.MovementType) -> void:
    if _next_movement != Movement.MovementType.NONE:
        _next_next_movement = movement
        # print_debug("%s enqued as next next movement (%s next)" % [
            # Movement.name(movement),
            # Movement.name(_next_movement),
        # ])
        return

    _next_movement = movement
    # print_debug("%s enqued as next movement" % [
        # Movement.name(_next_movement),
    # ])

func _clear_queue() -> void:
    _next_movement = Movement.MovementType.NONE
    _next_next_movement = Movement.MovementType.NONE

func _handle_new_tween(tween: Tween, primary_tween: bool) -> void:
    if tween != null:
        tween.play()

        if instant_step:
            var t: float = 999
            while tween.custom_step(t):
                t *= 2

    elif primary_tween:
        _tween = tween
    else:
        _concurrent_tween = tween

func update_entity_anchorage(node: GridNode, anchor: GridAnchor, deferred: bool = false) -> void:
    if anchor != null:
        set_grid_anchor(anchor, deferred)
        transportation_mode.mode = transportation_abilities.intersection(anchor.required_transportation_mode)
    else:
        set_grid_node(node, deferred)
        if transportation_abilities.has_flag(TransportationMode.FLYING):
            transportation_mode.mode = TransportationMode.FLYING
        else:
            transportation_mode.mode = TransportationMode.NONE

    print_debug("%s is now %s @ %s %s" % [name, transportation_mode.humanize(), node.name, CardinalDirections.name(anchor.direction) if anchor else "airbourne"])
    # print_stack()

func sync_position() -> void:
    var anchor: GridAnchor = get_grid_anchor()
    if anchor != null:
        global_position = anchor.global_position
        return

    var node: GridNode = get_grid_node()
    if node != null:
        global_position = node.get_center_pos()
        return

    push_error("%s doesn't have either a node or anchor set" % name)
    print_stack()


func orient() -> void:
    if look_direction == CardinalDirections.CardinalDirection.NONE || down == CardinalDirections.CardinalDirection.NONE:
        push_warning("Cannot orient looking %s and down %s" % [
            CardinalDirections.name(look_direction),
            CardinalDirections.name(down)
        ])
        print_stack()
        return

    look_at(
        global_position + Vector3(CardinalDirections.direction_to_vector(look_direction)),
        CardinalDirections.direction_to_vector(CardinalDirections.invert(down)),
    )
