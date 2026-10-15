# Render three gallery animations from the BoostRace race saved by sim.jl (runner states
# every 15 s), each over the course's elevation profile:
#   hist   runners per 50 m of road, stacked by start wave;
#   speed  each runner's speed against distance, coloured by start wave;
#   rho    distance-time map of the mean congestion weight rho over the runners in each
#          50 m bin, filled in as the race goes.
# rho is the notebook's R (cells 45 and 47): V = (1 - R) * free speed + R * mean speed of
# the slower runners ahead, with R = 0 when running freely and R in [minrho, maxrho] when crowded.
# The 50 m bins are a display choice: the notebook's own histogram uses 4 m bins
# (frontviewdistance), which are below one pixel at gallery size.

include(joinpath(@__DIR__, "model.jl"))   # notebook cells <= 51: course, parameters, NinWaves
using Serialization, Printf

const D = deserialize(joinpath(@__DIR__, "positions_every15s.jls"))
const P, V, R, dt = D.P, D.V, D.R, D.dt
const finish = parameters.racedistance

lastk = findlast(k -> any(view(P, :, k) .< finish), 1:size(P, 2))
lastk = min(size(P, 2), something(lastk, size(P, 2)) + 2)
println("frames: ", lastk, "  (t_end = ", (lastk - 1) * dt, " s)")

wavecolors = ["#0072B2", "#E69F00", "#009E73"]          # Okabe–Ito, as in render.jl
waveranges = let s = cumsum(NinWaves); [(i == 1 ? 1 : s[i-1] + 1):s[i] for i in eachindex(s)] end
wavelabels = ["wave $i" for i in eachindex(waveranges)]

const binw = 50.0
const edges = 0.0:binw:finish
const nb = length(edges) - 1
const xc = (collect(edges[1:end-1]) .+ binw / 2) ./ 1000      # bin centres, km
oncourse(x) = 0.0f0 <= x < finish
binof(x) = min(nb, floor(Int, x / binw) + 1)

# Per-wave counts per bin, and the mean of R per bin, for every frame.
counts = zeros(Int, nb, length(waveranges), lastk)
rhomap = fill(NaN, nb, lastk)
for k in 1:lastk
    s = zeros(nb); n = zeros(Int, nb)
    for (w, rng) in enumerate(waveranges), r in rng
        x = P[r, k]
        oncourse(x) || continue
        b = binof(x)
        counts[b, w, k] += 1
        s[b] += R[r, k]; n[b] += 1
    end
    for b in 1:nb
        n[b] > 0 && (rhomap[b, k] = s[b] / n[b])
    end
end
ymaxhist = maximum(sum(counts; dims = 2))
vmaxkmh = 3.6 * maximum(V[r, k] for k in 1:lastk for r in axes(P, 1) if oncourse(P[r, k]))
println("histogram peak: ", ymaxhist, " runners per 50 m;  top speed: ", round(vmaxkmh; digits = 1), " km/h")

xs = range(0.0, finish; length = 1000)
el = Float64.(course.cspline_elev(collect(xs)))
xkm = xs ./ 1000
hms(t) = @sprintf("%d:%02d:%02d", t ÷ 3600, (t % 3600) ÷ 60, t % 60)

gr()
default(fontfamily = "sans-serif", framestyle = :axes, grid = false, foreground_color_axis = "#9a958c",
        foreground_color_border = "#9a958c", tickfontcolor = "#5b6066", guidefontcolor = "#5b6066",
        tickfontsize = 18, guidefontsize = 20, titlefontsize = 24, legendfontsize = 18)

profile() = plot(xkm, el; fillrange = minimum(el) - 5, fillcolor = "#d9e6ea", linecolor = "#0d5b75", lw = 1.2,
                 label = false, xlims = (0, finish / 1000), ylims = (minimum(el) - 5, maximum(el) + 8),
                 xlabel = "distance (km)", ylabel = "elev. (m)", xticks = 0:2:10, yticks = [0, 40])
frame(top) = plot(top, profile(); layout = grid(2, 1; heights = [0.74, 0.26]), size = (960, 560),
                  left_margin = 10Plots.mm, bottom_margin = 10Plots.mm, right_margin = 4Plots.mm,
                  top_margin = 2Plots.mm, background_color = :white, dpi = 100)

function hist_top(k)
    c = cumsum(counts[:, :, k]; dims = 2)                # c[:, w] = waves 1..w stacked
    p = plot(; xlims = (0, finish / 1000), ylims = (0, 1.05 * ymaxhist), xticks = false,
             ylabel = "runners / 50 m", title = "t = " * hms(round(Int, (k - 1) * dt)),
             titlelocation = :left, legend = :topright, foreground_color_legend = nothing)
    for w in eachindex(waveranges)                       # wave w spans c[:, w-1] .. c[:, w]
        base = w == 1 ? zeros(Int, nb) : c[:, w-1]
        bar!(p, xc, c[:, w]; fillrange = base, bar_width = binw / 1000, linewidth = 0,
             color = wavecolors[w], label = wavelabels[w])
    end
    p
end

function speed_top(k)
    p = plot(; xlims = (0, finish / 1000), ylims = (0, ceil(vmaxkmh / 5) * 5), xticks = false,
             ylabel = "speed (km/h)", title = "t = " * hms(round(Int, (k - 1) * dt)),
             titlelocation = :left, legend = :topright, foreground_color_legend = nothing)
    for (w, rng) in enumerate(waveranges)
        idx = [r for r in rng if oncourse(P[r, k])]
        scatter!(p, isempty(idx) ? [NaN] : P[idx, k] ./ 1000, isempty(idx) ? [NaN] : 3.6 .* V[idx, k];
                 markersize = 1.8, markerstrokewidth = 0, markercolor = wavecolors[w], markeralpha = 0.6,
                 label = wavelabels[w])
    end
    p
end

const tmin = collect(0:lastk-1) .* (dt / 60)
function rho_top(k)
    M = fill(NaN, nb, lastk)
    M[:, 1:k] .= view(rhomap, :, 1:k)
    heatmap(xc, tmin, permutedims(M); c = :viridis, clims = (0, parameters.maxrho),
            xlims = (0, finish / 1000), ylims = (0, tmin[end]), xticks = false, ylabel = "time (min)",
            title = "t = " * hms(round(Int, (k - 1) * dt)) * "    mean ρ per 50 m", titlelocation = :left)
end

for (name, top) in (("hist", hist_top), ("speed", speed_top), ("rho", rho_top))
    dir = joinpath(@__DIR__, "views", name)
    mkpath(dir)
    for k in 1:lastk
        savefig(frame(top(k)), joinpath(dir, @sprintf("f%04d.png", k)))
        k % 100 == 0 && println(name, ": rendered ", k, "/", lastk)
    end
end
println("done")
