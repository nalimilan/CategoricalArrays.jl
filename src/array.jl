## Code for CategoricalArray

import Base: Array, convert, collect, copy, getindex, setindex!, similar, size,
             unique, vcat, in, summary, float, complex, copyto!

# Used for keyword argument default value
_isordered(x::AbstractCategoricalArray) = isordered(x)
_isordered(x::Any) = false

function reftype(sz::Int)
    if sz <= typemax(UInt8)
        return UInt8
    elseif sz <= typemax(UInt16)
        return UInt16
    elseif sz <= typemax(UInt32)
        return UInt32
    else
        return UInt64
    end
end

# This check is only there to print a user-friendly warning before
# a TypeError is thrown due to restrictions in the type signature
function check_supported_eltype(::Type{T}, ::Type{U}) where {T, U}
    T === Symbol &&
    throw(ArgumentError("CategoricalArray no longer supports Symbol as element type "*
                        "as that forces recompiling too many Julia Base methods: " *
                        "use strings instead, e.g. via categorical(string.(x))"))
    T <: Union{SupportedTypes, Missing} ||
        throw(ArgumentError("CategoricalArray only supports " *
                            "AbstractString, AbstractChar and Number element types " *
                            "(got element type $U)"))
end

fixstringtype(T::Type) = T <: SubString || T === AbstractString ? String : T
fixstringtype(T::Union) = Union{fixstringtype(T.a), fixstringtype(T.b)}
fixstringtype(::Type{Union{}}) = Union{}

# Find a narrow type that is supported to hold all elements if possible
function fixtype(A::AbstractArray{T}) where T
    if T <: Union{SupportedTypes, Missing}
        return fixstringtype(T)
    else
        U = fixstringtype(mapreduce(typeof, Base.promote_typejoin, A))
        check_supported_eltype(U, T)
        return U
    end
end

"""
    CategoricalArray{T}(undef, dims::Dims; levels=nothing, ordered=false)
    CategoricalArray{T}(undef, dims::Int...; levels=nothing, ordered=false)

Construct an uninitialized `CategoricalArray` with levels of type
`T <: $SupportedTypes` and dimensions `dims`.

The `levels` keyword argument can be a vector specifying possible values for the data
(this is equivalent to but more efficient than calling [`levels!`](@ref)
on the resulting array).
The `ordered` keyword argument determines whether the array values can be compared
according to the ordering of levels or not (see [`isordered`](@ref)).

    CategoricalArray{T, N, R}(undef, dims::Dims; levels=nothing, ordered=false)
    CategoricalArray{T, N, R}(undef, dims::Int...; levels=nothing, ordered=false)

Similar to definition above, but uses reference type `R` instead of the default type
(`$DefaultRefType`).

    CategoricalArray(A::AbstractArray; levels=nothing, ordered=false)

Construct a new `CategoricalArray` with the values from `A` and the same element type.

The `levels` keyword argument can be a vector specifying possible values for the data
(this is equivalent to but more efficient than calling [`levels!`](@ref)
on the resulting array).
If `levels` is omitted and the element type supports it, levels are sorted
in ascending order; else, they are kept in their order of appearance in `A`.
The `ordered` keyword argument determines whether the array values can be compared
according to the ordering of levels or not (see [`isordered`](@ref)).

If `A` is already a `CategoricalArray`, its levels, orderedness and reference type
are preserved unless explicitly overriden.
"""
function CategoricalArray end

"""
    CategoricalVector{T}(undef, m::Int; levels=nothing, ordered=false)

Construct an uninitialized `CategoricalVector` with levels of type
`T <: $SupportedTypes` and dimensions `dim`.

The `levels` keyword argument can be a vector specifying possible values for the data
(this is equivalent to but more efficient than calling [`levels!`](@ref)
on the resulting array).
The `ordered` keyword argument determines whether the array values can be compared
according to the ordering of levels or not (see [`isordered`](@ref)).

    CategoricalVector{T, R}(undef, m::Int; levels=nothing, ordered=false)

Similar to definition above, but uses reference type `R` instead of the default type
(`$DefaultRefType`).

    CategoricalVector(A::AbstractVector; levels=nothing, ordered=false)

Construct a `CategoricalVector` with the values from `A` and the same element type.

The `levels` keyword argument can be a vector specifying possible values for the data
(this is equivalent to but more efficient than calling [`levels!`](@ref)
on the resulting array).
If `levels` is omitted and the element type supports it, levels are sorted
in ascending order; else, they are kept in their order of appearance in `A`.
The `ordered` keyword argument determines whether the array values can be compared
according to the ordering of levels or not (see [`isordered`](@ref)).

If `A` is already a `CategoricalVector`, its levels, orderedness and reference type
are preserved unless explicitly overriden.
"""
function CategoricalVector end

"""
    CategoricalMatrix{T}(undef, m::Int, n::Int; levels=nothing, ordered=false)

Construct an uninitialized `CategoricalMatrix` with levels of type
`T <: $SupportedTypes` and dimensions `dim`.
The `ordered` keyword argument determines whether the array values can be compared
according to the ordering of levels or not (see [`isordered`](@ref)).

    CategoricalMatrix{T, R}(undef, m::Int, n::Int; levels=nothing, ordered=false)

Similar to definition above, but uses reference type `R` instead of the default type
(`$DefaultRefType`).

    CategoricalMatrix(A::AbstractMatrix; levels=nothing, ordered=false)

Construct a `CategoricalMatrix` with the values from `A` and the same element type.

The `levels` keyword argument can be a vector specifying possible values for the data
(this is equivalent to but more efficient than calling [`levels!`](@ref)
on the resulting array).
If `levels` is omitted and the element type supports it, levels are sorted
in ascending order; else, they are kept in their order of appearance in `A`.
The `ordered` keyword argument determines whether the array values can be compared
according to the ordering of levels or not (see [`isordered`](@ref)).

If `A` is already a `CategoricalMatrix`, its levels, orderedness and reference type
are preserved unless explicitly overriden.
"""
function CategoricalMatrix end

# UndefInitializer array constructors

CategoricalArray(::UndefInitializer, dims::Int...;
                 levels::Union{AbstractVector, Nothing}=nothing,
                 ordered::Bool=false) =
    CategoricalArray{String}(undef, dims, levels=levels, ordered=ordered)

