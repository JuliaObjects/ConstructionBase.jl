module ConstructionBaseLinearAlgebraExt

if isdefined(Base, :get_extension)
    using ConstructionBase
    using LinearAlgebra: LinearAlgebra, SubArray, LinRange, Cholesky, LowerTriangular, UpperTriangular, Tridiagonal
else
    using ..ConstructionBase
    using ..LinearAlgebra: LinearAlgebra, SubArray, LinRange, Cholesky, LowerTriangular, UpperTriangular, Tridiagonal
end

### SubArray
# `offset1` and `stride1` fields are calculated from parent indices.
# Setting them has no effect.
subarray_constructor(parent, indices, args...) = SubArray(parent, indices)

ConstructionBase.constructorof(::Type{<:SubArray}) = subarray_constructor

### ReinterpretArray
struct ReinterpretArrayConstructor{T} end
# `readable` and `writeable` are calculated from `T` and `parent`
# Setting them has no effect.
function (::ReinterpretArrayConstructor{T})(parent, args...) where T
    reinterpret(T, parent)
end

ConstructionBase.constructorof(::Type{<:Base.ReinterpretArray{T}}) where T = ReinterpretArrayConstructor{T}()

### PermutedDimsArray
struct PermutedDimsArrayConstructor{N,perm,iperm} end
# Parent must have the same N - it has to match length(perm)
function (::PermutedDimsArrayConstructor{N,perm,iperm})(parent::AA
) where {N,perm,iperm,AA<:AbstractArray{T,N}} where T
    PermutedDimsArray{T,N,perm,iperm,AA}(parent)
end

ConstructionBase.constructorof(::Type{<:PermutedDimsArray{<:Any,N,perm,iperm,<:Any}}) where {N,perm,iperm} =
    PermutedDimsArrayConstructor{N,perm,iperm}()

### Tridiagonal
function tridiagonal_constructor(dl::V, d::V, du::V) where {V<:AbstractVector{T}} where T
    Tridiagonal{T,V}(dl, d, du)
end
function tridiagonal_constructor(dl::V, d::V, du::V, du2::V) where {V<:AbstractVector{T}} where T
    Tridiagonal{T,V}(dl, d, du, du2)
end

# `du2` may be undefined, so we need a custom `getfields` that checks `isdefined`
function ConstructionBase.getfields(o::Tridiagonal)
    if isdefined(o, :du2)
        (dl=o.dl, d=o.d, du=o.du, du2=o.du2) 
    else
        (dl=o.dl, d=o.d, du=o.du)
    end
end

ConstructionBase.constructorof(::Type{<:Tridiagonal}) = tridiagonal_constructor

### LinRange
# `lendiv` is a calculated field
linrange_constructor(start, stop, len, lendiv) = LinRange(start, stop, len)

ConstructionBase.constructorof(::Type{<:LinRange}) = linrange_constructor

### Expr: args get splatted
# ::Expr annotation is to make it type-stable on Julia 1.3-
ConstructionBase.constructorof(::Type{<:Expr}) = (head, args) -> Expr(head, args...)::Expr

### Cholesky
ConstructionBase.setproperties(C::Cholesky, patch::NamedTuple{()}) = C
function ConstructionBase.setproperties(C::Cholesky, patch::NamedTuple{(:L,),<:Tuple{<:LowerTriangular}})
    return Cholesky(C.uplo === 'U' ? copy(patch.L.data') : patch.L.data, C.uplo, C.info)
end
function ConstructionBase.setproperties(C::Cholesky, patch::NamedTuple{(:U,),<:Tuple{<:UpperTriangular}})
    return Cholesky(C.uplo === 'L' ? copy(patch.U.data') : patch.U.data, C.uplo, C.info)
end
function ConstructionBase.setproperties(
    C::Cholesky,
    patch::NamedTuple{(:UL,),<:Tuple{<:Union{LowerTriangular,UpperTriangular}}}
)
    return Cholesky(patch.UL.data, C.uplo, C.info)
end
function ConstructionBase.setproperties(C::Cholesky, patch::NamedTuple)
    throw(ArgumentError("Invalid patch for `Cholesky`: $(patch)"))
end


end
