module OpenStreetMapPBF
using Logging

include("proto/OSMPBF_pb.jl")
include("model.jl")
include("scan.jl")
include("load.jl")

export scan_pbf, scan_nodes, scan_ways, scan_relations, load_pbf, Node, Way, Relation, way, node, relation
end