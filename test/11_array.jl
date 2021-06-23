module TestArray
using Test
using CategoricalArrays
using CategoricalArrays: DefaultRefType, leveltype

@testset "conversion ordered=$ordered reftype=$R" for ordered in (false, true),
    R in (CategoricalArrays.DefaultRefType, UInt8, UInt, Int8, Int)
    # Vector
    a = ["b", "a", "b"]
    x = CategoricalVector{String, R}(a, ordered=ordered)

    @test x == a
    @test leveltype(typeof(x)) === String
    @test leveltype(x) === String
    @test eltype(x) === CategoricalValue{String, R}
    @test isordered(x) === ordered
    @test levels(x) == sort(unique(a))
    @test uniquelevels(x) == unique(a)
    @test size(x) === (3,)
    @test length(x) === 3

    @test convert(CategoricalArray, x) === x
    @test convert(CategoricalArray{String}, x) === x
    @test convert(CategoricalArray{String, 1}, x) === x
    @test convert(CategoricalArray{String, 1, R}, x) === x
    @test convert(CategoricalArray{String, 1, DefaultRefType}, x) == x
    @test convert(CategoricalArray{String, 1, UInt8}, x) == x

    @test convert(CategoricalVector, x) === x
    @test convert(CategoricalVector{String}, x) === x
    @test convert(CategoricalVector{String, R}, x) === x
    @test convert(CategoricalVector{String, DefaultRefType}, x) == x
    @test convert(CategoricalVector{String, UInt8}, x) == x

    @test convert(CategoricalArray, a) == x
    @test convert(CategoricalArray{String}, a) == x
    @test convert(CategoricalArray{String, 1}, a) == x
    @test convert(CategoricalArray{String, 1, R}, a) == x
    @test convert(CategoricalArray{String, 1, DefaultRefType}, a) == x
    @test convert(CategoricalArray{String, 1, UInt8}, a) == x

    @test convert(CategoricalVector, a) == x
    @test convert(CategoricalVector{String}, a) == x
    @test convert(CategoricalVector{String, R}, a) == x
    @test convert(CategoricalVector{String, DefaultRefType}, a) == x
    @test convert(CategoricalVector{String, UInt8}, a) == x

    @test CategoricalArray{String}(a, ordered=ordered) == x
    @test CategoricalArray{String, 1}(a, ordered=ordered) == x
    @test CategoricalArray{String, 1, R}(a, ordered=ordered) == x
    @test CategoricalArray{String, 1, DefaultRefType}(a, ordered=ordered) == x
    @test CategoricalArray{String, 1, UInt8}(a, ordered=ordered) == x

    @test CategoricalVector(a, ordered=ordered) == x
    @test CategoricalVector{String}(a, ordered=ordered) == x
    @test CategoricalVector{String, R}(a, ordered=ordered) == x
    @test CategoricalVector{String, DefaultRefType}(a, ordered=ordered) == x
    @test CategoricalVector{String, UInt8}(a, ordered=ordered) == x

    @test convert(CategoricalArray{Union{String, Missing}}, x) == x
    @test convert(CategoricalArray{Union{String, Missing}, 1}, x) == x
    @test convert(CategoricalArray{Union{String, Missing}, 1, R}, x) == x
    @test convert(CategoricalArray{Union{String, Missing}, 1, DefaultRefType}, x) == x
    @test convert(CategoricalArray{Union{String, Missing}, 1, UInt8}, x) == x

    @test convert(CategoricalVector{Union{String, Missing}}, x) == x
    @test convert(CategoricalVector{Union{String, Missing}, R}, x) == x
    @test convert(CategoricalVector{Union{String, Missing}, DefaultRefType}, x) == x
    @test convert(CategoricalVector{Union{String, Missing}, UInt8}, x) == x

    @test CategoricalArray{Union{String, Missing}}(x, ordered=ordered) == x
    @test CategoricalArray{Union{String, Missing}, 1}(x, ordered=ordered) == x
    @test CategoricalArray{Union{String, Missing}, 1, R}(x, ordered=ordered) == x
    @test CategoricalArray{Union{String, Missing}, 1, DefaultRefType}(x, ordered=ordered) == x
    @test CategoricalArray{Union{String, Missing}, 1, UInt8}(x, ordered=ordered) == x

    @test CategoricalVector{Union{String, Missing}}(x, ordered=ordered) == x
    @test CategoricalVector{Union{String, Missing}, R}(x, ordered=ordered) == x
    @test CategoricalVector{Union{String, Missing}, DefaultRefType}(x, ordered=ordered) == x
    @test CategoricalVector{Union{String, Missing}, UInt8}(x, ordered=ordered) == x

    @testset "categorical($(typeof(y)), compress=$comp) R1=$R1 R2=$R2" for (y, R1, R2, comp) in
        ((a, DefaultRefType, UInt8, true),
         (a, DefaultRefType, DefaultRefType, false),
         (x, R, UInt8, true),
         (x, R, R, false))

        x2 = @inferred categorical(y, ordered=ordered)
        @test x2 == x
        @test isa(x2, CategoricalVector{String, R1})
        @test isordered(x2) === ordered
        @test leveltype(x2) === String
        @test eltype(x2) === CategoricalValue{String, R1}

        x2 = categorical(y, compress=comp, ordered=ordered)
        @test x2 == x
        @test isa(x2, CategoricalVector{String, R2})
        @test isordered(x2) === ordered
        @test leveltype(x2) === String
        @test eltype(x2) === CategoricalValue{String, R2}
    end

    x2 = compress(x)
    @test x2 == x
    @test isa(x2, CategoricalVector{String, UInt8})
    @test isordered(x2) === isordered(x)
    @test levels(x2) == levels(x)

    x2 = copy(x)
    @test x2 == x
    @test typeof(x2) === typeof(x)
    @test isordered(x2) === isordered(x)
    @test levels(x2) == levels(x)

    if !isordered(x)
        @test ordered!(x, true) === x
        @test isordered(x) === true
    end
    @test x[1] > x[2]
    @test x[3] > x[2]

    @test ordered!(x, false) === x
    @test isordered(x) === false
    @test_throws Exception x[1] > x[2]
    @test_throws Exception x[3] > x[2]

    @test x[1] === CategoricalValue(x.pool, 2)
    @test x[2] === CategoricalValue(x.pool, 1)
    @test x[3] === CategoricalValue(x.pool, 2)
    @test_throws BoundsError x[4]

    x2 = x[:]
    @test typeof(x2) === typeof(x)
    @test x2 == x
    @test x2 !== x
    @test levels(x2) == levels(x)
    @test levels(x2) !== levels(x)
    @test isordered(x2) == isordered(x)

    x2 = x[1:2]
    @test typeof(x2) === typeof(x)
    @test x2 == ["b", "a"]
    @test levels(x2) == levels(x)
    @test levels(x2) !== levels(x)
    @test isordered(x2) == isordered(x)

    x2 = x[1:1]
    @test typeof(x2) === typeof(x)
    @test x2 == ["b"]
    @test levels(x2) == levels(x)
    @test levels(x2) !== levels(x)
    @test isordered(x2) == isordered(x)

    x2 = x[2:1]
    @test typeof(x2) === typeof(x)
    @test isempty(x2)
    @test levels(x2) == levels(x)
    @test levels(x2) !== levels(x)
    @test isordered(x2) == isordered(x)

    x[1] = x[2]
    @test x[1] === CategoricalValue(x.pool, 1)
    @test x[2] === CategoricalValue(x.pool, 1)
    @test x[3] === CategoricalValue(x.pool, 2)

    x[3] = "c"
    @test levels(x) == ["a", "b", "c"]
    @test x[1] === CategoricalValue(x.pool, 1)
    @test x[2] === CategoricalValue(x.pool, 1)
    @test x[3] === CategoricalValue(x.pool, 3)

    x[2:3] .= "b"
    @test levels(x) == ["a", "b", "c"]
    @test x[1] === CategoricalValue(x.pool, 1)
    @test x[2] === CategoricalValue(x.pool, 2)
    @test x[3] === CategoricalValue(x.pool, 2)

    @test droplevels!(x) === x
    @test levels(x) == ["a", "b"]
    @test x[1] === CategoricalValue(x.pool, 1)
    @test x[2] === CategoricalValue(x.pool, 2)
    @test x[3] === CategoricalValue(x.pool, 2)

    @test levels!(x, ["b", "a"]) === x
    @test levels(x) == ["b", "a"]
    @test x[1] === CategoricalValue(x.pool, 2)
    @test x[2] === CategoricalValue(x.pool, 1)
    @test x[3] === CategoricalValue(x.pool, 1)

    @test_throws ArgumentError levels!(x, ["a"])
    @test_throws ArgumentError levels!(x, ["e", "b"])
    @test_throws ArgumentError levels!(x, ["e", "a", "b", "a"])

    @test levels!(x, ["e", "a", "b"]) === x
    @test levels(x) == ["e", "a", "b"]
    @test x[1] === CategoricalValue(x.pool, 2)
    @test x[2] === CategoricalValue(x.pool, 3)
    @test x[3] === CategoricalValue(x.pool, 3)

    x[1] = "c"
    @test x[1] === CategoricalValue(x.pool, 4)
    @test x[2] === CategoricalValue(x.pool, 3)
    @test x[3] === CategoricalValue(x.pool, 3)
    @test levels(x) == ["e", "a", "b", "c"]

    push!(x, "a")
    @test length(x) == 4
    @test x[end] == "a"
    @test levels(x) == ["e", "a", "b", "c"]

    push!(x, "zz")
    @test length(x) == 5
    @test x[end] == "zz"
    @test levels(x) == ["e", "a", "b", "c", "zz"]

    push!(x, x[1])
    @test length(x) == 6
    @test x[1] == x[end]
    @test levels(x) == ["e", "a", "b", "c", "zz"]

    x2 = copy(x)
    @test_throws MethodError push!(x, 1)
    @test x == x2
    @test x.pool.levels == x2.pool.levels
    @test x.pool.invindex == x2.pool.invindex

    empty!(x)
    @test length(x) == 0
    @test levels(x) == ["e", "a", "b", "c", "zz"]

    @testset "Vector created from range" begin
        # (i.e. non-Array AbstractArray),
        # direct conversion to a vector with different eltype
        a = 0.0:0.5:1.5
        x = CategoricalVector{Float64, R}(a, ordered=ordered)

        @test x == collect(a)
        @test isordered(x) === ordered
        @test levels(x) == uniquelevels(x) == unique(a)
        @test size(x) === (4,)
        @test length(x) === 4
        @test leveltype(x) === Float64
        @test eltype(x) <: CategoricalValue{Float64}

        @test convert(CategoricalArray, x) === x
        @test convert(CategoricalArray{Float64}, x) === x
        @test convert(CategoricalArray{Float64, 1}, x) === x
        @test convert(CategoricalArray{Float64, 1, R}, x) === x
        @test convert(CategoricalArray{Float64, 1, DefaultRefType}, x) == x
        @test convert(CategoricalArray{Float64, 1, UInt8}, x) == x

        @test convert(CategoricalVector, x) === x
        @test convert(CategoricalVector{Float64}, x) === x
        @test convert(CategoricalVector{Float32}, x) == x
        @test convert(CategoricalVector{Float64, R}, x) === x
        @test convert(CategoricalVector{Float32, R}, x) == x
        @test convert(CategoricalVector{Float64, DefaultRefType}, x) == x
        @test convert(CategoricalVector{Float32, DefaultRefType}, x) == x
        @test convert(CategoricalVector{Float64, UInt8}, x) == x
        @test convert(CategoricalVector{Float32, UInt8}, x) == x

        @test convert(CategoricalArray, a) == x
        @test convert(CategoricalArray{Float64}, a) == x
        @test convert(CategoricalArray{Float32}, a) == x
        @test convert(CategoricalArray{Float64, 1}, a) == x
        @test convert(CategoricalArray{Float32, 1}, a) == x
        @test convert(CategoricalArray{Float64, 1, R}, a) == x
        @test convert(CategoricalArray{Float32, 1, R}, a) == x
        @test convert(CategoricalArray{Float64, 1, DefaultRefType}, a) == x
        @test convert(CategoricalArray{Float32, 1, DefaultRefType}, a) == x
        @test convert(CategoricalArray{Float64, 1, UInt8}, a) == x
        @test convert(CategoricalArray{Float32, 1, UInt8}, a) == x

        @test convert(CategoricalVector, a) == x
        @test convert(CategoricalVector{Float64}, a) == x
        @test convert(CategoricalVector{Float32}, a) == x
        @test convert(CategoricalVector{Float64, R}, a) == x
        @test convert(CategoricalVector{Float32, R}, a) == x
        @test convert(CategoricalVector{Float64, DefaultRefType}, a) == x
        @test convert(CategoricalVector{Float32, DefaultRefType}, a) == x
        @test convert(CategoricalVector{Float64, UInt8}, a) == x
        @test convert(CategoricalVector{Float32, UInt8}, a) == x

        @test CategoricalArray{Float64}(a, ordered=ordered) == x
        @test CategoricalArray{Float32}(a, ordered=ordered) == x
        @test CategoricalArray{Float64, 1}(a, ordered=ordered) == x
        @test CategoricalArray{Float32, 1}(a, ordered=ordered) == x
        @test CategoricalArray{Float64, 1, R}(a, ordered=ordered) == x
        @test CategoricalArray{Float32, 1, R}(a, ordered=ordered) == x
        @test CategoricalArray{Float64, 1, DefaultRefType}(a, ordered=ordered) == x
        @test CategoricalArray{Float32, 1, DefaultRefType}(a, ordered=ordered) == x

        @test CategoricalVector(a, ordered=ordered) == x
        @test CategoricalVector{Float64}(a, ordered=ordered) == x
        @test CategoricalVector{Float32}(a, ordered=ordered) == x
        @test CategoricalVector{Float64, R}(a, ordered=ordered) == x
        @test CategoricalVector{Float32, R}(a, ordered=ordered) == x
        @test CategoricalVector{Float64, DefaultRefType}(a, ordered=ordered) == x
        @test CategoricalVector{Float32, DefaultRefType}(a, ordered=ordered) == x

        @test convert(CategoricalArray{Union{Float64, Missing}}, x) == x
        @test convert(CategoricalArray{Union{Float32, Missing}}, x) == x
        @test convert(CategoricalArray{Union{Float64, Missing}, 1}, x) == x
        @test convert(CategoricalArray{Union{Float32, Missing}, 1}, x) == x
        @test convert(CategoricalArray{Union{Float64, Missing}, 1, R}, x) == x
        @test convert(CategoricalArray{Union{Float32, Missing}, 1, R}, x) == x
        @test convert(CategoricalArray{Union{Float64, Missing}, 1, DefaultRefType}, x) == x
        @test convert(CategoricalArray{Union{Float32, Missing}, 1, DefaultRefType}, x) == x
        @test convert(CategoricalArray{Union{Float64, Missing}, 1, UInt8}, x) == x
        @test convert(CategoricalArray{Union{Float32, Missing}, 1, UInt8}, x) == x

        @test convert(CategoricalVector{Union{Float64, Missing}}, x) == x
        @test convert(CategoricalVector{Union{Float32, Missing}}, x) == x
        @test convert(CategoricalVector{Union{Float64, Missing}, R}, x) == x
        @test convert(CategoricalVector{Union{Float32, Missing}, R}, x) == x
        @test convert(CategoricalVector{Union{Float64, Missing}, DefaultRefType}, x) == x
        @test convert(CategoricalVector{Union{Float32, Missing}, DefaultRefType}, x) == x
        @test convert(CategoricalVector{Union{Float64, Missing}, UInt8}, x) == x
        @test convert(CategoricalVector{Union{Float32, Missing}, UInt8}, x) == x

        @test CategoricalArray{Union{Float64, Missing}}(x, ordered=ordered) == x
        @test CategoricalArray{Union{Float32, Missing}}(x, ordered=ordered) == x
        @test CategoricalArray{Union{Float64, Missing}, 1}(x, ordered=ordered) == x
        @test CategoricalArray{Union{Float32, Missing}, 1}(x, ordered=ordered) == x
        @test CategoricalArray{Union{Float64, Missing}, 1, R}(x, ordered=ordered) == x
        @test CategoricalArray{Union{Float32, Missing}, 1, R}(x, ordered=ordered) == x
        @test CategoricalArray{Union{Float64, Missing}, 1, DefaultRefType}(x, ordered=ordered) == x
        @test CategoricalArray{Union{Float32, Missing}, 1, DefaultRefType}(x, ordered=ordered) == x

        @test CategoricalVector{Union{Float64, Missing}}(x, ordered=ordered) == x
        @test CategoricalVector{Union{Float32, Missing}}(x, ordered=ordered) == x
        @test CategoricalVector{Union{Float64, Missing}, R}(x, ordered=ordered) == x
        @test CategoricalVector{Union{Float32, Missing}, R}(x, ordered=ordered) == x
        @test CategoricalVector{Union{Float64, Missing}, DefaultRefType}(x, ordered=ordered) == x
        @test CategoricalVector{Union{Float32, Missing}, DefaultRefType}(x, ordered=ordered) == x

        @testset "categorical($(typeof(y)), compress=$comp) R1=$R1 R2=$R2" for (y, R1, R2, comp) in
            ((a, DefaultRefType, UInt8, true),
             (a, DefaultRefType, DefaultRefType, false),
             (x, R, UInt8, true),
             (x, R, R, false))

            x2 = @inferred categorical(y, ordered=ordered)
            @test x2 == x
            @test isa(x2, CategoricalVector{Float64, R1})
            @test isordered(x2) === ordered
            @test leveltype(x2) === Float64
            @test eltype(x2) === CategoricalValue{Float64, R1}

            x2 = categorical(y, compress=comp, ordered=ordered)
            @test x2 == x
            @test isa(x2, CategoricalVector{Float64, R2})
            @test isordered(x2) === ordered
            @test leveltype(x2) === Float64
            @test eltype(x2) === CategoricalValue{Float64, R2}
        end

        x2 = copy(x)
        @test x2 == x
        @test typeof(x2) === typeof(x)
        @test isordered(x2) === isordered(x)
        @test levels(x2) == levels(x)

        @test x[1] === CategoricalValue(x.pool, 1)
        @test x[2] === CategoricalValue(x.pool, 2)
        @test x[3] === CategoricalValue(x.pool, 3)
        @test x[4] === CategoricalValue(x.pool, 4)
        @test_throws BoundsError x[5]

        x2 = x[:]
        @test typeof(x2) === typeof(x)
        @test x2 == x
        @test levels(x2) == levels(x)
        @test levels(x2) !== levels(x)
        @test isordered(x2) == isordered(x)

        x2 = x[1:2]
        @test typeof(x2) === typeof(x)
        @test x2 == [0.0, 0.5]
        @test levels(x2) == levels(x)
        @test levels(x2) !== levels(x)
        @test isordered(x2) == isordered(x)

        x2 = x[1:1]
        @test typeof(x2) === typeof(x)
        @test x2 == [0.0]
        @test levels(x2) == levels(x)
        @test levels(x2) !== levels(x)
        @test isordered(x2) == isordered(x)

        x2 = x[2:1]
        @test typeof(x2) === typeof(x)
        @test isempty(x2)
        @test levels(x2) == levels(x)
        @test levels(x2) !== levels(x)
        @test isordered(x2) == isordered(x)

        x[2] = 1
        @test x[1] === CategoricalValue(x.pool, 1)
        @test x[2] === CategoricalValue(x.pool, 3)
        @test x[3] === CategoricalValue(x.pool, 3)
        @test x[4] === CategoricalValue(x.pool, 4)
        @test levels(x) == unique(a)
        @test uniquelevels(x) == unique(collect(x))

        x[1:2] .= -1
        @test x[1] === CategoricalValue(x.pool, 5)
        @test x[2] === CategoricalValue(x.pool, 5)
        @test x[3] === CategoricalValue(x.pool, 3)
        @test x[4] === CategoricalValue(x.pool, 4)
        @test levels(x) == vcat(unique(a), -1)
        @test uniquelevels(x) == unique(collect(x))

        push!(x, 2.0)
        @test length(x) == 5
        @test x[end] == 2.0
        @test isordered(x) === false
        @test levels(x) == [0.0,  0.5,  1.0,  1.5, -1.0,  2.0]

        ordered!(x, ordered)
        push!(x, x[1])
        @test length(x) == 6
        @test x[1] == x[end]
        @test isordered(x) === ordered
        @test levels(x) == [0.0,  0.5,  1.0,  1.5, -1.0,  2.0]

        ordered!(x, ordered)
        empty!(x)
        @test length(x) == 0
        @test isordered(x) === ordered
        @test levels(x) == [0.0, 0.5, 1.0, 1.5, -1.0, 2.0]
    end

    @testset "Matrix" begin
        a = ["a" "b" "c"; "b" "a" "c"]
        x = CategoricalMatrix{String, R}(a, ordered=ordered)

        @test x == a
        @test isordered(x) === ordered
        @test levels(x) == uniquelevels(x) == unique(a)
        @test size(x) === (2, 3)
        @test length(x) === 6

        @test convert(CategoricalArray, x) === x
        @test convert(CategoricalArray{String}, x) === x
        @test convert(CategoricalArray{String, 2}, x) === x
        @test convert(CategoricalArray{String, 2, R}, x) === x
        @test convert(CategoricalArray{String, 2, DefaultRefType}, x) == x
        @test convert(CategoricalArray{String, 2, UInt8}, x) == x

        @test convert(CategoricalMatrix, x) === x
        @test convert(CategoricalMatrix{String}, x) === x
        @test convert(CategoricalMatrix{String, R}, x) === x
        @test convert(CategoricalMatrix{String, DefaultRefType}, x) == x
        @test convert(CategoricalMatrix{String, UInt8}, x) == x

        @test convert(CategoricalArray, a) == x
        @test convert(CategoricalArray{String}, a) == x
        @test convert(CategoricalArray{String, 2, R}, a) == x
        @test convert(CategoricalArray{String, 2, DefaultRefType}, a) == x
        @test convert(CategoricalArray{String, 2, UInt8}, a) == x

        @test convert(CategoricalMatrix, a) == x
        @test convert(CategoricalMatrix{String}, a) == x
        @test convert(CategoricalMatrix{String, R}, a) == x
        @test convert(CategoricalMatrix{String, DefaultRefType}, a) == x
        @test convert(CategoricalMatrix{String, UInt8}, a) == x

        @test CategoricalArray{String}(a, ordered=ordered) == x
        @test CategoricalArray{String, 2}(a, ordered=ordered) == x
        @test CategoricalArray{String, 2}(a, ordered=ordered) == x
        @test CategoricalArray{String, 2, R}(a, ordered=ordered) == x
        @test CategoricalArray{String, 2, DefaultRefType}(a, ordered=ordered) == x
        @test CategoricalArray{String, 2, UInt8}(a, ordered=ordered) == x

        @test CategoricalMatrix(a, ordered=ordered) == x
        @test CategoricalMatrix{String}(a, ordered=ordered) == x
        @test CategoricalMatrix{String, R}(a, ordered=ordered) == x
        @test CategoricalMatrix{String, DefaultRefType}(a, ordered=ordered) == x
        @test CategoricalMatrix{String, UInt8}(a, ordered=ordered) == x

        @test convert(CategoricalArray{Union{String, Missing}}, x) == x
        @test convert(CategoricalArray{Union{String, Missing}, 2, R}, x) == x
        @test convert(CategoricalArray{Union{String, Missing}, 2, DefaultRefType}, x) == x
        @test convert(CategoricalArray{Union{String, Missing}, 2, UInt8}, x) == x

        @test convert(CategoricalMatrix{Union{String, Missing}}, x) == x
        @test convert(CategoricalMatrix{Union{String, Missing}, R}, x) == x
        @test convert(CategoricalMatrix{Union{String, Missing}, DefaultRefType}, x) == x
        @test convert(CategoricalMatrix{Union{String, Missing}, UInt8}, x) == x

        @test CategoricalArray{Union{String, Missing}}(x, ordered=ordered) == x
        @test CategoricalArray{Union{String, Missing}, 2}(x, ordered=ordered) == x
        @test CategoricalArray{Union{String, Missing}, 2}(x, ordered=ordered) == x
        @test CategoricalArray{Union{String, Missing}, 2, R}(x, ordered=ordered) == x
        @test CategoricalArray{Union{String, Missing}, 2, DefaultRefType}(x, ordered=ordered) == x
        @test CategoricalArray{Union{String, Missing}, 2, UInt8}(x, ordered=ordered) == x

        @test CategoricalMatrix{Union{String, Missing}}(x, ordered=ordered) == x
        @test CategoricalMatrix{Union{String, Missing}, R}(x, ordered=ordered) == x
        @test CategoricalMatrix{Union{String, Missing}, DefaultRefType}(x, ordered=ordered) == x
        @test CategoricalMatrix{Union{String, Missing}, UInt8}(x, ordered=ordered) == x

        @testset "categorical($(typeof(y)), compress=$comp) R1=$R1 R2=$R2" for (y, R1, R2, comp) in
            ((a, DefaultRefType, UInt8, true),
             (a, DefaultRefType, DefaultRefType, false),
             (x, R, UInt8, true),
             (x, R, R, false))

            x2 = @inferred categorical(y, ordered=ordered)
            @test x2 == x
            @test isa(x2, CategoricalMatrix{String, R1})
            @test isordered(x2) === ordered

            x2 = categorical(y, compress=comp, ordered=ordered)
            @test x2 == x
            @test isa(x2, CategoricalMatrix{String, R2})
            @test isordered(x2) === ordered
        end

        x2 = compress(x)
        @test x2 == x
        @test isa(x2, CategoricalMatrix{String, UInt8})
        @test isordered(x2) === isordered(x)
        @test levels(x2) == levels(x)

        x2 = copy(x)
        @test x2 == x
        @test typeof(x2) === typeof(x)
        @test isordered(x2) === isordered(x)
        @test levels(x2) == levels(x)

        @test x[1] === CategoricalValue(x.pool, 1)
        @test x[2] === CategoricalValue(x.pool, 2)
        @test x[3] === CategoricalValue(x.pool, 2)
        @test x[4] === CategoricalValue(x.pool, 1)
        @test x[5] === CategoricalValue(x.pool, 3)
        @test x[6] === CategoricalValue(x.pool, 3)
        @test_throws BoundsError x[7]

        @test x[1,1] === CategoricalValue(x.pool, 1)
        @test x[2,1] === CategoricalValue(x.pool, 2)
        @test x[1,2] === CategoricalValue(x.pool, 2)
        @test x[2,2] === CategoricalValue(x.pool, 1)
        @test x[1,3] === CategoricalValue(x.pool, 3)
        @test x[2,3] === CategoricalValue(x.pool, 3)
        @test_throws BoundsError x[1,4]
        @test_throws BoundsError x[4,1]
        @test_throws BoundsError x[4,4]

        x2 = x[1:2,:]
        @test typeof(x2) === typeof(x)
        @test x2 == x
        @test levels(x2) == levels(x)
        @test levels(x2) !== levels(x)
        @test isordered(x2) == isordered(x)

        x2 = x[:,[1, 3]]
        @test typeof(x2) === typeof(x)
        @test x2 == ["a" "c"; "b" "c"]
        @test levels(x2) == levels(x)
        @test levels(x2) !== levels(x)
        @test isordered(x2) == isordered(x)

        x2 = x[1:1,2]
        @test isa(x2, CategoricalVector{String, R})
        @test x2 == ["b"]
        @test levels(x2) == levels(x)
        @test levels(x2) !== levels(x)
        @test isordered(x2) == isordered(x)

        x2 = x[1:0,:]
        @test typeof(x2) === typeof(x)
        @test size(x2) == (0,3)
        @test levels(x2) == levels(x)
        @test levels(x2) !== levels(x)
        @test isordered(x2) == isordered(x)

        @test_throws BoundsError x[1:4, :]
        @test_throws BoundsError x[1:1, -1:1]
        @test_throws BoundsError x[4, :]

        x[1] = "z"
        @test x[1] === CategoricalValue(x.pool, 4)
        @test x[2] === CategoricalValue(x.pool, 2)
        @test x[3] === CategoricalValue(x.pool, 2)
        @test x[4] === CategoricalValue(x.pool, 1)
        @test x[5] === CategoricalValue(x.pool, 3)
        @test x[6] === CategoricalValue(x.pool, 3)
        @test levels(x) == ["a", "b", "c", "z"]
        @test isordered(x) === false

        x[1,:] .= "a"
        @test x[1] === CategoricalValue(x.pool, 1)
        @test x[2] === CategoricalValue(x.pool, 2)
        @test x[3] === CategoricalValue(x.pool, 1)
        @test x[4] === CategoricalValue(x.pool, 1)
        @test x[5] === CategoricalValue(x.pool, 1)
        @test x[6] === CategoricalValue(x.pool, 3)
        @test levels(x) == ["a", "b", "c", "z"]
        @test isordered(x) === false

        x[1,1:2] .= "z"
        @test x[1] === CategoricalValue(x.pool, 4)
        @test x[2] === CategoricalValue(x.pool, 2)
        @test x[3] === CategoricalValue(x.pool, 4)
        @test x[4] === CategoricalValue(x.pool, 1)
        @test x[5] === CategoricalValue(x.pool, 1)
        @test x[6] === CategoricalValue(x.pool, 3)
        @test levels(x) == ["a", "b", "c", "z"]
        @test isordered(x) === false

        x[1,2] = "b"
        @test x[1] === CategoricalValue(x.pool, 4)
        @test x[2] === CategoricalValue(x.pool, 2)
        @test x[3] === CategoricalValue(x.pool, 2)
        @test x[4] === CategoricalValue(x.pool, 1)
        @test x[5] === CategoricalValue(x.pool, 1)
        @test x[6] === CategoricalValue(x.pool, 3)
        @test levels(x) == ["a", "b", "c", "z"]
        @test isordered(x) === false
    end

    # Uninitialized array
    v = Any[CategoricalArray(undef, 2, ordered=ordered),
            CategoricalArray{String}(undef, 2, ordered=ordered),
            CategoricalArray{String, 1}(undef, 2, ordered=ordered),
            CategoricalArray{String, 1, R}(undef, 2, ordered=ordered),
            CategoricalVector(undef, 2, ordered=ordered),
            CategoricalVector{String}(undef, 2, ordered=ordered),
            CategoricalVector{String, R}(undef, 2, ordered=ordered),
            CategoricalArray(undef, 2, 3, ordered=ordered),
            CategoricalArray{String}(undef, 2, 3, ordered=ordered),
            CategoricalArray{String, 2}(undef, 2, 3, ordered=ordered),
            CategoricalArray{String, 2, R}(undef, 2, 3, ordered=ordered),
            CategoricalMatrix(undef, 2, 3, ordered=ordered),
            CategoricalMatrix{String}(undef, 2, 3, ordered=ordered),
            CategoricalMatrix{String, R}(undef, 2, 3, ordered=ordered)]

    @testset "compress($(typeof(x))) and setindex!()" for x in v
        @test !isassigned(x, 1) && isdefined(x, 1)
        @test !isassigned(x, 2) && isdefined(x, 2)
        @test_throws UndefRefError x[1]
        @test_throws UndefRefError x[2]
        @test isordered(x) === ordered
        @test levels(x) == []

        x2 = compress(x)
        @test isa(x2, CategoricalArray{leveltype(x), ndims(x), UInt8})
        @test !isassigned(x2, 1) && isdefined(x2, 1)
        @test !isassigned(x2, 2) && isdefined(x2, 2)
        @test_throws UndefRefError x2[1]
        @test_throws UndefRefError x2[2]
        @test levels(x2) == []

        x[1] = "c"
        @test x[1] === CategoricalValue(x.pool, 1)
        @test !isassigned(x, 2) && isdefined(x, 2)
        @test_throws UndefRefError x[2]
        @test isordered(x) === false
        @test levels(x) == ["c"]

        x[1] = "a"
        @test x[1] === CategoricalValue(x.pool, 2)
        @test !isassigned(x, 2) && isdefined(x, 2)
        @test_throws UndefRefError x[2]
        @test isordered(x) === false
        @test levels(x) == ["c", "a"]

        x[2] = "c"
        @test x[1] === CategoricalValue(x.pool, 2)
        @test x[2] === CategoricalValue(x.pool, 1)
        @test isordered(x) === false
        @test levels(x) == ["c", "a"]

        x[1] = "b"
        @test x[1] === CategoricalValue(x.pool, 3)
        @test x[2] === CategoricalValue(x.pool, 1)
        @test isordered(x) === false
        @test levels(x) == ["c", "a", "b"]

        ordered!(x, ordered)
        v = CategoricalValue(2, CategoricalPool(["xyz", "b"]))
        x[1] = v
        @test x[1] === CategoricalValue(x.pool, 4)
        @test x[2] === CategoricalValue(x.pool, 1)
        @test isordered(x) === false
        @test levels(x) == ["c", "a", "xyz", "b"]
    end
