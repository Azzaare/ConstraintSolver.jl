module ConstraintSolver

using DataStructures
using Formatting
using JSON
using JuMP:
    @variable,
    @constraint,
    @objective,
    Model,
    optimizer_with_attributes,
    VariableRef,
    backend,
    set_optimizer,
    direct_model,
    optimize!,
    objective_value,
    set_lower_bound,
    set_upper_bound,
    termination_status
import JuMP.sense_to_set
import JuMP
using LightGraphs
using MathOptInterface
using MatrixNetworks
using Random
using Statistics
using StatsBase
using StatsFuns

const CS = ConstraintSolver
const CS_RNG = MersenneTwister(1)
const MOI = MathOptInterface
const MOIB = MathOptInterface.Bridges
const MOIBC = MathOptInterface.Bridges.Constraint
const MOIU = MOI.Utilities

const SVF = MOI.SingleVariable
const SAF = MOI.ScalarAffineFunction
const VAF = MOI.VectorAffineFunction

# indices
const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex

const VAR_TYPES = Union{MOI.ZeroOne,MOI.Integer}

include("types.jl")
const CoM = ConstraintSolverModel

include("tablelogger.jl")
include("options.jl")


include("type_inits.jl")

include("util.jl")
include("branching.jl")
include("traversing.jl")
include("lp_model.jl")
include("MOI_wrapper/MOI_wrapper.jl")
include("printing.jl")
include("logs.jl")
include("Variable.jl")
include("objective.jl")
include("constraints.jl")

include("constraints/all_different.jl")
include("constraints/boolset.jl")
include("constraints/and.jl")
include("constraints/or.jl")
include("constraints/linear_constraints.jl")
include("constraints/svc.jl")
include("constraints/equal_set.jl")
include("constraints/not_equal.jl")
include("constraints/table.jl")
include("constraints/activator_constraints.jl")
include("constraints/indicator.jl")
include("constraints/reified.jl")
include("constraints/geqset.jl")

include("pruning.jl")
include("simplify.jl")

"""
    get_inner_model(::Model) or get_inner_model(::MOIB.LazyBridgeOptimizer{Optimizer})

Return the ConstraintSolverModel for the Model or Optimizer
"""
function get_inner_model(m::Model)
    JuMP.backend(m).optimizer.model.model.inner
end

function get_inner_model(o::MOIB.LazyBridgeOptimizer{Optimizer})
    o.model.inner
end

"""
    fulfills_constraints(com::CS.CoM, vidx, value)

Return whether the model is still feasible after setting the variable at position `vidx` to `value`.
"""
function fulfills_constraints(com::CS.CoM, vidx, value)
    # variable doesn't have any constraint
    if vidx > length(com.subscription)
        return true
    end
    feasible = true
    constraints =  com.constraints
    for ci in com.subscription[vidx]
        constraint = constraints[ci]
        # only call if the function got initialized already
        if constraint.is_initialized
            feasible =
                still_feasible(com, constraint, constraint.fct, constraint.set, vidx, value)
            !feasible && break
        end
    end
    return feasible
end

"""
    set_pvals!(com::CS.CoM, constraint::Constraint)

Compute the possible values inside this constraint and set it as constraint.pvals
"""
function set_pvals!(com::CS.CoM, constraint::Constraint)
    indices = constraint.indices
    # nothing to do i.e x <= x will be x-x <= 0 => 0 <= 0 without variables
    length(indices) == 0 && return
    variables = Variable[v for v in com.search_space[indices]]
    pvals_intervals = Vector{NamedTuple}()
    push!(pvals_intervals, (from = variables[1].lower_bound, to = variables[1].upper_bound))
    for i in 1:length(indices)
        extra_from = variables[i].min
        extra_to = variables[i].max
        comp_inside = false
        for cpvals in pvals_intervals
            if extra_from >= cpvals.from && extra_to <= cpvals.to
                # completely inside the interval already
                comp_inside = true
                break
            elseif extra_from >= cpvals.from && extra_from <= cpvals.to
                extra_from = cpvals.to + 1
            elseif extra_to <= cpvals.to && extra_to >= cpvals.from
                extra_to = cpvals.from - 1
            end
        end
        if !comp_inside && extra_to >= extra_from
            push!(pvals_intervals, (from = extra_from, to = extra_to))
        end
    end
    pvals = collect((pvals_intervals[1].from):(pvals_intervals[1].to))
    for interval in pvals_intervals[2:end]
        pvals = vcat(pvals, collect((interval.from):(interval.to)))
    end
    constraint.pvals = pvals
    if constraint isa IndicatorConstraint || constraint isa ReifiedConstraint
        set_pvals!(com, constraint.inner_constraint)
    end
    if constraint isa BoolConstraint
        set_pvals!(com, constraint.lhs)
        set_pvals!(com, constraint.rhs)
    end
