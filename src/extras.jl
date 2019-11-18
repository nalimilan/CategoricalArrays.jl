import StatsBase

function fill_refs!(refs::AbstractArray, X::AbstractArray,
                    breaks::AbstractVector, extend::Bool, allow_missing::Bool)
    n = length(breaks)
    lower = first(breaks)
    upper = last(breaks)

    @inbounds for i in eachindex(X)
        x = X[i]

        if extend && x == upper
            refs[i] = n-1
        elseif !extend && !(lower <= x < upper)
            throw(ArgumentError("value $x (at index $i) does not fall inside the breaks: adapt them manually, or pass extend=true"))
        else
            refs[i] = searchsortedlast(breaks, x)
        end
    end
end

function fill_refs!(refs::AbstractArray, X::AbstractArray{>: Missing},
                    breaks::AbstractVector, extend::Bool, allow_missing::Bool)
    n = length(breaks)
    lower = first(breaks)
    upper = last(breaks)

    @inbounds for i in eachindex(X)
        ismissing(X[i]) && continue

        x = X[i]

        if extend && x == upper
            refs[i] = n-1
        elseif !extend && !(lower <= x < upper)
            allow_missing || throw(ArgumentError("value $x (at index $i) does not fall inside the breaks: adapt them manually, or pass extend=true or allow_missing=true"))
            refs[i] = 0
        else
            refs[i] = searchsortedlast(breaks, x)
        end
    end
end

"""
    default_formatter(from, to, i; closed=false)
    
Provide the default label format for the `cut` function.
"""
default_formatter(from, to, i; closed) = string("[", from, ", ", to, closed ? "]" : ")")

@doc raw"""
    cut(x::AbstractArray, breaks::AbstractVector;
        labels::Union{AbstractVector{<:AbstractString},Function}, 
        extend::Bool=false, allow_missing::Bool=false)

Cut a numeric array into intervals and return an ordered `CategoricalArray` indicating
the interval into which each entry falls. Intervals are of the form `[lower, upper)`,
i.e. the lower bound is included and the upper bound is excluded.

If `x` accepts missing values (i.e. `eltype(x) >: Missing`) the returned array will
also accept them.

# Arguments
* `extend::Bool=false`: when `false`, an error is raised if some values in `x` fall
  outside of the breaks; when `true`, breaks are automatically added to include all
  values in `x`, and the upper bound is included in the last interval.
* `labels::Union{AbstractVector,Function}: a vector of strings giving the names to use for
  the intervals; or a function `f(from, to, i; closed)` that generates the labels from the
  left and right interval boundaries and the group index. Defaults to 
  `"[from, to)"` (or `"[from, to]"` for the rightmost interval if `extend == true`).
* `allow_missing::Bool=true`: when `true`, values outside of breaks result in missing values.
  only supported when `x` accepts missing values.
  
# Examples
```jldoctest
julia> cut(-1:0.5:1, [0, 1], extend=true)
5-element CategoricalArray{String,1,UInt32}:
 "[-1.0, 0.0)"
 "[-1.0, 0.0)"
 "[0.0, 1.0]" 
 "[0.0, 1.0]" 
 "[0.0, 1.0]" 

julia> cut(-1:0.5:1, 2)
5-element CategoricalArray{String,1,UInt32}:
 "[-1.0, 0.0)"
 "[-1.0, 0.0)"
 "[0.0, 1.0]" 
 "[0.0, 1.0]" 
 "[0.0, 1.0]" 

julia> cut(-1:0.5:1, 2, labels=["A", "B"])
5-element CategoricalArray{String,1,UInt32}:
 "A"
 "A"
 "B"
 "B"
 "B"

julia> fmt(from, to, i; closed) = "grp $i ($from//$to)"
fmt (generic function with 1 method)

julia> cut(-1:0.5:1, 3, labels=fmt)
5-element CategoricalArray{String,1,UInt32}:
 "grp 1 (-1.0//-0.333333)"    
 "grp 1 (-1.0//-0.333333)"    
 "grp 2 (-0.333333//0.333333)"
 "grp 3 (0.333333//1.0)"      
 "grp 3 (0.333333//1.0)"      
```
"""
function cut(x::AbstractArray{T, N}, breaks::AbstractVector;
             extend::Bool=false,
             labels::Union{AbstractVector{<:AbstractString},Function}=default_formatter,
             allow_missing::Bool=false) where {T, N}
    if !issorted(breaks)
        breaks = sort(breaks)
    end

    if extend
        min_x, max_x = extrema(x)
        if !ismissing(min_x) && breaks[1] > min_x
            breaks = [min_x; breaks]
        end
        if !ismissing(max_x) && breaks[end] < max_x
            breaks = [breaks; max_x]
        end
    end

    refs = Array{DefaultRefType, N}(undef, size(x))
    try
        fill_refs!(refs, x, breaks, extend, allow_missing)
    catch err
        # So that the error appears to come from cut() itself,
        # since it refers to its keyword arguments
        if isa(err, ArgumentError)
            throw(err)
        else
            rethrow(err)
        end
    end

    n = length(breaks)
    if labels isa Function
        @static if VERSION >= v"0.7.0-DEV.4524"
            from = map(x -> sprint(show, x, context=:compact=>true), breaks[1:n-1])
            to = map(x -> sprint(show, x, context=:compact=>true), breaks[2:n])
        else
            from = map(x -> sprint(showcompact, x), breaks[1:n-1])
            to = map(x -> sprint(showcompact, x), breaks[2:n])
        end
        levs = Vector{String}(undef, n-1)
        for i in 1:n-2
            levs[i] = labels(from[i], to[i], i, closed=false)
        end
        levs[end] = labels(from[end], to[end], n-1, closed=extend)
    else
        length(labels) == n-1 || throw(ArgumentError("labels must be of length $(n-1), but got length $(length(labels))"))
        # Levels must have element type String for type stability of the result
        levs::Vector{String} = copy(labels)
    end

    pool = CategoricalPool(levs, true)
    S = T >: Missing ? Union{String, Missing} : String
    CategoricalArray{S, N}(refs, pool)
end

"""
    cut(x::AbstractArray, [w::AbstractWeights, ]ngroups::Integer;
        labels::Union{AbstractVector{<:AbstractString},Function})

Cut a numeric array into `ngroups` quantiles, determined using
[`quantile`](@ref).
"""
cut(x::AbstractArray, ngroups::Integer;
    labels::Union{AbstractVector{<:AbstractString},Function}=default_formatter) =
    cut(x, Statistics.quantile(x, (1:ngroups-1)/ngroups); extend=true, labels=labels)
    
cut(x::AbstractArray, w::AbstractWeights, ngroups::Integer;
  labels::Union{AbstractVector{<:AbstractString},Function}=default_formatter) =
  cut(x, StatsBase.quantile(x, w, (1:ngroups-1)/ngroups); extend=true, labels=labels)