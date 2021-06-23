module CategoricalArrays
    export CategoricalPool, CategoricalValue
    export AbstractCategoricalArray, AbstractCategoricalVector, AbstractCategoricalMatrix,
           CategoricalArray, CategoricalVector, CategoricalMatrix
    export LevelsException

    export categorical, compress, decompress, droplevels!, levels, levels!, levelcode,
           isordered, ordered!, uniquelevels
    export cut, recode, recode!

    import DataAPI: unwrap
    export unwrap

    using JSON
    using DataAPI
    using Missings
    using Printf
    import RecipesBase
    import StructTypes

    # JuliaLang/julia#36810
    if VERSION < v"1.5.2"
        Base.OrderStyle(::Type{Union{}}) = Base.Ordered()
    end

    include("typedefs.jl")

    include("pool.jl")
    include("value.jl")

    include("array.jl")
    include("missingarray.jl")
    include("subarray.jl")

    include("extras.jl")
    include("recode.jl")

    include("deprecated.jl")
end
