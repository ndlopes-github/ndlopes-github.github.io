# Render website animation frames from the BoostRace race simulation.
# The model is 1-D (position along the course). The lateral position of each
# runner inside the road band is cosmetic: a fixed U(0,1) fraction of the local
# road width, drawn once per runner so dots do not flicker between frames.

include(joinpath(@__DIR__, "model.jl"))   # notebook cells <= 51: course, parameters, NinWaves
using Serialization, Printf, Random

const D = deserialize(joinpath(@__DIR__, "positions_every15s.jls"))
const P = D.P                 # nrunners x nframes, column k <-> t = (k-1)*D.dt seconds
const dt = D.dt
const finish = parameters.racedistance

# Last frame: everyone has crossed the line, plus two frames of slack.
lastk = findlast(k -> any(view(P, :, k) .< finish), 1:size(P, 2))
lastk = min(size(P, 2), something(lastk, size(P, 2)) + 2)
println("frames: ", lastk, "  (t_end = ", (lastk - 1) * dt, " s)")

const lateral = rand(Xoshiro(7), Float32, nrunners)   # display-only lateral fraction

wavecolors = ["#0072B2", "#E69F00", "#009E73"]          # Okabe–Ito
waveranges = let s = cumsum(NinWaves); [(i == 1 ? 1 : s[i-1] + 1):s[i] for i in eachindex(s)] end

xs = range(-250.0, 10150.0; length = 1200)
w  = Float64.(course.cspline_width(collect(xs)))
el = Float64.(course.cspline_elev(collect(xs)))
xkm = xs ./ 1000

hms(t) = @sprintf("%d:%02d:%02d", t ÷ 3600, (t % 3600) ÷ 60, t % 60)

gr()
default(fontfamily = "sans-serif", framestyle = :axes, grid = false, foreground_color_axis = "#9a958c",
        foreground_color_border = "#9a958c", tickfontcolor = "#5b6066", guidefontcolor = "#5b6066")

framesdir = joinpath(@__DIR__, "frames")
mkpath(framesdir)

ks = isempty(get(ENV, "ONLY", "")) ? (1:lastk) : parse.(Int, split(ENV["ONLY"], ","))
for k in ks
    t = round(Int, (k - 1) * dt)
    X = view(P, :, k)

    road = plot(xkm, w ./ 2; fillrange = -w ./ 2, fillcolor = "#ece9e2", linecolor = "#b7b2a8", lw = 0.8,
                label = false, xlims = (xkm[1], xkm[end]), ylims = (-8.6, 12.2), yticks = false,
                xticks = false, xaxis = false, yaxis = false)
    plot!(road, xkm, -w ./ 2; linecolor = "#b7b2a8", lw = 0.8, label = false)
    vline!(road, [0.0, finish / 1000]; linecolor = "#5b6066", lw = 0.8, ls = :dash, label = false)

    for (c, rng) in zip(wavecolors, waveranges)
        idx = [r for r in rng if X[r] <= finish]
        isempty(idx) && continue
        xr = X[idx]
        yr = (lateral[idx] .- 0.5f0) .* Float32.(course.cspline_width(Float64.(xr)))
        scatter!(road, xr ./ 1000, yr; markersize = 2.4, markerstrokewidth = 0, markercolor = c,
                 markeralpha = 0.85, label = false)
    end
    annotate!(road, xkm[1] + 0.05, 10.6, text("t = " * hms(t), 30, "#1b1c1e", :left))
    annotate!(road, 5.2, 10.6, text("wave 1", 22, wavecolors[1], :left))
    annotate!(road, 6.85, 10.6, text("wave 2", 22, wavecolors[2], :left))
    annotate!(road, 8.5, 10.6, text("wave 3", 22, wavecolors[3], :left))

    prof = plot(xkm, el; fillrange = minimum(el) - 5, fillcolor = "#d9e6ea", linecolor = "#0d5b75", lw = 1.2,
                label = false, xlims = (xkm[1], xkm[end]), ylims = (minimum(el) - 5, maximum(el) + 8),
                xlabel = "distance (km)", ylabel = "elev. (m)", xticks = 0:2:10, guidefontsize = 20,
                tickfontsize = 19, yticks = [0, 40])

    p = plot(road, prof; layout = grid(2, 1; heights = [0.70, 0.30]), size = (1000, 500),
             left_margin = 8Plots.mm, bottom_margin = 9Plots.mm, right_margin = 3Plots.mm, background_color = :white, dpi = 100)
    savefig(p, joinpath(framesdir, @sprintf("f%04d.png", k)))
    k % 50 == 0 && println("rendered ", k, "/", lastk)
end
println("done")
