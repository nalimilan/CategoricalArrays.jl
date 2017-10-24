module TestUpdateOrder
using Base.Test
using CategoricalArrays
using CategoricalArrays: DefaultRefType

pool = CategoricalPool(
    [
        "a",
        "b",
        "c"
    ],
    Dict(
        "a" => convert(DefaultRefType, 1),
        "b" => convert(DefaultRefType, 2),
        "c" => convert(DefaultRefType, 3),
    )
)

order = Vector{DefaultRefType}(length(pool.index))

CategoricalArrays.buildorder!(order, pool.invindex, ["b", "a", "c"])

@test order[1] == convert(DefaultRefType, 2)
@test order[2] == convert(DefaultRefType, 1)
@test order[3] == convert(DefaultRefType, 3)

@testset "levels are built correctly" begin
    orig_index = [2, 5, 1, 3, 4]
    orig_levels = [1, 2, 3, 4, 5]
    pool = CategoricalPool(orig_index, orig_levels, true)
    @test orig_index == CategoricalArrays.index(pool)
    @test orig_levels == levels(pool)
    @test CategoricalArrays.index(pool) == levels(pool)[CategoricalArrays.order(pool)]
end

end
