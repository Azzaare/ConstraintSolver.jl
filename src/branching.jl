"""
    get_split_pvals(com, ::Val{:Auto}, var::Variable)

Splits the possible values into two by using either :smallest or :biggest value and the rest.
It depends on whether it's a satisfiability or optimization problem and whether the variable has a positive
or negative coefficient + minimization or maximization
Return lb, leq, geq, ub => the bounds for the lower part and the bounds for the upper part
"""
function get_split_pvals(com, ::Val{:Auto}, var::Variable)
    @assert var.min != var.max
    if isa(com.objective, LinearCombinationObjective)
        linear_comb = com.objective.lc
        for i in 1:length(linear_comb.indices)
            if linear_comb.indices[i] == var.idx
                coeff = linear_comb.coeffs[i]
                factor = com.sense == MOI.MIN_SENSE ? -1 : 1
                if coeff * factor > 0
                    return get_split_pvals(com, Val(:Biggest), var)
                else
                    return get_split_pvals(com, Val(:Smallest), var)
                end
            end
        end
    end
    # fallback for satisfiability or not in objective
    return get_split_pvals(com, rand(CS_RNG, [Val(:Smallest), Val(:Biggest)]), var)
end

"""
    get_split_pvals(com, ::Val{:InHalf}, var::Variable)

Splits the possible values into two by obtaining the mean value.
Return lb, leq, geq, ub => the bounds for the lower part and the bounds for the upper part
"""
function get_split_pvals(com, ::Val{:InHalf}, var::Variable)
    pvals = values(var)
    @assert length(pvals) >= 2
    mean_val = mean(pvals)
    leq = typemin(Int)
    geq = typemax(Int)
    lb = typemax(Int)
    ub = typemin(Int)
    for pval in pvals
        if pval <= mean_val && pval > leq
            leq = pval
        elseif pval > mean_val && pval < geq
            geq = pval
        end
        if pval < lb
            lb = pval
        end
        if pval > ub
            ub = pval
        end
    end
    return lb, leq, geq, ub
end

"""
    get_split_pvals(com, ::Val{:Random}, var::Variable)

Splits the possible values into two by using a random value for the left branch
**Attention:** The right branch is not useable atm.
"""
function get_split_pvals(com, ::Val{:Random}, var::Variable)
    @assert var.min != var.max
    val = rand(CS_RNG, values(var))
    return val, val, typemin(typeof(val)), typemin(typeof(val))
end

"""
    get_split_pvals(com, ::Val{:Smallest}, var::Variable)

Splits the possible values into two by using the smallest value and the rest.
Return lb, leq, geq, ub => the bounds for the lower part and the bounds for the upper part
"""
function get_split_pvals(com, ::Val{:Smallest}, var::Variable)
    @assert var.min != var.max
    right_lb = partialsort(values(var), 2)
    return var.min, var.min, right_lb, var.max
end

"""
    get_split_pvals(com, ::Val{:Biggest}, var::Variable)

Splits the possible values into two by using the biggest value and the rest.
Return lb, leq, geq, ub => the bounds for the lower part and the bounds for the upper part
"""
function get_split_pvals(com, ::Val{:Biggest}, var::Variable)
    @assert var.min != var.max
    left_ub = partialsort(values(var), 2; rev = true)
    return var.min, left_ub, var.max, var.max
end

"""
    get_next_branch_variable(com::CS.CoM)

Get the next weak index for backtracking. This will be the next branching variable.
Return whether there is an unfixed variable and a best index
"""
function get_next_branch_variable(com::CS.CoM)
    branch_var = get_next_branch_variable(com, com.branch_strategy)
    if !branch_var.is_feasible || branch_var.is_solution
        close_node!(com, com.c_backtrack_idx)
    end
    return branch_var
end

