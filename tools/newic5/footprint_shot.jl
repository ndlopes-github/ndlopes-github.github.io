# footprint_shot.jl — capture the map of the NewIC5 Footprint page for the Work in progress images.
#
# Drives headless Firefox over WebDriver BiDi; a port of the relevant part of NewIC5's
# scripts/paper/make_screenshots.mjs (Node is not installed on this machine). Nothing is computed
# or written by the page, and no button that starts a job is pressed. For the capture only, the map
# is pinned to the viewport at MAPW×MAPH px (default 1250×1000), its zoom and layer buttons are
# hidden, and it is fitted to Iberia ([35.9, -9.6]–[43.9, 3.4]); the colours are the page's own
# (fixed fill opacity 0.6 over OpenStreetMap).
#
# Needs:
#   1. the NewIC5 web server, with the project loaded:
#        julia --project=@. scripts/frontend_modular.jl 7790
#        curl "http://127.0.0.1:7790/api/load_project?dir=Proj_benchmark_60&file=benchmark_60.toml"
#   2. Firefox with BiDi (a snap: the profile must be under ~/snap/firefox/common/):
#        firefox --headless --no-remote --profile ~/snap/firefox/common/bidi --remote-debugging-port 9222
#   3. a Julia environment with HTTP and JSON3:
#        julia --project=<env> footprint_shot.jl <outdir> <corridors file regex> <species> <colormap> [W H]
#
# Fixed sleeps wait for the page's asynchronous loads: check the images.
using HTTP, JSON3, Base64

const OUT, FILE_RE, SPECIES, CMAP = ARGS[1], ARGS[2], ARGS[3], ARGS[4]
const W = length(ARGS) >= 5 ? parse(Int, ARGS[5]) : 1500
const H = length(ARGS) >= 6 ? parse(Int, ARGS[6]) : 950
const BASE = "http://127.0.0.1:7790"

HTTP.WebSockets.open("ws://127.0.0.1:9222/session") do ws
    nextid = Ref(0)
    function send(method, params = Dict())
        i = (nextid[] += 1)
        HTTP.WebSockets.send(ws, JSON3.write(Dict("id" => i, "method" => method, "params" => params)))
        while true                                   # skip events; return the reply with our id
            m = JSON3.read(String(HTTP.WebSockets.receive(ws)))
            haskey(m, :id) && m[:id] == i && return m
        end
    end
    send("session.new", Dict("capabilities" => Dict()))
    try
        ctx = send("browsingContext.getTree")[:result][:contexts][1][:context]
        ev(x) = begin
            r = send("script.evaluate", Dict("expression" => x, "target" => Dict("context" => ctx), "awaitPromise" => true))
            get(r[:result], :type, "") == "exception" && println("EVAL ERROR ", r[:result][:exceptionDetails][:text])
            v = get(r[:result], :result, nothing)
            v === nothing ? nothing : get(v, :value, nothing)
        end
        send("browsingContext.setViewport", Dict("context" => ctx, "viewport" => Dict("width" => W, "height" => H)))
        send("browsingContext.navigate", Dict("context" => ctx, "url" => "about:blank", "wait" => "complete"))
        send("browsingContext.navigate", Dict("context" => ctx, "url" => BASE * "/footprint", "wait" => "complete"))
        sleep(6)
        choose(sel, pattern) = ev("""(() => { const s = document.getElementById($(JSON3.write(sel))); if (!s) return 'no select';
            const o = Array.from(s.options).find(o => new RegExp($(JSON3.write(pattern))).test(o.value));
            if (!o) return 'no option: ' + Array.from(s.options).map(o => o.value).slice(0, 8).join(' | ');
            s.value = o.value; s.dispatchEvent(new Event('change', { bubbles: true })); return o.value; })()""")
        println("file: ", choose("corridors_csv_select", FILE_RE)); sleep(12)
        println("species: ", choose("species_select", "^" * SPECIES * "\$")); sleep(12)
        println("colormap: ", choose("colormap_select", "^" * CMAP * "\$")); sleep(5)
        rect(q) = ev("""(() => { const e = document.querySelector($(JSON3.write(q))); if (!e) return null;
            const r = e.getBoundingClientRect(); return JSON.stringify([r.x + scrollX, r.y + scrollY, r.width, r.height]); })()""")
        MW = parse(Int, get(ENV, "MAPW", "1250")); MH = parse(Int, get(ENV, "MAPH", "1000"))
        println("resize: ", ev("""(() => { const m = document.getElementById("map"); m.style.position = "fixed"; m.style.left = "0px"; m.style.top = "0px"; m.style.zIndex = "9999"; m.style.borderRadius = "0"; m.style.width = "$(MW)px"; m.style.maxWidth = "none"; m.style.height = "$(MH)px";
            document.querySelectorAll(".leaflet-control-zoom,.leaflet-control-layers").forEach(e => e.style.display = "none"); map.invalidateSize(); map.fitBounds([[35.9, -9.6], [43.9, 3.4]]); return map.getZoom(); })()"""))
        sleep(15)
        b = JSON3.read(rect("#map"))
        println("map rect: ", b)
        r = send("browsingContext.captureScreenshot", Dict("context" => ctx, "origin" => "viewport",
            "clip" => Dict("type" => "box", "x" => b[1], "y" => b[2], "width" => b[3], "height" => b[4])))
        name = joinpath(OUT, "fp_sp$(SPECIES)_$(CMAP).png")
        write(name, base64decode(String(r[:result][:data])))
        println("wrote ", name)
    finally
        send("session.end")
    end
end