end

"""
    add_constraint!(com::CS.CoM, constraint::Constraint; set_pvals=true)

Add a constraint to the model and set pvals if `set_pvals=true` as well.
Pushes the new constraint to the subscription vector of the involved variables.
"""
function add_constraint!(com::CS.CoM, constraint::Constraint; set_pvals = true)
    @assert constraint.idx == length(com.constraints) + 1
    push!(com.constraints, constraint)
    set_pvals && set_pvals!(com, constraint)
    for vidx in constraint.indices
        push!(com.subscription[vidx], constraint.idx)
    end
end

"""
    get_best_bound(com::CS.CoM, backtrack_obj::BacktrackObj; vidx=0, lb=0, ub=0)

Return the best bound if setting the variable with idx: `vidx` to
    lb <= var[vidx] <= ub if vidx != 0
Without an objective function return 0.
"""
function get_best_bound(com::CS.CoM, backtrack_obj::BacktrackObj; vidx = 0, lb = 0, ub = 0)
    if com.sense == MOI.FEASIBILITY_SENSE
        return zero(com.best_bound)
    end
    best_bound = zero(com.best_bound)
    if com.options.lp_optimizer !== nothing
        best_bound = get_best_bound_lp(com, backtrack_obj, vidx, lb, ub)
    else
        best_bound = get_best_bound(com, backtrack_obj, com.objective, vidx, lb, ub)
    end
    # vidx != 0 can mean a temporary backtrack object that doesn't get added to backtrack_vec
    if vidx == 0 && backtrack_obj.status == :Open
        set_update_backtrack_pq!(com, backtrack_obj; best_bound = best_bound)
    end
    return best_bound
end

"""
    checkout_from_to!(com::CS.CoM, from_nidx::Int, to_nidx::Int)

Change the state of the search space given the current position in the tree (`from_nidx`) and the index we want
to change to (`to_nidx`)
"""
function checkout_from_to!(com::CS.CoM, from_nidx::Int, to_nidx::Int)
    backtrack_vec = com.backtrack_vec
    from = backtrack_vec[from_nidx]
    to = backtrack_vec[to_nidx]
    if to.parent_idx == from.idx
        return
    end
    reverse_pruning!(com, from.idx)

    prune_steps = Vector{Int}()
    # first go to same level if new is higher in the tree
    if to.depth < from.depth
        depth = from.depth
        parent_nidx = from.parent_idx
        parent = backtrack_vec[parent_nidx]
        while to.depth < depth
            reverse_pruning!(com, parent_nidx)
            parent = backtrack_vec[parent_nidx]
            parent_nidx = parent.parent_idx
            depth -= 1
        end
        if parent_nidx == to.parent_idx
            return
        else
            from = parent
        end
    elseif from.depth < to.depth
        depth = to.depth
        parent_nidx = to.parent_idx
        parent = backtrack_vec[parent_nidx]
        while from.depth < depth
            pushfirst!(prune_steps, parent_nidx)
            parent = backtrack_vec[parent_nidx]
            parent_nidx = parent.parent_idx
            depth -= 1
        end


        to = parent
        if backtrack_vec[prune_steps[1]].parent_idx == from.parent_idx
            !isempty(prune_steps) && restore_prune!(com, prune_steps)
            return
        end
    end
    @assert from.depth == to.depth
    # same depth but different parent
    # => level up until same parent
    while from.parent_idx != to.parent_idx
        reverse_pruning!(com, from.parent_idx)
        from = backtrack_vec[from.parent_idx]

        pushfirst!(prune_steps, to.parent_idx)
        to = backtrack_vec[to.parent_idx]
    end

    !isempty(prune_steps) && restore_prune!(com, prune_steps)
