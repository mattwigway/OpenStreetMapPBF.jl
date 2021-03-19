# load a PBF file into memory
# often scan is a better tool, because it can process larger than memory datasets,
# up to and including Planet.osm

struct OsmData
    ways::Dict{Int64, Way}
    nodes::Dict{Int64, Node}
    relations::Dict{Int64, Relation}
end

OsmData() = OsmData(Dict{Int64, Way}(), Dict{Int64, Node}(), Dict{Int64, Relation}())

function load_pbf(pbffile::AbstractString)
    osm = OsmData()

    scan_pbf(pbffile, nodes=n -> osm.nodes[n.id] = n, ways=w -> osm.ways[w.id] = w, relations=r -> osm.relations[r.id] = r)

    return osm
end