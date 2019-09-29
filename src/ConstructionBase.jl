module ConstructionBase

export setproperties

"""
    constructor_of(T::Type)

Return an object `T2` that can be used to construct objects of type `T`
from their field values. Typically `T2` will be a supertype of `T`, but
this is not guaranteed.
"""
@generated function constructor_of(::Type{T}) where T
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
    setproperties(obj, patch)

Return a copy of `obj` with attributes updates accoring to `patch`.

# Examples
```jldoctest
julia> using Setfield

julia> struct S;a;b;c; end

julia> s = S(1,2,3)
S(1, 2, 3)

julia> setproperties(s, (a=10,c=4))
S(10, 2, 4)

julia> setproperties((a=1,c=2,b=3), (a=10,c=4))
(a = 10, c = 4, b = 3)
```
"""
function setproperties end

@generated function setproperties(obj, patch)
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
        Expr(:call,:(constructor_of($obj)), args...)
    )
end

@generated function setproperties(obj::NamedTuple, patch)
    # this function is only generated to force the following check
    # at compile time
    assert_hasfields(obj, fieldnames(patch))
    Expr(:block,
        Expr(:meta, :inline),
        :(merge(obj, patch))
    )
end


end # module
