var documenterSearchIndex = {"docs":
[{"location":"supported/#Supported-constraints-and-objectives-1","page":"Supported/Planned","title":"Supported constraints and objectives","text":"","category":"section"},{"location":"supported/#","page":"Supported/Planned","title":"Supported/Planned","text":"This solver is in a pre-release phase right now and not a lot of constraints or objectives are supported. If you want to be up to date you might want to check this page every couple of months. ","category":"page"},{"location":"supported/#","page":"Supported/Planned","title":"Supported/Planned","text":"You can also watch the project to be informed of every change but this might spam you ;)","category":"page"},{"location":"supported/#Supported-objectives-1","page":"Supported/Planned","title":"Supported objectives","text":"","category":"section"},{"location":"supported/#","page":"Supported/Planned","title":"Supported/Planned","text":"Currently the only objective supported is the linear objective i.e","category":"page"},{"location":"supported/#","page":"Supported/Planned","title":"Supported/Planned","text":"@objective(m, Min, 2x+3y)","category":"page"},{"location":"supported/#Supported-constraints-1","page":"Supported/Planned","title":"Supported constraints","text":"","category":"section"},{"location":"supported/#","page":"Supported/Planned","title":"Supported/Planned","text":"It's a bit more but still not as fully featured as I would like it to be.","category":"page"},{"location":"supported/#","page":"Supported/Planned","title":"Supported/Planned","text":"[X] Linear constraints\nAt the moment this is kind of partially supported as they are not really good at giving bounds yet\n[X] ==\n[X] <=\n[X] >=\n[X] All different\n@constraint(m, x[1:9] in CS.AllDifferentSet())\nCurrently you have to specify the length of vector\n[X] Support for !=\n[X] Supports a != b with a and b being single variables\n[X] Support for linear unequal constraints #66\n[ ] Cycle constraints","category":"page"},{"location":"supported/#","page":"Supported/Planned","title":"Supported/Planned","text":"If I miss something which would be helpful for your needs please open an issue.","category":"page"},{"location":"supported/#Additionally-1","page":"Supported/Planned","title":"Additionally","text":"","category":"section"},{"location":"supported/#","page":"Supported/Planned","title":"Supported/Planned","text":"[ ] adding new constraints after optimize! got called #72","category":"page"},{"location":"explanation/#Explanation-1","page":"Explanation","title":"Explanation","text":"","category":"section"},{"location":"explanation/#","page":"Explanation","title":"Explanation","text":"In this part I'll explain how the constraint solver works. You might want to read this either because you're just interested or because you might want to contribute to this project.","category":"page"},{"location":"explanation/#","page":"Explanation","title":"Explanation","text":"This project evolved during a couple of months and is more or less fully documented on my blog: Constraint Solver Series.","category":"page"},{"location":"explanation/#","page":"Explanation","title":"Explanation","text":"That is an ongoing project and there were a lot of changes especially at the beginning. Therefore here you can read just the current state in a shorter format.","category":"page"},{"location":"explanation/#General-concept-1","page":"Explanation","title":"General concept","text":"","category":"section"},{"location":"explanation/#","page":"Explanation","title":"Explanation","text":"The constraint solver works on a set of discrete bounded variables. In the solving process the first step is to go through all constraints and remove values which aren't possible i.e if we have a all_different([x,y]) constraint and x is fixed to 3 it can be removed from the possible set of values for y directly.","category":"page"},{"location":"explanation/#","page":"Explanation","title":"Explanation","text":"Now that y changed this might lead to further improvements by calling constraints where y is involved. By improvement I mean that the search space gets smaller.","category":"page"},{"location":"explanation/#","page":"Explanation","title":"Explanation","text":"After this step it might turn out that the problem is infeasible or solved but most of the time it's not yet known. That is when backtracking comes in to play.","category":"page"},{"location":"explanation/#Backtracking-1","page":"Explanation","title":"Backtracking","text":"","category":"section"},{"location":"explanation/#","page":"Explanation","title":"Explanation","text":"In backtracking we split the current model into several models in each of them we fix a variable to one particular value. This creates a tree structure. The constraint solver decides how to split the model into several parts. Most often it is useful to split it into a few parts rather than many parts. That means if we have two variables x and y and x has 3 possible values after the first step and y has 9 possible values we rather choose x to create three new branches in our tree than 9. This is useful as we get more information per solving step this way. ","category":"page"},{"location":"explanation/#","page":"Explanation","title":"Explanation","text":"After we fix a value we go into one of the open nodes. An open node is a node in the tree which we didn't split yet (it's a leaf node) and is neither infeasible nor is a fixed solution. ","category":"page"},{"location":"explanation/#","page":"Explanation","title":"Explanation","text":"There are two kind of problems which have a different backtracking strategy. One of them is a feasibility problem like solving sudokus and the other one is an optimization problem like graph coloring.","category":"page"},{"location":"explanation/#","page":"Explanation","title":"Explanation","text":"In the first way we try one branch until we reach a leaf node and then backtrack until we prove that the problem is infeasible or stop when we found a feasible solution.","category":"page"},{"location":"explanation/#","page":"Explanation","title":"Explanation","text":"For optimization problems a node is chosen which has the best bound (best possible objective) and if there are several ones the one with the highest depth is chosen.","category":"page"},{"location":"explanation/#","page":"Explanation","title":"Explanation","text":"In general the solver saves what changed in each step to be able to update the current search space when jumping to a different open node in the tree.","category":"page"},{"location":"options/#Solver-options-1","page":"Solver options","title":"Solver options","text":"","category":"section"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"This documentation lists all solver options and the default value in ()","category":"page"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"In general these options can be set as follows if you're using JuMP:","category":"page"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"m = Model(optimizer_with_attributes(CS.Optimizer, \"option_name\"=>option_value))","category":"page"},{"location":"options/#logging-([:Info,-:Table])-1","page":"Solver options","title":"logging ([:Info, :Table])","text":"","category":"section"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"Current possible symbols","category":"page"},{"location":"options/#","page":"Solver options","title":"Solver options","text":":Info\nShows info about how many variables are part of the model\nInfo about which constraints are present in the model\n:Table\nShows a table about the current solver status","category":"page"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"Output will be something like","category":"page"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"# Variables: 5\n# Constraints: 2\n - # Inequality: 2\n\n   #Open      #Closed         Incumbent             Best Bound        Time [s]  \n================================================================================\n     2           0                -                   44.20            0.0003  ","category":"page"},{"location":"options/#table-(TableSetup(...))-1","page":"Solver options","title":"table (TableSetup(...))","text":"","category":"section"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"Defines the exact table setup. The actual default is:","category":"page"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"TableSetup(\n        [:open_nodes, :closed_nodes, :incumbent, :best_bound, :duration],\n        [\"#Open\", \"#Closed\", \"Incumbent\", \"Best Bound\", \"[s]\"],\n        [10,10,20,20,10]; \n        min_diff_duration=5.0\n)","category":"page"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"which means that the open/closed nodes, the incumbent and the best bound is shown besides the duration of the optimization process. ","category":"page"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"[10,10,20,20,10] gives the width of each column\nmin_diff_duration=5.0 => a new row is added every 5 seconds or if a new solution was found.","category":"page"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"For satisfiability problems the incumbent and best bound are 0 so you could remove them. I'll probably add that ;)","category":"page"},{"location":"options/#time_limit-(Inf)-1","page":"Solver options","title":"time_limit (Inf)","text":"","category":"section"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"Time limit for backtracking in seconds. If reached before the problem was solved or infeasibility was proven will return the status MOI.TIME_LIMIT.","category":"page"},{"location":"options/#rtol-(1e-6)-1","page":"Solver options","title":"rtol (1e-6)","text":"","category":"section"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"Defines the relative tolerance of the solver.","category":"page"},{"location":"options/#atol-(1e-6)-1","page":"Solver options","title":"atol (1e-6)","text":"","category":"section"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"Defines the absolute tolerance of the solver.","category":"page"},{"location":"options/#lp_optimizer-(nothing)-1","page":"Solver options","title":"lp_optimizer (nothing)","text":"","category":"section"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"It is advised to use a linear problem solver like Cbc.jl if you have a lot of linear constraints and an optimization problem. The solver is used to compute bounds in the optimization steps.","category":"page"},{"location":"options/#traverse_strategy-(:Auto)-1","page":"Solver options","title":"traverse_strategy (:Auto)","text":"","category":"section"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"You can chose a traversal strategy for you model with this strategy. The default is choosing depending on the model. In feasibility problems depth first search is chosen and in optimization problems best first search. Other options:","category":"page"},{"location":"options/#","page":"Solver options","title":"Solver options","text":":BFS => Best First Search\n:DFS => Depth First Search\n:DBFS => Depth First Search until solution was found then Best First Search","category":"page"},{"location":"options/#branch_split-(:Smallest)-1","page":"Solver options","title":"branch_split (:Smallest)","text":"","category":"section"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"You can define how the variable is split into two branches with this option.  Normally the smallest value is chosen and then the problem gets split into the smallest value and the rest. Other options:","category":"page"},{"location":"options/#","page":"Solver options","title":"Solver options","text":":Biggest same as smallest but splits into biggest value as a single choice and the rest\n:InHalf takes the mean value to split the problem into two branches of equal size","category":"page"},{"location":"options/#all_solutions-(false)-1","page":"Solver options","title":"all_solutions (false)","text":"","category":"section"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"You can set this to true to get all feasible solutions. This can be used to get all solutions for a sudoku for example but maybe shouldn't be used for an optimization problem. Nevertheless I leave it here so you be able to use it even for optimization problems and get all feasible solutions.","category":"page"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"Look at all_optimal_solutions if you only want all solutions with the same optimum.","category":"page"},{"location":"options/#all_optimal_solutions-(false)-1","page":"Solver options","title":"all_optimal_solutions (false)","text":"","category":"section"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"You can set this to true to get optimal solutions. If you have a feasibility problem you can also use all_solutions but for optimization problems this will only return solutions with the same best incumbent.","category":"page"},{"location":"options/#backtrack-(true)-1","page":"Solver options","title":"backtrack (true)","text":"","category":"section"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"To solve the problem completely normally backtracking needs to be used but for some problems like certain sudokus this might not be necessary. This option is mostly there for debugging reasons to check the search space before backtracking starts.","category":"page"},{"location":"options/#max_bt_steps-(typemax(Int))-1","page":"Solver options","title":"max_bt_steps (typemax(Int))","text":"","category":"section"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"You can set the maximum amount of backtracking steps with this option. Probably you only want to change this if you want to debug some stuff.","category":"page"},{"location":"options/#backtrack_sorting-(true)-1","page":"Solver options","title":"backtrack_sorting (true)","text":"","category":"section"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"If set to true the order of new nodes is determined by their best bound. Otherwise they will be traversed in order they were added to the stack.","category":"page"},{"location":"options/#keep_logs-(false)-1","page":"Solver options","title":"keep_logs (false)","text":"","category":"section"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"Sometimes you might be interested in the exact way the problem got solved then you can set this option to true to get the full search tree.","category":"page"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"To save the logs as a json file you need to run:","category":"page"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"m = Model()\n...\ncom = JuMP.backend(m).optimizer.model.inner\n\nCS.save_logs(com, \"FILENAME.json\")","category":"page"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"Additionally because the mapping from JuMP can be different to your internal mapping you can use:","category":"page"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"CS.save_logs(com, \"FILENAME.json\", :x => x)","category":"page"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"if x is/are your variable/variables and if you have more variables:","category":"page"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"CS.save_logs(com, \"FILENAME.json\", :x => x, :y => y)","category":"page"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"etc...","category":"page"},{"location":"options/#solution_type-(Float64)-1","page":"Solver options","title":"solution_type (Float64)","text":"","category":"section"},{"location":"options/#","page":"Solver options","title":"Solver options","text":"Defines the type of best_bound and incumbent. Normally you don't want to change this as JuMP only works with Float but if you work directly using MathOptInterface you can use this option.","category":"page"},{"location":"reference/#Reference-1","page":"Reference","title":"Reference","text":"","category":"section"},{"location":"reference/#User-interface-functions-1","page":"Reference","title":"User interface functions","text":"","category":"section"},{"location":"reference/#","page":"Reference","title":"Reference","text":"ConstraintSolver.values(::Model, ::VariableRef)","category":"page"},{"location":"reference/#ConstraintSolver.values-Tuple{Model,VariableRef}","page":"Reference","title":"ConstraintSolver.values","text":"values(m::Model, v::VariableRef)\n\nReturn all possible values for the variable. (Only one if solved to optimality)\n\n\n\n\n\n","category":"method"},{"location":"#ConstraintSolver.jl-1","page":"Home","title":"ConstraintSolver.jl","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"Thanks for checking out the documentation of this constraint solver. The documentation is written in four different sections based on this post about how to write documentation.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"If you want to get a quick overview and just have a look at examples check out the tutorial.\nYou just have some How to questions? -> How to guide\nWhich constraints and objectives are supported? -> Supported constraints/objectives\nWhat solver options do exist? -> Solver options\nYou want to understand how it works deep down? Maybe improve it ;) -> Explanation\nGimme the code documentation directly! The reference section got you covered (It's not much currently)","category":"page"},{"location":"#","page":"Home","title":"Home","text":"If you have some questions please feel free to ask me by making an issue.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"You might be interested in the process of how I coded this: Checkout the full process on my blog opensourc.es.","category":"page"},{"location":"how_to/#How-To-Guide-1","page":"How-To","title":"How-To Guide","text":"","category":"section"},{"location":"how_to/#","page":"How-To","title":"How-To","text":"It seems like you have some specific questions about how to use the constraint solver.","category":"page"},{"location":"how_to/#How-to-create-a-simple-model?-1","page":"How-To","title":"How to create a simple model?","text":"","category":"section"},{"location":"how_to/#","page":"How-To","title":"How-To","text":"using JuMP, ConstraintSolver\nconst CS = ConstraintSolver\n\nm = Model(CS.Optimizer) \n@variable(m, 1 <= x <= 9, Int)\n@variable(m, 1 <= y <= 5, Int)\n\n@constraint(m, x + y == 14)\n\noptimize!(m)\nstatus = JuMP.termination_status(m)","category":"page"},{"location":"how_to/#How-to-add-a-uniqueness/all_different-constraint?-1","page":"How-To","title":"How to add a uniqueness/all_different constraint?","text":"","category":"section"},{"location":"how_to/#","page":"How-To","title":"How-To","text":"If you want that the values are all different for some variables you can use:","category":"page"},{"location":"how_to/#","page":"How-To","title":"How-To","text":"@constraint(m, vars in CS.AllDifferentSet()","category":"page"},{"location":"how_to/#","page":"How-To","title":"How-To","text":"where vars is an array of variables of the constraint solver i.e [x,y].","category":"page"},{"location":"how_to/#How-to-add-an-optimization-function-/-objective?-1","page":"How-To","title":"How to add an optimization function / objective?","text":"","category":"section"},{"location":"how_to/#","page":"How-To","title":"How-To","text":"Besides specifying the model you need to specify whether it's a minimization Min or maximization Max objective.","category":"page"},{"location":"how_to/#","page":"How-To","title":"How-To","text":"@objective(m, Min, x)","category":"page"},{"location":"how_to/#","page":"How-To","title":"How-To","text":"or for linear functions you would have something like:","category":"page"},{"location":"how_to/#","page":"How-To","title":"How-To","text":"@variable(m, x[1:4], Bin)\nweights = [0.2, -0.1, 0.4, -0.8]\n@objective(m, Min, sum(weights.*x))","category":"page"},{"location":"how_to/#","page":"How-To","title":"How-To","text":"Currently the only objective is to minimize or maximize a single variable or linear function.","category":"page"},{"location":"how_to/#","page":"How-To","title":"How-To","text":"More will come in the future ;)","category":"page"},{"location":"how_to/#How-to-get-the-solution?-1","page":"How-To","title":"How to get the solution?","text":"","category":"section"},{"location":"how_to/#","page":"How-To","title":"How-To","text":"If you define your variables x,y like shown in the simple model example you can get the value after solving with:","category":"page"},{"location":"how_to/#","page":"How-To","title":"How-To","text":"val_x = JuMP.value(x)\nval_y = JuMP.value(y)","category":"page"},{"location":"how_to/#","page":"How-To","title":"How-To","text":"or:","category":"page"},{"location":"how_to/#","page":"How-To","title":"How-To","text":"val_x, val_y = JuMP.value.([x,y])","category":"page"},{"location":"how_to/#How-to-get-the-state-before-backtracking?-1","page":"How-To","title":"How to get the state before backtracking?","text":"","category":"section"},{"location":"how_to/#","page":"How-To","title":"How-To","text":"For the explanation of the question look here.","category":"page"},{"location":"how_to/#","page":"How-To","title":"How-To","text":"Instead of solving the model directly you can have a look at the state before backtracking by setting an option of the ConstraintSolver:","category":"page"},{"location":"how_to/#","page":"How-To","title":"How-To","text":"m = Model(optimizer_with_attributes(CS.Optimizer, \"backtrack\"=>false))","category":"page"},{"location":"how_to/#","page":"How-To","title":"How-To","text":"and then check the variables using CS.values(m, x) or CS.values(m, y) this returns an array of possible values.","category":"page"},{"location":"how_to/#How-to-improve-the-bound-computation?-1","page":"How-To","title":"How to improve the bound computation?","text":"","category":"section"},{"location":"how_to/#","page":"How-To","title":"How-To","text":"You might have encountered that the bound computation is not good. If you haven't already you should check out the tutorial on bound computation. It is definitely advised that you use an LP solver for computing bounds. ","category":"page"},{"location":"tutorial/#Tutorial-1","page":"Tutorial","title":"Tutorial","text":"","category":"section"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"This is a series of tutorials to solve basic problems using the constraint solver.","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"Before we tackle some problems we first have to install the constraint solver.","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"$ julia\n] add https://github.com/Wikunia/ConstraintSolver.jl","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"The package is currently not an official package which is the reason why we need to specify the url here.","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"Then we have to use the package with:","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"using ConstraintSolver\nconst CS = ConstraintSolver","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"additionally we need to include the modelling package JuMP.jl with:","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"using JuMP","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"Solving:","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"Sudoku\nGraph coloring\nBetter bound computation","category":"page"},{"location":"tutorial/#Sudoku-1","page":"Tutorial","title":"Sudoku","text":"","category":"section"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"Everybody knows sudokus and for some it might be fun to solve them by hand. Today we want to use this constraint solver to let the computer do the hard work.","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"Rules of sudoku:     - We have 9x9 grid each cell contains a digit or is empty initially     - We have nine 3x3 blocks      - In the end we want to fill the grid such that       - Each row, column and block should have the digits 1-9 exactly once","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"We now have to translate this into code:","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"Defining the grid:","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"grid = [6 0 2 0 5 0 0 0 0;\n        0 0 0 0 0 3 0 4 0;\n        0 0 0 0 0 0 0 0 0;\n        4 3 0 0 0 8 0 0 0;\n        0 1 0 0 0 0 2 0 0;\n        0 0 0 0 0 0 7 0 0;\n        5 0 0 2 7 0 0 0 0;\n        0 0 0 0 0 0 0 8 1;\n        0 0 0 6 0 0 0 0 0]","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"0 represents an empty cell. Then we need a variable for each cell:","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"# creating a constraint solver model and setting ConstraintSolver as the optimizer.\nm = Model(CS.Optimizer) \n# define the 81 variables\n@variable(m, 1 <= x[1:9,1:9] <= 9, Int)\n# set variables if fixed\nfor r=1:9, c=1:9\n    if grid[r,c] != 0\n        @constraint(m, x[r,c] == grid[r,c])\n    end\nend","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"For the empty cell we create a variable with possible values 1-9 and otherwise we do the same but fix the value to the given cell value.","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"Then we define the constraints:","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"for rc = 1:9\n    @constraint(m, x[rc,:] in CS.AllDifferentSet())\n    @constraint(m, x[:,rc] in CS.AllDifferentSet())\nend","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"For each row and column (1-9) we create an AllDifferent constraint which specifies that all the variables should have a different value in the end using CS.AllDifferentSet(). As there are always nine variables and nine digits each value 1-9 is set exactly once per row and column.","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"Now we need to add the constraints for the 3x3 blocks:","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"for br=0:2\n    for bc=0:2\n        @constraint(m, vec(x[br*3+1:(br+1)*3,bc*3+1:(bc+1)*3]) in CS.AllDifferentSet())\n    end\nend","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"Then we call the solve function of JuMP called optimize with the model as the only parameter.","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"optimize!(m)","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"Attention: This might take a while for the first solve as everything needs to be compiled but the second time it will be fast.","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"The status of the model can be extracted by:","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"status = JuMP.termination_status(m)","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"This returns a MOI StatusCode which are explained here.","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"In our case it returns MOI.OPTIMAL. If we want to get the solved sudoku we can use:","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"@show convert.(Integer,JuMP.value.(x))","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"which outputs:","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"6  8  2  1  5  4  3  7  9\n9  5  1  7  6  3  8  4  2\n3  7  4  8  9  2  1  6  5\n4  3  7  5  2  8  9  1  6\n8  1  6  9  3  7  2  5  4\n2  9  5  4  1  6  7  3  8\n5  6  8  2  7  1  4  9  3\n7  2  9  3  4  5  6  8  1\n1  4  3  6  8  9  5  2  7","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"If you want to get a single value you can i.e use JuMP.value(com_grid[1]).","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"In the next part you'll learn a different constraint type and how to include an optimization function.","category":"page"},{"location":"tutorial/#Graph-coloring-1","page":"Tutorial","title":"Graph coloring","text":"","category":"section"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"The goal is to color a graph in such a way that neighboring nodes have a different color. This can also be used to color a map.","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"We want to find the coloring which uses the least amount of colors.","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"m = Model(CS.Optimizer)\nnum_colors = 10\n\n@variable(m, 1 <= countries[1:5] <= num_colors, Int)\ngermany, switzerland, france, italy, spain = countries","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"I know this is only a small example but you can easily extend it. In the above case we assume that we don't need more than 10 colors.","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"Adding the constraints:","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"@constraint(m, germany != france)\n@constraint(m, germany != switzerland)\n@constraint(m, france != spain)\n@constraint(m, france != switzerland)\n@constraint(m, france != italy)\n@constraint(m, switzerland != italy)","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"If we call optimize!(m) now we probably don't get a coloring with the least amount of colors.","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"We can get this by adding:","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"@variable(m, 1 <= max_color <= num_colors, Int)\n@constraint(m, max_color .>= countries)\n@objective(m, Min, max_color)\noptimize!(m)\nstatus = JuMP.termination_status(m)","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"We can get the value for each variable using JuMP.value(germany) for example or as before print the values:","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"println(JuMP.value.(countries))","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"and getting the maximum color used with ","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"println(\"#colors: $(JuMP.value(max_color))\")","category":"page"},{"location":"tutorial/#Bound-computation-1","page":"Tutorial","title":"Bound computation","text":"","category":"section"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"In this section you learn how to combine the alldifferent constraint and a sum constraint as well as using an objective function. When using a linear objective function it is useful to get good bounds to find the optimal solution faster and proof optimality. There is a very very basic bound computation build into the ConstraintSolver itself by just having a look at the maximum and minium values per variable. However this is a very bad estimate most of the time i.e for less than constraints.","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"If we have","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"m = Model(CS.Optimizer) \n@variable(m, 0 <= x[1:10] <= 15, Int)\n@constraint(m, sum(x) <=  15)\n@objective(m, Max, sum(x))","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"Each variable itself can have all values but the objective bound is of course 15 and not 150. Instead of building this directly into the ConstraintSolver I decided  to instead get help by a linear solver of your choice. You can use this with the option lp_optimizer:","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"cbc_optimizer = optimizer_with_attributes(Cbc.Optimizer, \"logLevel\" => 0)\nm = Model(optimizer_with_attributes(\n    CS.Optimizer,\n    \"lp_optimizer\" => cbc_optimizer,\n))\n@variable(m, 0 <= x[1:10] <= 15, Int)\n@constraint(m, sum(x) <=  15)\n@objective(m, Max, sum(x))\noptimize!(m)","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"It creates an LP with all supported constraints so <=, >=, ==. The ConstraintSolver will then work as the branch and bound part to solve the discrete problem. This is currently slower for problems that you can formulate directly as a MIP as the one above but now you can solve problems like:","category":"page"},{"location":"tutorial/#","page":"Tutorial","title":"Tutorial","text":"cbc_optimizer = optimizer_with_attributes(Cbc.Optimizer, \"logLevel\" => 0)\nm = Model(optimizer_with_attributes(\n    CS.Optimizer,\n    \"lp_optimizer\" => cbc_optimizer,\n))\n@variable(m, 0 <= x[1:10] <= 15, Int)\n@constraint(m, sum(x) >= 10)\n@constraint(m, x[1:5] in CS.AllDifferentSet())\n@constraint(m, x[6:10] in CS.AllDifferentSet())\n@objective(m, Min, sum(x))\noptimize!(m)","category":"page"}]
}
