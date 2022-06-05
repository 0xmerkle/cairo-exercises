%builtins output range_check
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.squash_dict import squash_dict
from starkware.cairo.common.serialize import serialize_word
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_nn_le

# #### STRUCTS #### #

struct KeyValue:
    member key : felt
    member value : felt
end

struct Location:
    member row : felt
    member col : felt
end

# #### UTILS #### #

# Returns the value associated with the given key.
func get_value_by_key{range_check_ptr}(list : KeyValue*, size, key) -> (value):
    alloc_locals
    local idx
    %{
        # Populate idx using a hint.
        ENTRY_SIZE = ids.KeyValue.SIZE
        KEY_OFFSET = ids.KeyValue.key
        VALUE_OFFSET = ids.KeyValue.value
        for i in range(ids.size):
            addr = ids.list.address_ + ENTRY_SIZE * i + KEY_OFFSET
            if memory[addr] == ids.key:
                ids.idx = i
                break
        else:
            raise Exception(
                f'Key {ids.key} was not found in the list.')
    %}

    # Verify that we have the correct key.
    let item : KeyValue = list[idx]
    assert item.key = key

    # Verify that the index is in range (0 <= idx <= size - 1).
    assert_nn_le(a=idx, b=size - 1)

    # Return the corresponding value.
    return (value=item.value)
end

func build_dict(loc_list : Location*, tile_list : felt*, n_steps, dict : DictAccess*) -> (
        dict : DictAccess*):
    if n_steps == 0:
        # When there are no more steps, just return the dict
        # pointer.
        return (dict=dict)
    end

    # Set the key to the current tile being moved.
    assert dict.key = [tile_list]

    # Its previous location should be where the empty tile is  going to be.
    let next_loc : Location* = loc_list + Location.SIZE
    assert dict.prev_value = 4 * next_loc.row + next_loc.col

    # next location should be where the empty tile is now
    assert dict.new_value = 4 * loc_list.row + loc_list.col

    # Call build_dict recursively
    return build_dict(
        loc_list=next_loc,
        tile_list=tile_list + 1,
        n_steps=n_steps - 1,
        dict=dict + DictAccess.SIZE)