end

"""
    set_state_to_best_sol!(com::CS.CoM, last_backtrack_id::Int)

Set the state of the model to the best solution found
"""
function set_state_to_best_sol!(com::CS.CoM, last_backtrack_id::Int)
    obj_factor = com.sense == MOI.MIN_SENSE ? 1 : -1
    backtrack_vec = com.backtrack_vec
    # find one of the best solutions
    sol, sol_id = findmin([
        backtrack_vec[sol.backtrack_id].best_bound * obj_factor for sol in com.solutions
    ])
    backtrack_id = com.solutions[sol_id].backtrack_id
    checkout_from_to!(com, last_backtrack_id, backtrack_id)
    # prune the last step as checkout_from_to! excludes the to part
    restore_prune!(com, backtrack_id)
end

"""
    addBacktrackObj2Backtrack_vec!(backtrack_vec, backtrack_obj, com::CS.CoM)

Add a backtrack object to the backtrack vector and create necessary vectors and maybe include it in the logs
"""
function addBacktrackObj2Backtrack_vec!(backtrack_vec, backtrack_obj, com::CS.CoM)
    push!(backtrack_vec, backtrack_obj)
    @assert length(backtrack_vec) == backtrack_obj.idx
    add2priorityqueue(com, backtrack_obj)

    for v in com.search_space
        push!(v.changes, Vector{Tuple{Symbol,Int,Int,Int}}())
    end
    create_log_node(com)
end

"""
    backtrack_vec::Vector{BacktrackObj{T}}, com::CS.CoM{T}, parent_idx, depth, vidx;
     check_bound=false, only_one=false, compute_bound=true)

Create two branches with two additional `BacktrackObj`s and add them to `backtrack_vec`.
Normally bounds are not checked so it gets added even if it's worse.
One can use `only_one` if one wants to probe instead one strain instead of creating the two
    possible children.
If the bound is not important one can set `compute_bound = false` to improve running time.
"""
function add2backtrack_vec!(
    backtrack_vec::Vector{BacktrackObj{T}},
    com::CS.CoM{T},
    parent_idx,
    vidx;
    check_bound = false,
    only_one = false,
    compute_bound = true,
) where {T<:Real}
    @assert !check_bound || compute_bound
    obj_factor = com.sense == MOI.MIN_SENSE ? 1 : -1
    left_lb, left_ub, right_lb, right_ub =
        get_split_pvals(com, com.branch_split, com.search_space[vidx])

    #=
        Check whether the new node is needed which depends on
        - Is there a solution already?
            - no => Add
        - Do we want all solutions?
            - yes => Add
        - Do we want all optimal solutions?
            - yes => Add if better or same as previous optimal one
    =#

    # left branch
    backtrack_obj = new_BacktrackObj(com, parent_idx, vidx, left_lb, left_ub)
    if compute_bound
        backtrack_obj.best_bound =
            get_best_bound(com, backtrack_obj; vidx = vidx, lb = left_lb, ub = left_ub)
    end
    # only include nodes which have a better objective than the current best solution if one was found already
    if com.options.all_solutions ||
       !check_bound ||
       length(com.solutions) == 0 ||
       backtrack_obj.best_bound * obj_factor < com.best_sol * obj_factor ||
       com.options.all_optimal_solutions &&
       backtrack_obj.best_bound * obj_factor <= com.best_sol * obj_factor

        addBacktrackObj2Backtrack_vec!(backtrack_vec, backtrack_obj, com)
    end
    only_one && return
    @assert left_ub < right_lb
    # right branch
    backtrack_obj = new_BacktrackObj(com, parent_idx, vidx, right_lb, right_ub)
    if compute_bound
        backtrack_obj.best_bound =
            get_best_bound(com, backtrack_obj; vidx = vidx, lb = right_lb, ub = right_ub)
    end
    if com.options.all_solutions ||
       !check_bound ||
       length(com.solutions) == 0 ||
       backtrack_obj.best_bound * obj_factor < com.best_sol ||
       com.options.all_optimal_solutions &&
       backtrack_obj.best_bound * obj_factor <= com.best_sol * obj_factor

        addBacktrackObj2Backtrack_vec!(backtrack_vec, backtrack_obj, com)
    end
