
# Anonymous functions have no `new` constructor. Here we generaate
# one for them based on the types of args passed to FunctionConstructor

struct FunctionConstructor{F} end

@generated function (::FunctionConstructor{F})(args...) where F
    exp = Expr(:new, Expr(:curly, F.name.wrapper, args...))
    for i in 1:length(args)
        push!(exp.args, :(args[$i]))
    end
    return exp
end

function ConstructionBase.constructorof(f::Type{F}) where F <: Function
    FunctionConstructor{F}()
end
