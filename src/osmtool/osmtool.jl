module OSMTool

using ..OSMPBF
using ArchGDAL, RuntimeGeneratedFunctions
using MacroTools: postwalk

RuntimeGeneratedFunctions.init(@__MODULE__)

include("core.jl")
include("filter.jl")

end