end

"""
    set_bounds!(com, backtrack_obj)

Set lower/upper bounds for the current variable index `backtrack_obj.vidx`.
Return if simple removable is still feasible
"""
function set_bounds!(com, backtrack_obj)
    vidx = backtrack_obj.vidx
    !remove_above!(com, com.search_space[vidx], backtrack_obj.ub) && return false
    !remove_below!(com, com.search_space[vidx], backtrack_obj.lb) && return false
    return true
end

"""
    add_new_solution!(com::CS.CoM, backtrack_vec::Vector{BacktrackObj{T}}, backtrack_obj::BacktrackObj{T}, log_table) where T <: Real

A new solution was found.
- Add it to the solutions objects
Return true if backtracking can be stopped
"""
function add_new_solution!(
    com::CS.CoM,
    backtrack_vec::Vector{BacktrackObj{T}},
    backtrack_obj::BacktrackObj{T},
    log_table,
) where {T<:Real}
    obj_factor = com.sense == MOI.MIN_SENSE ? 1 : -1
    find_more_solutions = com.options.all_solutions || com.options.all_optimal_solutions

    new_sol = get_best_bound(com, backtrack_obj)
    backtrack_obj.best_bound = new_sol
    if length(com.solutions) == 0 || obj_factor * new_sol <= obj_factor * com.best_sol
        # also push it to the solutions object
        new_sol_obj = Solution(new_sol, CS.value.(com.search_space), backtrack_obj.idx)
        push!(com.solutions, new_sol_obj)
        com.best_sol = new_sol
        log_table && (last_table_row = update_table_log(com, backtrack_vec; force = true))
        if com.best_sol == com.best_bound && !find_more_solutions
            return true
        end
        # set all nodes to :Worse if they can't achieve a better solution
        for bo in backtrack_vec
            if bo.status == :Open && obj_factor * bo.best_bound >= obj_factor * com.best_sol
                bo.status = :Worse
            end
        end
    else # if new solution was found but it's worse
        log_table && (last_table_row = update_table_log(com, backtrack_vec; force = true))
        if com.options.all_solutions
            new_sol_obj = Solution(new_sol, CS.value.(com.search_space), backtrack_obj.idx)
            push!(com.solutions, new_sol_obj)
        end
    end
    # change the traverse strategy for example if it was :DBFS and we found the first solution
    old_traverse_strategy = com.traverse_strategy
    com.traverse_strategy = get_traverse_strategy(com; options = com.options)
    if com.traverse_strategy != old_traverse_strategy
        changed_traverse_strategy!(com, old_traverse_strategy)
    end
    return false
end

"""
    checkout_new_node!(com::CS.CoM, last_id, new_id)

If last id is not 0 then changes from last_id to new_id and sets `com.c_backtrack_idx`
"""
function checkout_new_node!(com::CS.CoM, last_id, new_id)
    if last_id != 0
        com.c_backtrack_idx = 0
        checkout_from_to!(com, last_id, new_id)
        com.c_backtrack_idx = new_id
    end
end

