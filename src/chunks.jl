
using MemPool

export chunk, collect

export domain, UnitDomain, project, alignfirst, ArrayDomain

import Base: isempty, getindex, intersect,
             ==, size, length, ndims

"""
    domain(x::T)

Returns metadata about `x`. This metadata will be in the `domain`
field of a Chunk object when an object of type `T` is created as
the result of evaluating a Thunk.
"""
function domain end

"""
Default domain -- has no information about the value
"""
struct UnitDomain end

"""
If no `domain` method is defined on an object, then
we use the `UnitDomain` on it. A `UnitDomain` is indivisible.
"""
domain(x::Any) = UnitDomain()

###### Chunk ######

"""
A chunk with some data
"""
mutable struct Chunk{T, H}
    chunktype::Type{T}
    domain
    handle::H
    persist::Bool
end

domain(c::Chunk) = c.domain
chunktype(c::Chunk) = c.chunktype
persist!(t::Chunk) = (t.persist=true; t)
shouldpersist(p::Chunk) = t.persist
affinity(c::Chunk) = affinity(c.handle)

function unrelease(c::Chunk{T,DRef}) where T
    # set spilltodisk = true if data is still around
    try
        destroyonevict(c.handle, false)
        return Nullable{Any}(c)
    catch err
        if isa(err, KeyError)
            return Nullable{Any}()
        else
            rethrow(err)
        end
    end
end
unrelease(c::Chunk) = c

function collect(ctx::Context, chunk::Chunk)
    # delegate fetching to handle by default.
    collect(ctx, chunk.handle)
end


### ChunkIO
function collect(ctx::Context, ref::Union{DRef, FileRef})
    poolget(ref)
end
affinity(r::DRef) = [OSProc(r.owner) => r.size]
function affinity(r::FileRef)
    if haskey(MemPool.who_has_read, r.file)
        return map(MemPool.who_has_read[r.file]) do dref
            OSProc(dref.owner) => r.size
        end
    else
        return []
    end
end

"""
Create a chunk from a sequential object.
"""
function tochunk(x; persist=false, cache=false)
    ref = poolset(x, destroyonevict=persist ? false : cache)
    Chunk(typeof(x), domain(x), ref, persist)
end
tochunk(x::Union{Chunk, Thunk}) = x

# Check to see if the node is set to persist
# if it is foce can override it
function free!(s::Chunk{X, DRef}; force=true, cache=false) where X
    if force || !s.persist
        if cache
            try
                destroyonevict(s.handle, true) # keep around, but remove when evicted
            catch err
                isa(err, KeyError) || rethrow(err)
            end
        else
            pooldelete(s.handle) # remove immediately
        end
    end
end
free!(x; force=true,cache=false) = x # catch-all for non-chunks
free!(x::DRef) = pooldelete(x)

function savechunk(data, dir, f)
    sz = open(joinpath(dir, f), "w") do io
        serialize(io, MemPool.MMWrap(data))
        return position(io)
    end
    Chunk(typeof(data), domain(data), FileRef(f, sz), true)
end


const refcount = Dict{MemPool.DRef, Int}()

function addrefcount(r::DRef, x)
    refcount[r] = getrefcount(r)+x
end

function getrefcount(r::DRef)
    if haskey(refcount, r)
        return refcount[r]
    else
        0
    end
end

Base.@deprecate_binding AbstractPart Union{Chunk, Thunk}
Base.@deprecate_binding Part Chunk
Base.@deprecate parts(args...) chunks(args...)
Base.@deprecate part(args...) tochunk(args...)
Base.@deprecate parttype(args...) chunktype(args...)
