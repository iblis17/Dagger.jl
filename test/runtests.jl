addprocs(2)

using Base.Test
using Dagger
using DagScheduler

@everywhere begin
function dcompute(ctx, d::Dagger.Thunk)
    if ctx.runenv === nothing
        ctx.runenv = DagScheduler.RunEnv()
    end
    DagScheduler.rundag(ctx.runenv, d)
end

Dagger._compute[] = dcompute
end

include("domain.jl")
include("array.jl")
include("cache.jl")
