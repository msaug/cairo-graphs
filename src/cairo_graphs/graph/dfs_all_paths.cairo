from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.dict import dict_write, dict_update, dict_read

from cairo_graphs.data_types.data_types import Edge, Vertex, Graph
from cairo_graphs.graph.graph import GraphMethods
from cairo_graphs.utils.array_utils import Stack

const MAX_FELT = 2 ** 251 - 1;
const MAX_HOPS = 4;

func init_dict() -> (dict_ptr: DictAccess*) {
    alloc_locals;

    let (local dict_start) = default_dict_new(default_value=0);
    let dict_end = dict_start;
    return (dict_end,);
}

func init_dfs{range_check_ptr}(
    graph: Graph, start_identifier: felt, dst_identifier: felt, max_hops: felt
) -> (saved_paths_len: felt, saved_paths: felt*) {
    alloc_locals;
    let (dict_ptr: DictAccess*) = init_dict();
    let (saved_paths: felt*) = alloc();
    let (current_path: felt*) = alloc();

    let start_vertex_index = GraphMethods.get_vertex_index{
        graph=graph, identifier=start_identifier
    }(0);
    let dst_vertex_index = GraphMethods.get_vertex_index{graph=graph, identifier=dst_identifier}(0);

    let (saved_paths_len, _, _) = DFS_rec{dict_ptr=dict_ptr}(
        graph=graph,
        current_node=graph.vertices[start_vertex_index],
        destination_node=graph.vertices[dst_vertex_index],
        max_hops=max_hops,
        current_path_len=0,
        current_path=current_path,
        saved_paths_len=0,
        saved_paths=saved_paths,
    );

    // stores the identifiers instead of the indexes in the path
    let (identifiers_path: felt*) = alloc();
    get_identifiers_from_path(
        graph, saved_paths_len, saved_paths, current_index=0, identifiers_path=identifiers_path
    );
    return (saved_paths_len, identifiers_path);
}

func DFS_rec{dict_ptr: DictAccess*, range_check_ptr}(
    graph: Graph,
    current_node: Vertex,
    destination_node: Vertex,
    max_hops: felt,
    current_path_len: felt,
    current_path: felt*,
    saved_paths_len: felt,
    saved_paths: felt*,
) -> (saved_paths_len: felt, current_path_len: felt, current_path: felt*) {
    alloc_locals;
    dict_write{dict_ptr=dict_ptr}(key=current_node.index, new_value=1);

    let (current_path_len, current_path) = Stack.put(
        current_path_len, current_path, current_node.index
    );

    // When we return from this recursive function, we want to:
    // 1. Update the saved_paths array with the current path if it is a valid path. Since we're working with a pointer
    // to the saved_paths array that never changes, we just need to update its length
    // 2. Update the current_path array, after trimming the last elem.
    // 3. Update the current_path_len, after trimming the last elem.
    // 5. Incrementing the remaining_hops since we're going up in the recursion stack

    if (current_node.identifier == destination_node.identifier) {
        // store current path length inside saved_paths
        assert saved_paths[saved_paths_len] = current_path_len;
        let (saved_paths_len) = save_path(
            current_path_len, current_path, saved_paths_len + 1, saved_paths
        );
        tempvar current_path_len = current_path_len;
        tempvar current_path = current_path;
        tempvar saved_paths_len = saved_paths_len;
    } else {
        tempvar current_path_len = current_path_len;
        tempvar current_path = current_path;
        tempvar saved_paths_len = saved_paths_len;
    }

    let (saved_paths_len, current_path_len, current_path, _, _) = visit_successors{
        dict_ptr=dict_ptr
    }(
        graph=graph,
        current_node=current_node,
        destination_node=destination_node,
        remaining_hops=max_hops,
        successors_len=graph.adjacent_vertices_count[current_node.index],
        current_path_len=current_path_len,
        current_path=current_path,
        saved_paths_len=saved_paths_len,
        saved_paths=saved_paths,
    );
    return (saved_paths_len, current_path_len, current_path);
}