function get_next_branch_variable(com::CS.CoM, ::Val{:IMPS})
    lowest_num_pvals = typemax(Int)
    biggest_inf = -1
    best_vidx = -1
    biggest_dependent = typemax(Int)
    is_in_objective = false
    is_solution = true

    for vidx in 1:length(com.search_space)
        if !isfixed(com.search_space[vidx])
            num_pvals = nvalues(com.search_space[vidx])
            inf = com.bt_infeasible[vidx]
            if !is_in_objective && com.var_in_obj[vidx]
                is_in_objective = true
                lowest_num_pvals = num_pvals
                biggest_inf = inf
                best_vidx = vidx
                is_solution = false
                continue
            end
            if !is_in_objective || com.var_in_obj[vidx]
                if inf >= biggest_inf
                    if inf > biggest_inf || num_pvals < lowest_num_pvals
                        lowest_num_pvals = num_pvals
                        biggest_inf = inf
                        best_vidx = vidx
                        is_solution = false
                    end
                end
            end
        end
    end
    return BranchVarObj(true, is_solution, best_vidx)
end

function get_next_branch_variable(com::CS.CoM, ::Val{:Random})
    variables = com.search_space
    is_free = com.activity_vars.is_free
    if com.c_backtrack_idx == 1
        com.activity_vars.is_free = zeros(Bool, length(variables))
        is_free = com.activity_vars.is_free
    else
        is_free .= false
    end

    for variable in variables
        if !isfixed(variable)
            is_free[variable.idx] = true
        end
    end
    is_solution = !any(is_free)
    vidx = -1
    if !is_solution
        vidx = sample(CS_RNG, 1:length(variables), Weights(is_free))
    end
    return BranchVarObj(true, is_solution, vidx)
end

"""
    still_probing(n, μ, variance, max_deviation)

Determine whether probing should be continued.
This depends on
- the number of probes (at least 2)
- the variance and standard deviation
- whether the 95% confidence interval is in µ ± max_deviation * µ
- max_deviation should be options.activity.max_confidence_deviation / 100
"""
function still_probing(n, μ, variance, max_deviation)
    n < 2 && return true
    for i in 1:length(μ)
        σ = sqrt(variance[i])
        if tdistcdf(n - 1, 0.05) * (σ / sqrt(n)) > max_deviation * μ[i]
            range = tdistcdf(n - 1, 0.05) * (σ / sqrt(n))
            return true
        end
    end
    return false
end

"""
    probe_until(com::CS.CoM)

Start probing from current node:
- Create paths in a depth first search way and use a random branch variable strategy
- Update activity
This creates new `BacktrackObj` inside `backtrack_vec` which get overwritten in each probe
"""
function probe_until(com::CS.CoM)
    mean_activities = [var.activity for var in com.search_space]
    variance_activities = zeros(length(com.search_space))
    saved_traverse_strategy = com.traverse_strategy
    saved_traverse_strategy_option = com.options.traverse_strategy
    saved_branch_strategy = com.branch_strategy
    saved_branch_split = com.branch_split

    # options for probing
    com.options.traverse_strategy = :DFS
    com.traverse_strategy = Val(:DFS)
    com.branch_split = Val(:Random)
    com.branch_strategy = Val(:Random)
    global_feasible = true
    changed_traverse_strategy!(com, saved_traverse_strategy)

    backtrack_obj = BacktrackObj(com)
    backtrack_obj.idx = length(com.backtrack_vec) + 1
    backtrack_obj.parent_idx = 1
    backtrack_obj.depth = 1
    com.c_step_nr += 1
    backtrack_obj.step_nr = com.c_step_nr

    addBacktrackObj2Backtrack_vec!(com.backtrack_vec, backtrack_obj, com)
    update_log_node!(com, 2)
    # the option itself is in percentage
    max_deviation = com.options.activity.max_confidence_deviation / 100

    n = 1
    while n <= com.options.activity.max_probes &&
              still_probing(n, mean_activities, variance_activities, max_deviation) &&
              global_feasible
        n += 1
        root_feasible, feasible, activities, last_backtrack_id = probe(com)
        for i in 1:length(com.search_space)
            new_mean = mean_activities[i] + (activities[i] - mean_activities[i]) / n
            # update variance: https://math.stackexchange.com/questions/102978/incremental-computation-of-standard-deviation
            if n != 1
                variance_activities[i] =
                    (
                        (n - 2) * variance_activities[i] +
                        (n - 1) * (mean_activities[i] - new_mean)^2 +
                        (activities[i] - new_mean)^2
                    ) / (n - 1)
            end
            mean_activities[i] = new_mean
        end
        # if root infeasible we can remove that setting completely
        if !root_feasible
            backtrack_obj = com.backtrack_vec[last_backtrack_id]
            vidx = backtrack_obj.vidx
            vidx == 0 && break # all variables are fixed already
            # use the variable from com not ccom to remove it from the actual model
            variable = com.search_space[vidx]
            lb = backtrack_obj.lb
            ub = backtrack_obj.ub
            push!(com.root_infeasible_vars, VarAndVal(vidx, lb, ub))
        end
    end
    for i in 1:length(com.search_space)
        com.search_space[i].activity = mean_activities[i]
    end
    com.branch_split = saved_branch_split
    com.traverse_strategy = saved_traverse_strategy
    com.options.traverse_strategy = saved_traverse_strategy_option
    com.branch_strategy = saved_branch_strategy
    changed_traverse_strategy!(com, Val(:DFS))

    # checkout root node
    checkout_from_to!(com, com.c_backtrack_idx, 1)
    # prune the last step as checkout_from_to! excludes the to part
    restore_prune!(com, 1)

    return global_feasible
