const LatLon = @NamedTuple{lat::Float64, lon::Float64}

function main(args)
    file = args["input_file"]

    all_node_locations = Dict{Int64, LatLon}()

    @info "Caching node locations"
    scan_pbf(file, nodes=n -> begin
        all_node_locations[n.id] = (lat=n.lat, lon=n.lon)
    end)

    @info "Cached $(length(all_node_locations)) node locations"

    @info "Reading ways"
    local way_filter
    if haskey(args, "filter-ways")
        way_filter = generate_filter(args["filter-ways"])
    else
        way_filter = x -> true  # no-op filter
    end

    # TODO handle x:y tags, convert to x_y or something
    gdal_tags = lowercase.(split(args["gdal-tags"], ","))

    ArchGDAL.create(args["write-gdal-ways"], driver = ArchGDAL.getdriver(args["gdal-driver"])) do ds
        # EPSG 4326 - WGS 84 - coordinate reference system used by OpenStreetMap
        ArchGDAL.createlayer(name="osm", geom=ArchGDAL.wkbLineString, dataset=ds, spatialref=ArchGDAL.importEPSG(4326)) do layer
            ArchGDAL.addfielddefn!(layer, "osmid", ArchGDAL.OFTInteger64)
            for tag in gdal_tags
                # todo long field names for shapefile
                ArchGDAL.addfielddefn!(layer, tag, ArchGDAL.OFTString)
            end
            
            lats = Vector{Float64}()
            lons = Vector{Float64}()
            oid = zero(Int64)

            scan_pbf(file, ways = way -> begin
                if way_filter(way)
                    if length(way.nodes) < 2
                        return
                    end
                    empty!(lats)
                    empty!(lons)
                    nodes = Vector{Int64}()
                    push!(nodes, way.nodes[1])

                    # prepopulate with first node
                    prev_nodeid = -one(Int64)
                    for nodeid in way.nodes
                        # skip duplicated nodes
                        if nodeid != prev_nodeid
                            node = all_node_locations[nodeid]
                        
                            push!(lats, node.lat)
                            push!(lons, node.lon)
                            prev_nodeid = nodeid
                        end
                    end

                    # save the way to the file
                    ArchGDAL.addfeature(layer) do f
                        ArchGDAL.setgeom!(f, ArchGDAL.createlinestring(lons, lats))
                        ArchGDAL.setfield!(f, 0, way.id)
                        for (i, tag) in enumerate(gdal_tags)
                            # GDAL uses zero-based indexing while Julia uses 1-based so it's okay that the way id is the first field
                            if haskey(way.tags, tag)
                                ArchGDAL.setfield!(f, i, way.tags[tag])
                            else
                                ArchGDAL.setfieldnull!(f, i)
                            end
                        end

                        # createfeature uses setfeature! instead of addfeature!, so fid needs to be defined
                        ArchGDAL.setfid!(f, oid)
                        oid += 1
                    end
                    # prepare for next way segment
                    empty!(lats)
                    empty!(lons)
                end
            end)

            @info "Wrote $(oid + 1) ways"
        end
    end
end