function CategoricalArray{T, N, R}(::UndefInitializer, dims::NTuple{N,Int};
                                   levels::Union{AbstractVector, Nothing}=nothing,
                                   ordered::Bool=false) where {T, N, R}
    U = leveltype(nonmissingtype(T))
    S = T >: Missing ? Union{U, Missing} : U
    check_supported_eltype(S, T)
    V = CategoricalValue{U, R}
    levs = levels === nothing ? U[] : collect(U, levels)
    CategoricalArray{S, N}(zeros(R, dims), CategoricalPool{U, R, V}(levs, ordered))
end

CategoricalArray{T, N}(::UndefInitializer, dims::NTuple{N,Int};
                       levels::Union{AbstractVector, Nothing}=nothing,
                       ordered::Bool=false) where {T, N} =
    CategoricalArray{T, N, DefaultRefType}(undef, dims, levels=levels, ordered=ordered)
CategoricalArray{T, N}(::UndefInitializer, dims::NTuple{N,Int};
                       levels::Union{AbstractVector, Nothing}=nothing,
                       ordered::Bool=false) where
    {R, T <: Union{Missing, CategoricalValue{<:Any, R}}, N} =
    CategoricalArray{T, N, R}(undef, dims, levels=levels, ordered=ordered)
CategoricalArray{T}(::UndefInitializer, dims::NTuple{N,Int};
                    levels::Union{AbstractVector, Nothing}=nothing,
                    ordered::Bool=false) where {T, N} =
    CategoricalArray{T, N}(undef, dims, levels=levels, ordered=ordered)
CategoricalArray{T, 1}(::UndefInitializer, m::Int;
                       levels::Union{AbstractVector, Nothing}=nothing,
                       ordered::Bool=false) where {T} =
    CategoricalArray{T, 1}(undef, (m,), levels=levels, ordered=ordered)
CategoricalArray{T, 2}(::UndefInitializer, m::Int, n::Int;
                       levels::Union{AbstractVector, Nothing}=nothing,
                       ordered::Bool=false) where {T} =
    CategoricalArray{T, 2}(undef, (m, n), levels=levels, ordered=ordered)
CategoricalArray{T, 1, R}(::UndefInitializer, m::Int;
                          levels::Union{AbstractVector, Nothing}=nothing,
                          ordered=false) where {T, R} =
    CategoricalArray{T, 1, R}(undef, (m,), levels=levels, ordered=ordered)
# R <: Integer is required to prevent default constructor from being called instead
CategoricalArray{T, 2, R}(::UndefInitializer, m::Int, n::Int;
                          levels::Union{AbstractVector, Nothing}=nothing,
                          ordered::Bool=false) where {T, R <: Integer} =
    CategoricalArray{T, 2, R}(undef, (m, n), levels=levels, ordered=ordered)
CategoricalArray{T, 3, R}(::UndefInitializer, m::Int, n::Int, o::Int;
                          levels::Union{AbstractVector, Nothing}=nothing,
                          ordered::Bool=false) where {T, R} =
    CategoricalArray{T, 3, R}(undef, (m, n, o), levels=levels, ordered=ordered)
CategoricalArray{T}(::UndefInitializer, m::Int;
                    levels::Union{AbstractVector, Nothing}=nothing,
                    ordered::Bool=false) where {T} =
    CategoricalArray{T}(undef, (m,), levels=levels, ordered=ordered)
CategoricalArray{T}(::UndefInitializer, m::Int, n::Int;
                    levels::Union{AbstractVector, Nothing}=nothing,
                    ordered::Bool=false) where {T} =
    CategoricalArray{T}(undef, (m, n), levels=levels, ordered=ordered)
CategoricalArray{T}(::UndefInitializer, m::Int, n::Int, o::Int;
                    levels::Union{AbstractVector, Nothing}=nothing,
                    ordered::Bool=false) where {T} =
    CategoricalArray{T}(undef, (m, n, o), levels=levels, ordered=ordered)

CategoricalVector(::UndefInitializer, m::Integer;
                  levels::Union{AbstractVector, Nothing}=nothing,
                  ordered::Bool=false) =
    CategoricalArray(undef, m, levels=levels, ordered=ordered)

CategoricalMatrix(::UndefInitializer, m::Int, n::Int;
                  levels::Union{AbstractVector, Nothing}=nothing,
                  ordered::Bool=false) =
    CategoricalArray(undef, m, n, levels=levels, ordered=ordered)

## Constructors from arrays

function CategoricalArray{T, N, R}(A::CategoricalArray{S, N, Q};
                                   levels::Union{AbstractVector, Nothing}=nothing,
                                   ordered::Bool=_isordered(A)) where {S, T, N, Q, R}
    V = unwrap_catvaluetype(T)
    res = convert(CategoricalArray{V, N, R}, A)
    refs = res.refs === A.refs ? copy(res.refs) : res.refs
    pool = res.pool === A.pool ? copy(res.pool) : res.pool
    ordered!(pool, ordered)
    res = CategoricalArray{V, N}(refs, pool)
    if levels !== nothing
        # Calling levels! is faster than checking beforehand which values are used
        try
            levels!(res, levels)
        catch err
            err isa LevelsException || rethrow(err)
            throw(ArgumentError("encountered value(s) not in specified `levels`: " *
                                "$(setdiff(CategoricalArrays.levels(res), levels))"))
        end
    end
    return res
end

function CategoricalArray{T, N, R}(A::AbstractArray;
                                   levels::Union{AbstractVector, Nothing}=nothing,
                                   ordered::Bool=_isordered(A)) where {T, N, R}
    V = unwrap_catvaluetype(T)
    ordered!(_convert(CategoricalArray{V, N, R}, A, levels=levels), ordered)
end

# From AbstractArray

CategoricalArray{T, N}(A::AbstractArray{S, N};
                       levels::Union{AbstractVector, Nothing}=nothing,
                       ordered::Bool=_isordered(A)) where {S, T, N} =
    CategoricalArray{T, N, DefaultRefType}(A, levels=levels, ordered=ordered)
CategoricalArray{T}(A::AbstractArray{S, N};
                    levels::Union{AbstractVector, Nothing}=nothing,
                    ordered::Bool=_isordered(A)) where {S, T, N} =
    CategoricalArray{T, N}(A, levels=levels, ordered=ordered)
CategoricalArray(A::AbstractArray{T, N};
                 levels::Union{AbstractVector, Nothing}=nothing,
                 ordered::Bool=_isordered(A)) where {T, N} =
    CategoricalArray{fixtype(A), N}(A, levels=levels, ordered=ordered)

