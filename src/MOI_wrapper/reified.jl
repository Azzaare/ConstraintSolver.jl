function _build_reified_constraint(
    _error::Function,
    variable::JuMP.AbstractVariableRef,
    constraint::JuMP.ScalarConstraint,
    ::Type{<:CS.ReifiedSet{A}},
) where {A}
    S = typeof(JuMP.moi_set(constraint))
    set = ReifiedSet{A,S}(JuMP.moi_set(constraint), 2)
    return JuMP.VectorConstraint([variable, JuMP.jump_function(constraint)], set)
end

function _build_reified_constraint(
    _error::Function,
    variable::JuMP.AbstractVariableRef,
    jump_constraint::JuMP.VectorConstraint,
    ::Type{<:CS.ReifiedSet{A}},
) where {A}
    S = typeof(jump_constraint.set)
    set = CS.ReifiedSet{A,S}(jump_constraint.set, 1 + length(jump_constraint.func))
    if jump_constraint.func isa Vector{VariableRef}
        vov = JuMP.VariableRef[variable]
    else
        vov = JuMP.AffExpr[variable]
    end
    append!(vov, jump_constraint.func)
    return JuMP.VectorConstraint(vov, set)
end

function _reified_variable_set(::Function, variable::Symbol)
    return variable, ReifiedSet{MOI.ACTIVATE_ON_ONE}
end

function _reified_variable_set(_error::Function, expr::Expr)
    if expr.args[1] == :¬ || expr.args[1] == :!
        if length(expr.args) != 2
            _error("Invalid binary variable expression `$(expr)` for reified constraint.")
        end
        return expr.args[2], ReifiedSet{MOI.ACTIVATE_ON_ZERO}
    else
        return expr, ReifiedSet{MOI.ACTIVATE_ON_ONE}
    end
end

function JuMP.parse_constraint_head(_error::Function, ::Val{:(:=)}, lhs, rhs)
    variable, S = _reified_variable_set(_error, lhs)
    if !JuMP.isexpr(rhs, :braces) || length(rhs.args) != 1
        _error("Invalid right-hand side `$(rhs)` of reified constraint. Expected constraint surrounded by `{` and `}`.")
    end
    rhs_con = rhs.args[1]
    rhs_vectorized, rhs_parsecode, rhs_buildcall =
        JuMP.parse_constraint_expr(_error, rhs_con)

    # TODO implement vectorized version
    vectorized = false
    if rhs_vectorized
        _error("`$(rhs)` should be non vectorized. There is currently no vectorized support for reified constraints. Please open an issue at ConstraintSolver.jl")
    end

    buildcall = :($(esc(:(CS._build_reified_constraint)))(
        $_error,
        $(esc(variable)),
        $rhs_buildcall,
        $S,
    ))
    return vectorized, rhs_parsecode, buildcall
end
