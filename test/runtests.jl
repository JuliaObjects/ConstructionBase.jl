using ConstructionBase
using Test
using ConstructionBase: constructor_of

struct Empty end
struct AB{A,B}
    a::A
    b::B
end

@testset "constructor_of" begin
    @test constructor_of(Empty)() === Empty()
    @test constructor_of(AB{Int, Int})(1, 2) === AB(1,2)
    @test constructor_of(AB{Int, Int})(1.0, 2) === AB(1.0,2)
end

@testset "setproperties" begin
    o = AB(1,2)
    @test setproperties(o, (a=2, b=3))   === AB(2,3)
    @test setproperties(o, (a=2, b=3.0)) === AB(2,3.0)
    @test_throws ArgumentError setproperties(o, (a=2, c=3.0))
    @test setproperties(Empty(), NamedTuple()) === Empty()
    @test setproperties((a=1, b=2), (a=1.0,)) === (a=1.0, b=2)
end
