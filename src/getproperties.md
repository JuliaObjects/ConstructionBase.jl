    getproperties(obj)

Return the fields of `obj` as a `NamedTuple`.

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

julia> getproperties(s)
(a = 10, b = 2, c = 4)
```

# Implementation

`getproperties` is defined by default for all objects. However for a custom type `MyType`, 
`getproperties(obj::MyType)` may be defined when objects may have undefined fields, 
when it has calculated fields that should not be accessed or set manually, or
other conditions that do not meet the specification with the default implementation.

## Specification

`getproperties` guarantees a couple of invariants. When overloading it, the user is responsible for ensuring them:

1. Relation to `propertynames` and `fieldnames`: `getproperties` relates to `propertynames` and `getproperty`, not to `fieldnames` and `getfield`.
   This means that any series `p₁, p₂, ..., pₙ` of `propertynames(obj)` that is not undefined should be returned by `getproperties`.
2. `getproperties` is defined in relation to `constructorof` so that:
   ```julia
   obj == constructorof(obj)(getproperties(obj)...)
   ```
2. `getproperties` is defined in relation to `setproperties` so that:
   ```julia
   obj == setproperties(obj, getproperties(obj))
   ```
