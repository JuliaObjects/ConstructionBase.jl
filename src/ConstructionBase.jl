module ConstructionBase

export getproperties
export setproperties
export constructorof

# Use markdown files as docstring:
for (name, path) in [
    :ConstructionBase => joinpath(dirname(@__DIR__), "README.md"),
    :constructorof => joinpath(@__DIR__, "constructorof.md"),
    :getproperties => joinpath(@__DIR__, "getproperties.md"),
    :setproperties => joinpath(@__DIR__, "setproperties.md"),
]
    # Don't fail when somehow importing docstrings doesn't work (we
    # don't loose any functionalities for that).  We use explicit
    # `@docs` in `docs/src/index.md` to make sure importing docstrings
    # succeeds in CI.
    try
        include_dependency(path)
        str = read(path, String)
        @eval @doc $str $name
    catch err
        @error "Failed to import docstring for $name" exception=(err, catch_backtrace())
    end
end

@static if isdefined(Base, Symbol("@assume_effects"))
    using Base: @assume_effects
else
    macro assume_effects(_, ex)
        Base.@pure ex
    end
end
struct PropertyNames{syms} end

struct PropertyIndices{inds} end

const PropertyKeys{K} = Union{PropertyNames{K},PropertyIndices{K}}

Base.eltype(@nospecialize p::PropertyKeys) = eltype(typeof(p))
Base.eltype(@nospecialize T::Type{<:PropertyIndices}) = Int
Base.eltype(@nospecialize T::Type{<:PropertyNames}) = Symbol

PropertyNames(::Type{T}) where {T} = PropertyNames{fieldnames(T)}()
PropertyNames(@nospecialize(T::Type{<:NamedTuple})) = PropertyNames{T.parameters[1]}()
PropertyNames(@nospecialize(x)) = PropertyNames(typeof(x))

PropertyIndices(::Type{T}) where {T} = PropertyIndices{ntuple(identity, Val(fieldcount(T)))}()
PropertyIndices(@nospecialize T::Type{<:PropertyKeys}) = PropertyIndices{ntuple(identity, Val(length(T.parameters[1])))}()
PropertyIndices(@nospecialize(x)) = PropertyIndices(typeof(x))

Base.IteratorSize(@nospecialize T::Type{<:PropertyKeys}) = Base.HasLength()

Base.values(@nospecialize(p::PropertyKeys)) = values(typeof(p))
Base.values(@nospecialize(T::Type{<:PropertyKeys})) = T.parameters[1]

Base.length(@nospecialize(p::PropertyKeys)) = length(values(p))
_vlength(@nospecialize p) = Val(length(values(p)))

@inline function _getfields(@nospecialize(obj), @nospecialize(fields), v::Val{N}) where {N}
    ntuple(i -> getfield(obj, getfield(fields, i)), v)
end
Base.@propagate_inbounds Base.getindex(@nospecialize(p::PropertyKeys), @nospecialize(i::Integer)) = values(p)[i]
Base.@propagate_inbounds function Base.getindex(@nospecialize(p1::PropertyIndices), @nospecialize(p2::PropertyIndices))
    PropertyIndices{_getfields(values(p1), values(p2), _vlength(p2))}()
end
function Base.getindex(@nospecialize(p1::PropertyNames), @nospecialize(p2::PropertyIndices))
    PropertyNames{_getfields(values(p1), values(p2), _vlength(p2))}()
end

Base.isdone(@nospecialize(p::PropertyKeys), i::Int) = length(p) < i
Base.iterate(::PropertyKeys{()}) = nothing
Base.iterate(@nospecialize(p::PropertyKeys)) = @inbounds(p[1]), 2
@inline function Base.iterate(@nospecialize(p::PropertyKeys), state::Int)
    if Base.isdone(p, state)
        return nothing
    else
        return @inbounds(p[state]), state + 1
    end
end

constructorof(::Type{T}) where {T} = _default_constructorof(T)
@assume_effects :total function _default_constructorof(T::DataType)
    getfield(parentmodule(T), getfield(getfield(T, :name), :name))
end

constructorof(@nospecialize(T::Type{<:Tuple})) = tuple
constructorof(@nospecialize(T::Type{<:NamedTuple})) = NamedTupleConstructor{fieldnames(T)}()

struct NamedTupleConstructor{names} end

(::NamedTupleConstructor{names})(args...) where {names} = NamedTuple{names}(args)

# getproperties
getproperties(@nospecialize(obj::NamedTuple)) = obj
getproperties(@nospecialize(obj::Tuple)) = obj
getproperties(@nospecialize(obj)) = getproperties(obj, PropertyNames(obj))

function getproperties(@nospecialize(obj::Tuple), @nospecialize(p::PropertyIndices))
    _getfields(obj, values(p), _vlength(p))
end
@inline function getproperties(@nospecialize(obj), @nospecialize(p::PropertyIndices))
    getproperties(o, PropertyNames(o)[p])