CategoricalVector(A::AbstractVector{T};
                  levels::Union{AbstractVector, Nothing}=nothing,
                  ordered::Bool=_isordered(A)) where {T} =
    CategoricalArray{fixtype(A), 1}(A, levels=levels, ordered=ordered)

CategoricalMatrix(A::AbstractMatrix{T};
                  levels::Union{AbstractVector, Nothing}=nothing,
                  ordered::Bool=_isordered(A)) where {T} =
    CategoricalArray{fixtype(A), 2}(A, levels=levels, ordered=ordered)

# From CategoricalArray (preserve R)
CategoricalArray{T, N}(A::CategoricalArray{S, N, R};
                       levels::Union{AbstractVector, Nothing}=nothing,
                       ordered::Bool=_isordered(A)) where {S, T, N, R} =
    CategoricalArray{T, N, R}(A, levels=levels, ordered=ordered)
CategoricalArray{T}(A::CategoricalArray{S, N, R};
                    levels::Union{AbstractVector, Nothing}=nothing,
                    ordered::Bool=_isordered(A)) where {S, T, N, R} =
    CategoricalArray{T, N, R}(A, levels=levels, ordered=ordered)
CategoricalArray(A::CategoricalArray{T, N, R};
                 levels::Union{AbstractVector, Nothing}=nothing,
                 ordered::Bool=_isordered(A)) where {T, N, R} =
    CategoricalArray{T, N, R}(A, levels=levels, ordered=ordered)

CategoricalVector(A::CategoricalArray{T, 1, R};
                  levels::Union{AbstractVector, Nothing}=nothing,
                  ordered::Bool=_isordered(A)) where {T, R} =
    CategoricalArray{T, 1, R}(A, levels=levels, ordered=ordered)

CategoricalMatrix(A::CategoricalArray{T, 2, R};
                  levels::Union{AbstractVector, Nothing}=nothing,
                  ordered::Bool=_isordered(A)) where {T, R} =
    CategoricalArray{T, 2, R}(A, levels=levels, ordered=ordered)

## Conversion methods

# From AbstractArray
convert(::Type{CategoricalArray{T, N}}, A::AbstractArray{S, N}) where {S, T, N} =
    convert(CategoricalArray{T, N, DefaultRefType}, A)
convert(::Type{CategoricalArray{T}}, A::AbstractArray{S, N}) where {S, T, N} =
    convert(CategoricalArray{T, N}, A)
convert(::Type{CategoricalArray}, A::AbstractArray{T, N}) where {T, N} =
    convert(CategoricalArray{fixtype(A), N}, A)

convert(::Type{CategoricalVector{T}}, A::AbstractVector) where {T} =
    convert(CategoricalVector{T, DefaultRefType}, A)
convert(::Type{CategoricalVector}, A::AbstractVector{T}) where {T} =
    convert(CategoricalVector{fixtype(A)}, A)
convert(::Type{CategoricalVector{T}},
        A::CategoricalVector{S, R}) where {S, T, R <: Integer} =
    convert(CategoricalVector{T, R}, A)
convert(::Type{CategoricalVector{T}}, A::CategoricalVector{T}) where {T} = A
convert(::Type{CategoricalVector}, A::CategoricalVector) = A

convert(::Type{CategoricalMatrix{T}}, A::AbstractMatrix) where {T} =
    convert(CategoricalMatrix{T, DefaultRefType}, A)
convert(::Type{CategoricalMatrix}, A::AbstractMatrix{T}) where {T} =
    convert(CategoricalMatrix{fixtype(A)}, A)
convert(::Type{CategoricalMatrix{T}},
        A::CategoricalMatrix{S, R}) where {S, T, R <: Integer} =
    convert(CategoricalMatrix{T, R}, A)
convert(::Type{CategoricalMatrix{T}}, A::CategoricalMatrix{T}) where {T} = A
convert(::Type{CategoricalMatrix}, A::CategoricalMatrix) = A

convert(::Type{CategoricalArray{T, N, R}}, A::AbstractArray{S, N}) where {S, T, N, R} =
    _convert(CategoricalArray{T, N, R}, A)

function _convert(::Type{CategoricalArray{T, N, R}}, A::AbstractArray{S, N};
                  levels::Union{AbstractVector, Nothing}=nothing) where {S, T, N, R}
    check_supported_eltype(T, T)

    res = CategoricalArray{T, N, R}(undef, size(A), levels=levels)
    copyto!(res, A)

    if levels !== nothing
        CategoricalArrays.levels(res) == levels ||
            throw(ArgumentError("encountered value(s) not in specified `levels`: " *
                                "$(setdiff(CategoricalArrays.levels(res), levels))"))
    else
        # if order is defined for level type, automatically apply it
        L = leveltype(res)
        if Base.OrderStyle(L) isa Base.Ordered
            levels!(res, sort(CategoricalArrays.levels(res)))
        elseif hasmethod(isless, (L, L))
            # isless may throw an error, e.g. for AbstractArray{T} of unordered T
            try
                levels!(res, sort(CategoricalArrays.levels(res)))
            catch e
                 e isa MethodError || rethrow(e)
            end
        end
    end

    res
end

# From CategoricalArray (preserve levels, ordering and R)
function convert(::Type{CategoricalArray{T, N, R}}, A::CategoricalArray{S, N}) where {S, T, N, R}
    if length(A.pool) > typemax(R)
        throw(LevelsException{T, R}(levels(A)[typemax(R)+1:end]))
    end

    if !(T >: Missing) && S >: Missing && any(iszero, A.refs)
        throw(MissingException("cannot convert CategoricalArray with missing values to a CategoricalArray{$T}"))
    end

    pool = convert(CategoricalPool{unwrap_catvaluetype(nonmissingtype(T)), R}, A.pool)
    refs = convert(Array{R, N}, A.refs)
    CategoricalArray{unwrap_catvaluetype(T), N}(refs, pool)
end

convert(::Type{CategoricalArray{T, N}},
        A::CategoricalArray{S, N, R}) where {S, T, N, R <: Integer} =
    convert(CategoricalArray{T, N, R}, A)
convert(::Type{CategoricalArray{T}},
        A::CategoricalArray{S, N, R}) where {S, T, N, R <: Integer} =
    convert(CategoricalArray{T, N, R}, A)
convert(::Type{CategoricalArray}, A::CategoricalArray{T, N, R}) where {T, N, R} =
    convert(CategoricalArray{T, N, R}, A)

