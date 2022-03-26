    fieldvalues(obj) -> Tuple

Return a tuple containing field values of `obj`.

# Examples
```jldoctest
julia> using ConstructionBase

julia> struct S
           a::A
           b::B
       end

julia> fieldvalues(S(1,2))
(1,2)

julia> fieldvalues((a=10,b=20))
(10,20)

julia> fieldvalues((4,5,6))
(4,5,6)
```

# Specification

Semantically `fieldvalues` boils down to `getfield` and `fieldcount`:
```julia
fieldvalues(obj) == Tuple(getfield(obj,i) for i in 1:fieldcount(obj))
```
The following relation to [`constructorof`](@ref) should be satisfied:
```julia
@assert obj == constructorof(obj)(fieldvalues(obj)...)
```

# Implementation

The semantics of `fieldvalues` should generally not be changed. It should equivalent to
```julia
Tuple(getfield(obj,i) for i in 1:fieldcount(obj))
```
even if that included private fields of `obj`.
See also [`getproperties`](@ref), [`constructorof`](@ref)


See also [Tips section in the manual](@ref type-tips)
