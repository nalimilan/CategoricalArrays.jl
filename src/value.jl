# union of all categorical value types
const CatValue{R} = Union{CategoricalValue{T, R} where T,
                          CategoricalString{R}}

# checks whether the type is categorical value
iscatvalue(::Type) = false
iscatvalue(::Type{Union{}}) = false # prevent incorrect dispatch to Type{<:CatValue} method
iscatvalue(::Type{<:CatValue}) = true
iscatvalue(x::Any) = iscatvalue(typeof(x))

leveltype(::Type{<:CategoricalValue{T}}) where {T} = T
leveltype(::Type{<:CategoricalString}) = String
leveltype(::Type) = throw(ArgumentError("Not a categorical value type"))
leveltype(x::Any) = leveltype(typeof(x))

# integer type of category reference codes used by categorical value
reftype(::Type{<:CatValue{R}}) where {R} = R
reftype(x::Any) = reftype(typeof(x))

pool(x::CatValue) = x.pool
level(x::CatValue) = x.level

# extract the type of the original value from array eltype `T`
unwrap_catvaluetype(::Type{T}) where {T} = T
unwrap_catvaluetype(::Type{T}) where {T >: Missing} =
    Union{unwrap_catvaluetype(Missings.T(T)), Missing}
unwrap_catvaluetype(::Type{Union{}}) = Union{} # prevent incorrect dispatch to T<:CatValue method
unwrap_catvaluetype(::Type{Any}) = Any # prevent recursion in T>:Missing method
unwrap_catvaluetype(::Type{T}) where {T <: CatValue} = leveltype(T)

# get the categorical value type given value type `T` and reference type `R`
catvaluetype(::Type{T}, ::Type{R}) where {T >: Missing, R} =
    catvaluetype(Missings.T(T), R)
catvaluetype(::Type{T}, ::Type{R}) where {T <: CatValue, R} =
    catvaluetype(leveltype(T), R)
catvaluetype(::Type{Any}, ::Type{R}) where {R} =
    CategoricalValue{Any, R}  # prevent recursion in T>:Missing method
catvaluetype(::Type{T}, ::Type{R}) where {T, R} =
    CategoricalValue{T, R}
catvaluetype(::Type{<:AbstractString}, ::Type{R}) where {R} =
    CategoricalString{R}
# to prevent incorrect dispatch to T<:CatValue method
catvaluetype(::Type{Union{}}, ::Type{R}) where {R} = CategoricalValue{Union{}, R}

# get the categorical value type given value type `T`
catvaluetype(::Type{T}) where {T >: Missing} = catvaluetype(Missings.T(T))
catvaluetype(::Type{T}) where {T <: CatValue} = catvaluetype(leveltype(T))
catvaluetype(::Type{Any}) = CategoricalValue{Any}  # prevent recursion in T>:Missing method
catvaluetype(::Type{T}) where {T} = CategoricalValue{T}
catvaluetype(::Type{<:AbstractString}) = CategoricalString
# to prevent incorrect dispatch to T<:CatValue method
catvaluetype(::Type{Union{}}) where {R} = CategoricalValue{Union{}}

Base.get(x::CatValue) = index(pool(x))[level(x)]
order(x::CatValue) = order(pool(x))[level(x)]

# creates categorical value for `level` from the `pool`
# The result is of type `C` that has "categorical value" trait
catvalue(level::Integer, pool::CategoricalPool{T, R, C}) where {T, R, C} =
    C(convert(R, level), pool)

Base.promote_rule(::Type{C}, ::Type{T}) where {C <: CatValue, T} = promote_type(leveltype(C), T)
Base.promote_rule(::Type{C1}, ::Type{Union{C2, Missing}}) where {C1 <: CatValue, C2 <: CatValue} =
    Union{promote_type(C1, C2), Missing}
# To fix ambiguities with definitions from Base
Base.promote_rule(::Type{C}, ::Type{Missing}) where {C <: CatValue} = Union{C, Missing}
Base.promote_rule(::Type{C}, ::Type{Any}) where {C <: CatValue} = Any

Base.promote_rule(::Type{CategoricalValue{S, R1}},
                  ::Type{CategoricalValue{T, R2}}) where {S, T, R1<:Integer, R2<:Integer} =
    CategoricalValue{promote_type(S, T), promote_type(R1, R2)}