# R<:Integer is needed for this method to be considered more specific
# than the generic one above (JuliaLang/julia#18443)
convert(::Type{CategoricalArray{T, N, R}}, A::CategoricalArray{T, N, R}) where {T, N, R<:Integer} = A
convert(::Type{CategoricalArray{T, N}}, A::CategoricalArray{T, N}) where {T, N} = A
convert(::Type{CategoricalArray{T}}, A::CategoricalArray{T}) where {T} = A
convert(::Type{CategoricalArray}, A::CategoricalArray) = A

function Base.:(==)(A::CategoricalArray{S}, B::CategoricalArray{T}) where {S, T}
    if size(A) != size(B)
        return false
    end
    anymissing = false
    if A.pool === B.pool
        @inbounds for (a, b) in zip(A.refs, B.refs)
            if a == 0 || b == 0
                (S >: Missing || T >: Missing) && (anymissing = true)
            elseif a != b
                return false
            end
        end
    else
        @inbounds for (a, b) in zip(A, B)
            eq = (a == b)
            if eq === false
                return false
            elseif S >: Missing || T >: Missing
                anymissing |= ismissing(eq)
            end
        end
    end
    return anymissing ? missing : true
end

function Base.isequal(A::CategoricalArray, B::CategoricalArray)
    if size(A) != size(B)
        return false
    end
    if A.pool === B.pool
        @inbounds for (a, b) in zip(A.refs, B.refs)
            if a != b
                return false
            end
        end
    else
        @inbounds for (a, b) in zip(A, B)
            if !isequal(a, b)
                return false
            end
        end
    end
    return true
end

size(A::CategoricalArray) = size(A.refs)
Base.IndexStyle(::Type{<:CategoricalArray}) = IndexLinear()

function update_refs!(A::CategoricalArray, newlevels::AbstractVector)
    oldlevels = levels(A)
    levelsmap = similar(A.refs, length(oldlevels)+1)
    # 0 maps to a missing value
    levelsmap[1] = 0
    levelsmap[2:end] .= something.(indexin(oldlevels, newlevels), 0)

    refs = A.refs
    @inbounds for (i, x) in enumerate(refs)
        refs[i] = levelsmap[x+1]
    end
    A
end

function merge_pools!(A::CatArrOrSub,
                      B::Union{CategoricalValue, CatArrOrSub};
                      updaterefs::Bool=true,
                      updatepool::Bool=true)
    newlevels, ordered = merge_pools(pool(A), pool(B))
    oldlevels = levels(A)
    pA = A isa SubArray ? parent(A) : A
    ordered!(pA, ordered)
    # If A's levels are an ordered superset of new (merged) pool, no need to recompute refs
    if updaterefs &&
        (length(newlevels) < length(oldlevels) ||
         view(newlevels, 1:length(oldlevels)) != oldlevels)
        update_refs!(pA, newlevels)
    end
    if updatepool
        pA.pool = typeof(pA.pool)(newlevels, ordered)
    end
    newlevels, ordered
end

@inline function setindex!(A::CategoricalArray, v::Any, I::Real...)
    @boundscheck checkbounds(A, I...)
    if v isa CategoricalValue && pool(v) !== pool(A) && pool(v) ⊈ pool(A)
        merge_pools!(A, v)
    end
    @inbounds A.refs[I...] = get!(A.pool, v)
end

Base.fill(v::CategoricalValue{T}, dims::NTuple{N, Integer}) where {T, N} =
    CategoricalArray{T, N}(fill(refcode(v), dims), copy(pool(v)))

# to avoid ambiguity
Base.fill(v::CategoricalValue, dims::Tuple{}) =
    invoke(fill, Tuple{CategoricalValue{T}, NTuple{N, Integer}} where {T, N}, v, dims)

function Base.fill!(A::CategoricalArray, v::Any)
    if v isa CategoricalValue && pool(v) !== pool(A) && pool(v) ⊈ pool(A)
        merge_pools!(A, v, updaterefs=false)
    end
    fill!(A.refs, get!(A.pool, v))
    A
end

# Methods preserving levels and more efficient than AbstractArray fallbacks
copy(A::CategoricalArray{T, N}) where {T, N} =
    CategoricalArray{T, N}(copy(A.refs), copy(A.pool))

function copyto!(dest::CatArrOrSub{T, N, R}, dstart::Integer,
                 src::CatArrOrSub{<:Any, N}, sstart::Integer,
                 n::Integer) where {T, N, R}
    n < 0 && throw(ArgumentError("tried to copy n=$n elements, but n should be nonnegative"))
    destinds, srcinds = LinearIndices(dest), LinearIndices(src)
    if n > 0
        (dstart ∈ destinds && dstart+n-1 ∈ destinds) || throw(BoundsError(dest, dstart:dstart+n-1))
        (sstart ∈ srcinds  && sstart+n-1 ∈ srcinds)  || throw(BoundsError(src,  sstart:sstart+n-1))
    end

    drefs = refs(dest)
    srefs = refs(src)
    dpool = pool(dest)
    spool = pool(src)

    # try converting src to dest type to avoid partial copy corruption of dest
    # in the event that the src cannot be copied into dest
    slevs = convert(Vector{T}, levels(src))
    dlevs = levels(dest)
    if eltype(src) >: Missing && !(eltype(dest) >: Missing) && !all(x -> x > 0, srefs)
        throw(MissingException("cannot copy array with missing values to an array with element type $T"))
    end

    destp = dest isa SubArray ? parent(dest) : dest

    # For partial copy, need to recompute existing refs
    # TODO: for performance, avoid ajusting refs which are going to be overwritten
    updaterefs = isa(dest, SubArray) || !(n == length(dest) == length(src))
    newlevels, ordered = merge_pools!(dest, src, updaterefs=updaterefs, updatepool=false)

    # If destination levels are an ordered superset of source, no need to recompute refs
    if view(newlevels, 1:length(slevs)) == slevs
        copyto!(drefs, dstart, srefs, sstart, n)
    else # Otherwise, recompute refs according to new levels
        # Then adjust refs from source
        levelsmap = similar(drefs, length(slevs)+1)
        # 0 maps to a missing value
        levelsmap[1] = 0
        levelsmap[2:end] = indexin(slevs, newlevels)

        @inbounds for i = 0:(n-1)
            x = srefs[sstart+i]
            drefs[dstart+i] = levelsmap[x+1]
        end
    end
    # Need to allocate a new pool only if reordering destination levels
    if view(newlevels, 1:length(dlevs)) == dlevs
        levels!(dpool, newlevels, checkunique=false)
    else
        destp.pool = CategoricalPool{nonmissingtype(T), R}(newlevels, ordered)
    end

    dest
