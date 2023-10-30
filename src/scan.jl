# read a PBF format file
# format documentation: https://wiki.openstreetmap.org/wiki/PBF_Format, https://github.com/mapbox/osmpbf-tutorial

import .OSMPBF_pb
using ProtoBuf
using Mmap
using CodecZlib

# read a blob header (they occur many times in the file). off points to the offset into the PBF of the 
# header length (which is four raw bytes before the protobuf header)
# all of these read_* functions return their data, and the offset in the file for the next read
function read_blob_header(pbf::Vector{UInt8}, off::Int64)::Tuple{OSMPBF_pb.BlobHeader,Int64}
    # read the length of the header
    hdr_len::Int32 = convert(Int32, ntoh(reinterpret(Int32, @view pbf[off:off + 3])[1]))
    off += 4

    buf = IOBuffer(@view pbf[off:off + hdr_len - 1])
    out = readproto(buf, OSMPBF_pb.BlobHeader())
    off += hdr_len
    return out, off
end

# This reads the header block which occurs once per file
function read_file_header!(pbf::Vector{UInt8}, off::Int64, blhdr::OSMPBF_pb.BlobHeader, out::OSMPBF_pb.HeaderBlock)::Int64
    # read the blob
    off = read_blob!(pbf, off, blhdr, out)
    return off + b
end

function read_blob(pbf::Vector{UInt8}, off::Int64, hdr::OSMPBF_pb.BlobHeader, T::Type)::Tuple{T, Int64}
    buf = IOBuffer(@view pbf[off : off + hdr.datasize - 1])
    blob = readproto(buf, OSMPBF_pb.Blob())

    if hasproperty(blob, :raw)
        buf = IOBuffer(blob.raw)
        out = readproto(buf, T())
    elseif hasproperty(blob, :zlib_data)
        buf = ZlibDecompressorStream(IOBuffer(blob.zlib_data))
        out = readproto(buf, T())
    else
        error("Blob not in raw or zlib format")
    end

    return out, off + hdr.datasize
end

# Parsing raw nodes (i.e. not packed into dense nodes)
# This function is untested because PBF files with regular rather than dense nodes are few and far between
function parse_nodes(nodelist::Vector{OSMPBF_pb.Node}, block::OSMPBF_pb.PrimitiveBlock, strtab::Vector{String}, cb::Function)
    @info "got $(length(nodelist)) nodes"
    for raw_node in nodelist
        nodeid = raw_node.id::Int64
        lat = 1e-9 * (block.lat_offset + (block.granularity * raw_node.lat))::Float64
        lon = 1e-9 * (block.lon_offset + (block.granularity * raw_node.lon))::Float64
        tags = map(Iterators.zip(raw_node.keys, raw_node.vals)) do t
            return lowercase(strtab[t[1]]) => strtab[t[2]]
        end |> Dict
        node = Node(
            nodeid,
            lat,
            lon,
            tags
        )
        cb(node)
    end

    return nothing
end

function parse_dense_nodes(dense::OSMPBF_pb.DenseNodes, block::OSMPBF_pb.PrimitiveBlock, strtab::Vector{String}, cb::Function)
    # first, parse and de-delta-code
    ids = Vector{Int64}()
    lats = Vector{Float64}()
    lons = Vector{Float64}()
    n = length(dense.id)
    sizehint!(ids, n)
    sizehint!(lats, n)
    sizehint!(lons, n)

    # read and de-delta-code ids
    current_id = 0
    for id in dense.id
        current_id += id
        push!(ids, current_id)
    end

    current_lat = 0
    for lat in dense.lat
        current_lat += lat
        push!(lats, 1e-9 * (block.lat_offset + (block.granularity * current_lat)))
    end

    current_lon = 0
    for lon in dense.lon
        current_lon += lon
        push!(lons, 1e-9 * (block.lon_offset + (block.granularity * current_lon)))
    end

    if length(dense.keys_vals) > 0
        # parse tags and yield simultaneously to save memory
        off = 1
        current_node = 1
        current_tags = Dict{String, String}()
        while off <= length(dense.keys_vals)
            if dense.keys_vals[off] == 0
                # yield this node
                Node(ids[current_node], lats[current_node], lons[current_node], current_tags) |> cb

                # prepare for next node
                current_tags = Dict{String, String}()  # can't just call empty! as caller may have a reference to tags from current node
                current_node += 1
                off += 1
                continue
            end

            key = strtab[dense.keys_vals[off]]
            val = strtab[dense.keys_vals[off + 1]]
            current_tags[key] = val
            off += 2
        end

        # yield final node if we have not already
        # the spec doesn't say whether the last element of keys_vals needs to be a zero. osmium does
        # zero-terminate these arrays, but I don't want to count on this behavior
        if current_node == n
            Node(ids[current_node], lats[current_node], lons[current_node], current_tags) |> cb
            current_node += 1
        end

        # make sure we have yielded everything
        @assert current_node == n + 1
    else
        # special case of no tags
        for current_node in 1:n
            Node(ids[current_node], lats[current_node], lons[current_node], Dict{String, String}()) |> cb
        end
    end

    return nothing
