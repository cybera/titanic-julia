module Titanic

using DataArrays
import Plots

export to_enum, SurvivedType

@enum SurvivedType Dead=0 Survived=1
Plots.convertToAnyVector(v::Array{SurvivedType}, d::Dict{Symbol,Any}) = Plots.convertToAnyVector(map(string,v), d)
to_enum{T<:Enum}(t::Type{T}, v::DataArray{Int}) = convert(PooledDataArray{t}, v)

end