end

function copyto!(dest::CatArrOrSub{T1, N, R}, dstart::Integer,
                 src::AbstractArray{T2, N}, sstart::Integer,
                 n::Integer) where {T1, T2, N, R}
    n == 0 && return dest
    n < 0 && throw(ArgumentError("tried to copy n=$n elements, but n should be nonnegative"))
    destinds, srcinds = LinearIndices(dest), LinearIndices(src)
    (checkbounds(Bool, destinds, dstart) && checkbounds(Bool, destinds, dstart+n-1)) || throw(BoundsError(dest, dstart:dstart+n-1))
    (checkbounds(Bool, srcinds, sstart)  && checkbounds(Bool, srcinds, sstart+n-1))  || throw(BoundsError(src,  sstart:sstart+n-1))
    srclevs = DataAPI.refpool(src)
    srcrefs = DataAPI.refarray(src)
    # Fast path only supports refs which can be used to index
    # into vector mapping from source levels to destination levels
    if !(srclevs isa AbstractVector) || !(srcrefs isa AbstractArray{<:Integer})
        return invoke(copyto!, Tuple{AbstractArray, Integer, AbstractArray, Integer, Integer},
                      dest, dstart, src, sstart, n)
    end
    newdestlevs = destlevs = copy(levels(dest)) # copy since we need original levels below
    srclevsnm = T2 >: Missing ? setdiff(srclevs, [missing]) : srclevs
    if !(srclevsnm ⊆ destlevs)
        # if order is defined for level type, automatically apply it
        L = nonmissingtype(eltype(srclevsnm))
        if hasmethod(isless, Tuple{L, L})
            srclevsnm = srclevsnm === srclevs ? sort(srclevsnm) : sort!(srclevsnm)
        end
        newdestlevs = union(destlevs, srclevsnm)
        levels!(pool(dest), newdestlevs, checkunique=false)
    end
    levelsmap = something.(indexin(srclevs, [missing; newdestlevs])) .- 1
    destrefs = refs(dest)
    seen = fill(false, length(newdestlevs)+1)
    firstind = firstindex(srclevs)
    @inbounds for i in 0:(n-1)
        j = srcrefs[sstart+i] - firstind + 1
        ref = levelsmap[j]
        seen[ref+1] = true
        if !(T1 >: Missing) && T2 >: Missing && ref == 0
            throw(MethodError(convert, (T1, missing)))
        end
        destrefs[dstart+i] = ref
    end
    seennm = @view seen[2:end]
    if !all(seennm)
        destlevsset = Set(destlevs)
        keptlevs = [l for (i, l) in enumerate(newdestlevs)
                    if seennm[i] || l in destlevsset]
        levels!(dest, keptlevs)
    end
    dest
end

# This uses linear indexing even for IndexCartesian src, but
# the performance impact should be modest compared to the dict lookup
copyto!(dest::CatArrOrSub, src::AbstractArray) =
    copyto!(dest, 1, src, 1, length(src))

copyto!(dest::CatArrOrSub, dstart::Integer, src::AbstractArray) =
    copyto!(dest, dstart, src, 1, length(src))

if VERSION >= v"1.1"
    import Base: copy!
else
    import Future: copy!
end
copy!(dest::CatArrOrSub, src::AbstractArray) = copyto!(dest, 1, src, 1, length(src))
# To fix ambiguities
copy!(dest::CatArrOrSub{<:Any, 1}, src::AbstractArray{<:Any, 1}) =
    copyto!(dest, 1, src, 1, length(src))
copy!(dest::CatArrOrSub{T, 1}, src::AbstractArray{T, 1}) where {T} =
    copyto!(dest, 1, src, 1, length(src))

similar(A::CategoricalArray{S, M, R}, ::Type{T},
        dims::NTuple{N, Int}) where {T, N, S, M, R} =
    Array{T, N}(undef, dims)
similar(A::CategoricalArray{S, M, R}, ::Type{Missing},
        dims::NTuple{N, Int}) where {N, S, M, R} =
    Array{Missing, N}(missing, dims)
similar(A::CategoricalArray{S, M, Q}, ::Type{CategoricalValue{T, R}},
        dims::NTuple{N, Int}) where {R, T, N, S, M, Q} =
    CategoricalArray{T, N, R}(undef, dims)
similar(A::CategoricalArray{S, M, Q}, ::Type{CategoricalValue{T}},
        dims::NTuple{N, Int}) where {T, N, S, M, Q} =
    CategoricalArray{T, N, Q}(undef, dims)
similar(A::CategoricalArray{S, M, Q}, ::Type{Union{CategoricalValue{T, R}, Missing}},
        dims::NTuple{N, Int}) where {R, T, N, S, M, Q} =
    CategoricalArray{Union{T, Missing}, N, R}(undef, dims)
similar(A::CategoricalArray{S, M, Q}, ::Type{Union{CategoricalValue{T}, Missing}},
        dims::NTuple{N, Int}) where {T, N, S, M, Q} =
    CategoricalArray{Union{T, Missing}, N, Q}(undef, dims)

# AbstractRange methods are needed since collect uses 1:1 as dummy array
for A in (:Array, :Vector, :Matrix, :AbstractRange)
    @eval begin
        similar(A::$A, ::Type{CategoricalValue{T, R}},
                dims::NTuple{N, Int}=size(A)) where {T, R, N} =
            CategoricalArray{T, N, R}(undef, dims)
        similar(A::$A, ::Type{CategoricalValue{T}},
                dims::NTuple{N, Int}=size(A)) where {T, N} =
            CategoricalArray{T, N}(undef, dims)
        similar(A::$A, ::Type{Union{CategoricalValue{T, R}, Missing}},
                dims::NTuple{N, Int}=size(A)) where {T, R, N} =
            CategoricalArray{Union{T, Missing}, N, R}(undef, dims)
        similar(A::$A, ::Type{Union{CategoricalValue{T}, Missing}},
                dims::NTuple{N, Int}=size(A)) where {T, N} =
            CategoricalArray{Union{T, Missing}, N}(undef, dims)
    end
end

