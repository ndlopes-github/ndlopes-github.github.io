#!/usr/bin/env julia
# Generate the publication lists in index.html from tools/pubs/pubs.toml:
#   <!-- pubs:begin --> ... <!-- pubs:end -->      grouped lists in the Publications section
#   <!-- review:begin --> ... <!-- review:end -->  papers under review in Work in progress
# Each entry gets topic tags (for the filters), a venue badge, and optional Abstract / BibTeX panels.
# The BibTeX is generated here from the curated fields, not fetched, so it matches the page.
#
# Usage: julia tools/pubs/build.jl        (standard library only)
using TOML, Unicode

const HERE = @__DIR__
const ROOT = normpath(joinpath(HERE, "..", ".."))
const SELF = "N. D. Lopes"
const TOPICS = ("waves", "coastal", "flows", "industry", "other")
const SECTIONS = [  # (key, heading, id of the heading)
    ("journal", "Journal articles", ""),
    ("book", "Book and book chapter", ""),
    ("proceedings", "Conference proceedings", ""),
    ("report", "Reports from industry problems", "reports"),
    ("thesis", "Theses", "theses"),
]

htmlesc(s) = replace(s, "&" => "&amp;", "<" => "&lt;", ">" => "&gt;")

# "H. B. de Oliveira" -> ("H. B.", "de Oliveira"): initials are the leading tokens ending in '.'
function splitname(a::AbstractString)
    toks = split(a)
    k = findlast(t -> endswith(t, "."), toks)
    (k === nothing || k == length(toks)) && error("cannot split author name \"$a\" into initials and surname")
    join(toks[1:k], " "), join(toks[k+1:end], " ")
end

author_html(a) = (s = replace(a, " " => "&nbsp;"); a == SELF ? "<span class=\"me\">$s</span>" : s)

# ---------------------------------------------------------------- BibTeX

bibname(a) = ((ini, sur) = splitname(a); "$sur, $ini")
fold(s) = filter(c -> isascii(c) && (isletter(c) || isdigit(c)), Unicode.normalize(s; stripmark = true))
texify(s) = replace(s, "—" => "---", "–" => "--", "&" => "\\&")

# Brace every word that carries a capital after its first character, or any capital at all
# after the first word, so bibliography styles do not lowercase names and acronyms.
function protect(title)
    words = split(title, ' ')
    for (i, w) in enumerate(words)
        caps = any(isuppercase, i == 1 ? chop(w; head = 1, tail = 0) : w)
        caps && (words[i] = "{$w}")
    end
    join(words, ' ')
end

const STOP = Set(split("a an the of on for and in to um uma o os as de do da dos das e com para"))
function bibkey(p)
    sur = fold(split(splitname(p["authors"][1])[2])[end])          # "de Oliveira" -> "Oliveira"
    words = filter(!isempty, fold.(lowercase.(split(p["title"], r"[\s:/\-–]+"))))
    w = something(findfirst(x -> !(x in STOP), words), 1)
    string(sur, get(p, "year", ""), words[w])
end

function bibtex(p)
    f = Pair{String,String}[]
    push!(f, "author" => join(bibname.(p["authors"]), " and "))
    push!(f, "title" => protect(p["title"]))
    haskey(p, "editor") && push!(f, "editor" => join(bibname.(p["editor"]), " and "))
    for k in ("journal", "booktitle", "series", "volume", "number", "pages", "edition",
              "publisher", "institution", "school", "address", "note")
        haskey(p, k) && push!(f, k => string(p[k]))
    end
    push!(f, "year" => string(p["year"]))
    haskey(p, "doi") && push!(f, "doi" => p["doi"])
    haskey(p, "url") && push!(f, "url" => p["url"])
    w = maximum(length(first(x)) for x in f)
    body = join(["  " * rpad(k, w) * " = {" * (k in ("doi", "url") ? v : texify(v)) * "}" for (k, v) in f], ",\n")
    "@$(p["bibtype"]){$(KEYS[p["id"]]),\n$body\n}"
end

# ---------------------------------------------------------------- HTML

