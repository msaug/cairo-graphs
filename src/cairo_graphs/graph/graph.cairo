from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_not_equal

from cairo_graphs.data_types.data_types import Vertex, Edge, AdjacentVertex, Graph
from cairo_graphs.utils.array_utils import Array

// # Adjancency list graph implementation

namespace GraphMethods {
    // @notice Creates a new empty graph.
    func new_graph() -> Graph {
        let (graph: Vertex*) = alloc();
        let (adj_vertices_count: felt*) = alloc();
        tempvar res: Graph = Graph(0, graph, adj_vertices_count);
        return res;
    }

    // @notice Builds an undirected graph
    // @param edges_len : The length of the array of edges
    // @param edges : The array of edges
    // @returns graph : The graph built from the array of edges
    func build_undirected_graph_from_edges(edges_len: felt, edges: Edge*) -> Graph {
        alloc_locals;
        let graph = GraphMethods.new_graph();
        return build_undirected_graph_from_edges_internal(edges_len, edges, graph);
    }

    // @notice Builds a directed graph
    // @param edges_len : The length of the array of edges
    // @param edges : The array of edges
    // @returns graph : The graph built from the array of edges
    func build_directed_graph_from_edges(edges_len: felt, edges: Edge*) -> Graph {
        let graph = GraphMethods.new_graph();
        return build_directed_graph_from_edges_internal(edges_len, edges, graph);
    }

    // @notice Adds an edge between two graph vertices
    // @dev if the vertices don't exist yet, adds them to the graph
    // @param graph : The graph we're adding the edges to
    // @param edge : Edge to add to the graph. Holds the info about the src_identifier, dst_identifier and weight.
    // @returns the updated Graph
    func add_edge(graph: Graph, edge: Edge) -> Graph {
        alloc_locals;
        let src_identifier = edge.src_identifier;
        let dst_identifier = edge.dst_identifier;
        let vertices = graph.vertices;
        let weight = edge.weight;

        let graph_len = graph.length;
        let vertices = graph.vertices;
        let adjacent_vertices_count: felt* = graph.adjacent_vertices_count;

        assert_not_equal(src_identifier, dst_identifier);  // can't add two nodes with the same identifier
        let src_vertex_index = get_vertex_index{graph=graph, identifier=src_identifier}(0);
        let dst_vertex_index = get_vertex_index{graph=graph, identifier=dst_identifier}(0);

        // Add both vertices to the graph if they aren't already there
        if (src_vertex_index == -1) {
            let graph = add_vertex_to_graph(graph, src_identifier);
            tempvar src_vertex_index = graph.length - 1;
            tempvar graph = graph;
        } else {
            tempvar src_vertex_index = src_vertex_index;
            tempvar graph = graph;
        }

        tempvar src_vertex_index = src_vertex_index;

        if (dst_vertex_index == -1) {
            let graph = add_vertex_to_graph(graph, dst_identifier);
            tempvar dst_vertex_index = graph.length - 1;
            tempvar graph = graph;
        } else {
            tempvar dst_vertex_index = dst_vertex_index;
            tempvar graph = graph;
        }

        tempvar dst_vertex_index = dst_vertex_index;

        // Add the edge from src to dst to the graph, stored as an adjacent vertex in the adjacency lists of the source.
        let res = add_neighbor(
            vertices[src_vertex_index],
            vertices[dst_vertex_index],
            graph,
            src_vertex_index,
            weight,
        );
        tempvar dst_vertex_index = dst_vertex_index;
        return res;
    }

    // @notice Adds a vertex to the graph.
    // @dev Creates a new vertex stored at graph.vertices[graph_len].
    // @param graph : The graph we want to add the vertex to.
    // @param identifier : Unique identifier of the vertex to add.
    // @returns graph_len : The updated graph.
    func add_vertex_to_graph(graph: Graph, identifier: felt) -> Graph {
        let adj_vertices: AdjacentVertex* = alloc();
        tempvar vertex: Vertex = Vertex(graph.length, identifier, adj_vertices);
        assert graph.vertices[graph.length] = vertex;
        assert graph.adjacent_vertices_count[graph.length] = 0;
        let new_graph_len = graph.length + 1;
        tempvar res: Graph = Graph(new_graph_len, graph.vertices, graph.adjacent_vertices_count);
        return res;
    }

    // @notice Recursive function returning the index of the node in the graph
    // @param graph : The graph we're working with.
    // @param identifier, The unique identifier of the vertex.
    // @returns -1 if it's not in the graph, the index in the graph.vertices array otherwise
    func get_vertex_index{graph: Graph, identifier: felt}(current_index) -> felt {
        alloc_locals;
        if (graph.length == current_index) {
            return -1;
        }
        local current_identifier: felt = graph.vertices[current_index].identifier;
        if (current_identifier == identifier) {
            return graph.vertices[current_index].index;
        }

        return get_vertex_index(current_index + 1);
    }
}

// @notice adds a neighbor to the adjacent vertices of a vertex
// @param vertex : The vertex to add the neighbor to.
// @param new_neighbor : The neighbor to add to the vertex.
// @param adj_vertices_count_len : The length of the adj_vertices_count array.
// @param adj_vertices_count : Array that tracks how many adjacent vertices each vertex has.
// @param vertex_index_in_graph : The index of the vertex in the graph.
// @return the updated adj_vertices_count
func add_neighbor(
    vertex: Vertex,
    new_neighbor: Vertex,
    graph:Graph,
    vertex_index_in_graph: felt,
    weight: felt,
) -> Graph {
    let current_count = graph.adjacent_vertices_count[vertex_index_in_graph];
    tempvar adjacent_vertex = AdjacentVertex(new_neighbor, weight);
    assert vertex.adjacent_vertices[current_count] = adjacent_vertex;
    // update neighbors_len
    let new_count = current_count + 1;
    let (new_adj_vertices_count: felt*) = Array.update_value_at_index(
        graph.length, graph.adjacent_vertices_count, vertex_index_in_graph, new_count
    );
    tempvar res = Graph(graph.length, graph.vertices, new_adj_vertices_count);
    return res;
}

// @notice internal function to build the graph recursively
// @dev
// @param pairs_len : The length of the pairs edges_len
// @param edges : The edges array
// @param graph : The graph
func build_undirected_graph_from_edges_internal(
    edges_len: felt, edges: Edge*, graph: Graph
) -> Graph {
    alloc_locals;

    if (edges_len == 0) {
        return graph;
    }

    let graph = GraphMethods.add_edge(graph, [edges]);

    let graph = GraphMethods.add_edge(
        graph, Edge([edges].dst_identifier, [edges].src_identifier, [edges].weight)
    );

    return build_undirected_graph_from_edges_internal(edges_len - 1, edges + Edge.SIZE, graph);
}

// @notice internal function to build the graph recursively
// @dev
// @param pairs_len : The length of the pairs array
// @param pairs : The pairs array
// @param graph : The graph
func build_directed_graph_from_edges_internal(
    edges_len: felt, edges: Edge*, graph: Graph
) -> Graph {
    alloc_locals;

    if (edges_len == 0) {
        return graph;
    }

    let graph = GraphMethods.add_edge(graph, [edges]);

    return build_directed_graph_from_edges_internal(edges_len - 1, edges + Edge.SIZE, graph);
}
