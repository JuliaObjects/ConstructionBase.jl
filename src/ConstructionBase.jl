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

function setproperties(obj; kw...)
    setproperties(obj, (;kw...))
end

setproperties(obj, patch::NamedTuple) = _setproperties(obj, patch)
#setproperties(obj::NamedTuple, patch::NamedTuple) = setproperties_namedtuple(obj, patch)


setproperties(obj::Tuple, patch::typeof(NamedTuple())) = obj
@noinline function setproperties(obj::Tuple, patch::NamedTuple)
    msg = """
    Tuple has no named properties.
    obj  ::Tuple      = $obj
    patch::NamedTuple = $patch
    """
    throw(ArgumentError(msg))
end

function setproperties(obj::Tuple, patch::Tuple)
    setproperties_tuple(obj, patch)
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
_setproperties(obj, patch::typeof(NamedTuple())) = obj
@generated function _setproperties(obj, patch::NamedTuple)
    if issubset(fieldnames(patch), fieldnames(obj))
        args = map(fieldnames(obj)) do fn
            if fn in fieldnames(patch)
                :(patch.$fn)
            else
                :(obj.$fn)
            end
        end
        return Expr(:block,
            Expr(:meta, :inline),
            Expr(:call,:(constructorof($obj)), args...)
        )
    else
        :(setproperties_unknown_field_error(obj, patch))
    end
end

@noinline function setproperties_unknown_field_error(obj, patch)
    O = typeof(obj)
    P = typeof(patch)
    msg = """
    Failed to assign properties $(fieldnames(P)) to object with fields $(fieldnames(O)).
    You may want to overload
    ConstructionBase.setproperties(obj::$O, patch::NamedTuple)
    """
    throw(ArgumentError(msg))
end

include("nonstandard.jl")
include("functions.jl")

end # module
