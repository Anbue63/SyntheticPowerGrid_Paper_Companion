using Pkg
Pkg.activate(joinpath(@__DIR__, "../"))
using Revise
using SyntheticPowerGridsPaper

using SyntheticPowerGrids
using PowerDynamics
using OrdinaryDiffEq
using PowerGridNoise  
using Interpolations
using Statistics
using DelimitedFiles

## Loading a synthetic Power Grid consisting of droop controlled inverters
file_path = joinpath(@__DIR__, "../data/powergrids/synthetic_power_grid_example.json")
pg = read_powergrid(file_path, Json) 
op = find_operationpoint(pg)

ω_nodes, nodes, fluc_node_idxs, P_set, Q_set, f_idx = nodal_data(pg) # Accessing the node data from the grid
Δt = 0.001

## Load all solar time series
file_paths = readdir("data/PVDataSet", join = true)
P_pv_arr = Vector{Vector{Float64}}(undef, length(file_paths)) 

iter = 1

for path in file_paths
    P_pv_temp = readdlm(path) # Load the time series
    P_pv_temp = P_pv_temp[:, 1] # Turn Matrix to an array

    nan_idxs = findall(typeof.(P_pv_temp) .!== Float64) # find all NaNs
    deleteat!(P_pv_temp, nan_idxs)

    P_pv_temp .-= mean(P_pv_temp) # Shifting the mean such that only the fluctuations are left

    P_pv_arr[iter] = P_pv_temp[191:end] # Throw away beginning of the time series!
    
    iter += 1
end

## Interpolate the time series
P_pv_corr = P_pv_arr[1]
t = collect(range(0.0, length = length(P_pv_corr), step = Δt))
tspan = (0.0, t[end])
P_pv_inter = linear_interpolation(t, P_pv_corr)

## Multi Node Fluctuations, completely correlated, exchange all PQAlgebraic with FluctuationNode
fluctuations_corr = map(f -> FluctuationNode(t -> P_set[f] + P_pv_inter(t), t -> Q_set[f]), 1:length(fluc_node_idxs))
pg_solar = generate_powergrid_fluctuations(pg, fluc_node_idxs, fluctuations_corr)

ode = ODEProblem(rhs(pg_solar), op.vec, tspan)
sol = solve(ode, Rodas4(), maxiters = 10^6)
pg_sol = PowerGridSolution(sol, pg_solar)

step_size = round(mean(diff(sol.t)), digits = 3)
t_stops = collect(tspan[1]:step_size:tspan[end])

writedlm("data/solar_fluctuations/corr/frequencies.txt", sol(t_stops, idxs = f_idx).u./(2π))
writedlm("data/solar_fluctuations/corr/powers.txt", transpose(pg_sol(t_stops, fluc_node_idxs, :p)))
writedlm("data/solar_fluctuations/corr/rocof.txt", sol(t_stops, Val{1}, idxs = f_idx).u./(2π))

## Multi Node Fluctuations, completely uncorrelated
P_pv_inter = map(f -> linear_interpolation(t, P_pv_arr[f]), 1:length(fluc_node_idxs)) # Interpolate the time series
fluctuations_uncorr = map(f -> FluctuationNode(t -> P_set[f] + P_pv_inter[f](t), t -> Q_set[f]), 1:length(fluc_node_idxs))
pg_solar = generate_powergrid_fluctuations(pg, fluc_node_idxs, fluctuations_uncorr)

ode = ODEProblem(rhs(pg_solar), op.vec, tspan)
sol = solve(ode, Rodas4(), maxiters = 10^6)
pg_sol = PowerGridSolution(sol, pg_solar)

step_size = round(mean(diff(sol.t)), digits = 3)
t_stops = collect(tspan[1]:step_size:tspan[end])

writedlm("data/solar_fluctuations/uncorr/frequencies.txt", sol(t_stops, idxs = f_idx).u./(2π))
writedlm("data/solar_fluctuations/uncorr/powers.txt", transpose(pg_sol(t_stops, fluc_node_idxs, :p)))
writedlm("data/solar_fluctuations/uncorr/rocof.txt", sol(t_stops, Val{1}, idxs = f_idx).u./(2π))