similar(::Type{T}, dims::Dims) where {U, R, T<:Array{CategoricalValue{U, R}}} =
    CategoricalArray{eltype(T)}(undef, dims)
similar(::Type{T}, dims::Dims) where {U, T<:Array{CategoricalValue{U}}} =
    CategoricalArray{eltype(T)}(undef, dims)
similar(::Type{T}, dims::Dims) where {U, R, T<:Array{Union{CategoricalValue{U, R}, Missing}}} =
    CategoricalArray{eltype(T)}(undef, dims)
similar(::Type{T}, dims::Dims) where {U, T<:Array{Union{CategoricalValue{U}, Missing}}} =
    CategoricalArray{eltype(T)}(undef, dims)

"""
    compress(A::CategoricalArray)

Return a copy of categorical array `A` using the smallest reference type able to hold the
number of [`levels`](@ref DataAPI.levels) of `A`.

While this will reduce memory use, this function is type-unstable, which can affect
performance inside the function where the call is made. Therefore, use it with caution.
"""
function compress(A::CategoricalArray{T, N}) where {T, N}
    R = reftype(length(levels(A.pool)))
    convert(CategoricalArray{T, N, R}, A)
end

"""
    decompress(A::CategoricalArray)

Return a copy of categorical array `A` using the default reference type ($DefaultRefType).
If `A` is using a small reference type (such as `UInt8` or `UInt16`) the decompressed array
will have room for more levels.

To avoid the need to call decompress, ensure [`compress`](@ref) is not called when creating
the categorical array.
"""
decompress(A::CategoricalArray{T, N}) where {T, N} =
    convert(CategoricalArray{T, N, DefaultRefType}, A)

function vcat(A::CategoricalArray...)
    ordered = any(isordered, A) && all(a->isordered(a) || isempty(levels(a)), A)
    newlevels, ordered = mergelevels(ordered, map(levels, A)...)

    refsvec = map(A) do a
        ii = convert(Vector{Int}, indexin(levels(a.pool), newlevels))
        [x==0 ? 0 : ii[x] for x in a.refs]::Array{Int,ndims(a)}
    end

    T = cat_promote_eltype(A...) >: Missing ?
        Union{eltype(newlevels), Missing} : eltype(newlevels)
    refs = DefaultRefType[refsvec...;]
    pool = CategoricalPool(newlevels, ordered)
    CategoricalArray{T, ndims(refs)}(refs, pool)
end

@inline function getindex(A::CategoricalArray{T}, I...) where {T}
    @boundscheck checkbounds(A, I...)
    # Let Array indexing code handle everything
    @inbounds r = A.refs[I...]

    if isa(r, Array)
        res = CategoricalArray{T, ndims(r)}(r, copy(A.pool))
        return ordered!(res, isordered(A))
    else
        r > 0 || throw(UndefRefError())
        @inbounds res = A.pool[r]
        return res
    end
end

leveltype(::Type{T}) where {T <: CategoricalArray} = leveltype(nonmissingtype(eltype(T)))

"""
    levels(x::CategoricalArray)
    levels(x::CategoricalValue)

Return the levels of categorical array or value `x`.
This may include levels which do not actually appear in the data
(see [`droplevels!`](@ref)).
"""
DataAPI.levels(A::CategoricalArray) = levels(A.pool)

"""
    levels!(A::CategoricalArray, newlevels::Vector; allowmissing::Bool=false)

Set the levels categorical array `A`. The order of appearance of levels will be respected
by [`levels`](@ref DataAPI.levels), which may affect display of results in some operations; if `A` is
ordered (see [`isordered`](@ref)), it will also be used for order comparisons
using `<`, `>` and similar operators. Reordering levels will never affect the values
of entries in the array.

If `A` accepts missing values (i.e. `eltype(A) >: Missing`) and `allowmissing=true`,
entries corresponding to omitted levels will be set to `missing`.
Else, `newlevels` must include all levels which appear in the data.
"""
function levels!(A::CategoricalArray{T, N, R}, newlevels::Vector;
                 allowmissing::Bool=false,
                 allow_missing::Union{Bool, Nothing}=nothing) where {T, N, R}
    if allow_missing !== nothing
        Base.depwarn("allow_missing argument is deprecated, use allowmissing instead",
                     :levels!)
        allowmissing = allow_missing
    end
    if !allunique(newlevels)
        throw(ArgumentError(string("duplicated levels found: ",
                                   join(unique(filter(x->sum(==(x), newlevels)>1, newlevels)), ", "))))
    end

    oldlevels = levels(A.pool)

    # first pass to check whether, if some levels are removed, changes can be applied without error
    # TODO: save original levels and undo changes in case of error to skip this step
    # equivalent to issubset but faster due to JuliaLang/julia#24624
    if !isempty(setdiff(oldlevels, newlevels))
        deleted = [!(l in newlevels) for l in oldlevels]
        @inbounds for (i, x) in enumerate(A.refs)
            if T >: Missing
                !allowmissing && x > 0 && deleted[x] &&
                    throw(ArgumentError("cannot remove level $(repr(oldlevels[x])) as it " *
                                        "is used at position $i and allowmissing=false."))
            else
                x > 0 && deleted[x] &&
                    throw(ArgumentError("cannot remove level $(repr(oldlevels[x])) as it " *
                                        "is used at position $i. Change the array element " *
                                        "type to Union{$T, Missing} using convert if you want " *
                                        "to transform some levels to missing values."))
            end
        end
    end

    # replace the pool and recode refs to reflect new pool
    if newlevels != oldlevels
        newpool = CategoricalPool{nonmissingtype(T), R}(copy(newlevels), isordered(A.pool))
        update_refs!(A, newlevels)
        A.pool = newpool
    end

    A
end

# return unique refs (each value is unique) in the order of appearance in `refs`
# similar to fallback Base.unique() implementation,
# but short-circuits once references to all levels are encountered
function _uniquerefs(A::AbstractCategoricalArray{T}) where T
    arefs = refs(A)
    res = similar(arefs, 0)
    nlevels = length(levels(A))
    seen = fill(false, nlevels+1) # +1 for 0 (missing ref)
    maxunique = nlevels + (T >: Missing ? 1 : 0)
    @inbounds for ref in arefs
        if !seen[ref + 1]
            push!(res, ref)
            seen[ref + 1] = true
            (length(res) == maxunique) && break
        end
    end
    return res
end