end

function parse_ways(ways::Vector{OSMPBF_pb.Way}, strtab::Vector{String}, cb::Function)
    for raw_way in ways
        wayid = raw_way.id::Int64

        nodes = Vector{Int64}()
        sizehint!(nodes, length(raw_way.refs))

        current_nodeid = 0
        for nodeid in raw_way.refs
            current_nodeid += nodeid
            push!(nodes, current_nodeid)
        end

        tags = map(Iterators.zip(raw_way.keys, raw_way.vals)) do t
            return strtab[t[1]] => strtab[t[2]]
        end |> Dict

        Way(wayid, nodes, tags) |> cb
    end

    return nothing
end

function parse_relations(relations::Vector{OSMPBF_pb.Relation}, strtab::Vector{String}, cb::Function)
    for raw_rel in relations
        relid = raw_rel.id::Int64
        tags = map(Iterators.zip(raw_rel.keys, raw_rel.vals)) do t
            return strtab[t[1]] => strtab[t[2]]
        end |> Dict
        members = Vector{RelationMember}()
        sizehint!(members, length(raw_rel.memids))

        memid = 0
        for i in 1:length(raw_rel.memids)
            memid += raw_rel.memids[i]  # de-delta-code
            role = strtab[raw_rel.roles_sid[i]]
            raw_type = raw_rel.types[i]
            type = raw_type == OSMPBF_pb.Relation_MemberType.NODE ? node :
                (raw_type == OSMPBF_pb.Relation_MemberType.WAY ? way : relation)
            push!(members, RelationMember(memid, type, role))
        end

        Relation(relid, members, tags) |> cb
    end
end

# hoping that the compiler is smart enough that the Any return types won't cause type instability, since the return values are not used...
function scan_pbf(pbffile; nodes::Union{Function, Missing}=missing, ways::Union{Function, Missing}=missing, relations::Union{Function, Missing}=missing)
    # read the file
    open(pbffile, "r") do stream
        pbf::Vector{UInt8} = Mmap.mmap(stream) 

        off::Int64 = 1

        blhdr, off = read_blob_header(pbf, off)

        @assert blhdr._type == "OSMHeader"  "Malformed OSM PBF file, expected OSMData block but found $(blhdr._type)"

         file_header, off = read_blob(pbf, off, blhdr, OSMPBF_pb.HeaderBlock)

        @info "Reading file written by $(file_header.writingprogram)"

        # track these to avoid spammy log messages, only log once
        has_relations = false
        has_changesets = false

        # <= b/c julia starts array indices at 1, so pbf[length(pbf)] is the last byte of the file
        while (off <= length(pbf))
            # TODO should be okay to reuse blob headers right
            blhdr, off = read_blob_header(pbf, off)
            @assert blhdr._type == "OSMData"  "Malformed OSM PBF file, expected OSMData block but found $(blhdr._type)"

            block, off = read_blob(pbf, off, blhdr, OSMPBF_pb.PrimitiveBlock)

            # the primitiveblock contains several primitivegroups which may contain nodes, ways, etc.
            # but they reference string tables
            # drop index 1 (in Julia land)/index 0 (everywhere) which is always empty string and used as a delimiter
            # this also means that if a node etc say string x, strtab[x] is the correct string - no off-by-one errors
            # due to Julia starting arrays at 1. 
            strtab::Vector{String} = map(String, block.stringtable.s[2:length(block.stringtable.s)])

            for grp in block.primitivegroup
                if (length(grp.nodes) > 0)
                    if !ismissing(nodes)
                        parse_nodes(grp.nodes, block, strtab, nodes)
                    end
                elseif hasproperty(grp, :dense) && length(grp.dense.id) > 0
                    if !ismissing(nodes)
                        parse_dense_nodes(grp.dense, block, strtab, nodes)
                    end
                elseif (length(grp.ways) > 0)
                    if !ismissing(ways)
                        parse_ways(grp.ways, strtab, ways)
                    end
                elseif (length(grp.relations) > 0)
                    if !ismissing(relations)
                        parse_relations(grp.relations, strtab, relations)
                    end
                elseif (length(grp.changesets) > 0)
                    if !has_changesets
                        @warn "changesets are present in $pbffile, but are not yet supported"
                        has_changesets = true  # don't warn again
                    end
                else
                    error("Malformed PBF file, PrimitiveGroup has no ways, nodes, dense nodes, relations, or changesets")
                end
            end
        end
    end
end

# convenience functions to scan nodes, ways, relations with do block syntax
scan_nodes(nodefunc, pbffile) = scan_pbf(pbffile, nodes=nodefunc)
scan_ways(wayfunc, pbffile) = scan_pbf(pbffile, ways=wayfunc)
scan_relations(relationfunc, pbffile) = scan_pbf(pbffile, relations=relationfunc)
