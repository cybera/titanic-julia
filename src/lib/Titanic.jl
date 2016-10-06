module Titanic

using DataArrays
import Plots

export to_enum, SurvivedType

Plots.convertToAnyVector{T<:Enum}(v::Array{T}, d::Dict{Symbol,Any}) = Plots.convertToAnyVector(map(string,v), d)
to_enum{T<:Enum}(t::Type{T}, v) = convert(PooledDataArray{t}, v)

end
