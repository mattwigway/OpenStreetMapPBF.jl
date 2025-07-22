@testitem "Write simple PBF" begin
    import OpenStreetMapPBF: RelationMember

    # write a simple PBF file and read it back
    nodes = [
        Node(1, 37.361, -122.123, Dict()),
        Node(7, 37.367, -122.123, Dict()),
        Node(3, 37.363, -122.123, Dict()),
        Node(12, 37.312, -122.123, Dict("highway"=>"traffic_signals"))
    ]

    ways = [
        Way(1, [1, 7, 12], Dict("highway"=>"footway")),
        Way(959, [1, 3, 12], Dict("highway"=>"residential", "sidewalk:left"=>"yes"))
    ]

    relations = [
        Relation(17, [RelationMember(1, way, "left"), RelationMember(7, node, "right")], Dict("reltype"=>"test"))
    ]

    mktemp() do p, io
        close(io)
        write_pbf(p, nodes, ways, relations)
        f = load_pbf(p)

        @test length(f.nodes) == length(nodes)
        for node ∈ nodes
            @test node ≈ f.nodes[node.id]
        end

        @test length(f.ways) == length(ways)
        for way ∈ ways
            @test way ≈ f.ways[way.id]
        end

        @test length(f.relations) == length(relations)
        for rel ∈ relations
            # no floating point values, can use ==
            @test rel == f.relations[rel.id]
        end
    end
end