module ConstructionBaseIntervalSetsExt

if isdefined(Base, :get_extension)
    using ConstructionBase
    using IntervalSets
else
    using ..ConstructionBase
    using ..IntervalSets
end

ConstructionBase.constructorof(::Type{<:Interval{L, R}}) where {L, R} = Interval{L, R}

end