"""
    found_best_node(com::CS.CoM)

Return whether a optimal solution was found
"""
function found_best_node(com::CS.CoM)
    obj_factor = com.sense == MOI.MIN_SENSE ? 1 : -1
    return length(com.solutions) > 0 &&
           obj_factor * com.best_bound >= obj_factor * com.best_sol
end

"""
    handle_infeasible!(com::CS.CoM; finish_pruning=false)

Handle infeasibility:
- finish pruning if `finish_pruning` is true
- log if desired
- increase `backtrack_reverses`

Return true to make calls like `!feasible && handle_infeasible!(com) && continue` possible
"""
function handle_infeasible!(com::CS.CoM; finish_pruning = false)
    # need to call as some function might have pruned something.
    # Just need to be sure that we save the latest states
    finish_pruning && call_finished_pruning!(com)
    last_backtrack_id = com.c_backtrack_idx
    com.backtrack_vec[last_backtrack_id].is_feasible = false
    update_log_node!(com, last_backtrack_id; feasible = false)
    com.info.backtrack_reverses += 1
    return true
end

function solve_with_backtrack!(com, max_bt_steps; sorting = true)
    com.info.backtrack_fixes = 1

    log_table = false
    if :Table in com.options.logging
        log_table = true
    end

    check_bounds = com.sense != MOI.FEASIBILITY_SENSE
    status, last_backtrack_id =
        backtrack!(com, max_bt_steps; sorting = sorting, log_table = log_table, check_bounds = check_bounds)

    status != :TBD && return status

    if length(com.solutions) > 0
        set_state_to_best_sol!(com, last_backtrack_id)
        com.best_bound = com.best_sol
        if time() - com.start_time > com.options.time_limit
            return :Time
        else
            return :Solved
        end
    end

    if time() - com.start_time > com.options.time_limit
        return :Time
    else
        return :Infeasible
    end
end

