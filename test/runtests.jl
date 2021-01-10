using ConstructionBase
using Test

struct Empty end
struct AB{A,B}
    a::A
    b::B
end

@testset "constructorof" begin
    @test constructorof(Empty)() === Empty()
    @inferred constructorof(AB{Int, Int})
    @test constructorof(AB{Int, Int})(1, 2) === AB(1,2)
    @test constructorof(AB{Int, Int})(1.0, 2) === AB(1.0,2)
    @test constructorof(typeof((a=1, b=2)))(1.0, 2) === (a=1.0, b=2)
    @test constructorof(NamedTuple{(:a, :b)})(1.0, 2) === (a=1.0, b=2)
    @test constructorof(Tuple)(1.0, 2) === (1.0, 2)
    @test constructorof(Tuple{Nothing, Missing})(1.0, 2) === (1.0, 2)
end

@testset "getproperties" begin
    o = AB(1, 2)
    @test getproperties(o) === (a=1, b=2)
    @inferred getproperties(o)
    @test getproperties(Empty()) === NamedTuple()
end

@testset "setproperties" begin
    o = AB(1,2)
    @test setproperties(o, (a=2, b=3))   === AB(2,3)
    @test setproperties(o, (a=2, b=3.0)) === AB(2,3.0)
    @test setproperties(o, a=2, b=3.0) === AB(2,3.0)

    res = @test_throws ArgumentError setproperties(o, (a=2, this_field_does_not_exist=3.0))
    msg = sprint(showerror, res.value)
    @test occursin("this_field_does_not_exist", msg)
    @test occursin("overload", msg)
    @test occursin("ConstructionBase.setproperties", msg)

    res = @test_throws ArgumentError setproperties(o, a=2, this_field_does_not_exist=3.0)
    msg = sprint(showerror, res.value)
    @test occursin("this_field_does_not_exist", msg)
    @test occursin("overload", msg)
    @test occursin("ConstructionBase.setproperties", msg)

    @test setproperties(42, NamedTuple()) === 42
    @test setproperties(42) === 42

    @test setproperties(Empty(), NamedTuple()) === Empty()
    @test setproperties(Empty()) === Empty()

    @test setproperties((a=1, b=2), (a=1.0,)) === (a=1.0, b=2)
    @test setproperties((a=1, b=2), a=1.0) === (a=1.0, b=2)

    @inferred setproperties(o, a=2, b=3.0)
    @inferred setproperties(Empty(), NamedTuple())
    @inferred setproperties((a=1, b=2), a=1.0)
    @inferred setproperties((a=1, b=2), (a=1.0,))
end

struct CustomSetproperties
    _a::Int
end
function ConstructionBase.setproperties(o::CustomSetproperties, patch::NamedTuple)
    if isempty(patch)
        o
    elseif propertynames(patch) == (:a,)
        CustomSetproperties(patch.a)
    else
        error()
    end
end

@testset "custom setproperties unambiguous on empty" begin
    o = CustomSetproperties(1)
    @test o === setproperties(o)
    @test o === setproperties(o, NamedTuple())
    @test CustomSetproperties(2) === setproperties(o, a=2)
    @test CustomSetproperties(2) === setproperties(o, (a=2,))
end
