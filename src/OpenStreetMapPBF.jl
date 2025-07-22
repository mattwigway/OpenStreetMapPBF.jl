module OpenStreetMapPBF
using Logging
import ProtoBuf: ProtoDecoder, decode, ProtoEncoder, encode, OneOf
import Mmap
import CodecZlib: ZlibDecompressorStream, ZlibCompressor
import StructEquality: @struct_hash_equal_isapprox

include("proto/OSMPBF/OSMPBF.jl")

include("model.jl")
include("scan.jl")
include("load.jl")
include("write.jl")

export scan_pbf, scan_nodes, scan_ways, scan_relations, load_pbf, Node, Way, Relation, way, node, relation, write_pbf
end