end
func build_dict(list : KeyValue*, size, dict : DictAccess*) -> (dict):
    if size == 0:
        return (dict=dict)
    end
    alloc_locals
    local loc_list
    local next_loc

    %{
        ENTRY_SIZE = ids.KeyValue.SIZE
        KEY_OFFSET = ids.KeyValue.key
        VALUE_OFFSET = ids.KeyValue.value

        loc_list=list
        # Populate ids.dict.prev_value using cumulative_sums...
        # Add list.value to cumulative_sums[list.key]...
        for i in enumerate(ids.size):
          ids.dict.prev_value = loc_list[i].value + loc_list[i - 1].value
          addr = ids.list.address_ + ENTRY_SIZE * i + \
                KEY_OFFSET
            if memory[addr] == ids.key:
                ids.idx = i
                break
        next_loc = loc_list.SIZE +
    %}

    # Copy list.key to dict.key...
    # Verify that dict.new_value = dict.prev_value + list.value...
    # Call recursively to build_dict()...
    build_dict(list=
end

func verify_and_output_squashed_dict(
        squashed_dict : DictAccess*, squashed_dict_end : DictAccess*, result : KeyValue*) -> (
        result):
    tempvar diff = squashed_dict_end - squashed_dict
    if diff == 0:
        return (result=result)
    end
end

# returns sum of key values with same key

func sum_by_key{range_checj_ptr}(list : KeyValue*, size, dict : KeyValue*) -> (
        dict):
        alloc_locals
        local
        if size == 0:
            return (dict=dict)

        %{

        %}
        build_dict(dict)
        squash_dict(dict)
        verify_and_output_squashed_dict(dict)
        return (dict)
end
func finalize_state(dict : DictAccess*, idx) -> (dict : DictAccess*):
    if idx == 0:
        return (dict=dict)
    end

    assert dict.key = idx
    assert dict.prev_value = idx - 1
    assert dict.new_value = idx - 1

    # finalize_state recursively.
    return finalize_state(dict=dict + DictAccess.SIZE, idx=idx - 1)
end

func output_initial_values{output_ptr : felt*}(squashed_dict : DictAccess*, n):
    if n == 0:
        return ()
    end

    serialize_word(squashed_dict.prev_value)

    # Call output_initial_values recursively.
    return output_initial_values(squashed_dict=squashed_dict + DictAccess.SIZE, n=n - 1)
end
# instructs Cairo to interpret loc as the address of a Location instance
func verify_location_is_valid(loc : Location*):
    tempvar row = loc.row  # scope of a temporary variable is restricted. For example, a temporary variable may be revoked due to jumps or function calls
    assert row * (row - 1) * (row - 2) * (row - 3) = 0

    tempvar col = loc.col
    assert col * (col - 1) * (col - 2) * (col - 3) = 0

    return ()
end

func verify_adjacent_locations(loc0 : Location*, loc1 : Location*):
    alloc_locals
    local row_diff = loc0.row - loc1.row
    local col_diff = loc0.col - loc1.col

    if row_diff == 0:
        # The row coordinate is the same. Make sure the difference
        # in col is 1 or -1.
        assert col_diff * col_diff = 1
        return ()
    else:
        # Verify the difference in row is 1 or -1.
        assert row_diff * row_diff = 1
        # Verify that the col coordinate is the same.
        assert col_diff = 0
        return ()
    end
end

func verify_location_list(loc_list : Location*, n_steps):
    # Always verify that the location is valid, even if
    # n_steps = 0 (remember that there is always one more
    # location than steps).
    verify_location_is_valid(loc=loc_list)

    if n_steps == 0:
        return ()
    end

    verify_adjacent_locations(loc0=loc_list, loc1=loc_list + Location.SIZE)

    # Call verify_location_list recursively.
    verify_location_list(loc_list=loc_list + Location.SIZE, n_steps=n_steps - 1)
    return ()
end

func check_solution{output_ptr : felt*, range_check_ptr}(
        loc_list : Location*, tile_list : felt*, n_steps):
    alloc_locals

    # Start by verifying that loc_list is valid.
    verify_location_list(loc_list=loc_list, n_steps=n_steps)

    # Allocate memory for the dict and the squashed dict.
    let (local dict_start : DictAccess*) = alloc()
    let (local squashed_dict : DictAccess*) = alloc()

    let (dict_end) = build_dict(
        loc_list=loc_list, tile_list=tile_list, n_steps=n_steps, dict=dict_start)

    let (dict_end) = finalize_state(dict=dict_end, idx=15)

    let (squashed_dict_end : DictAccess*) = squash_dict(
        dict_accesses=dict_start, dict_accesses_end=dict_end, squashed_dict=squashed_dict)

    # Store range_check_ptr in a local variable to make it
    # accessible after the call to output_initial_values().
    local range_check_ptr = range_check_ptr

    # Verify that the squashed dict has exactly 15 entries.
    # This will guarantee that all the values in the tile list
    # are in the range 1-15.
    assert squashed_dict_end - squashed_dict = 15 *
        DictAccess.SIZE

    output_initial_values(squashed_dict=squashed_dict, n=15)

    # Output the initial location of the empty tile.
    serialize_word(4 * loc_list.row + loc_list.col)

    # Output the number of steps.
    serialize_word(n_steps)

    return ()
end

# #### MAIN #### #

func main{output_ptr : felt*, range_check_ptr}():
    alloc_locals

    # Declare two vars pointing to the two lists and another var that contains the number of steps.
    local loc_list : Location*
    local tile_list : felt*
    local n_steps

    %{
        #  use a hint to populate them fields allocated above
        locations = program_input['loc_list']
        tiles = program_input['tile_list']

        ids.loc_list = loc_list = segments.add()
        for i, val in enumerate(locations):
            memory[loc_list + i] = val

        ids.tile_list = tile_list = segments.add()
        for i, val in enumerate(tiles):
            memory[tile_list + i] = val

        ids.n_steps = len(tiles)

        # Sanity check (only the prover runs this check).
        assert len(locations) == 2 * (len(tiles) + 1)
    %}

    check_solution(loc_list=loc_list, tile_list=tile_list, n_steps=n_steps)
    return ()
end
