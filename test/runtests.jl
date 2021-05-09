using ConstructionBase
using Test
using LinearAlgebra

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

@testset "constructors for non-standadard Base and LinearAlgebra etc objects" begin
    A1 = zeros(5, 6)
    A2 = ones(Float32, 5, 6)

    @testset "SubArray" begin
        subarray = view(A1, 1:2, 3:4)
        @test constructorof(typeof(subarray))(getproperties(subarray)...) === subarray
        @test all(constructorof(typeof(subarray))(A2, (Base.OneTo(2), 3:4), 0, 0) .== Float32[1 1; 1 1])
        @inferred constructorof(typeof(subarray))(getproperties(subarray)...)
        @inferred constructorof(typeof(subarray))(A2, (Base.OneTo(2), 3:4), 0, 0)
    end

    @testset "ReinterpretArray" begin
        ra1 = reinterpret(Float16, A1)
        @test constructorof(typeof(ra1))(A1) === ra1
        @test constructorof(typeof(ra1))(getproperties(ra1)...) === ra1
        ra2 = constructorof(typeof(ra1))(A2)
        @test size(ra2) == (10, 6)
        @test eltype(ra2) == Float16
        @inferred constructorof(typeof(ra1))(getproperties(ra1)...)
        @inferred constructorof(typeof(ra1))(A2)
    end

    @testset "PermutedDimsArray" begin
        pda1 = PermutedDimsArray(A1, (2, 1))
        @test constructorof(typeof(pda1))(A1) === pda1
        @test constructorof(typeof(pda1))(getproperties(pda1)...) === pda1
        @test eltype(constructorof(typeof(pda1))(A2)) == Float32
        @inferred constructorof(typeof(pda1))(getproperties(pda1)...)
        @inferred constructorof(typeof(pda1))(A2)
    end

    @testset "Tridiagonal" begin
        d = randn(12)
        dl = randn(11)
        du = randn(11)
        tda = Tridiagonal(dl, d, du)
        @test isdefined(tda, :du2) == false
        @test constructorof(typeof(tda))(dl, d, du) === tda
        @test constructorof(typeof(tda))(getproperties(tda)...) === tda
        # lu factorization defines du2
        tda_lu = lu!(tda).factors
        @test isdefined(tda_lu, :du2) == true
        @test constructorof(typeof(tda_lu))(getproperties(tda_lu)...) === tda_lu
        @test constructorof(typeof(tda_lu))(getproperties(tda)...) !== tda_lu
        @test constructorof(typeof(tda_lu))(getproperties(tda)...) === tda
        @inferred constructorof(typeof(tda))(getproperties(tda)...)
        @inferred constructorof(typeof(tda))(getproperties(tda_lu)...)
    end

    @testset "LinRange" begin
        lr1 = LinRange(1, 7, 10)
        lr2 = LinRange(1.0f0, 7.0f0, 10)
        @test constructorof(typeof(lr1))(1, 7, 10, nothing) === lr1
        @test constructorof(typeof(lr1))(getproperties(lr2)...) === lr2
        @inferred constructorof(typeof(lr1))(getproperties(lr1)...)
        @inferred constructorof(typeof(lr1))(getproperties(lr2)...)
    end

    @testset "Dict" begin
        d1 = Dict(:a => 1, :b => 2)
        d2 = setproperties(d1, vals=d1.vals .* 2.0)
        @test typeof(d2) <: Dict{Symbol,Float64}
        @test d2[:a] == 2.0
        @test d2[:b] == 4.0
        d3 = setproperties(d1, keys=["x", "y"])
        @test d3 isa Dict{String,Int}
        @test d3["x"] == 1
        @test d3["y"] == 2
    end

end

@testset "Anonymous function constructors" begin
    function multiplyer(a, b)
        x -> x * a * b
    end

    mult11 = multiplyer(1, 1)
    @test mult11(1) === 1
    mult23 = @inferred constructorof(typeof(mult11))(2.0, 3.0)
    @inferred mult23(1)
    @test mult23(1) === 6.0
    multbc = @inferred constructorof(typeof(mult23))("b", "c")
    @inferred multbc("a")
    @test multbc("a") == "abc" 
end

struct Adder{V} <: Function
    value::V
end
(o::Adder)(x) = o.value + x

struct Adder2{V} <: Function
    value::V
    int::Int
end
(o::Adder2)(x) = o.value + o.int + x 

struct AddTuple{T} <: Function
    tuple::Tuple{T,T,T}
end
(o::AddTuple)(x) = sum(o.tuple) + x

# A function with an inner constructor with checks
struct Rotation{M} <: Function
    matrix::M
    function Rotation(m)
        @assert isapprox(det(m), 1)
        @assert isapprox(m*m', I)
        new{typeof(m)}(m)   
    end
end

@testset "Custom function object constructors still work" begin
    add1 = Adder(1)
    @test add1(1) === 2
    add2 = @inferred ConstructionBase.constructorof(typeof(add1))(2.0)
    @inferred add2(1)
    @test add2(1) == 3.0
    add12 = Adder2(1, 2)
    @test @inferred add12(3) ==  6
    add22 = @inferred ConstructionBase.constructorof(typeof(add12))(2.0, 2)
    @test @inferred add22(3) ==  7.0

    addtuple123 = AddTuple((1, 2, 3))
    @test addtuple123(1) === 7
    addtuple234 = @inferred ConstructionBase.constructorof(typeof(addtuple123))((2.0, 3.0, 4.0))
    @inferred addtuple234(1)
    @test addtuple234(1) === 10.0

    @testset "inner constructor without type parameters is still called" begin
        @test_throws AssertionError constructorof(Rotation{Matrix{Float64}})(zeros(3,3))
    end
end