"""
    uniquelevels(A::AbstractCategoricalArray)

Return levels which appear in `A` in their order of appearance.
This function is significantly slower than [`levels`](@ref DataAPI.levels)
since it needs to check whether levels are used or not.
"""
function uniquelevels(A::AbstractCategoricalArray{T}) where T
    alevs = levels(A)
    T[ref == 0 ? missing : @inbounds alevs[ref]
      for ref in _uniquerefs(A)]
end

unique(A::AbstractCategoricalArray{T}) where T =
    CategoricalVector{T}(_uniquerefs(A), copy(pool(A)))

function unique!(A::CategoricalVector{T}) where T
    _urefs = _uniquerefs(A)
    if length(_urefs) != length(A)
        resize!(A.refs, length(_urefs))
        copyto!(A.refs, _urefs)
    end
    return A
end

"""
    droplevels!(A::CategoricalArray)

Drop levels which do not appear in categorical array `A` (so that they will no longer be
returned by [`levels`](@ref DataAPI.levels)).
"""
droplevels!(A::CategoricalArray) = levels!(A, intersect(levels(A), uniquelevels(A)))

"""
    isordered(A::CategoricalArray)

Test whether entries in `A` can be compared using `<`, `>` and similar operators,
using the ordering of levels.
"""
isordered(A::CategoricalArray) = isordered(A.pool)

"""
    ordered!(A::CategoricalArray, ordered::Bool)

Set whether entries in `A` can be compared using `<`, `>` and similar operators,
using the ordering of levels. Return the modified `A`.
"""
ordered!(A::CategoricalArray, ordered) = (ordered!(A.pool, ordered); return A)

function Base.resize!(A::CategoricalVector, n::Integer)
    n_orig = length(A)
    resize!(A.refs, n)
    if n > n_orig
        A.refs[n_orig+1:end] .= 0
    end
    A
end

function Base.push!(A::CategoricalVector, v::Any)
    if v isa CategoricalValue && pool(v) !== pool(A) && pool(v) ⊈ pool(A)
        merge_pools!(A, v)
    end
    r = get!(A.pool, v)
    push!(A.refs, r)
    A
end

function Base.append!(A::CategoricalVector, B::CatArrOrSub)
    if pool(B) !== pool(A) && pool(B) ⊈ pool(A)
        merge_pools!(A, B)
    end
    # TODO: optimize recoding
    len = length(A)
    len2 = length(B)
    resize!(A.refs, len + len2)
    for i = 1:len2
        A[len + i] = B[i]
    end
    return A
end

Base.empty!(A::CategoricalVector) = (empty!(A.refs); return A)
Base.sizehint!(A::CategoricalVector, sz::Integer) = (sizehint!(A.refs, sz); return A)

function Base.reshape(A::CategoricalArray{T, N}, dims::Dims) where {T, N}
    x = reshape(A.refs, dims)
    res = CategoricalArray{T, ndims(x)}(x, A.pool)
    ordered!(res, isordered(res))
end

"""
    categorical(A::AbstractArray; levels=nothing, ordered=false, compress=false)

Construct a categorical array with the values from `A`.

The `levels` keyword argument can be a vector specifying possible values for the data
(this is equivalent to but more efficient than calling [`levels!`](@ref)
on the resulting array).
If `levels` is omitted and the element type supports it, levels are sorted
in ascending order; else, they are kept in their order of appearance in `A`.
The `ordered` keyword argument determines whether the array values can be compared
according to the ordering of levels or not (see [`isordered`](@ref)).

If `compress` is `true`, the smallest reference type able to hold the
number of unique values in `A` will be used. While this will reduce memory use, passing
this parameter will also introduce a type instability which can affect performance inside
the function where the call is made. Therefore, use this option with caution (the
one-argument version does not suffer from this problem).

    categorical(A::CategoricalArray; compress=false, levels=nothing, ordered=false)

If `A` is already a `CategoricalArray`, its levels, orderedness and reference type
are preserved unless explicitly overriden.
"""
@inline function categorical(A::AbstractArray{T, N};
                             levels::Union{AbstractVector, Nothing}=nothing,
                             ordered=_isordered(A),
                             compress::Bool=false) where {T, N}
    # @inline is needed so that return type is inferred when compress is not provided
    RefType = compress ? reftype(length(unique(A))) : DefaultRefType
    CategoricalArray{fixtype(A), N, RefType}(A, levels=levels, ordered=ordered)
end
@inline function categorical(A::CategoricalArray{T, N, R};
                             levels::Union{AbstractVector, Nothing}=nothing,
                             ordered=_isordered(A),
                             compress::Bool=false) where {T, N, R}
    # @inline is needed so that return type is inferred when compress is not provided
    RefType = compress ? reftype(length(CategoricalArrays.levels(A))) : R
    CategoricalArray{T, N, RefType}(A, levels=levels, ordered=ordered)
end

function in(x::Any, y::CategoricalArray{T, N, R}) where {T, N, R}
    ref = get(y.pool, x, zero(R))
    ref != 0 ? ref in y.refs : false
end

function in(x::CategoricalValue, y::CategoricalArray{T, N, R}) where {T, N, R}
    if x.pool === y.pool
        return refcode(x) in y.refs
    else
        ref = get(y.pool, levels(x.pool)[refcode(x)], zero(R))
        return ref != 0 ? ref in y.refs : false
    end
end

Array(A::CategoricalArray{T}) where {T} = Array{T}(A)
collect(A::CategoricalArray) = copy(A)

# Defined for performance
collect(x::Base.SkipMissing{<: CatArrOrSub{T}}) where {T} =
    CategoricalVector{nonmissingtype(T)}(filter(v -> v > 0, refs(x.x)), copy(pool(x.x)))

function float(A::CategoricalArray{T}) where T
    if !isconcretetype(T)
        error("`float` not defined on abstractly-typed arrays; please convert to a more specific type")
    end
    convert(AbstractArray{typeof(float(zero(T)))}, A)
end
function complex(A::CategoricalArray{T}) where T
    if !isconcretetype(T)
        error("`complex` not defined on abstractly-typed arrays; please convert to a more specific type")
    end
    convert(AbstractArray{typeof(complex(zero(T)))}, A)
end

# Override AbstractArray method to avoid printing useless type parameters
if VERSION >= v"0.7.0-DEV.2657"
    summary(io::IO, A::CategoricalArray{T, N, R}) where {T, N, R} =
        print(io, Base.dims2string(size(A)), " $CategoricalArray{$T,$N,$R}")
