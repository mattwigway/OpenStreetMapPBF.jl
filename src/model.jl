# models for OSM data

struct Way
    id::Int64
    nodes::Vector{Int64}
    tags::Dict{String, String}
end

struct Node
    id::Int64
    lat::Float64
    lon::Float64
    tags::Dict{String, String}
end

@enum RelationMemberType way node relation

struct Relation
    id::Int64
    members::Vector{Int64}
    member_types::Vector{RelationMemberType}
    roles::Vector{String}
end

# used by load_pbf but not by scan_pbf
struct OSMFile
    ways::Dict{Int64, Way}
    nodes::Dict{Int64, Node}
    relations::Dict{Int64, Node}
end