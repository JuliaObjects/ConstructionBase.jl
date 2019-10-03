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

    @test setproperties(Empty(), NamedTuple()) === Empty()
    @test setproperties(Empty()) === Empty()

    @test setproperties((a=1, b=2), (a=1.0,)) === (a=1.0, b=2)
    @test setproperties((a=1, b=2), a=1.0) === (a=1.0, b=2)

    @inferred setproperties(o, a=2, b=3.0)
    @inferred setproperties(Empty(), NamedTuple())
    @inferred setproperties((a=1, b=2), a=1.0)
    @inferred setproperties((a=1, b=2), (a=1.0,))
end