Base.promote_rule(::Type{CategoricalString{R1}},
                  ::Type{CategoricalString{R2}}) where {R1<:Integer, R2<:Integer} =
    CategoricalString{promote_type(R1, R2)}
Base.promote_rule(::Type{C1}, ::Type{C2}) where
    {R1<:Integer, R2<:Integer, C1<:CatValue{R1}, C2<:CatValue{R2}} =
    catvaluetype(promote_type(leveltype(C1), leveltype(C2)), promote_type(R1, R2))
Base.promote_rule(::Type{C1}, ::Type{C2}) where {C1<:CatValue, C2<:CatValue} =
    catvaluetype(promote_type(leveltype(C1), leveltype(C2)))

Base.convert(::Type{Ref}, x::CatValue) = RefValue{leveltype(x)}(x)
Base.convert(::Type{String}, x::CatValue) = convert(String, get(x))

# Defined separately to avoid ambiguities
Base.convert(::Type{AbstractString}, x::CategoricalString) = x
Base.convert(::Type{T}, x::T) where {T <: CatValue} = x
Base.convert(::Type{Union{T, Missing}}, x::T) where {T <: CatValue} = x
Base.convert(::Type{Union{T, Nothing}}, x::T) where {T <: CatValue} = x

@static if isdefined(Base, :unwrap)
    Base.unwrap(x::CatValue) = get(x)
else
# General fallbacks
    Base.convert(::Type{Any}, x::CatValue) = x
    Base.convert(::Type{S}, x::T) where {S, T <: CatValue} =
        T <: S ? x : convert(S, get(x))
    Base.convert(::Type{Union{S, Missing}}, x::T) where {S, T <: CatValue} =
        T <: S ? x : convert(S, get(x))
    Base.convert(::Type{Union{S, Nothing}}, x::T) where {S, T <: CatValue} =
        T <: S ? x : convert(S, get(x))
end

(::Type{T})(x::T) where {T <: CatValue} = x

Base.Broadcast.broadcastable(x::CatValue) = Ref(x)

function Base.show(io::IO, x::CatValue)
    if Missings.T(get(io, :typeinfo, Any)) === Missings.T(typeof(x))
        print(io, repr(x))
    elseif isordered(pool(x))
        @printf(io, "%s %s (%i/%i)",
                typeof(x), repr(x),
                order(x), length(pool(x)))
    else
        @printf(io, "%s %s", typeof(x), repr(x))
    end
end

Base.print(io::IO, x::CatValue) = print(io, get(x))
Base.repr(x::CatValue) = repr(get(x))

@inline function Base.:(==)(x::CatValue, y::CatValue)
    if pool(x) === pool(y)
        return level(x) == level(y)
    else
        return get(x) == get(y)
    end
end

Base.:(==)(::CatValue, ::Missing) = missing
Base.:(==)(::Missing, ::CatValue) = missing

# To fix ambiguities with Base
Base.:(==)(x::CatValue, y::WeakRef) = get(x) == y
Base.:(==)(x::WeakRef, y::CatValue) = y == x

Base.:(==)(x::CatValue, y::AbstractString) = get(x) == y
Base.:(==)(x::AbstractString, y::CatValue) = y == x

Base.:(==)(x::CatValue, y::Any) = get(x) == y
Base.:(==)(x::Any, y::CatValue) = y == x

@inline function Base.isequal(x::CatValue, y::CatValue)
    if pool(x) === pool(y)
        return level(x) == level(y)
    else
        return isequal(get(x), get(y))
    end
end

Base.isequal(x::CatValue, y::Any) = isequal(get(x), y)
Base.isequal(x::Any, y::CatValue) = isequal(y, x)

Base.isequal(::CatValue, ::Missing) = false
Base.isequal(::Missing, ::CatValue) = false

Base.in(x::CatValue, y::AbstractRange{T}) where {T<:Integer} = get(x) in y

Base.hash(x::CatValue, h::UInt) = hash(get(x), h)

# Method defined even on unordered values so that sort() works
function Base.isless(x::CatValue, y::CatValue)
    if pool(x) !== pool(y)
        throw(ArgumentError("CategoricalValue objects with different pools cannot be tested for order"))
    else
        return order(x) < order(y)
    end
end

