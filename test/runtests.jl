using Test, OpenStreetMapPBF

@testset "Read file" begin
    # read the Chapel Hill, North Carolina, USA OSM file that is checked into the repository.
    # retrieved from https://protomaps.com/downloads/osm/08bb2494-c06e-4270-ad1f-243f050284cd
    
    file = joinpath(Base.source_dir(), "chapel_hill_nc_usa.osm.pbf")

    # Check node loading code
    node_ids = Set{Int64}()
    found_med_deli = false

    scan_nodes(file) do n
        # no duplicated nodes
        @test n.id ∉ node_ids
        push!(node_ids, n.id)

        if n.id == 3921279444
            found_med_deli = true
            # Check that tags were stored properly, for the best restaurant in Chapel Hill, node version 5
            @test n.tags["name"] == "Mediterranean Deli, Bakery and Catering"
            @test n.tags["addr:city"] == "Chapel Hill"
            @test n.tags["addr:country"] == "US"
            @test n.tags["addr:housenumber"] == "410"
            @test n.tags["addr:postcode"] == "27516"
            @test n.tags["addr:state"] == "NC"
            @test n.tags["addr:street"] == "West Franklin Street"
            @test n.tags["amenity"] == "restaurant"
            @test n.tags["capacity"] == "150"
            @test n.tags["contact:website"] == "http://www.mediterraneandeli.com"
            @test n.tags["cuisine"] == "kebab"
            @test n.tags["cuisine_1"] == "mediterranean"
            @test n.tags["cuisine_2"] == "shawerma"
            @test n.tags["delivery"] == "yes"
            @test n.tags["opening_hours"] == "Mo-Su 11:00-22:00"
            @test n.tags["payment:bitcoin"] == "yes"
            @test n.tags["smoking"] == "outside"
            @test n.tags["takeaway"] == "yes"

            @test length(n.tags) == 18  # make sure no extra tags

            # check location
            @test n.lat ≈ 35.9113153
            @test n.lon ≈ -79.0609806
        end
    end

    @test found_med_deli

    @test length(node_ids) == 632572

    # check ways
    way_ids = Set{Int64}()
    found_tanyard = false

    scan_ways(file) do way
        @test way.id ∉ way_ids
        push!(way_ids, way.id)

        @test all(way.nodes .∈ Ref(node_ids))
        
        if way.id == 651257375
            found_tanyard = true

            @test way.nodes == [5076304249, 7052878634, 5076304252, 5076304253, 5076304254, 7052878635, 5076304255, 5076304256, 7052878636, 5076304257, 5076304258, 5210917959, 4972477818]

            @test way.tags["bicycle"] == "designated"
            @test way.tags["foot"] == "designated"
            @test way.tags["highway"] == "cycleway"
            @test way.tags["lit"] == "no"
            @test way.tags["name"] == "Tanyard Branch Trail"
            @test way.tags["segregated"] == "no"
            @test way.tags["start_date"] == "2018-06-02"
            @test way.tags["surface"] == "concrete"
            @test way.tags["website"] == "https://www.townofchapelhill.org/town-hall/departments-services/parks-recreation/facilities-greenways-parks/greenways/tanyard-branch-trail"
            @test way.tags["width"] == "3"

            @test length(way.tags) == 10
        end
    end

    @test found_tanyard
    @test length(way_ids) == 50260

    rel_ids = Set{Int64}()
    found_u_turn = false

    scan_relations(file) do r
        @test r.id ∉ rel_ids
        push!(rel_ids, r.id)

        if r.id == 9360865
            # No U turn at Columbia/Franklin
            @test r.tags["type"] == "restriction"
            @test r.tags["restriction"] == "no_u_turn"
            @test length(r.tags) == 2

            @test map(x -> x.id, r.members) == [16711116, 172698088, 16711116]
            @test map(x -> x.type, r.members) == [way, node, way]
            @test map(x -> x.role, r.members) == ["from", "via", "to"]

            @test 16711116 ∈ way_ids
            @test 172698088 ∈ node_ids

            found_u_turn = true
        end
    end

    @test length(rel_ids) == 836
    @test found_u_turn

    # not checking that members are in file, as many may not be,
    # for instance most members of https://www.openstreetmap.org/relation/224045 won't be
end