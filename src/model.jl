# models for OSM data

@struct_hash_equal_isapprox struct Way
    id::Int64
    nodes::Vector{Int64}
    tags::Dict{String, String}
end

@struct_hash_equal_isapprox struct Node
    id::Int64
    lat::Float64
    lon::Float64
    tags::Dict{String, String}
end

@enum RelationMemberType way node relation

function Base.convert(::Type{OSMPBF.var"Relation.MemberType".T}, m::RelationMemberType)
    if m == way
        OSMPBF.var"Relation.MemberType".WAY
    elseif m == node
        OSMPBF.var"Relation.MemberType".NODE
    elseif m == relation
        OSMPBF.var"Relation.MemberType".RELATION
    else
        error("unrecognized member type enum value (internal error, file bug report)")
    end
end

@struct_hash_equal_isapprox struct RelationMember
    id::Int64
    type::RelationMemberType
    role::String
end

@struct_hash_equal_isapprox struct Relation
    id::Int64
    members::Vector{RelationMember}
    tags::Dict{String, String}
end

# used by load_pbf but not by scan_pbf
struct OSMFile
    ways::Dict{Int64, Way}
    nodes::Dict{Int64, Node}
    relations::Dict{Int64, Node}
end