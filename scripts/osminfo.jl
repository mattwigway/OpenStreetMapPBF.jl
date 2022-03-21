include("src/OSMPBF.jl")

using .OSMPBF

function main()
    n_nodes = 0
    n_ways = 0
    n_rels = 0

    w::Float64 = Inf64
    e::Float64 = -Inf64
    s::Float64 = Inf64
    n::Float64 = -Inf64



    function node_handler(node)
        n_nodes += 1
        w = min(w, node.lon)
        e = max(e, node.lon)
        n = max(n, node.lat)
        s = min(n, node.lat)
    end

    @time scan_pbf(ARGS[1], nodes=node_handler, ways=w -> n_ways += 1, relations=r -> n_rels += 1)

    @info "PBF file has $n_nodes nodes, $n_ways ways, and $n_rels relations, bbox $n $e $s $w"
end

main()