using Documenter, ConstructionBase

makedocs(;
    modules=[ConstructionBase],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/jw3126/ConstructionBase.jl/blob/{commit}{path}#L{line}",
    sitename="ConstructionBase.jl",
    authors="["Takafumi Arakaki", "Rafael Schouten", "Jan Weidner"]",
    assets=String[],
)

deploydocs(;
    repo="github.com/jw3126/ConstructionBase.jl",
)