else
    summary(A::CategoricalArray{T, N, R}) where {T, N, R} =
        string(Base.dims2string(size(A)), " $CategoricalArray{$T,$N,$R}")
end

refs(A::CategoricalArray) = A.refs
pool(A::CategoricalArray) = A.pool

Base.deleteat!(A::CategoricalArray, inds) = (deleteat!(A.refs, inds); A)

Base.Broadcast.broadcasted(::typeof(ismissing), A::CategoricalArray{T}) where {T} =
    T >: Missing ? Base.Broadcast.broadcasted(==, A.refs, 0) :
                   Base.Broadcast.broadcasted(_ -> false, A.refs)

Base.Broadcast.broadcasted(::typeof(!ismissing), A::CategoricalArray{T}) where {T} =
    T >: Missing ? Base.Broadcast.broadcasted(>, A.refs, 0) :
                   Base.Broadcast.broadcasted(_ -> true, A.refs)

function Base.Broadcast.broadcasted(::typeof(levelcode), A::CategoricalArray{T}) where {T}
    if T >: Missing
        Base.Broadcast.broadcasted(r -> r > 0 ? Signed(widen(r)) : missing, A.refs)
    else
        Base.Broadcast.broadcasted(r -> Signed(widen(r)), A.refs)
    end
end

function Base.sort!(v::CategoricalVector;
                    # alg is ignored since counting sort is more efficient
                    alg::Base.Algorithm=Base.Sort.defalg(v),
                    lt=isless,
                    by=identity,
                    rev::Bool=false,
                    order::Base.Ordering=Base.Forward)
    counts = zeros(UInt, length(v.pool) + (eltype(v) >: Missing))

    # do a count/histogram of the references
    @inbounds for ref in v.refs
        counts[ref + (eltype(v) >: Missing)] += 1
    end

    # compute the order in which to read from counts
    ord = Base.Sort.ord(lt, by, rev, order)
    seen = counts .> 0
    anymissing = eltype(v) >: Missing && seen[1]
    levs = eltype(v) >: Missing ?
        eltype(v)[i == 0 ? missing : CategoricalValue(v.pool, i) for i in 0:length(v.pool)] :
        eltype(v)[CategoricalValue(v.pool, i) for i in 1:length(v.pool)]
    sortedlevs = sort!(Vector(view(levs, seen)), order=ord)
    levelsmap = something.(indexin(sortedlevs, levs))
    j = 0
    refs = v.refs
    @inbounds for i in eachindex(levelsmap)
        ref = levelsmap[i]
        tmpj = j + counts[ref]
        refs[(j+1):tmpj] .= ref - (eltype(v) >: Missing)
        j = tmpj
    end

    return v
end

Base.repeat(a::CatArrOrSub{T, N},
            counts::Integer...) where {T, N} =
    CategoricalArray{T, N}(repeat(refs(a), counts...), copy(pool(a)))

Base.repeat(a::CatArrOrSub{T, N};
            inner = nothing, outer = nothing) where {T, N} =
    CategoricalArray{T, N}(repeat(refs(a), inner=inner, outer=outer), copy(pool(a)))

# JSON3 writing/reading
StructTypes.StructType(::Type{<:CategoricalVector}) = StructTypes.ArrayType()

StructTypes.construct(::Type{<:CategoricalArray}, A::AbstractVector) =
    constructgeneral(A)
StructTypes.construct(::Type{<:CategoricalArray}, A::Vector) =
    constructgeneral(A)

function constructgeneral(A)
    if eltype(A) === Any
        # unlike `replace`, broadcast narrows the type, which allows us to return small
        # union eltypes (e.g. Union{String,Missing})
        categorical(ifelse.(A .=== nothing, missing, A))
    elseif eltype(A) >: Nothing
        categorical(replace(A, nothing=>missing))
    else
        categorical(A)
    end
end

StructTypes.construct(::Type{<:CategoricalArray{Union{Missing, T}}},
                      A::AbstractVector) where {T} =
    CategoricalArray{Union{Missing, T}}(replace(A, nothing=>missing))
StructTypes.construct(::Type{<:CategoricalArray{Union{Missing, T}}},
                      A::Vector) where {T} =
    CategoricalArray{Union{Missing, T}}(replace(A, nothing=>missing))

# DataAPI refarray/refvalue/refpool support
struct CategoricalRefPool{T, P} <: AbstractVector{T}
    pool::P
end

Base.IndexStyle(::Type{<: CategoricalRefPool}) = Base.IndexLinear()

@inline function Base.getindex(x::CategoricalRefPool, i::Int)
    @boundscheck checkbounds(x, i)
    i > 0 ? @inbounds(x.pool[i]) : missing
end

Base.size(x::CategoricalRefPool{T}) where {T} = (length(x.pool) + (T >: Missing),)
Base.axes(x::CategoricalRefPool{T}) where {T} =
    ((T >: Missing ? 0 : 1):length(x.pool),)
Base.LinearIndices(x::CategoricalRefPool) = axes(x, 1)

DataAPI.refarray(A::CatArrOrSub) = refs(A)
DataAPI.refpool(A::CatArrOrSub{T}) where {T} =
    CategoricalRefPool{eltype(A), typeof(pool(A))}(pool(A))
DataAPI.invrefpool(A::CatArrOrSub{T}) where {T} =
    CategoricalInvRefPool{eltype(A), typeof(pool(A).invindex)}(pool(A).invindex)

@inline function DataAPI.refvalue(A::CatArrOrSub{T}, i::Integer) where T
    @boundscheck checkindex(Bool, (T >: Missing ? 0 : 1):length(pool(A)), i) ||
        throw(BoundsError())
    i > 0 ? @inbounds(pool(A)[i]) : missing
end

struct CategoricalInvRefPool{T, P}
    invpool::P
end

@inline function Base.haskey(x::CategoricalInvRefPool{T}, v) where {T}
    if T >: Missing && ismissing(v)
        return true
    else
        return haskey(x.invpool, v)
    end
end

@inline function Base.getindex(x::CategoricalInvRefPool{T}, v) where {T}
    if T >: Missing && ismissing(v)
        return zero(valtype(x.invpool))
    else
        return x.invpool[v]
    end
end

@inline function Base.get(x::CategoricalInvRefPool{T}, v, default) where {T}
    if T >: Missing && ismissing(v)
        return zero(valtype(x.invpool))
    else
        return get(x.invpool, v, default)
    end
end
