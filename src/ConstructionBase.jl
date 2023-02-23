module ConstructionBase

export getproperties
export setproperties
export constructorof
export getfields

# Use markdown files as docstring:
for (name, path) in [
    :ConstructionBase => joinpath(dirname(@__DIR__), "README.md"),
    :constructorof => joinpath(@__DIR__, "constructorof.md"),
    :getfields => joinpath(@__DIR__, "getfields.md"),
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

@generated function constructorof(::Type{T}) where T
    getfield(parentmodule(T), nameof(T))
end

constructorof(::Type{<:Tuple}) = tuple
constructorof(::Type{<:NamedTuple{names}}) where names =
    NamedTupleConstructor{names}()

struct NamedTupleConstructor{names} end

@inline function (::NamedTupleConstructor{names})(args...) where names
    NamedTuple{names}(args)
end

################################################################################
#### getfields
################################################################################
getfields(x::Tuple) = x
getfields(x::NamedTuple) = x
getproperties(o::NamedTuple) = o
getproperties(o::Tuple) = o

if VERSION >= v"1.7"
    function check_properties_are_fields(obj)
        if propertynames(obj) != fieldnames(typeof(obj))
            error("""
            The function `Base.propertynames` was overloaded for type `$(typeof(obj))`.
            Please make sure `ConstructionBase.setproperties` is also overloaded for this type.
            """)
        end
    end
else
    function is_propertynames_overloaded(T::Type)::Bool
        which(propertynames, Tuple{T}).sig !== Tuple{typeof(propertynames), Any}
    end

    @generated function check_properties_are_fields(obj)
        if is_propertynames_overloaded(obj)
            return quote
                T = typeof(obj)
                msg = """
                The function `Base.propertynames` was overloaded for type `$T`.
                Please make sure the following methods are also overloaded for this type:
                ```julia
                ConstructionBase.setproperties
                ConstructionBase.getproperties # optional in VERSION >= julia v1.7
                ```
                """
                error(msg)
            end
        else
            :(nothing)
        end
    end
end

# names are consecutive integers: return tuple
# names are symbols: return namedtuple
# names are empty (object has no properties): also return namedtuple, for backwards compat and generally makes more sense
@inline tuple_or_ntuple(names::Tuple{}, vals::Tuple) = NamedTuple{names}(vals)
@inline tuple_or_ntuple(names::Tuple{Vararg{Symbol}}, vals::Tuple) = NamedTuple{names}(vals)
@inline function tuple_or_ntuple(names::Tuple{Vararg{Int}}, vals::Tuple)
    @assert names === ntuple(identity, length(names))
    vals
end

if VERSION >= v"1.7"
    function getproperties(obj)
        fnames = propertynames(obj)
        tuple_or_ntuple(fnames, getproperty.(Ref(obj), fnames))
    end
    function getfields(obj::T) where {T}
        fnames = fieldnames(T)
        NamedTuple{fnames}(getfield.(Ref(obj), fnames))
    end
else
    @generated function getfields(obj)
        fnames = fieldnames(obj)
        fvals = map(fnames) do fname
             Expr(:call, :getfield, :obj, QuoteNode(fname))
        end
        :(NamedTuple{$fnames}(($(fvals...),)))
    end
    function getproperties(obj)
        check_properties_are_fields(obj)
        getfields(obj)
    end
end

################################################################################
##### setproperties
################################################################################
function setproperties(obj; kw...)
    setproperties(obj, (;kw...))
end

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
function setproperties_namedtuple(obj, patch)
    res = merge(obj, patch)
    check_patch_properties_exist(res, obj, obj, patch)
    res
end
function check_patch_properties_exist(
    nt_new::NamedTuple{fields}, nt_old::NamedTuple{fields}, obj, patch) where {fields}
    nothing
end
@noinline function check_patch_properties_exist(nt_new, nt_old, obj, patch)
    O = typeof(obj)
    msg = """
    Failed to assign properties $(propertynames(patch)) to object with properties $(propertynames(obj)).
    """
    throw(ArgumentError(msg))
end
function setproperties_namedtuple(obj::NamedTuple{fields}, patch::NamedTuple{fields}) where {fields}
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
function setproperties_tuple(obj::NTuple{N,Any}, patch::NTuple{N,Any}) where {N}
    patch
end
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
@noinline function setproperties_object(obj, patch::Tuple)
    msg = """
    setproperties(obj, patch::Tuple) only allowed for empty Tuple. Got:
    obj = $obj
    patch = $patch
    """
    throw(ArgumentError(msg))
end
setproperties_object(obj, patch::NamedTuple{()}) = obj

function setproperties_object(obj, patch)
    check_properties_are_fields(obj)
    nt = getproperties(obj)
    nt_new = merge(nt, patch)
    check_patch_properties_exist(nt_new, nt, obj, patch)
    args = Tuple(nt_new) # old julia inference prefers if we wrap in Tuple
    constructorof(typeof(obj))(args...)
end

include("nonstandard.jl")
include("functions.jl")

end # module
