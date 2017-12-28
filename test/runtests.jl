addprocs(2)

using Base.Test
using Dagger
using DagScheduler

@everywhere begin
_drunenv = nothing
function dcompute(ctx, d::Dagger.Thunk)
    global _drunenv
    if _drunenv === nothing
        _drunenv = DagScheduler.RunEnv(workers(), false)
    end
    DagScheduler.rundag(_drunenv, d)
end

Dagger._compute[] = dcompute
end

include("domain.jl")
include("array.jl")
#include("cache.jl")
