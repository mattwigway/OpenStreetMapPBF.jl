# OSMPBF.jl

Julia library for reading [OSM PBF](https://wiki.openstreetmap.org/wiki/PBF_Format). The basic interface is through the function `scan_pbf`, which is called with callbacks for nodes, ways, and relations (the latter is not yet implemented). It may require several passes through the file to read everything, as there is no guarantee that (say) nodes come before ways. For instance, this code will extract all nodes that occur in highways.

```julia

include("src/OSMPBF.jl")

using .OSMPBF

highway_node_ids = Set{Int64}()
highway_nodes = Dict{Int64, Node}()

function way_handler(way)
    if haskey(way.tags, "highway")
        append!(highway_node_ids, way.nodes)
    end
end

function node_handler(node)
    # store node
    if in(node.id, highway_nodes)
        nodes[node.id] = node
    end
end

# parse ways
scan_pbf(pbf_file, ways=way_handler)

# second pass, parse nodes
scan_pbf(pbf_file, nodes=node_handler)

```