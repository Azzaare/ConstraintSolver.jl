"""
    activate_inner!(com, constraint::ActivatorConstraint)

Activate the inner constraint of `constraint` when not activated yet.
Saves at which stage it was activated.
"""
function activate_inner!(com, constraint::ActivatorConstraint)
    inner_constraint = constraint.inner_constraint
    if !constraint.inner_activated && inner_constraint.impl.activate 
        !activate_constraint!(com, inner_constraint, inner_constraint.fct, inner_constraint.set) && return false
        constraint.inner_activated = true
        constraint.inner_activated_in_backtrack_idx = com.c_backtrack_idx
    end
    return true
end

"""
    activate_anti_inner!(com, constraint::ActivatorConstraint)

Activate the anti constraint of `constraint` when not activated yet.
Saves at which stage it was activated.
"""
function activate_anti_inner!(com, constraint::ActivatorConstraint)
    anti_constraint = constraint.anti_constraint
    if !constraint.anti_inner_activated && anti_constraint.impl.activate 
        !activate_constraint!(com, anti_constraint, anti_constraint.fct, anti_constraint.set) && return false
        constraint.anti_inner_activated = true
        constraint.anti_inner_activated_in_backtrack_idx = com.c_backtrack_idx
    end
    return true
end

"""
    update_best_bound_constraint!(com::CS.CoM,
        constraint::ActivatorConstraint,
        fct::Union{MOI.VectorOfVariables, VAF{T}},
        set::IS,
        vidx::Int,
        lb::Int,
        ub::Int
    ) where {T<:Real}

Update the bound constraint associated with this constraint. This means that the `bound_rhs` bounds will be changed according to
the possible values the table constraint allows. `vidx`, `lb` and `ub` don't are not considered atm.
Additionally only a rough estimated bound is used which can be computed relatively fast.
This method calls the inner_constraint method if it exists and the indicator is activated.
"""
function update_best_bound_constraint!(
    com::CS.CoM,
    constraint::ActivatorConstraint,
    fct::Union{MOI.VectorOfVariables,VAF{T}},
    set,
    vidx::Int,
    lb::Int,
    ub::Int,
) where {
    T<:Real,
}
    inner_constraint = constraint.inner_constraint
    activator_vidx = constraint.indices[1]
    search_space = com.search_space
    activator_var = search_space[activator_vidx]
    if inner_constraint.impl.update_best_bound
        if CS.issetto(activator_var, Int(constraint.activate_on))
            return update_best_bound_constraint!(
                com,
                inner_constraint,
                inner_constraint.fct,
                inner_constraint.set,
                vidx,
                lb,
                ub,
            )
        else
            # if not activated (for example in a different subtree) we reset the bounds
            for rhs in constraint.bound_rhs
                rhs.lb = typemin(Int64)
                rhs.ub = typemax(Int64)
            end
        end
    end
    return true
end

function single_reverse_pruning_constraint!(
    com::CoM,
    constraint::ActivatorConstraint,
    fct::Union{MOI.VectorOfVariables,VAF{T}},
    set,
    var::Variable,
    backtrack_idx::Int,
) where {
    T<:Real,
}
    inner_constraint = constraint.inner_constraint
    # the variable must be part of the inner constraint
    if inner_constraint.impl.single_reverse_pruning &&
       (var.idx != constraint.indices[1] || constraint.activator_in_inner)
        single_reverse_pruning_constraint!(
            com,
            inner_constraint,
            inner_constraint.fct,
            inner_constraint.set,
            var,
            backtrack_idx,
        )
    end
end

function reverse_pruning_constraint!(
    com::CoM,
    constraint::ActivatorConstraint,
    fct::Union{MOI.VectorOfVariables,VAF{T}},
    set,
    backtrack_id::Int,
) where {
    T<:Real,
}
    # check if inner constraint should be deactived again
    if constraint.inner_activated && backtrack_id == constraint.inner_activated_in_backtrack_idx
        constraint.inner_activated = false
        constraint.inner_activated_in_backtrack_idx = 0
    end
    if constraint isa ReifiedConstraint 
        if constraint.anti_inner_activated && backtrack_id == constraint.anti_inner_activated_in_backtrack_idx
            constraint.anti_inner_activated = false
            constraint.anti_inner_activated_in_backtrack_idx = 0
        end
    end

    inner_constraint = constraint.inner_constraint
    if inner_constraint.impl.reverse_pruning
        reverse_pruning_constraint!(
            com,
            inner_constraint,
            inner_constraint.fct,
            inner_constraint.set,
            backtrack_id,
        )
    end
end

function restore_pruning_constraint!(
    com::CoM,
    constraint::ActivatorConstraint,
    fct::Union{MOI.VectorOfVariables,VAF{T}},
    set,
    prune_steps::Union{Int,Vector{Int}},
) where {
    T<:Real,
}
    inner_constraint = constraint.inner_constraint
    if inner_constraint.impl.restore_pruning
        restore_pruning_constraint!(
            com,
            inner_constraint,
            inner_constraint.fct,
            inner_constraint.set,
            prune_steps,
        )
    end
end

function finished_pruning_constraint!(
    com::CS.CoM,
    constraint::ActivatorConstraint,
    fct::Union{MOI.VectorOfVariables,VAF{T}},
    set,
) where {
    T<:Real,
}
    inner_constraint = constraint.inner_constraint
    if inner_constraint.impl.finished_pruning
        finished_pruning_constraint!(
            com,
            inner_constraint,
            inner_constraint.fct,
            inner_constraint.set,
        )
    end
end
