# OpenStreetMapPBF.jl

Julia library for reading [OSM PBF](https://wiki.openstreetmap.org/wiki/PBF_Format). The basic interface is through the functions `scan_nodes`, `scan_ways`, and `scan_relations`, which calls the callback for each node, way, or relation, respectively. It may require several passes through the file to read everything, as there is no guarantee that (say) nodes come before ways. For instance, this code will extract all nodes that occur in highways. The interface is inspired by the very useful but unfortunately unmaintained [imposm.parser](https://github.com/omniscale/imposm-parser) for Python.

```julia

using OpenStreetMapPBF

highway_node_ids = Set{Int64}()
highway_nodes = Dict{Int64, Node}()

# parse ways
scan_ways(pbf_file_name) do way
    if haskey(way.tags, "highway")
        union!(highway_node_ids, way.nodes)
    end
end

# second pass, parse nodes
scan_nodes(pbf_file_name) do node
    # store node
    if in(node.id, highway_node_ids)
        highway_nodes[node.id] = node
    end
end

```

In some cases it may be valuable to parse nodes, ways, and relations in a single pass. This can be done with the function `scan_pbf`, which takes the name of the file as the first argument and named arguments `nodes`, `ways`, and `relations` with the appropriate callbacks (which can be anonymous functions or named functions, and any you don't need can be omitted).