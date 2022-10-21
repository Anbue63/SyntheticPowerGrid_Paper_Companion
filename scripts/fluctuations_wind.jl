using Pkg
Pkg.activate(joinpath(@__DIR__, "../"))
using Revise
using SyntheticPowerGridsPaper

using SyntheticPowerGrids
using PowerDynamics
using OrdinaryDiffEq
using Plots
using PowerGridNoise
using Interpolations
using Statistics
using LaTeXStrings
using DelimitedFiles
default(grid = false, foreground_color_legend = nothing, bar_edges = false,  lw=1.5, framestyle =:box, msc = :auto, dpi=300, legendfontsize = 11, labelfontsize = 15, tickfontsize = 10)

##
# Generating a synthetic Power Grid consisting of droop controlled inverters
nodal_parameters = Dict(:τ_Q => 5.0, :K_P => 5, :K_Q => 0.1, :τ_P => 0.5)

nodal_dynamics = [(0.5, get_DroopControlledInverterApprox, nodal_parameters), (0.5, get_PQ, nothing)]
num_nodes = 100

a = PGGeneration(num_nodes = num_nodes, nodal_dynamics = nodal_dynamics)
pg, op, pg_struct_new, rejections = generate_powergrid_dynamics(a)

##
# Accessing the node data from the grid
ω_indices = findall(n -> :x_1 ∈ symbolsof(n), pg.nodes)
nodes = deepcopy(pg.nodes) 
fluc_node_idxs = findall(typeof.(pg.nodes) .== PQAlgebraic) # Find all Load Buses in the grid
P_set = map(i -> nodes[i].P, fluc_node_idxs) # Load their power set-points
Q_set = map(i -> nodes[i].Q, fluc_node_idxs)

##
# Using an intermittent wind power fluctuation Langevin-type model to generate fluctuating time series
tspan = (0.0, 1000.0)
Δt = 10000.0
D = 0.1 # Intermittence strength
p = 0.2 # Penetration parameter
x, t = wind_power_model(tspan, D = D, Δt = Δt)
x_inter = linear_interpolation(t, x) # Interpolate the time series

##
# Multi Node Fluctuations, completely correlated, exchange all PQAlgebraic with FluctuationNode
fluctuations_corr = map(f -> FluctuationNode(t -> P_set[f] + p * x_inter(t), t -> Q_set[f]), 1:length(fluc_node_idxs))
pg_wind_corr = generate_powergrid_fluctuations(pg, fluc_node_idxs, fluctuations_corr)

##
# Simulate a trajectory
ode = ODEProblem(rhs(pg_wind_corr), op.vec, tspan)
sol_corr = solve(ode, Rodas4())
pg_sol_corr_wind = PowerGridSolution(sol_corr, pg_wind_corr)

##
# Results
plt_uncorr_active_power, plt_uncorr_frequency, plt_uncorr_voltage, hist_uncorr_voltage, hist_uncorr_frequency = plot_fluc_results(pg_sol_corr_wind, fluc_node_idxs, ω_indices)

savefig(plt_uncorr_active_power, "plots/wind_fluc/multi_node_wind_fluc_correlated_active_power.png")
savefig(plt_uncorr_frequency, "plots/wind_fluc/multi_node_wind_fluc_correlated_frequency.png")
savefig(plt_uncorr_voltage, "plots/wind_fluc/multi_node_wind_fluc_correlated_voltage.png")
savefig(hist_uncorr_voltage, "plots/wind_fluc/multi_node_wind_fluc_correlated_voltage_histogram.png")
savefig(hist_uncorr_frequency, "plots/wind_fluc/multi_node_wind_fluc_correlated_frequency_histogram.png")

mean_norm, sync_norm = calculate_performance_measures(pg_sol_corr_wind) # calculate performance measures

writedlm("data/wind_fluctuations/performance_measures_wind_correlated.txt", [mean_norm, sync_norm])

##
# Multi Node Fluctuations , completely uncorrelated, exchange all PQAlgebraic with FluctuationNode
# Generate a time series for each node

flucs = [wind_power_model(tspan, D = D, Δt = Δt) for x in 1:length(fluc_node_idxs)]
x_inter = map(f -> linear_interpolation(flucs[f][2], flucs[f][1]), 1:length(fluc_node_idxs)) # Interpolate the time series
fluctuations_uncorr = map(f -> FluctuationNode(t -> P_set[f] + p * x_inter[f](t), t -> Q_set[f]), 1:length(fluc_node_idxs))
pg_wind_uncorr = generate_powergrid_fluctuations(pg, fluc_node_idxs, fluctuations_uncorr)

##
# Simulate a trajectory
ode = ODEProblem(rhs(pg_wind_uncorr), op.vec, tspan)
sol_uncorr = solve(ode, Rodas4())
pg_sol_uncorr_wind = PowerGridSolution(sol_uncorr, pg_wind_uncorr)

##
# Results
plt_uncorr_active_power, plt_uncorr_frequency, plt_uncorr_voltage, hist_uncorr_voltage, hist_uncorr_frequency = plot_fluc_results(pg_sol_uncorr_wind, fluc_node_idxs, ω_indices)

savefig(plt_uncorr_active_power, "plots/wind_fluc/multi_node_wind_fluc_uncorrelated_active_power.png")
savefig(plt_uncorr_frequency, "plots/wind_fluc/multi_node_wind_fluc_uncorrelated_frequency.png")
savefig(plt_uncorr_voltage, "plots/wind_fluc/multi_node_wind_fluc_uncorrelated_voltage.png")
savefig(hist_uncorr_voltage, "plots/wind_fluc/multi_node_wind_fluc_uncorrelated_voltage_histogram.png")
savefig(hist_uncorr_frequency, "plots/wind_fluc/multi_node_wind_fluc_uncorrelated_frequency_histogram.png")

mean_norm, sync_norm = calculate_performance_measures(pg_sol_uncorr_wind) # calculate performance measures

writedlm("data/wind_fluctuations/performance_measures_wind_uncorrelated.txt", [mean_norm, sync_norm])