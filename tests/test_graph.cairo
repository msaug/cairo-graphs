%lang starknet
from src.graph.graph import add_neighbor, add_vertex_to_graph, get_vertex_index, add_edge
from starkware.cairo.common.alloc import alloc
from src.data_types.data_types import Edge, Vertex

const TOKEN_A = 123
const TOKEN_B = 456
const TOKEN_C = 990
const TOKEN_D = 982

func build_graph_before_each() -> (
    graph : Vertex*, graph_len : felt, neighbors : felt*, neighbors_len : felt
):
    alloc_locals
    let (graph : Vertex*) = alloc()
    let (adj_vertices_count : felt*) = alloc()  # array that tracks neighbors_len

    let (vertex_a_neighbors : Vertex*) = alloc()
    let (vertex_b_neighbors : Vertex*) = alloc()
    let (vertex_c_neighbors : Vertex*) = alloc()

    local vertex_a : Vertex = Vertex(0, TOKEN_A, vertex_a_neighbors)
    local vertex_b : Vertex = Vertex(1, TOKEN_B, vertex_b_neighbors)
    local vertex_c : Vertex = Vertex(2, TOKEN_C, vertex_c_neighbors)

    # populate graph
    assert graph[0] = vertex_a
    assert adj_vertices_count[0] = 0
    assert graph[1] = vertex_b
    assert adj_vertices_count[1] = 0
    assert graph[2] = vertex_c
    assert adj_vertices_count[2] = 0
    let neighbors_len = 3
    let graph_len = 3
    return (graph, graph_len, adj_vertices_count, neighbors_len)
end

@external
func test_add_node_to_graph():
    let (graph : Vertex*) = alloc()
    let (adj_vertices_count : felt*) = alloc()  # array that tracks the number of neighbor_nodes
    let graph_len : felt = 0

    let (graph_len) = add_vertex_to_graph(graph_len, graph, adj_vertices_count, TOKEN_A)
    assert graph_len = 1
    assert graph[0].identifier = TOKEN_A
    assert adj_vertices_count[0] = 0

    let (graph_len) = add_vertex_to_graph(graph_len, graph, adj_vertices_count, TOKEN_B)
    assert graph_len = 2
    assert graph[1].identifier = TOKEN_B
    assert adj_vertices_count[1] = 0

    return ()
end

@external
func test_add_neighbor():
    alloc_locals
    let (graph, graph_len, adj_vertices_count, adj_vertices_count_len) = build_graph_before_each()
    assert graph[0].identifier = TOKEN_A
    assert graph[1].identifier = TOKEN_B
    assert graph[2].identifier = TOKEN_C
    assert adj_vertices_count_len = 3  # neighbors_len is 3 because we have 3 nodes in our graph

    # add TOKEN_B as neighbor of TOKEN_A
    let (adj_vertices_count) = add_neighbor(
        graph[0], graph[1], adj_vertices_count_len, adj_vertices_count, 0, 0
    )
    assert graph[0].adjacent_vertices[0].identifier = TOKEN_B
    assert adj_vertices_count[0] = 1  # TOKEN_A has 1 neighbor, which is TOKEN_B
    assert adj_vertices_count[1] = 0  # TOKEN_B still has 0 neighbors

    # now add TOKEN_A as neighbor of TOKEN_B
    let (adj_vertices_count) = add_neighbor(
        graph[1], graph[0], adj_vertices_count_len, adj_vertices_count, 1, 0
    )
    assert graph[1].adjacent_vertices[0].identifier = TOKEN_A
    assert adj_vertices_count[1] = 1  # TOKEN_B now has 1 neighbor

    # add TOKEN_C as neighbor of TOKEN_A
    let (adj_vertices_count) = add_neighbor(
        graph[0], graph[2], adj_vertices_count_len, adj_vertices_count, 0, 0
    )
    assert graph[0].adjacent_vertices[1].identifier = TOKEN_C
    assert adj_vertices_count[0] = 2  # TOKEN_A now has 2 neighbors

    return ()
end

@external
func test_add_edge():
    alloc_locals
    let (graph, graph_len, adj_vertices_count, adj_vertices_count_len) = build_graph_before_each()

    # add C<>D
    let (graph_len, adj_vertices_count) = add_edge(
        graph, graph_len, adj_vertices_count, Edge(TOKEN_C, TOKEN_D, 0)
    )

    let (local res : felt) = get_vertex_index(graph_len, graph, TOKEN_C)
    assert res = 2
    let (local res : felt) = get_vertex_index(graph_len, graph, TOKEN_D)
    assert res = 3

    assert graph[3].adjacent_vertices[0].identifier = TOKEN_C

    return ()
end

@external
func test_get_node_index():
    alloc_locals
    let (graph, graph_len, neighbors, neighbors_len) = build_graph_before_each()

    let (local res : felt) = get_vertex_index(graph_len, graph, TOKEN_A)
    assert res = 0
    let (local res : felt) = get_vertex_index(graph_len, graph, TOKEN_B)
    assert res = 1

    return ()
end


struct Pair:
    member token_0 : felt
    member token_1 : felt
end

@external
func test_build_graph_bidirected():
    alloc_locals
    let (local graph : Vertex*) = alloc()
    let (local adj_vertices_count : felt*) = alloc()
    let input_data : Pair* = alloc()
    assert input_data[0] = Pair(TOKEN_A, TOKEN_B)
    assert input_data[1] = Pair(TOKEN_A, TOKEN_C)
    assert input_data[2] = Pair(TOKEN_B, TOKEN_C)

    # the node at graph[i] has adj_vertices_count[i] adjacent vertices.
    # that allows us to dynamically modify the number of neighbors to a vertex, without the need
    # to rebuild the graph (since memory is write-once, we can't update a property of a struct already stored.)
    let (graph_len, adj_vertices_count) = _build_graph_bidirected(
        3, input_data, 0, graph, adj_vertices_count
    )

    assert graph_len = 3
    assert graph[0].identifier = TOKEN_A
    assert graph[1].identifier = TOKEN_B
    assert graph[2].identifier = TOKEN_C
    assert adj_vertices_count[0] = 2
    assert adj_vertices_count[1] = 2
    assert adj_vertices_count[2] = 2
    return ()
end

# @notice internal function to build the graph recursively
# @dev
# @param pairs_len : The length of the pairs array
# @param pairs : The pairs array
# @param graph_len : The length of the graph
# @param graph : The graph
# @param neighbors : The array of neighbors
func _build_graph_bidirected(
    pairs_len : felt, pairs : Pair*, graph_len : felt, graph : Vertex*, adj_vertices_count : felt*
) -> (graph_len : felt, adj_vertices_count : felt*):
    alloc_locals

    if pairs_len == 0:
        return (graph_len, adj_vertices_count)
    end

    let token_0 = [pairs].token_0
    let token_1 = [pairs].token_1

    let (graph_len, adj_vertices_count) = add_edge(
        graph, graph_len, adj_vertices_count, Edge(token_0, token_1, 0)
    )

    let (graph_len, adj_vertices_count) = add_edge(
        graph, graph_len, adj_vertices_count, Edge(token_1, token_0, 0)
    )

    return _build_graph_bidirected(
        pairs_len - 1, pairs + Pair.SIZE, graph_len, graph, adj_vertices_count
    )
end