Base.isless(x::CatValue, y) = order(x) < order(x.pool[get(x.pool, y)])
Base.isless(x::CatValue, y::AbstractString) = order(x) < order(x.pool[get(x.pool, y)])
Base.isless(::CatValue, ::Missing) = true
Base.isless(y, x::CatValue) = order(x.pool[get(x.pool, y)]) < order(x)
Base.isless(y::AbstractString, x::CatValue) = order(x.pool[get(x.pool, y)]) < order(x)
Base.isless(::Missing, ::CatValue) = false

function Base.:<(x::CatValue, y::CatValue)
    if pool(x) !== pool(y)
        throw(ArgumentError("CategoricalValue objects with different pools cannot be tested for order"))
    elseif !isordered(pool(x)) # !isordered(pool(y)) is implied by pool(x) === pool(y)
        throw(ArgumentError("Unordered CategoricalValue objects cannot be tested for order using <. Use isless instead, or call the ordered! function on the parent array to change this"))
    else
        return order(x) < order(y)
    end
end

function Base.:<(x::CatValue, y)
    if !isordered(pool(x))
        throw(ArgumentError("Unordered CategoricalValue objects cannot be tested for order using <. Use isless instead, or call the ordered! function on the parent array to change this"))
    else
        return order(x) < order(x.pool[get(x.pool, y)])
    end
end

Base.:<(x::CatValue, y::AbstractString) = invoke(<, Tuple{CatValue, Any}, x, y)
Base.:<(::CatValue, ::Missing) = missing

function Base.:<(y, x::CatValue)
    if !isordered(pool(x))
        throw(ArgumentError("Unordered CategoricalValue objects cannot be tested for order using <. Use isless instead, or call the ordered! function on the parent array to change this"))
    else
        return order(x.pool[get(x.pool, y)]) < order(x)
    end
end

Base.:<(y::AbstractString, x::CatValue) = invoke(<, Tuple{Any, CatValue}, y, x)
Base.:<(::Missing, ::CatValue) = missing

# JSON of CatValue is JSON of the value it refers to
JSON.lower(x::CatValue) = JSON.lower(get(x))
DataAPI.defaultarray(::Type{CategoricalString{R}}, N) where {R} =
  CategoricalArray{String, N, R}
DataAPI.defaultarray(::Type{Union{CategoricalString{R}, Missing}}, N) where {R} =
  CategoricalArray{Union{String, Missing}, N, R}
DataAPI.defaultarray(::Type{CategoricalValue{T, R}}, N) where {T, R} =
  CategoricalArray{T, N, R}
DataAPI.defaultarray(::Type{Union{CategoricalValue{T, R}, Missing}}, N) where {T, R} =
  CategoricalArray{Union{T, Missing}, N, R}

# AbstractString interface for CategoricalString
Base.string(x::CategoricalString) = get(x)
Base.eltype(x::CategoricalString) = Char
Base.length(x::CategoricalString) = length(get(x))
Compat.lastindex(x::CategoricalString) = lastindex(get(x))
Base.sizeof(x::CategoricalString) = sizeof(get(x))
Base.nextind(x::CategoricalString, i::Int) = nextind(get(x), i)
Base.prevind(x::CategoricalString, i::Int) = prevind(get(x), i)
if VERSION > v"0.7.0-DEV.5126"
    Base.iterate(x::CategoricalString) = iterate(get(x))
    Base.iterate(x::CategoricalString, i::Int) = iterate(get(x), i)
else
    Base.next(x::CategoricalString, i::Int) = next(get(x), i)
end
Base.getindex(x::CategoricalString, i::Int) = getindex(get(x), i)
Base.codeunit(x::CategoricalString, i::Integer) = codeunit(get(x), i)
Base.ascii(x::CategoricalString) = ascii(get(x))
Base.isvalid(x::CategoricalString) = isvalid(get(x))
Base.isvalid(x::CategoricalString, i::Integer) = isvalid(get(x), i)
Base.match(r::Regex, s::CategoricalString,
           idx::Integer=firstindex(s), add_opts::UInt32=UInt32(0)) =
    match(r, get(s), idx, add_opts)
if VERSION > v"0.7.0-DEV.3526"
else
    Base.matchall(r::Regex, s::CategoricalString; overlap::Bool=false) =
        matchall(r, get(s), overlap)
    Base.matchall(r::Regex, s::CategoricalString, overlap::Bool) =
        matchall(r, get(s), overlap)
end
Base.collect(x::CategoricalString) = collect(get(x))
Base.reverse(x::CategoricalString) = reverse(get(x))
Compat.ncodeunits(x::CategoricalString) = ncodeunits(get(x))