end
@generated function getproperties(@nospecialize(obj), ::PropertyNames{nms}) where {nms}
    t = Expr(:tuple)
    for n in nms
        push!(t.args, Expr(:call, :getproperty, :obj, QuoteNode(n)))
    end
    Expr(:block, Expr(:meta, :inline), :(NamedTuple{$(nms)}($(t))))
end

################################################################################
##### setproperties
################################################################################
setproperties(obj; kw...) = setproperties(obj, (;kw...))
setproperties(obj             , patch::Tuple      ) = setproperties_object(obj     , patch )
setproperties(obj             , patch::NamedTuple ) = setproperties_object(obj     , patch )
setproperties(obj::NamedTuple , patch::Tuple      ) = setproperties_namedtuple(obj , patch )
setproperties(obj::NamedTuple , patch::NamedTuple ) = setproperties_namedtuple(obj , patch )
setproperties(obj::Tuple      , patch::Tuple      ) = setproperties_tuple(obj      , patch )
setproperties(obj::Tuple      , patch::NamedTuple ) = setproperties_tuple(obj      , patch )

setproperties_namedtuple(obj, patch::Tuple{}) = obj
@noinline function setproperties_namedtuple(obj, patch::Tuple)
    msg = """
    setproperties(obj::NamedTuple, patch::Tuple) only allowed for empty Tuple. Got:
    obj = $obj
    patch = $patch
    """
    throw(ArgumentError(msg))
end
function setproperties_namedtuple(@nospecialize(obj), @nospecialize( patch))
    _generated_setproperties(obj, patch, PropertyNames(obj), PropertyNames(patch))
end
function validate_setproperties_result(
    nt_new::NamedTuple{fields}, nt_old::NamedTuple{fields}, obj, patch) where {fields}
    nothing
end
@noinline function validate_setproperties_result(nt_new, nt_old, obj, patch)
    O = typeof(obj)
    _setproperties_object(O, fieldnames(O), fieldnames(typeof(patch)))
end
@noinline function _setproperties_result_error(O::DataType, @nospecialize(objsyms), @nospecialize(patchsyms))
    msg = """
    Failed to assign properties $(patchsyms) to object with fields $(objsyms).
    You may want to overload
    ConstructionBase.setproperties(obj::$O, patch::NamedTuple)
    ConstructionBase.getproperties(obj::$O)
    """
    throw(ArgumentError(msg))
end

function setproperties_namedtuple(::NamedTuple{fields}, patch::NamedTuple{fields}) where {fields}
    patch
end

setproperties_tuple(obj::Tuple, patch::NamedTuple{()}) = obj
@noinline function setproperties_tuple(obj::Tuple, patch::NamedTuple)
    msg = """
    setproperties(obj::Tuple, patch::NamedTuple) only allowed for empty NamedTuple. Got:
    obj  ::Tuple      = $obj
    patch::NamedTuple = $patch
    """
    throw(ArgumentError(msg))
end
setproperties_tuple(::NTuple{N,Any}, patch::NTuple{N,Any}) where {N} = patch
append(x,y) = (x..., y...)
@noinline function throw_setproperties_tuple_error(obj, patch)
    msg = """
    Cannot call `setproperties(obj::Tuple, patch::Tuple)` with `length(obj) < length(patch)`. Got:
    obj = $obj
    patch = $patch
    """
    throw(ArgumentError(msg))
end
function setproperties_tuple(obj::NTuple{N,Any}, patch::NTuple{K,Any}) where {N,K}
    if K > N
        throw_setproperties_tuple_error(obj, patch)
    end
    append(patch, after(obj, Val{K}()))
end
function after(xs::Tuple, ::Val{N}) where {N}
    after(Base.tail(xs), Val{N-1}())
end
function after(x::Tuple, ::Val{0})
    x
end

setproperties_object(obj, patch::Tuple{}) = obj
@noinline function setproperties_object(obj, @nospecialize(patch::Tuple))
    msg = """
    setproperties(obj, patch::Tuple) only allowed for empty Tuple. Got:
    obj = $obj
    patch = $patch
    """
end
setproperties_object(obj, patch::NamedTuple{()}) = obj
@inline function setproperties_object(obj, patch)
    _generated_setproperties(obj, patch, PropertyNames(obj), PropertyNames(patch))
end
@generated function _generated_setproperties(obj, patch, ::PropertyNames{objsyms}, ::PropertyNames{patchsyms}) where {objsyms,patchsyms}
    out = Expr(:call, :(constructorof(typeof(obj))))
    names = Symbol[objsyms...]
    for ps in patchsyms
        if !in(ps, objsyms)
            push!(names, ps)
        end
    end
    if all(in(objsyms), names)
        for n in names
            qn = QuoteNode(n)
            push!(out.args, in(n, patchsyms) ? Expr(:call, :getfield, :patch, qn) : Expr(:call, :getproperty, :obj, qn))
        end
        return out
    else
        return :(_setproperties_result_error(typeof(obj), objsyms, patchsyms))
    end
end

include("nonstandard.jl")
include("functions.jl")

end # module
