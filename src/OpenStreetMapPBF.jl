module OpenStreetMapPBF
using Logging
import ProtoBuf: ProtoDecoder, decode
import Mmap
import CodecZlib: ZlibDecompressorStream

include("proto/OSMPBF/OSMPBF.jl")

include("model.jl")
include("scan.jl")
include("load.jl")

export scan_pbf, scan_nodes, scan_ways, scan_relations, load_pbf, Node, Way, Relation, way, node, relation
end