@testset "Small special tests" begin
    @testset "Fix variable" begin
        m = Model(CSJuMPTestOptimizer())
        @variable(m, 1 <= x <= 9, Int)
        @variable(m, y == 2, Int)
        # should just return optimal with any 1-9 for x and y is fixed
        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test 1 <= JuMP.value(x) <= 9 && length(CS.values(m, x)) == 1
        @test JuMP.value(y) == 2

        m = Model(CSJuMPTestOptimizer())
        @variable(m, 1 <= x <= 9, Int)
        @variable(m, y == 2, Int)
        @constraint(m, x + y == 10)
        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.value(x) == 8
        @test JuMP.value(y) == 2
    end

    @testset "LessThan constraints JuMP" begin
        m = Model(CSJuMPTestOptimizer(; branch_strategy = :ABS))
        @variable(m, 1 <= x[1:5] <= 9, Int)
        @constraint(m, sum(x) <= 25)
        @constraint(m, sum(x) >= 20)
        weights = [1, 2, 3, 4, 5]
        @objective(m, Max, sum(weights .* x))
        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.value.(x) == [1, 1, 5, 9, 9]
        @test JuMP.objective_value(m) == 99

        # minimize
        m = Model(CSJuMPTestOptimizer())
        @variable(m, 1 <= x[1:5] <= 9, Int)
        @constraint(m, sum(x) <= 25)
        @constraint(m, sum(x) >= 20)
        weights = [1, 2, 3, 4, 5]
        @objective(m, Min, sum(weights .* x))
        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.value.(x) == [9, 8, 1, 1, 1]
        @test JuMP.objective_value(m) == 37

        # minimize with negative and positive real weights
        m = Model(CSJuMPTestOptimizer(; branch_strategy = :ABS))
        @variable(m, 1 <= x[1:5] <= 9, Int)
        @constraint(m, sum(x) <= 25)
        weights = [-0.1, 0.2, -0.3, 0.4, 0.5]
        @constraint(m, sum(x[i] for i = 1:5 if weights[i] > 0) >= 15)
        @objective(m, Min, sum(weights .* x))
        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.value.(x) == [1, 9, 9, 5, 1]
        @test JuMP.objective_value(m) ≈ 1.5
    end

    @testset "Knapsack problems" begin
        m = Model(CSJuMPTestOptimizer())

        @variable(m, 1 <= x[1:5] <= 9, Int)
        @constraint(m, sum(x) <= 25)
        @constraint(m, x[2] + 1.2 * x[4] - x[5] <= 12)
        weights = [1.2, 3.0, -0.3, -5.2, 2.7]
        @objective(m, Max, dot(weights, x))

        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL
        x_vals = JuMP.value.(x)
        @test x_vals[1] ≈ 5
        @test x_vals[2] ≈ 9
        @test x_vals[3] ≈ 1
        @test x_vals[4] ≈ 1
        @test x_vals[5] ≈ 9
        @test JuMP.objective_value(m) ≈ 51.8

        # less variables in the objective
        m = Model(CSJuMPTestOptimizer())

        @variable(m, 1 <= x[1:5] <= 9, Int)
        @constraint(m, sum(x) <= 25)
        @constraint(m, x[2] + 1.2 * x[4] - x[5] <= 12)
        @constraint(m, -x[3] - 1.2 * x[4] + x[5] <= 12)
        weights = [1.2, 3.0, -0.3, -5.2, 2.7]
        @objective(m, Max, x[3] + 2.7 * x[4] - x[1])

        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL
        x_vals = JuMP.value.(x)
        @test sum(x_vals) <= 25
        @test x_vals[2] + 1.2 * x_vals[4] - x_vals[5] <= 12
        @test JuMP.objective_value(m) ≈ 32.3

        # minimize
        m = Model(CSJuMPTestOptimizer())

        @variable(m, 1 <= x[1:5] <= 9, Int)
        @constraint(m, sum(x) >= 25)
        @constraint(m, x[2] + 1.2 * x[4] >= 12)
        weights = [1.2, 3.0, 0.3, 5.2, 2.7]
        @objective(m, Min, dot(weights, x))

        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL
        x_vals = JuMP.value.(x)
        @test x_vals[1] ≈ 3
        @test x_vals[2] ≈ 9
        @test x_vals[3] ≈ 9
        @test x_vals[4] ≈ 3
        @test x_vals[5] ≈ 1
        @test JuMP.objective_value(m) ≈ 51.6

        # minimize only part of the weights and some are negative
        m = Model(CSJuMPTestOptimizer())

        @variable(m, 1 <= x[1:5] <= 9, Int)
        @constraint(m, sum(x) >= 25)
        @constraint(m, x[2] + 1.2 * x[4] - x[1] >= 12)
        @constraint(m, x[5] <= 7)
        @objective(m, Min, 3 * x[2] + 5 * x[1] - 2 * x[3])

        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL
        x_vals = JuMP.value.(x)
        @test x_vals[1] ≈ 1
        @test x_vals[2] ≈ 3
        @test x_vals[3] ≈ 9
        @test x_vals[4] ≈ 9
        @test sum(x_vals) >= 25
        @test JuMP.objective_value(m) ≈ -4

        m = Model(CSJuMPTestOptimizer())
        @variable(m, 1 <= x[1:5] <= 9, Int)
        @constraint(m, sum(x) <= 25)
        @constraint(m, -x[1] - x[2] - x[3] + x[4] + x[5] >= 5)
        weights = [-1, 2, 3, 4, 5]
        @objective(m, Min, sum(weights[1:3] .* x[1:3]))

        optimize!(m)

        x_vals = JuMP.value.(x)
        @test sum(x_vals) <= 25
        @test -x_vals[1] - x_vals[2] - x_vals[3] + x_vals[4] + x_vals[5] >= 5
        @test JuMP.objective_value(m) ≈ -3
    end

    @testset "Not supported constraints" begin
        m = Model(CSJuMPTestOptimizer())
        # must be an Integer upper bound
        @variable(m, 1 <= x[1:5] <= NaN, Int)
        @test_throws ErrorException optimize!(m)

        m = Model(CSJuMPTestOptimizer())
        # must be an Integer lower bound
        @variable(m, NaN <= x[1:5] <= 2, Int)
        @test_throws ErrorException optimize!(m)

        m = Model(CSJuMPTestOptimizer())
        @variable(m, 1 <= x[1:5] <= 2, Int)

        m = Model(CSJuMPTestOptimizer())
        @variable(m, 1 <= x[1:5] <= 2, Int)

        m = Model(CSJuMPTestOptimizer())
        @variable(m, 1 <= x[1:5] <= 2, Int)
    end

    @testset "Bipartite matching" begin
        match = CS.bipartite_cardinality_matching([2, 1, 3], [1, 2, 3], 3, 3)
        @test match.weight == 3
        @test match.match == [2, 1, 3]

        # no perfect matching
        match = CS.bipartite_cardinality_matching(
            [1, 2, 3, 4, 1, 2, 3, 3],
            [1, 1, 2, 2, 2, 2, 3, 4],
            4,
            4,
        )
        @test match.weight == 3
        # 4 is zero and the rest should be different
        @test match.match[4] == 0
        @test allunique(match.match)


        # more values than indices
        match = CS.bipartite_cardinality_matching(
            [1, 2, 3, 4, 1, 2, 3, 3, 2, 1, 2],
            [1, 1, 2, 2, 2, 2, 3, 4, 5, 5, 6],
            4,
            6,
        )
        @test match.weight == 4
        # all should be matched to different values
        @test allunique(match.match)
        # no unmatched vertex
        @test count(i -> i == 0, match.match) == 0

        # more values than indices with matching_init
        m = 4
        n = 6
        l = [1, 2, 3, 4, 1, 2, 3, 3, 2, 1, 2, 0, 0]
        r = [1, 1, 2, 2, 2, 2, 3, 4, 5, 5, 6, 0, 0]
        # don't use the zeros
        l_len = length(l) - 2
        matching_init = CS.MatchingInit(
            l_len,
            zeros(Int, m),
            zeros(Int, n),
            zeros(Int, m + 1),
            zeros(Int, m + n),
            zeros(Int, m + n),
            zeros(Int, m + n),
            zeros(Bool, m),
            zeros(Bool, n),
        )
        match = CS.bipartite_cardinality_matching(l, r, m, n; matching_init = matching_init)
        @test match.weight == 4
        # all should be matched to different values
        @test allunique(match.match)
        # no unmatched vertex
        @test count(i -> i == 0, match.match) == 0
    end

    @testset "Not equal" begin
        m = Model(CSJuMPTestOptimizer())

        @variable(m, 1 <= x <= 10, Int)
        @variable(m, 1 <= y <= 1, Int)
        @variable(m, 1 <= z <= 10, Int)
        @constraint(m, x != 2 - 1) # != 1
        @constraint(m, 2x != 4) # != 2
        @constraint(m, π / 3 * x != π) # != 3
        @constraint(m, 2.2x != 8.8) # != 4
        @constraint(m, 4x + 5y != 25) # != 5
        @constraint(m, 4x + π * y != 10) # just some random stuff
        @constraint(m, x + y + z - π != 10)
        @constraint(m, x + y + z + 2 != 10)
        @objective(m, Min, x)
        optimize!(m)

        @test JuMP.objective_value(m) == 6
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.value(x) == 6
        @test JuMP.value(y) == 1
        # the values should be fixed
        @test length(CS.values(m, x)) == 1
        @test length(CS.values(m, y)) == 1
        @test length(CS.values(m, z)) == 1
        @test JuMP.value(x) + JuMP.value(y) + JuMP.value(z) + 2 != 10
    end

    @testset "Integers basic" begin
        m = Model(CSJuMPTestOptimizer())
        @variable(m, x, CS.Integers([1, 2, 4]))
        @variable(m, y, CS.Integers([2, 3, 5, 6]))
        @constraint(m, x == y)
        @objective(m, Max, x)
        optimize!(m)
        @test JuMP.value(x) ≈ 2
        @test JuMP.value(y) ≈ 2
        @test JuMP.objective_value(m) ≈ 2

        m = Model(optimizer_with_attributes(CS.Optimizer, "backtrack" => false))
        @variable(m, x, CS.Integers([1, 2, 4]))
        optimize!(m)
        com = CS.get_inner_model(m)
        @test !CS.has(com.search_space[1], 3)
        @test sort(CS.values(com.search_space[1])) == [1, 2, 4]

        m = Model(optimizer_with_attributes(CS.Optimizer, "backtrack" => false))
        @variable(m, y, CS.Integers([2, 5, 6, 3]))
        optimize!(m)
        com = CS.get_inner_model(m)
        @test !CS.has(com.search_space[1], 1)
        @test !CS.has(com.search_space[1], 4)
        @test sort(CS.values(com.search_space[1])) == [2, 3, 5, 6]
    end

    @testset "Biggest cube square number up to 100" begin
        m = Model(CSJuMPTestOptimizer())
        @variable(m, x, CS.Integers([i^2 for i = 1:20 if i^2 < 100]))
        @variable(m, y, CS.Integers([i^3 for i = 1:20 if i^3 < 100]))
        @constraint(m, x == y)
        @objective(m, Max, x)
        optimize!(m)
        @test JuMP.value(x) ≈ 64
        @test JuMP.value(y) ≈ 64
        @test JuMP.objective_value(m) ≈ 64
    end

    @testset "Pythagorean triples" begin
        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "all_solutions" => true,
            "branch_strategy" => :ABS,
            "activity.decay" => 0.999,
            "activity.max_probes" => 20,
            "logging" => [],
        ))
        @variable(m, x[1:3], CS.Integers([i^2 for i in 1:50]))
        @constraint(m, x[1] + x[2] == x[3])
        @constraint(m, x[1] <= x[2])
        optimize!(m)
        com = CS.get_inner_model(m)
        @test is_solved(com)
        @test MOI.get(m, MOI.ResultCount()) == 20
    end

    @testset "Infeasible by fixing variable to outside domain" begin
        m = Model(CSJuMPTestOptimizer())
        @variable(m, x, CS.Integers([1, 2, 4]))
        @constraint(m, x == 3)
        optimize!(m)
        @test JuMP.termination_status(m) == MOI.INFEASIBLE
    end

    @testset "Infeasible by fixing variable to two values" begin
        m = Model(CSJuMPTestOptimizer())
        @variable(m, x, CS.Integers([1, 2, 4]))
        @constraint(m, x == 1)
        @constraint(m, x == 2)
        optimize!(m)
        @test JuMP.termination_status(m) == MOI.INFEASIBLE
    end

    @testset "5 variables all equal" begin
        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "all_solutions" => true,
            "logging" => [],
        ))

        @variable(m, 5 <= x <= 10, Int)
        @variable(m, 2 <= y <= 15, Int)
        @variable(m, 1 <= z <= 7, Int)
        @variable(m, 2 <= a <= 9, Int)
        @variable(m, 6 <= b <= 10, Int)
        @constraint(m, x == y)
        # should not result in linking to x -> y -> x ...
        @constraint(m, y == x)
        @constraint(m, x == y)

        @constraint(m, y == z)
        @constraint(m, a == z)
        @constraint(m, b == y)
        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.value(x) ==
              JuMP.value(y) ==
              JuMP.value(z) ==
              JuMP.value(a) ==
              JuMP.value(b)
        @test JuMP.value(x; result = 2) ==
              JuMP.value(y; result = 2) ==
              JuMP.value(z; result = 2) ==
              JuMP.value(a; result = 2) ==
              JuMP.value(b; result = 2)
        @test JuMP.value(x) == 6 || JuMP.value(x) == 7
        @test JuMP.value(x; result = 2) == 6 || JuMP.value(x; result = 2) == 7
        @test JuMP.value(x) != JuMP.value(x; result = 2)
    end

    @testset "x[1] <= x[1]" begin
        model = Model(CSJuMPTestOptimizer())
        n = 4
        @variable(model, 1 <= x[1:n] <= n, Int)
        for i in 1:n
            @constraint(model, x[1] <= x[i])
        end

        optimize!(model)
        status = JuMP.termination_status(model)
        @test status == MOI.OPTIMAL
        com = CS.get_inner_model(model)
        @test is_solved(com)
    end

    @testset "x[1] <= x[1] - 1 " begin
        model = Model(CSJuMPTestOptimizer())
        n = 4
        @variable(model, 1 <= x[1:n] <= n, Int)
        for i in 1:n
            @constraint(model, x[1] <= x[i] - 1)
        end

        optimize!(model)
        status = JuMP.termination_status(model)
        @test status == MOI.INFEASIBLE
    end

    @testset "x[1] == x[1]" begin
        model = Model(CSJuMPTestOptimizer())
        n = 4
        @variable(model, 1 <= x[1:n] <= n, Int)
        for i in 1:n
            @constraint(model, x[1] == x[i])
        end

        optimize!(model)
        status = JuMP.termination_status(model)
        @test status == MOI.OPTIMAL
        com = CS.get_inner_model(model)
        @test is_solved(com)
    end

    @testset "x[1] == x[1] - 1 " begin
        model = Model(CSJuMPTestOptimizer())
        n = 4
        @variable(model, 1 <= x[1:n] <= n, Int)
        for i in 1:n
            @constraint(model, x[1] == x[i] - 1)
        end

        optimize!(model)
        status = JuMP.termination_status(model)
        @test status == MOI.INFEASIBLE
    end

    @testset "x[1] == x[1] - 1 in reified" begin
        model = Model(CSCbcJuMPTestOptimizer())
        n = 4
        @variable(model, 1 <= x[1:n] <= n, Int)
        @variable(model, b[1:n], Bin)
        for i in 1:n
            @constraint(model, b[i] := {x[1] == x[i] - 1})
        end
        @objective(model, Max, sum(b))
        optimize!(model)
        status = JuMP.termination_status(model)
        @test status == MOI.OPTIMAL
        @test JuMP.objective_value(model) ≈ 3
        @test JuMP.value(b[1]) ≈ 0
    end

    @testset "x[1] == x[1] - 1 in indicator" begin
        model = Model(CSCbcJuMPTestOptimizer())
        n = 4
        @variable(model, 1 <= x[1:n] <= n, Int)
        @variable(model, b[1:n], Bin)
        for i in 1:n
            @constraint(model, b[i] => {x[1] == x[i] - 1})
        end
        @objective(model, Max, sum(b))
        optimize!(model)
        status = JuMP.termination_status(model)
        @test status == MOI.OPTIMAL
        @test JuMP.objective_value(model) ≈ 3
        @test JuMP.value(b[1]) ≈ 0
    end

    @testset "Infeasible all different in indicator" begin
        model = Model(CSCbcJuMPTestOptimizer(; branch_strategy = :ABS))
        n = 2
        @variable(model, 1 <= x[1:n] <= n - 1, Int)
        @variable(model, b, Bin)
        @constraint(model, b => {x in CS.AllDifferentSet()})
        @objective(model, Max, b)
        optimize!(model)
        status = JuMP.termination_status(model)
        @test status == MOI.OPTIMAL
        @test JuMP.objective_value(model) ≈ 0
        @test JuMP.value(b) ≈ 0
    end

    @testset "Infeasible all different in reified" begin
        model = Model(CSJuMPTestOptimizer())
        n = 4
        @variable(model, 1 <= x[1:n] <= n - 1, Int)
        @variable(model, b, Bin)
        @constraint(model, b := {x in CS.AllDifferentSet()})
        @objective(model, Max, b)
        optimize!(model)
        status = JuMP.termination_status(model)
        @test status == MOI.OPTIMAL
        @test JuMP.objective_value(model) ≈ 0
        @test JuMP.value(b) ≈ 0
    end

    @testset "Table dim not matching" begin
        model = Model(CSJuMPTestOptimizer())
        n = 4
        @variable(model, 1 <= x[1:n] <= n - 1, Int)
        @variable(model, b, Bin)
        @test_throws ArgumentError @constraint(model, b => {x in CS.TableSet([
            10 20
            11 5
        ])})
    end

    @testset "Infeasible table in indicator" begin
        model = Model(CSJuMPTestOptimizer())
        n = 2
        @variable(model, 1 <= x[1:n] <= n - 1, Int)
        @variable(model, b, Bin)
        @constraint(model, b => {x in CS.TableSet([
            10 20
            11 5
        ])})
        @objective(model, Max, b)
        optimize!(model)
        status = JuMP.termination_status(model)
        @test status == MOI.OPTIMAL
        @test JuMP.objective_value(model) ≈ 0
        @test JuMP.value(b) ≈ 0
    end


    @testset "Infeasible table in reified" begin
        model = Model(CSJuMPTestOptimizer())
        n = 2
        @variable(model, 1 <= x[1:n] <= n - 1, Int)
        @variable(model, b, Bin)
        @constraint(model, b := {x in CS.TableSet([
            10 20
            11 5
        ])})
        @objective(model, Max, b)
        optimize!(model)
        status = JuMP.termination_status(model)
        @test status == MOI.OPTIMAL
        @test JuMP.objective_value(model) ≈ 0
        @test JuMP.value(b) ≈ 0
    end

    @testset "Magic Square 5x5" begin
        n = 5
        model = Model(optimizer_with_attributes(
            CS.Optimizer,
            "traverse_strategy" => :BFS,
            "logging" => [],
            "branch_split" => :InHalf,
            "time_limit" => 3,
        ))


        # The total for each row, column, and the two main diaginals
        s = round(Int, n * (n^2 + 1) / 2)
        @variable(model, 1 <= x[1:n, 1:n] <= n^2, Int)
        @constraint(model, x[:] in CS.AllDifferentSet())

        for i in 1:n
            # Rows
            @constraint(model, sum(x[i, :]) == s)

            # Columns
            @constraint(model, sum(x[:, i]) == s)
        end

        # diagonals
        @constraint(model, sum([x[i, i] for i in 1:n]) == s)
        @constraint(model, s == sum([x[i, n - i + 1] for i in 1:n]))

        optimize!(model)
        status = JuMP.termination_status(model)
        @test status == MOI.OPTIMAL
        sol = convert.(Int, JuMP.value.(x))
        for i in 1:n
            @test sum(sol[i, :]) == 65
            @test sum(sol[:, i]) == 65
        end
        @test sum([sol[i, i] for i in 1:n]) == 65
        @test sum([sol[i, n - i + 1] for i in 1:n]) == 65
        @test allunique(sol)
    end

    @testset "Indicator with > and active" begin
        cbc_optimizer = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0)
        model = Model(optimizer_with_attributes(
            CS.Optimizer,
            "lp_optimizer" => cbc_optimizer,
            "logging" => []
        ))
        @variable(model, b >= 1, Bin)
        @variable(model, 0 <= x[1:4] <= 5, Int)
        @constraint(model, b => {sum([0.4,0.5,0.7,0.8] .* x) > 9})
        @objective(model, Min, sum([0.4,0.5,0.7,0.8] .* x))
        optimize!(model)
        CS.get_inner_model(model)
        @test JuMP.termination_status(model) == MOI.OPTIMAL
        @test JuMP.objective_value(model) ≈ 9.1
        @test JuMP.value(x[1]) ≈ 2.0
        @test JuMP.value(x[2]) ≈ 3.0
        @test JuMP.value(x[3]) ≈ 4.0
        @test JuMP.value(x[4]) ≈ 5.0
    end

    @testset "AllDifferent except 0" begin
        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "logging" => []
        ))
        @variable(m, 0 <= x[1:5] <= 3, Int)
        len = length(x)
        for i in 2:len, j in 1:i-1
            b = @variable(m, binary=true)
            @constraint(m, b := {x[i] != 0 && x[j] != 0})
            @constraint(m, b => {x[i] != x[j]} ) 
        end
        
        @objective(m, Min, sum(x))
        optimize!(m)
        CS.get_inner_model(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 0
        @test JuMP.value(x[1]) ≈ 0
        @test JuMP.value(x[2]) ≈ 0
        @test JuMP.value(x[3]) ≈ 0
        @test JuMP.value(x[4]) ≈ 0
        @test JuMP.value(x[5]) ≈ 0

        # maximize
        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "logging" => []
        ))
        @variable(m, 0 <= x[1:5] <= 3, Int)
        len = length(x)
        for i in 2:len, j in 1:i-1
            b = @variable(m, binary=true)
            @constraint(m, b := {x[i] != 0 && x[j] != 0})
            @constraint(m, b => {x[i] != x[j]} ) 
        end
        
        @objective(m, Max, sum(x))
        optimize!(m)
        CS.get_inner_model(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 3+2+1+0+0
    end

    @testset "Try to fulfill b with several conditions" begin
        # inner part is infeasible
        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "logging" => []
        ))
        @variable(m, 0 <= x[1:5] <= 3, Int)
        @variable(m, b, Bin)
        @constraint(m, b => {x[1] > x[2] && x[2] > x[3] && x[3] > x[4] && x[4] > x[5]})
        
        @objective(m, Max, b)
        optimize!(m)
        CS.get_inner_model(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 0
        @test JuMP.value(b) ≈ 0

        # inner part is feasible
        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "logging" => []
        ))
        @variable(m, 0 <= x[1:5] <= 4, Int)
        @variable(m, b, Bin)
        @constraint(m, b => {x[1] > x[2] && x[2] > x[3] && x[3] > x[4] && x[4] > x[5]})
        
        @objective(m, Max, b)
        optimize!(m)
        CS.get_inner_model(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 1
        @test JuMP.value(b) ≈ 1
        vx = JuMP.value.(x)
        @test vx[1] > vx[2] && vx[2] > vx[3] && vx[3] > vx[4] && vx[4] > vx[5]


        # inner part is feasible
        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "logging" => []
        ))
        @variable(m, 0 <= x[1:5] <= 4, Int)
        @variable(m, b, Bin)
        @constraint(m, b => {x[1] >= x[2] && (x[3] <= x[2] && (x[3] >= x[4] && x[4] > x[5])) && x in CS.AllDifferentSet()})
        
        @objective(m, Max, b)
        optimize!(m)
        CS.get_inner_model(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 1
        @test JuMP.value(b) ≈ 1
        vx = JuMP.value.(x)
        @test vx[1] > vx[2] && vx[2] > vx[3] && vx[3] > vx[4] && vx[4] > vx[5]

        # inner part is feasible have AndSet && AndSet 
        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "logging" => []
        ))
        @variable(m, 0 <= x[1:5] <= 4, Int)
        @variable(m, b, Bin)
        @constraint(m, b => {(x[1] >= x[2] && x[3] <= x[2]) && (x[3] >= x[4] && x[4] > x[5] && x in CS.AllDifferentSet())})
        
        @objective(m, Max, b)
        optimize!(m)
        CS.get_inner_model(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 1
        @test JuMP.value(b) ≈ 1
        vx = JuMP.value.(x)
        @test vx[1] > vx[2] && vx[2] > vx[3] && vx[3] > vx[4] && vx[4] > vx[5]
    end

    @testset "Table in reified where setting activator to false" begin
        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "logging" => []
        ))
        @variable(m, 1 <= x[1:5] <= 4, Int)
        @variable(m, b, Bin)
        @constraint(m, b => {x[1] > x[2] && [x[1],x[2]] in CS.TableSet([1 2; 1 3])})
        
        @objective(m, Max, 10b+sum(x))
        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 20
        @test JuMP.value(b) ≈ 0
    end

    @testset "Small test case for || in reified" begin
        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "logging" => []
        ))
        @variable(m, 1 <= x[1:5] <= 4, Int)
        @variable(m, b, Bin)
        @constraint(m, b := {(x[1] > x[2] || x in CS.AllDifferentSet()) })

        @objective(m, Max, 100b+sum(x))
        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL

        @test JuMP.value(b) ≈ 1.0
        @test JuMP.value.(x) ≈ [4,3,4,4,4]
        @test JuMP.objective_value(m) ≈ sum([4,3,4,4,4]) + 100
    end

    @testset "Small test case for || and && in reified" begin
        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "logging" => []
        ))
        @variable(m, 1 <= x[1:5] <= 4, Int)
        @variable(m, b, Bin)
        table = [
            4 0;
            3 2;
        ]
        @constraint(m, b := {(x[1] > x[2] || x in CS.AllDifferentSet()) && x[4:5] in CS.TableSet(table) })

        @objective(m, Max, 100b+sum(x))
        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL

        @test JuMP.value(b) ≈ 1.0
        @test JuMP.value.(x) ≈ [4,3,4,3,2]
        @test JuMP.objective_value(m) ≈ sum([4,3,4,3,2]) + 100
    end 

    @testset "Small test case for || and &&" begin
        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "logging" => []
        ))
        @variable(m, 1 <= x[1:5] <= 4, Int)
        table = [
            4 0;
            3 2;
        ]
        @constraint(m, (x[1] > x[2] || x in CS.AllDifferentSet()) && x[4:5] in CS.TableSet(table))

        @objective(m, Max, sum(x))
        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL

        @test JuMP.value.(x) ≈ [4,3,4,3,2]
        @test JuMP.objective_value(m) ≈ sum([4,3,4,3,2])
    end 

    @testset "Small test case for && and TableSet" begin
        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "logging" => [],
            "all_solutions" => true
        ))
        @variable(m, x[1:2], Bin)
        @variable(m, y[1:2], Bin)
        xor = [
            0 1;
            1 0;
        ]
        and = [
            1 1;
        ]
        @constraint(m, (x in CS.TableSet(xor) || y in CS.TableSet(and)))

        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL

        # x = 0 1 | y = 00 / 01 / 10 / 11
        # x = 1 0 | y = 00 / 01 / 10 / 11
        # y = 1 1 | x = 00 / 11 <- without double counting
        num_sols = MOI.get(m, MOI.ResultCount())
        @test num_sols == 10

        sets = [
            [0, 1, 0, 0],
            [0, 1, 0, 1],
            [0, 1, 1, 0],
            [0, 1, 1, 1],
            [1, 0, 0, 0],
            [1, 0, 0, 1],
            [1, 0, 1, 0],
            [1, 0, 1, 1],
            [0, 0, 1, 1],
            [1, 1, 1, 1]
        ]
        for i in 1:10
            found = false
            for j in 1:10
                if JuMP.value.([x...,y...]; result=j) == sets[i]
                    found = true
                    break
                end
            end
            @test found
        end
    end 

    @testset "Monks and Doors" begin
        model = Model(optimizer_with_attributes(CS.Optimizer,   "all_solutions"=> true,
                "logging"=>[],
                "traverse_strategy"=>:BFS,
                "branch_split"=>:InHalf,
                "branch_strategy" => :ABS,
        ))

        num_doors = 4
        num_monks = 8
        @variable(model, doors[1:num_doors], Bin)
        da,db,dc,dd = doors 
        door_names = ["A","B","C","D"]
    
        @variable(model, monks[1:num_monks], Bin)
        m1,m2,m3,m4,m5,m6,m7,m8 = monks
    
        # Monk 1: Door A is the exit.
        # M1 #= A (Picat constraint)
        @constraint(model, m1 == da)
    
        #  Monk 2: At least one of the doors B and C is the exit.
        # M2 #= 1 #<=> (B #\/ C)
        # @constraint(model, m2 := { db + dc >= 1})
        @constraint(model, m2 := { [db, dc] in CS.TableSet([
            1 0;
        ]) || dc == 1})
    
        #  Monk 3: Monk 1 and Monk 2 are telling the truth.
        # M3 #= 1 #<=> (M1 #/\ M2)
        # @constraint(model, m3 := { m1 + m2 == 2})
        # @constraint(model, m3 := { m1 == 1 && m2 == 1})
        @constraint(model, m3 := { m1 == 1 && m2 == 1})
    
        #  Monk 4: Doors A and B are both exits.
        # M4 #= 1 #<=> (A #/\ B)
        # @constraint(model, m4 := { da + db == 2})
        @constraint(model, m4 := { da == 1 && db == 1})
    
        #  Monk 5: Doors A and C are both exits.
        # M5 #= 1 #<=> (A #/\ C)
        # @constraint(model, m5 := { da + dc == 2})
        @constraint(model, m5 := { da == 1 && dc == 1})
    
        #  Monk 6: Either Monk 4 or Monk 5 is telling the truth.
        # M6 #= 1 #<=> (M4 #\/ M5)
        # @constraint(model, m6 := { m4 + m5 == 1})
        @constraint(model, m6 := { m4 == 1 || m5 == 1})
    
        #  Monk 7: If Monk 3 is telling the truth, so is Monk 6.
        # M7 #= 1 #<=> (M3 #=> M6)
        @constraint(model, m7 := { [m3, m6] in CS.TableSet([1 1; 0 0; 0 1;]) && [m3, m6] in CS.TableSet([1 1; 0 0; 0 1;]) }) 
        # @constraint(model, m7 := { m3 => m6})  # This don't work!
        # @constraint(model, m7 := { m3 => {m6 == 1}}) # This don't work either.
    
        #  Monk 8: If Monk 7 and Monk 8 are telling the truth, so is Monk 1.
        # M8 #= 1 #<=> ((M7 #/\ M8) #=> (M1))
        b1 = @variable(model, binary=true)
        # @constraint(model, b1 := {m7 + m8 == 2})
        @constraint(model, b1 := {m7 == 1 && [m7,m8] in CS.TableSet([1 1; 2 2; 3 3;])})
        @constraint(model, m8 := {b1 <= m1})
    
        # Exactly one door is an exit.
        # (A + B + C + D) #= 1
        @constraint(model, da + db + dc + dd == 1)

        optimize!(model)

        status = JuMP.termination_status(model)
        @test JuMP.termination_status(model) == MOI.OPTIMAL

        @test MOI.get(model, MOI.ResultCount()) == 1
        doors_val = convert.(Integer,JuMP.value.(doors))
        monks_val = convert.(Integer,JuMP.value.(monks))
        @test doors_val == [1, 0, 0, 0]
        @test monks_val == [1, 0, 0, 0, 0, 0, 1, 1]

        com = CS.get_inner_model(model)
        for var in com.search_space
            @test issorted(var.init_vals)
        end
    end
end
