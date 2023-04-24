
# Anonymous functions have no `new` constructor. Here we generate
# one for them based on the types of args passed to FunctionConstructor

struct FunctionConstructor{F} end
_isgensym(s::Symbol) = occursin("#", string(s))

@generated function (fc::FunctionConstructor{F})(args...) where F
    T = getfield(parentmodule(F), nameof(F))
    # We assume all gensym names are anonymous functions
    _isgensym(nameof(F)) || return :($T(args...))
    # Define `new` for rebuilt function type that matches args
    exp = Expr(:new, Expr(:curly, T, args...))
    for i in 1:length(args)
        push!(exp.args, :(args[$i]))
    end
    return exp
end

function ConstructionBase.constructorof(f::Type{F}) where F <: Function
    FunctionConstructor{F}()
end