end

"""
    probe(com::CS.CoM)

Probe from node root node
- Follow a DFS path by random selection of a branching variable
- Update activity
Return if feasible and the created backtrack ids along the way
"""
function probe(com::CS.CoM)
    activities = zeros(length(com.search_space))

    first_parent_idx = 2
    options = com.options

    status, last_backtrack_id = backtrack!(
        com,
        options.max_bt_steps;
        sorting = options.backtrack_sorting,
        log_table = false,
        first_parent_idx = first_parent_idx,
        single_path = true,
        compute_bounds = false,
        check_bounds = false,
        cb_finished_pruning = (com1) -> update_probe_activity!(activities, com1),
    )

    feasible = com.backtrack_vec[last_backtrack_id].is_feasible
    root_feasible = true
    if last_backtrack_id == first_parent_idx ||
       com.backtrack_vec[last_backtrack_id].parent_idx == first_parent_idx
        root_feasible = feasible
    end

    # checkout root node
    checkout_from_to!(com, last_backtrack_id, first_parent_idx)
    # prune the last step as checkout_from_to! excludes the to part
    restore_prune!(com, first_parent_idx)
    return root_feasible, feasible, activities, last_backtrack_id
end

function update_activity!(com)
    c_backtrack_idx = com.c_backtrack_idx
    backtrack_obj = com.backtrack_vec[c_backtrack_idx]
    branch_vidx = backtrack_obj.vidx
    γ = com.options.activity.decay
    for variable in com.search_space
        variable.idx == branch_vidx && continue
        if nvalues(variable) > 1
            variable.activity *= γ
        end
        if length(variable.changes[c_backtrack_idx]) > 0
            variable.activity += 1
        end
    end
end

function update_probe_activity!(activities, com)
    c_backtrack_idx = com.c_backtrack_idx
    backtrack_obj = com.backtrack_vec[c_backtrack_idx]
    branch_vidx = backtrack_obj.vidx
    for variable in com.search_space
        variable.idx == branch_vidx && continue
        if length(variable.changes[c_backtrack_idx]) > 0
            activities[variable.idx] += 1
        end
    end
end

function get_next_branch_variable(com::CS.CoM, ::Val{:ABS})
    update_activity!(com)

    if com.in_probing_phase
        com.in_probing_phase = false
        global_feasible = probe_until(com)
        if !global_feasible
            return BranchVarObj(false, false, -1)
        end
    end


    # activity based search
    is_in_objective = false
    highest_activity = -1.0
    best_vidx = -1
    is_solution = true

    for variable in com.search_space
        if !isfixed(variable)
            vidx = variable.idx
            num_pvals = nvalues(variable)
            activity_ratio = variable.activity / num_pvals
            if !is_in_objective && com.var_in_obj[vidx]
                highest_activity = activity_ratio
                is_in_objective = true
                is_solution = false
                best_vidx = vidx
                continue
            end
            if !is_in_objective || com.var_in_obj[vidx]
                if activity_ratio >= highest_activity
                    highest_activity = activity_ratio
                    best_vidx = vidx
                    is_solution = false
                end
            end
        end
    end
    return BranchVarObj(true, is_solution, best_vidx)
end
