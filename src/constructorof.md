    constructorof(T::Type) -> constructor

Return an object `constructor` that can be used to construct objects of type `T`
from their field values. Typically `constructor` will be the type `T` with all parameters removed:
```jldoctest
julia> using ConstructionBase

julia> struct T{A,B}
           a::A
           b::B
       end

julia> constructorof(T{Int,Int})
T
```
It is however not guaranteed, that `constructor` is a type at all:
```jldoctest; setup = :(using ConstructionBase)
julia> struct S
           a
           b
           checksum
           S(a,b) = new(a,b,a+b)
       end

julia> ConstructionBase.constructorof(::Type{<:S}) =
           (a, b, checksum=a+b) -> (@assert a+b == checksum; S(a,b))

julia> constructorof(S)(1,2)
S(1, 2, 3)

julia> constructorof(S)(1,2,4)
ERROR: AssertionError: a + b == checksum
```
Instead `constructor` can be any object that satisfies the following properties:
* It must be possible to reconstruct an object from its fields:
```julia
ctor = constructorof(typeof(obj))
@assert obj == ctor(fieldvalues(obj)...)
@assert typeof(obj) == typeof(ctor(fieldvalues(obj)...))
```
* The other direction should hold for as many values of `args` as possible:
```julia
ctor = constructorof(T)
fieldvalues(ctor(args...)) == args
```
For instance given a suitable parametric type it should be possible to change
the type of its fields:
```jldoctest; setup = :(using ConstructionBase)
julia> struct T{A,B}
           a::A
           b::B
       end

julia> t = T(1,2)
T{Int64,Int64}(1, 2)

julia> constructorof(typeof(t))(1.0, 2)
T{Float64,Int64}(1.0, 2)

julia> constructorof(typeof(t))(10, 2)
T{Int64,Int64}(10, 2)
```

See also [Tips section in the manual](@ref type-tips)