"""
    backtrack!(com::CS.CoM, max_bt_steps; sorting=true)

Start backtracking and stop after `max_bt_steps`.
If `sorting` is set to `false` the same ordering is used as when used without objective this has only an effect when an objective is used.
Return :Solved or :Infeasible if proven or `:NotSolved` if interrupted by `max_bt_steps`.
"""
function backtrack!(
    com::CS.CoM,
    max_bt_steps;
    sorting = true,
    log_table = true,
    first_parent_idx = 1,
    single_path = false,
    compute_bounds = true,
    check_bounds = true,
    cb_finished_pruning = (args...) -> nothing,
)

    branch_var = get_next_branch_variable(com)
    branch_var.is_solution && return :Solved, first_parent_idx
    !branch_var.is_feasible && return :Infeasible, first_parent_idx

    backtrack_vec = com.backtrack_vec

    find_more_solutions = com.options.all_solutions || com.options.all_optimal_solutions

    log_table && println(get_header(com.options.table))

    backtrack_vec = com.backtrack_vec

    add2backtrack_vec!(
        backtrack_vec,
        com,
        first_parent_idx, # parent_idx
        branch_var.vidx;
        only_one = single_path,
        compute_bound = compute_bounds,
        check_bound = check_bounds,
    )
    last_backtrack_id = first_parent_idx

    started = true
    obj_factor = com.sense == MOI.MIN_SENSE ? 1 : -1

    while length(backtrack_vec) > 0
        # get next open backtrack object
        if !started
            # close the previous backtrack object
            close_node!(com, last_backtrack_id)
            update_log_node!(com, last_backtrack_id)
        end
        # run at least once so that everything is well defined
        if !started && time() - com.start_time > com.options.time_limit
            break
        end

        if !started && compute_bounds
            update_best_bound!(com)
        end
        found, backtrack_obj = get_next_node(com, backtrack_vec, sorting)
        !found && break

        # there is no better node => return best solution
        !find_more_solutions && found_best_node(com) && break

        vidx = backtrack_obj.vidx

        com.c_backtrack_idx = backtrack_obj.idx

        checkout_new_node!(com, last_backtrack_id, backtrack_obj.idx)

        # if backtracking was started
        # => remove all values which are root infeasible
        # this is done here instead of at the root node to avoid removing variables
        # in nodes which already have children
        if started
            for root_infeasible in com.root_infeasible_vars
                for val in (root_infeasible.lb):(root_infeasible.ub)
                    if has(com.search_space[root_infeasible.vidx], val)
                        if !rm!(com, com.search_space[root_infeasible.vidx], val)
                            return :Infeasible, last_backtrack_id
                        end
                    end
                end
            end
        end

        started = false
        last_backtrack_id = backtrack_obj.idx

        # limit the variable bounds
        if !set_bounds!(com, backtrack_obj)
            update_log_node!(com, last_backtrack_id; feasible = false)
            continue
        end

        constraints = com.constraints[com.subscription[vidx]]
        com.info.backtrack_fixes += 1

        # prune completely start with all that changed by the fix or by updating best bound
        feasible = prune!(com)
        !feasible && handle_infeasible!(com; finish_pruning = true) && continue
        call_finished_pruning!(com)
        cb_finished_pruning(com)

        if log_table
            last_table_row = update_table_log(com, backtrack_vec)
        end

        branch_var = get_next_branch_variable(com)
        if branch_var.is_solution
            finished = add_new_solution!(com, backtrack_vec, backtrack_obj, log_table)
            update_log_node!(com, last_backtrack_id)
            if finished
                # close the previous backtrack object
                close_node!(com, last_backtrack_id)
                return :Solved, last_backtrack_id
            end
            continue
        end

        if com.info.backtrack_fixes > max_bt_steps
            close_node!(com, last_backtrack_id)
            update_log_node!(com, last_backtrack_id)
            return :NotSolved, last_backtrack_id
        end

        update_log_node!(com, backtrack_obj.idx)

        last_backtrack_obj = backtrack_vec[last_backtrack_id]
        add2backtrack_vec!(
            backtrack_vec,
            com,
            last_backtrack_obj.idx,
            branch_var.vidx;
            only_one = single_path,
            compute_bound = compute_bounds,
            check_bound = check_bounds,
        )
    end

    close_node!(com, last_backtrack_id)
    update_log_node!(com, last_backtrack_id)
    return :TBD, last_backtrack_id
end

"""
    set_in_all_different!(com::CS.CoM)

Set `constraint.in_all_different` if all variables in the constraint are part of the same `all_different` constraint.
"""
function set_in_all_different!(com::CS.CoM; constraints = com.constraints)
    for constraint in constraints
        if :in_all_different in fieldnames(typeof(constraint))
            if !constraint.in_all_different
                subscriptions_idxs =
                    [[i for i in com.subscription[v]] for v in constraint.indices]
                length(subscriptions_idxs) == 0 && continue
                intersects = intersect(subscriptions_idxs...)

                for i in intersects
                    if isa(com.constraints[i].set, AllDifferentSetInternal)
                        constraint.in_all_different = true
                        push!(com.constraints[i].sub_constraint_idxs, constraint.idx)
                    end
                end
            end
        end
    end
end

"""
    sort_solutions!(com::CS.CoM)

Order com.solutions by objective
"""
function sort_solutions!(com::CS.CoM)
    obj_factor = com.sense == MOI.MIN_SENSE ? 1 : -1
    sort!(com.solutions, by = s -> s.incumbent * obj_factor)
end

function print_info(com::CS.CoM)
    println("# Variables: ", length(com.search_space))
    println("# Constraints: ", length(com.constraints))
    for field in fieldnames(CS.NumberConstraintTypes)
        field_str = uppercasefirst(String(field))
        val = getfield(com.info.n_constraint_types, field)
        val != 0 && println(" - # $field_str: $val")
    end
    println()
end

