module StaticArraysExt

using ConstructionBase
using StaticArrays

# general static arrays need to keep the size parameter
ConstructionBase.constructorof(sa::Type{<:SArray{S}}) where {S} = SArray{S}
ConstructionBase.constructorof(sa::Type{<:MArray{S}}) where {S} = MArray{S}
ConstructionBase.constructorof(sa::Type{<:SizedArray{S}}) where {S} = SizedArray{S}

# static vectors don't even need the explicit size specification
ConstructionBase.constructorof(::Type{<:SVector}) = SVector
ConstructionBase.constructorof(::Type{<:MVector}) = MVector

end
