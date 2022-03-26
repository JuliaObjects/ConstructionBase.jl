module ConstructionBase

export getproperties
export setproperties
export constructorof
export fieldvalues


# Use markdown files as docstring:
for (name, path) in [
    :ConstructionBase => joinpath(dirname(@__DIR__), "README.md"),
    :constructorof => joinpath(@__DIR__, "constructorof.md"),
    :fieldvalues => joinpath(@__DIR__, "fieldvalues.md"),
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

@generated function (::NamedTupleConstructor{names})(args...) where names
    quote
        Base.@_inline_meta
        $(NamedTuple{names, Tuple{args...}})(args)
    end
end

getproperties(o::NamedTuple) = o
getproperties(o::Tuple) = o
@generated function getproperties(obj)
    fnames = fieldnames(obj)
    fvals = map(fnames) do fname
        Expr(:call, :getproperty, :obj, QuoteNode(fname))
    end
    fvals = Expr(:tuple, fvals...)
    :(NamedTuple{$fnames}($fvals))
end

################################################################################
#### fieldvalues
################################################################################
fieldvalues(x::Tuple) = x
fieldvalues(x::NamedTuple) = Tuple(x)
@generated function fieldvalues(x::T) where {T}
    fields = (:(getfield(x, $i)) for i in 1:fieldcount(T))
    Expr(:tuple, fields...)
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
    validate_setproperties_result(res, obj, obj, patch)
    res
end
function validate_setproperties_result(
    nt_new::NamedTuple{fields}, nt_old::NamedTuple{fields}, obj, patch) where {fields}
    nothing
end
@noinline function validate_setproperties_result(nt_new, nt_old, obj, patch)
    O = typeof(obj)
    P = typeof(patch)
    msg = """
    Failed to assign properties $(fieldnames(P)) to object with fields $(fieldnames(O)).
    You may want to overload
    ConstructionBase.setproperties(obj::$O, patch::NamedTuple)
    ConstructionBase.getproperties(obj::$O)
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
end
setproperties_object(obj, patch::NamedTuple{()}) = obj
function setproperties_object(obj, patch)
    nt = getproperties(obj)
    nt_new = merge(nt, patch)
    validate_setproperties_result(nt_new, nt, obj, patch)
    constructorof(typeof(obj))(Tuple(nt_new)...)
end

include("nonstandard.jl")
include("functions.jl")

end # module
