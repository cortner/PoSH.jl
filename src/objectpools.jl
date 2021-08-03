

module ObjectPools

# This is inspired by 
#      https://github.com/tpapp/ObjectPools.jl
# but considerably simplified and now evolved 

export acquire!, release!
export VectorPool, MatrixPool, ArrayPool, StaticVectorPool


# TODO: 
# * General ObjectPool 
# * convert to more general ArrayPool 
# * Consider allowing the most common "derived" types and enabling 
#   those via dispatch; e.g. Duals? Complex? All possible Floats? ....

struct VectorPool{T}
    arrays::Vector{Vector{T}}

    VectorPool{T}() where {T} = new( Vector{T}[ ] )
end

const StaticVectorPool = VectorPool


acquire!(pool::VectorPool{T}, sz::Union{Integer, Tuple}, ::Type{T}) where {T} = 
        acquire!(pool, sz)


function acquire!(pool::VectorPool{T}, len::Integer) where {T}
    if length(pool.arrays) > 0     
        x = pop!(pool.arrays)
        if len > length(x) 
            resize!(x, len)
        end 
        return x 
    else
        return Vector{T}(undef, len)
    end
end

function release!(pool::VectorPool{T}, x::Vector{T}) where {T}
    push!(pool.arrays, x)
    return nothing 
end

# Vector -> Array  -> Vector 

function acquire!(pool::VectorPool{T}, sz::NTuple{N}) where {T, N}
    len = prod(sz)::Integer
    if length(pool.arrays) > 0     
        x = pop!(pool.arrays)
        if len != length(x)
            resize!(x, len)
        end 
        return reshape(x, sz)
    else
        return Array{T, N}(undef, sz)
    end
end

release!(pool::VectorPool{T}, x::Array{T}) where {T} = 
        release!(pool, reshape(x, :))

# fallbacks 

acquire!(pool::VectorPool{T}, sz::Union{Integer, Tuple}, S::Type{T1}) where {T, T1} = 
        Vector{S}(undef, len)

release!(pool::VectorPool{T}, x::AbstractVector) where {T} = 
    nothing 


end # module

