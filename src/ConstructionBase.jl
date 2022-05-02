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

"""
    PropertyNames(T::Type) -> PropertyNames{fieldnames(T)}()

Provides a compile time known representation of property names for `T`. This defaults to
`fieldnames(T)` but may be changed for types whose `propertynames` are differ from their
type's `fieldnames`. It may also provide a small performance benefit to manually
specificying this type even if `propertynames(::T) == fieldnames(T)`.
"""
struct PropertyNames{syms} end

"""
    FieldIndices(T::Type) -> FieldIndices{(1, 2, 3, ...fieldcount(T))}()

Stores a tuple whose contents represent the fields of `T`. This corresponds to the raw
definition of `T` and should not be defined for new types.
"""
struct FieldIndices{inds} end

const PropertyKeys{K} = Union{PropertyNames{K},FieldIndices{K}}

PropertyNames(::Type{T}) where {T} = PropertyNames{fieldnames(T)}()
PropertyNames(@nospecialize(T::Type{<:NamedTuple})) = PropertyNames{T.parameters[1]}()
PropertyNames(@nospecialize(x)) = PropertyNames(typeof(x))

FieldIndices(@nospecialize T::Type) = FieldIndices{ntuple(identity, Val(fieldcount(T)))}()
FieldIndices(@nospecialize(x)) = FieldIndices(typeof(x))

Base.IteratorSize(@nospecialize T::Type{<:PropertyKeys}) = Base.HasLength()

Base.values(@nospecialize(p::PropertyKeys)) = values(typeof(p))
Base.values(@nospecialize(T::Type{<:PropertyKeys})) = T.parameters[1]

Base.length(@nospecialize(p::PropertyKeys)) = length(values(p))
_vlength(@nospecialize p) = Val(length(values(p)))

@inline function _getfields(@nospecialize(obj), @nospecialize(fields), v::Val{N}) where {N}
    ntuple(i -> getfield(obj, getfield(fields, i)), v)
end
Base.@propagate_inbounds Base.getindex(@nospecialize(p::PropertyKeys), @nospecialize(i::Integer)) = values(p)[i]

@inline function Base.iterate(@nospecialize(p::PropertyKeys), state::Int=1)
    if length(p) < state
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
getproperties(obj) = getproperties(obj, PropertyNames(obj))

function getproperties(@nospecialize(obj::Tuple), @nospecialize(p::FieldIndices))
    _getfields(obj, values(p), _vlength(p))
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
setproperties(obj, patch) = isempty(patch) ? obj : _setproperties(obj, patch)
function _setproperties(@nospecialize(obj::Tuple), @nospecialize(patch::Tuple))
    _generated_setproperties(obj, patch, FieldIndices(obj), FieldIndices(patch))
end
function _setproperties(obj, patch)
    _generated_setproperties(obj, patch, PropertyNames(obj), PropertyNames(patch))
end
_setproperties(::NamedTuple{fields}, patch::NamedTuple{fields}) where {fields} = patch
@noinline function _setproperties(@nospecialize(obj::NamedTuple), patch::Tuple)
    msg = """
    setproperties(obj::NamedTuple, patch::Tuple) only allowed for empty Tuple. Got:
    obj = $obj
    patch = $patch
    """
    throw(ArgumentError(msg))
end
@noinline function _setproperties(@nospecialize(obj), @nospecialize(patch::Tuple))
    msg = """
    setproperties(obj, patch::Tuple) only allowed for empty Tuple. Got:
    obj = $obj
    patch = $patch
    """
end
@noinline function _setproperties(@nospecialize(obj::Tuple), @nospecialize(patch::NamedTuple))
    msg = """
    setproperties(obj::Tuple, patch::NamedTuple) only allowed for empty NamedTuple. Got:
    obj  ::Tuple      = $obj
    patch::NamedTuple = $patch
    """
    throw(ArgumentError(msg))
end
@generated function _generated_setproperties(obj, patch, ::PropertyKeys{objkeys}, ::PropertyKeys{patchkeys}) where {objkeys,patchkeys}
    out = Expr(:call, :(constructorof(typeof(obj))))
    names = [objkeys...]
    for ps in patchkeys
        if !in(ps, objkeys)
            push!(names, ps)
        end
    end
    if all(in(objkeys), names)
        for n in names
            qn = QuoteNode(n)
            push!(out.args, in(n, patchkeys) ? Expr(:call, :getfield, :patch, qn) : Expr(:call, :getproperty, :obj, qn))
        end
        return out
    else
        return quote
            O = typeof(obj)
            msg = """
            Failed to assign properties $(patchkeys) to object with fields $(objkeys).
            You may want to overload
            ConstructionBase.setproperties(obj::$O, patch::NamedTuple)
            ConstructionBase.getproperties(obj::$O)
            """
            throw(ArgumentError(msg))
        end
    end
end

include("nonstandard.jl")
include("functions.jl")

end # module
