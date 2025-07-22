const ENTITIES_PER_BLOCK = 8192
const GRANULARITY = 100

"""
    write_pbf(filename, nodes, ways, relations)

Write the nodes, ways, and relations from the respective iterators to the PBF file filename.
"""
function write_pbf(filename, nodes, ways, relations)
    open(filename, "w") do pbf
        write_header(pbf)
        write_nodes(pbf, nodes)
        write_ways(pbf, ways)
        write_relations(pbf, relations)
    end
end

function write_header(pbf)
    hdr = OSMPBF.HeaderBlock(nothing, [], [], "OpenStreetMapPBF.jl", "", 0, 0, "")
    write_blob!(pbf, hdr; typ="OSMHeader")
end

function get_or_add_string!(stringtable, string)
    idx = findfirst(x -> x == string, stringtable)
    if isnothing(idx)
        push!(stringtable, string)
        return length(stringtable)
    else
        return idx
    end
end

# idx 0 is always empty string delimiter
create_string_table(vec::Vector{String}) = OSMPBF.StringTable([UInt8[], Vector{UInt8}.(vec)...])

function write_blob!(pbf, block; typ="OSMData")
    blob = IOBuffer()
    blob_encoder = ProtoEncoder(blob)
    encode(blob_encoder, block)
    decompressed_bytes = take!(blob)

    if length(decompressed_bytes) > 16 * 1024 * 1024
        return false # too big
    end


    blobob = OSMPBF.Blob(length(decompressed_bytes), OneOf(:zlib_data, transcode(ZlibCompressor, decompressed_bytes)))
    
    blobdata = IOBuffer()
    encode(ProtoEncoder(blobdata), blobob)
    blob_bytes = take!(blobdata)

    hdr = IOBuffer()
    encode(ProtoEncoder(hdr), OSMPBF.BlobHeader(typ, [], length(blob_bytes)))
    hdrdata = take!(hdr)

    write(pbf, hton(convert(Int32, length(hdrdata))))
    write(pbf, hdrdata)
    write(pbf, blob_bytes)
    return true
end

function write_nodes(pbf, nodes)
    # we write as DenseNodes
    for nodegroup in Iterators.partition(nodes, ENTITIES_PER_BLOCK)
        write_nodegroup(pbf, nodegroup)
    end
end

function write_nodegroup(pbf, nodegroup)
    stringtable = String[]
    last_id = 0
    last_lat = 0
    last_lon = 0

    ids = Int64[]
    lats = Int64[]
    lons = Int64[]
    keys_vals = Int64[]

    for node::Node ∈ nodegroup
        push!(ids, node.id - last_id)
        last_id = node.id

        # we always encode with offset 0
        ilat = round(Int64, node.lat * 1e9 / GRANULARITY)
        push!(lats, ilat - last_lat)
        last_lat = ilat

        ilon = round(Int64, node.lon * 1e9 / GRANULARITY)
        push!(lons, ilon - last_lon)
        last_lon = ilon

        for (key, val) ∈ pairs(node.tags)
            push!(keys_vals, get_or_add_string!(stringtable, key))
            push!(keys_vals, get_or_add_string!(stringtable, val))
        end

        push!(keys_vals, 0)
    end

    # if no nodes have tags, no need to record any separators
    if isempty(stringtable)
        empty!(keys_vals)
    end

    dnodes = OSMPBF.DenseNodes(ids, nothing, lats, lons, keys_vals)
    group = OSMPBF.PrimitiveGroup([], dnodes, [], [], [])
    stab = create_string_table(stringtable)
    block = OSMPBF.PrimitiveBlock(stab, [group], GRANULARITY, 0, 0, 0)
    
    if !write_blob!(pbf, block)
        # node group was too large, split in half and try again
        @warn "Node group with $(length(nodegroup)) nodes was too large, splitting"
        for ng2 in Iterators.partition(nodegroup, length(nodegroup) ÷ 2 + 1)
            write_nodegroup(pbf, ng2)
        end
    end
end

function write_ways(pbf, ways)
    for waygroup ∈ Iterators.partition(ways, ENTITIES_PER_BLOCK)
        write_waygroup(pbf, waygroup)
    end
end

function write_waygroup(pbf, waygroup)
    stringtable = String[]

    ways = map(waygroup) do way
        keys = Int32[]
        vals = Int32[]
        refs = Int64[]
        last_node = 0

        for node ∈ way.nodes
            push!(refs, node - last_node)
            last_node = node
        end

        for (key, val) ∈ pairs(way.tags)
            push!(keys, get_or_add_string!(stringtable, key))
            push!(vals, get_or_add_string!(stringtable, val))
        end

        return OSMPBF.Way(way.id, keys, vals, nothing, refs, [], [])
    end

    group = OSMPBF.PrimitiveGroup([], nothing, ways, [], [])
    stab = create_string_table(stringtable)
    block = OSMPBF.PrimitiveBlock(stab, [group], GRANULARITY, 0, 0, 0)
    if !write_blob!(pbf, block)
        @warn "Way group with $(length(waygroup)) nodes was too large, splitting"
        for wg2 in Iterators.partition(waygroup, length(waygroup) ÷ 2 + 1)
            write_waygroup(pbf, wg2)
        end
    end
end

function write_relations(pbf, relations)
    for relgroup ∈ Iterators.partition(relations, ENTITIES_PER_BLOCK)
        write_relgroup(pbf, relgroup)
    end
end

function write_relgroup(pbf, relgroup)
    stringtable = String[]

    relations = map(relgroup) do rel::Relation
        keys = Int32[]
        vals = Int32[]
        roles = Int32[]
        memids = Int64[]
        memtype = OSMPBF.var"Relation.MemberType".T[]
        last_memid = 0

        for (key, val) ∈ pairs(rel.tags)
            push!(keys, get_or_add_string!(stringtable, key))
            push!(vals, get_or_add_string!(stringtable, val))
        end

        for member in rel.members
            push!(memids, member.id - last_memid)
            last_memid = member.id
            push!(roles, get_or_add_string!(stringtable, member.role))
            push!(memtype, convert(OSMPBF.var"Relation.MemberType".T, member.type))
        end

        return OSMPBF.Relation(rel.id, keys, vals, nothing, roles, memids, memtype)
    end

    group = OSMPBF.PrimitiveGroup([], nothing, [], relations, [])
    stab = create_string_table(stringtable)
    block = OSMPBF.PrimitiveBlock(stab, [group], GRANULARITY, 0, 0, 0)
    if !write_blob!(pbf, block)
        @warn "Way group with $(length(waygroup)) nodes was too large, splitting"
        for wg2 in Iterators.partition(waygroup, length(waygroup) ÷ 2 + 1)
            write_waygroup(pbf, wg2)
        end
    end
end