function entry_html(p)
    id, topics = p["id"], p["topics"]
    yr = haskey(p, "year") ? "<span class=\"yr\">$(p["year"])</span>" : ""
    acts = String[]
    haskey(p, "abstract") && push!(acts, "<button type=\"button\" class=\"tog\" aria-expanded=\"false\" aria-controls=\"$id-abs\">Abstract</button>")
    hasbib = p["section"] != "review"
    hasbib && push!(acts, "<button type=\"button\" class=\"tog\" aria-expanded=\"false\" aria-controls=\"$id-bib\">BibTeX</button>")
    haskey(p, "doi") && push!(acts, "<a href=\"https://doi.org/$(p["doi"])\">DOI</a>")
    for l in get(p, "links", [])
        push!(acts, "<a href=\"$(l["url"])\">$(l["label"])</a>")
    end
    io = IOBuffer()
    println(io, "      <li class=\"pub\" id=\"$id\" data-topics=\"$(join(topics, ' '))\">")
    println(io, "        <div class=\"pub-meta\"><span class=\"vbadge t-$(topics[1])\">$(htmlesc(p["badge"]))</span>$yr</div>")
    println(io, "        <div class=\"cite\">")
    println(io, "          <span class=\"t\">$(htmlesc(p["title"]))</span>")
    println(io, "          <span class=\"au\">$(join(author_html.(p["authors"]), ", "))</span>")
    println(io, "          <span class=\"ve\">$(p["display"])</span>")
    isempty(acts) || println(io, "          <div class=\"actions\">$(join(acts))</div>")
    haskey(p, "abstract") && println(io, "          <div class=\"panel abs\" id=\"$id-abs\"><p>$(p["abstract"])</p></div>")
    hasbib && println(io, "          <div class=\"panel bib\" id=\"$id-bib\"><pre><code>$(htmlesc(bibtex(p)))</code></pre><button type=\"button\" class=\"copy\">Copy</button></div>")
    println(io, "        </div>")
    print(io, "      </li>")
    String(take!(io))
end

list_html(ps) = "    <ol class=\"pubs\">\n" * join(entry_html.(ps), "\n") * "\n    </ol>\n"

function splice(html, name, content)
    b, e = "<!-- $name:begin -->", "<!-- $name:end -->"
    i, j = findfirst(b, html), findfirst(e, html)
    (i === nothing || j === nothing) && error("index.html lacks the $name markers")
    html[1:last(i)] * "\n" * content * "  " * html[first(j):end]
end

# ---------------------------------------------------------------- checks and output

pubs = TOML.parsefile(joinpath(HERE, "pubs.toml"))["pub"]
ids = [p["id"] for p in pubs]

# BibTeX keys: Surname + year + first content word; a, b, ... appended when two entries collide.
const KEYS = Dict{String,String}()
let bib = filter(p -> p["section"] != "review", pubs), base = Dict(p["id"] => bibkey(p) for p in bib), seen = Dict{String,Int}()
    for p in bib
        k = base[p["id"]]
        dup = count(q -> base[q["id"]] == k, bib) > 1
        seen[k] = get(seen, k, 0) + 1
        KEYS[p["id"]] = dup ? k * string(Char(Int('a') + seen[k] - 1)) : k
    end
end
length(unique(ids)) == length(ids) || error("duplicate ids: ", [i for i in unique(ids) if count(==(i), ids) > 1])
for p in pubs
    for k in ("id", "section", "topics", "badge", "authors", "title", "display")
        haskey(p, k) || error("$(get(p, "id", "?")): missing field $k")
    end
    all(in(TOPICS), p["topics"]) || error("$(p["id"]): unknown topic in $(p["topics"])")
    p["section"] in (first.(SECTIONS)..., "review") || error("$(p["id"]): unknown section $(p["section"])")
    p["section"] == "review" || (haskey(p, "year") && haskey(p, "bibtype")) || error("$(p["id"]): needs year and bibtype")
    splitname.(p["authors"])
    SELF in p["authors"] || error("$(p["id"]): self-name \"$SELF\" not among the authors")
end

groups = IOBuffer()
for (key, heading, hid) in SECTIONS
    ps = filter(p -> p["section"] == key, pubs)
    isempty(ps) && continue
    idattr = isempty(hid) ? "" : " id=\"$hid\""
    print(groups, "  <div class=\"pubgroup\">\n    <h3 class=\"eyebrow\"$idattr>$heading</h3>\n", list_html(ps), "  </div>\n")
end
review = list_html(filter(p -> p["section"] == "review", pubs))

path = joinpath(ROOT, "index.html")
html = read(path, String)
html = splice(splice(html, "pubs", String(take!(groups))), "review", review)
write(path * ".tmp", html)
mv(path * ".tmp", path; force = true)
println("publications: ", count(p -> p["section"] != "review", pubs), " listed, ",
        count(p -> p["section"] == "review", pubs), " under review, ",
        count(p -> haskey(p, "abstract"), pubs), " with abstracts")
