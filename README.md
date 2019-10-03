# ConstructionBase

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaObjects.github.io/ConstructionBase.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaObjects.github.io/ConstructionBase.jl/dev)
[![Build Status](https://travis-ci.com/JuliaObjects/ConstructionBase.jl.svg?branch=master)](https://travis-ci.com/JuliaObjects/ConstructionBase.jl)
[![Codecov](https://codecov.io/gh/JuliaObjects/ConstructionBase.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaObjects/ConstructionBase.jl)
[![GitHub stars](https://img.shields.io/github/stars/JuliaObjects/ConstructionBase.jl?style=social)](https://github.com/JuliaObjects/ConstructionBase.jl)

ConstructionBase is a very lightwight package, that provides primitive functions for construction of objects:
```julia
setproperties(obj::MyType, patch::NamedTuple)
constructorof(MyType)
```
These functions can be overloaded and doing so provides interoperability with the following packages:
* [Flatten.jl](https://github.com/rafaqz/Flatten.jl)
* [Setfield.jl](https://github.com/jw3126/Setfield.jl)
* [BangBang.jl](https://github.com/tkf/BangBang.jl)