"""
    solve!(com::CS.CoM, options::SolverOptions)

Solve the constraint model based on the given settings.
"""
function solve!(com::CS.CoM)
    options = com.options
    Random.seed!(CS_RNG, options.seed)
    backtrack = options.backtrack
    max_bt_steps = options.max_bt_steps
    backtrack_sorting = options.backtrack_sorting
    keep_logs = options.keep_logs
    if options.traverse_strategy == :Auto
        options.traverse_strategy = get_auto_traverse_strategy(com)
    end
    if options.branch_strategy == :Auto
        options.branch_strategy = get_auto_branch_strategy(com)
    end
    com.traverse_strategy = get_traverse_strategy(com; options = options)
    com.branch_strategy = get_branch_strategy(; options = options)
    com.branch_split = get_branch_split(; options = options)

    set_impl_functions!(com)

    if :Info in com.options.logging
        print_info(com)
    end
    com.start_time = time()

    !set_init_fixes!(com) && return :Infeasible
    set_in_all_different!(com)

    # initialize constraints if `init_constraint!` exists for the constraint
    !init_constraints!(com) && return :Infeasible

    com.input[:logs] = keep_logs
    if keep_logs
        com.init_search_space = deepcopy(com.search_space)
    end


    # check for better constraints
    if options.simplify
        added_con_idxs = simplify!(com)
        if length(added_con_idxs) > 0
            set_in_all_different!(com; constraints = com.constraints[added_con_idxs])
            set_impl_functions!(com; constraints = com.constraints[added_con_idxs])
            !init_constraints!(com; constraints = com.constraints[added_con_idxs]) &&
                return :Infeasible
            !update_init_constraints!(com; constraints = com.constraints[added_con_idxs]) &&
                return :Infeasible
            recompute_subscriptions(com)
        end
    end

    options.no_prune && return :NotSolved

    # check if all feasible even if for example everything is fixed
    feasible = prune!(com; pre_backtrack = true, initial_check = true)
    # finished pruning will be called in second call a few lines down...


    if !feasible
        com.solve_time = time() - com.start_time
        return :Infeasible
    end
    if all(v -> isfixed(v), com.search_space)
        # root node is the first backtrack obj
        dummy_backtrack_obj = BacktrackObj(com)
        com.best_bound = get_best_bound(com, dummy_backtrack_obj)

        backtrack_vec = com.backtrack_vec
        addBacktrackObj2Backtrack_vec!(backtrack_vec, dummy_backtrack_obj, com)

        com.best_sol = com.best_bound
        com.solve_time = time() - com.start_time
        new_sol_obj = Solution(com.best_sol, CS.value.(com.search_space), 1)
        push!(com.solutions, new_sol_obj)
        return :Solved
    end
    feasible = prune!(com; pre_backtrack = true)
    call_finished_pruning!(com)

    # root node is the first backtrack obj
    dummy_backtrack_obj = BacktrackObj(com)
    dummy_backtrack_obj.step_nr = com.c_step_nr
    com.best_bound = get_best_bound(com, dummy_backtrack_obj)

    backtrack_vec = com.backtrack_vec
    addBacktrackObj2Backtrack_vec!(backtrack_vec, dummy_backtrack_obj, com)

    if keep_logs
        com.logs[1].step_nr = 1
    end

    if !feasible
        com.solve_time = time() - com.start_time
        return :Infeasible
    end

    if all(v -> isfixed(v), com.search_space)
        com.best_sol = com.best_bound
        com.solve_time = time() - com.start_time
        new_sol_obj = Solution(com.best_sol, CS.value.(com.search_space), 1)
        push!(com.solutions, new_sol_obj)
        return :Solved
    end
    if backtrack
        com.info.backtracked = true
        if time() - com.start_time > com.options.time_limit
            com.solve_time = time() - com.start_time
            return :Time
        end
        keep_logs && update_log_node!(com, 1)
        status = solve_with_backtrack!(com, max_bt_steps; sorting = backtrack_sorting)
        com.solve_time = time() - com.start_time
        return status
    else
        @info "Backtracking is turned off."
        com.solve_time = time() - com.start_time
        return :NotSolved
    end
end

end # module
