module ConstructionBase

export setproperties

"""
    constructor_of(T::Type)

Return an object `ctor` that can be used to construct objects of type `T`
from their field values. Typically `ctor` will be the type `T` with all parameters removed:
```jldoctest
julia> struct T{A,B};a::A;b::B;end

julia> constructor_of(T{Int,Int})
T
```
It is however not guaranteed, that `ctor` is a type at all:
```jldoctest
julia> struct S
           a
           b
           checksum
           S(a,b) = new(a,b,a+b)
       end

julia> ConstructionBase.constructor_of(S) = (a,b,checksum) -> (@assert a+b == checksum; S(a,b))

julia> constructor_of(S)(1,2)
S(1, 2, 3)
```
Instead `ctor` can be any object that satisfies the following properties:
* It must be possible to reconstruct an object from its fields:
```julia
ctor = constructor_of(typeof(obj))
@assert obj == ctor(fieldvalues(obj)...)
@assert typeof(obj) == typeof(ctor(fieldvalues(obj)...))
```
* The other direction should hold for as many values of `args` as possible:
```julia
ctor = constructor_of(T)
fieldvalues(ctor(args...)) == args
```
For instance given a suitable parametric type it should be possible to change
the type of its fields:
```jldoctest
julia> using ConstructionBase: constructor_of

julia> struct T{A,B};a::A;b::B;end

julia> t = T(1,2)
T{Int64,Int64}(1, 2)

julia> constructor_of(typeof(t))(1.0, 2)
T{Float64,Int64}(1.0, 2)

julia> constructor_of(typeof(t))(10, 2)
T{Int64,Int64}(10, 2)
```
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
