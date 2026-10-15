# Run the BoostRace race (notebook cells <= 51 define the model; see make.sh) and keep
# runner positions every 15 s for rendering. The training run (cell 53) is not needed.
include(joinpath(@__DIR__, "model.jl"))
using Serialization
t = @elapsed begin
    _, allrunners = race(true)
end
println(">Elapsed time=", t)
# Column k of allrunners.pos holds positions at time (k-1)*observertimestep (see rk2_solver);
# vels and rhos are stored on the same observer grid. render.jl uses P; views.jl also V and R.
const framestride = 15
P = allrunners.pos[:, 1:framestride:end]
V = allrunners.vels[:, 1:framestride:end]
R = allrunners.rhos[:, 1:framestride:end]
serialize(joinpath(@__DIR__, "positions_every15s.jls"),
          (P = P, V = V, R = R, dt = framestride * parameters.observertimestep, ninwaves = NinWaves))
println(">Saved ", size(P), " positions")
