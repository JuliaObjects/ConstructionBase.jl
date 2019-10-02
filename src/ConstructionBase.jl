module ConstructionBase

export setproperties
export constructorof

# Use markdown files as docstring:
for (name, path) in [
    :ConstructionBase => joinpath(dirname(@__DIR__), "README.md"),
    :constructorof => joinpath(@__DIR__, "constructorof.md"),
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

function assert_hasfields(T, fnames)
    for fname in fnames
        if !(fname in fieldnames(T))
            msg = "$T has no field $fname"
            throw(ArgumentError(msg))
        end
    end
end

"""
    setproperties(obj, patch::NamedTuple)

Return a copy of `obj` with attributes updates accoring to `patch`.

# Examples
```jldoctest
julia> using ConstructionBase

julia> struct S
           a
           b
           c
       end

julia> s = S(1,2,3)
S(1, 2, 3)

julia> setproperties(s, (a=10,c=4))
S(10, 2, 4)

julia> setproperties((a=1,c=2,b=3), (a=10,c=4))
(a = 10, c = 4, b = 3)
```

There is also a convenience method, which builds the `patch` argument from
keywords:

    setproperties(obj; kw...)

# Examples
```jldoctest
julia> using ConstructionBase

julia> struct S;a;b;c; end

julia> o = S(10, 2, 4)
S(10, 2, 4)

julia> setproperties(o, a="A", c="cc")
S("A", 2, "cc")
```

# Overloading

**WARNING** The signature `setproperties(obj::MyType; kw...)` should never be overloaded.
Instead `setproperties(obj::MyType, patch::NamedTuple)` should be overloaded.
"""
function setproperties end

function setproperties(obj; kw...)
    setproperties(obj, (;kw...))
end

@generated function setproperties(obj, patch::NamedTuple)
    assert_hasfields(obj, fieldnames(patch))
    args = map(fieldnames(obj)) do fn
        if fn in fieldnames(patch)
            :(patch.$fn)
        else
            :(obj.$fn)
        end
    end
    Expr(:block,
        Expr(:meta, :inline),
        Expr(:call,:(constructorof($obj)), args...)
    )
end

@generated function setproperties(obj::NamedTuple, patch::NamedTuple)
    # this function is only generated to force the following check
    # at compile time
    assert_hasfields(obj, fieldnames(patch))
    Expr(:block,
        Expr(:meta, :inline),
        :(merge(obj, patch))
    )
end


end # module
