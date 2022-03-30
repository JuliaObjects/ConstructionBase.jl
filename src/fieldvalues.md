    getfields(obj) -> Tuple

Return a tuple containing field values of `obj`.

# Examples
```jldoctest
julia> using ConstructionBase

julia> struct S{A,B}
           a::A
           b::B
       end

julia> getfields(S(1,2))
(1, 2)

julia> getfields((a=10,b=20))
(10, 20)

julia> getfields((4,5,6))
(4, 5, 6)
```

# Specification

Semantically `getfields` boils down to `getfield` and `fieldcount`:
```julia
getfields(obj) == Tuple(getfield(obj,i) for i in 1:fieldcount(obj))
```
The following relation to [`constructorof`](@ref) should be satisfied:
```julia
@assert obj == constructorof(obj)(getfields(obj)...)
```

# Implementation

The semantics of `getfields` should generally not be changed. It should equivalent to
```julia
Tuple(getfield(obj,i) for i in 1:fieldcount(obj))
```
even if that includes private fields of `obj`.
See also [`getproperties`](@ref), [`constructorof`](@ref)