func visit_successors{dict_ptr: DictAccess*, range_check_ptr}(
    graph: Graph,
    current_node: Vertex,
    destination_node: Vertex,
    remaining_hops: felt,
    successors_len: felt,
    current_path_len: felt,
    current_path: felt*,
    saved_paths_len: felt,
    saved_paths: felt*,
) -> (
    saved_paths_len: felt,
    current_path_len: felt,
    current_path: felt*,
    successors_len: felt,
    remaining_hops: felt,
) {
    alloc_locals;

    //
    // Return conditions
    //

    // No more successors
    if (successors_len == 0) {
        // dict_write{dict_ptr=dict_ptr}(key=current_node.index, new_value=2)
        let (current_path_len, current_path, _) = Stack.pop(current_path_len, current_path);
        // explore previous_node's next_successor
        return (
            saved_paths_len, current_path_len, current_path, successors_len - 1, remaining_hops
        );
    }

    // Hops greater than limit
    if (remaining_hops == 0) {
        let (current_path_len, current_path, _) = Stack.pop(current_path_len, current_path);
        // explore previous_node's next_successor
        return (
            saved_paths_len, current_path_len, current_path, successors_len - 1, remaining_hops
        );
    }

    // Already visited successor, avoid cycles
    let successor = current_node.adjacent_vertices[successors_len - 1].dst;
    let successor_index = successor.index;
    let (is_already_visited) = is_in_path(current_path_len, current_path, successor_index);
    if (is_already_visited == 1) {
        return visit_successors(
            graph=graph,
            current_node=current_node,
            destination_node=destination_node,
            remaining_hops=remaining_hops,
            successors_len=successors_len - 1,
            current_path_len=current_path_len,
            current_path=current_path,
            saved_paths_len=saved_paths_len,
            saved_paths=saved_paths,
        );
    }

    //
    // Go deeper in the recursion (do DFSrec from current node)
    //

    
    let (successor_visit_state) = dict_read{dict_ptr=dict_ptr}(key=successor_index);

    local saved_paths_len_updated: felt;
    local current_path_updated: felt*;
    local current_path_len_updated: felt;

    let is_state_1_or_0 = is_le(successor_visit_state, 1);
    if (is_state_1_or_0 == 1) {
        // assert current_path[current_path_len] = successor_index
        let (saved_paths_len, current_path_len, current_path) = DFS_rec(
            graph=graph,
            current_node=successor,
            destination_node=destination_node,
            max_hops=remaining_hops - 1,
            current_path_len=current_path_len,
            current_path=current_path,
            saved_paths_len=saved_paths_len,
            saved_paths=saved_paths,
        );
        saved_paths_len_updated = saved_paths_len;
        current_path_len_updated = current_path_len;
        current_path_updated = current_path;
        tempvar dict_ptr = dict_ptr;
        tempvar range_check_ptr = range_check_ptr;
    } else {
        saved_paths_len_updated = saved_paths_len;
        current_path_len_updated = current_path_len;
        current_path_updated = current_path;
        tempvar dict_ptr = dict_ptr;
        tempvar range_check_ptr = range_check_ptr;
    }

    // Visit next successor (decrement successors_len)

    return visit_successors(
        graph=graph,
        current_node=current_node,
        destination_node=destination_node,
        remaining_hops=remaining_hops,
        successors_len=successors_len - 1,
        current_path_len=current_path_len_updated,
        current_path=current_path_updated,
        saved_paths_len=saved_paths_len_updated,
        saved_paths=saved_paths,
    );
}

// @notice returns the index of the node in the graph
// @returns -1 if it's not in the graph
// @returns array index otherwise
func is_in_path(current_path_len: felt, current_path: felt*, index: felt) -> (boolean: felt) {
    if (current_path_len == 0) {
        return (0,);
    }

    let current_index: felt = [current_path];
    if (current_index == index) {
        return (1,);
    }

    return is_in_path(current_path_len - 1, current_path + 1, index);
}

func save_path(
    current_path_len: felt, current_path: felt*, saved_paths_len: felt, saved_paths: felt*
) -> (new_saved_paths_len: felt) {
    let new_saved_paths_len = saved_paths_len + current_path_len;
    memcpy(saved_paths + saved_paths_len, current_path, current_path_len);
    return (new_saved_paths_len,);
}

// @notice Return with an array composed by (path_len,path) subarrays identified by identifiers.
func get_identifiers_from_path(
    graph: Graph,
    saved_paths_len: felt,
    saved_paths: felt*,
    current_index: felt,
    identifiers_path: felt*,
) {
    if (current_index == saved_paths_len) {
        return ();
    }
    let subarray_length = saved_paths[current_index];
    assert [identifiers_path] = subarray_length;

    parse_array_segment(
        graph=graph,
        saved_paths=saved_paths,
        i=current_index + 1,
        j=current_index + 1 + subarray_length,
        identifiers_path=identifiers_path + 1,
    );
    return get_identifiers_from_path(
        graph=graph,
        saved_paths_len=saved_paths_len,
        saved_paths=saved_paths,
        current_index=current_index + subarray_length + 1,
        identifiers_path=identifiers_path + 1 + subarray_length,
    );
}

// @notice parses the identifiers for all vertices between indexes i and j in the indexes array
func parse_array_segment(
    graph: Graph, saved_paths: felt*, i: felt, j: felt, identifiers_path: felt*
) {
    if (i == j) {
        return ();
    }
    let index_in_graph = saved_paths[i];
    assert [identifiers_path] = graph.vertices[index_in_graph].identifier;
    return parse_array_segment(graph, saved_paths, i + 1, j, identifiers_path + 1);
}
