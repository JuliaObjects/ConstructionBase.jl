module ConstructionBase

export setproperties
export constructorof

using Base: tail

# Use markdown files as docstring:
for (name, path) in [
    :ConstructionBase => joinpath(dirname(@__DIR__), "README.md"),
    :constructorof => joinpath(@__DIR__, "constructorof.md"),
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

function setproperties(obj; kw...)
    setproperties(obj, (;kw...))
end

@generated __fieldnames__(::Type{T}) where T = fieldnames(T)

@inline _value(::Val{x}) where x = x
@inline _issubset(::Tuple{}, _) = true
@inline _issubset(xs::Tuple, ys) = inargs(xs[1], ys...) && _issubset(tail(xs), ys)
@inline inargs(x) = false
@inline inargs(x, y, ys...) = x === y || inargs(x, ys...)

@inline foldlargs(op, x) = x
@inline foldlargs(op, x1, x2, xs...) = foldlargs(op, op(x1, x2), xs...)

@inline function setproperties(obj, patch::NamedTuple{pnames′}) where pnames′
    pnames = map(Val, pnames′)
    fnames = map(Val, __fieldnames__(typeof(obj)))
    if !_issubset(pnames, fnames)
        setproperties_unknown_field_error(obj, patch)
    end
    fields = foldlargs((), fnames...) do fields, name
        if inargs(name, pnames...)
            (fields..., patch[_value(name)])
        else
            (fields..., getfield(obj, _value(name)))
        end
    end
    return constructorof(typeof(obj))(fields...)
end

function setproperties_unknown_field_error(obj, patch)
    O = typeof(obj)
    P = typeof(patch)
    msg = """
    Failed to assign properties $(fieldnames(P)) to object with fields $(fieldnames(O)).
    You may want to overload
    ConstructionBase.setproperties(obj::$O, patch::NamedTuple)
    """
    throw(ArgumentError(msg))
end


end # module