end

@testset "unique() and levels()" begin
    x = CategoricalArray(["Old", "Young", "Middle", "Young"])
    @test levels!(x, ["Young", "Middle", "Old"]) === x
    @test levels(x) == ["Young", "Middle", "Old"]
    @test uniquelevels(x) == ["Old", "Young", "Middle"]
    @test levels!(x, ["Young", "Middle", "Old", "Unused"]) === x
    @test levels(x) == ["Young", "Middle", "Old", "Unused"]
    @test uniquelevels(x) == ["Old", "Young", "Middle"]
    @test levels!(x, ["Unused1", "Young", "Middle", "Old", "Unused2"]) === x
    @test levels(x) == ["Unused1", "Young", "Middle", "Old", "Unused2"]
    @test uniquelevels(x) == ["Old", "Young", "Middle"]

    x = CategoricalArray(String[])
    @test isa(levels(x), Vector{String}) && isempty(levels(x))
    @test isa(uniquelevels(x), Vector{String}) && isempty(uniquelevels(x))
    @test levels!(x, ["Young", "Middle", "Old"]) === x
    @test levels(x) == ["Young", "Middle", "Old"]
    @test isa(uniquelevels(x), Vector{String}) && isempty(uniquelevels(x))

    # To test short-circuiting
    x = CategoricalArray(repeat(1:10, inner=10))
    @test levels(x) == collect(1:10)
    @test uniquelevels(x) == collect(1:10)
    @test levels!(x, [19:-1:1; 20]) === x
    @test levels(x) == [19:-1:1; 20]
    @test uniquelevels(x) == collect(1:10)
end

end
