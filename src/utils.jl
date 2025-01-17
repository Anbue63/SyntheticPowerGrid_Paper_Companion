function nodal_data(pg::PowerGrid)
    ω_nodes = findall(n -> :x_1 ∈ symbolsof(n), pg.nodes)
    f_idx = findall(s -> occursin(Regex("x_1_"), String(s)), rhs(pg).syms)

    nodes = deepcopy(pg.nodes) 
    fluc_node_idxs = findall(typeof.(pg.nodes) .== PQAlgebraic) # Find all Load Buses in the grid
    P_set = map(i -> nodes[i].P, fluc_node_idxs) # Load their power set-points
    Q_set = map(i -> nodes[i].Q, fluc_node_idxs)

    return ω_nodes, nodes, fluc_node_idxs, P_set, Q_set, f_idx
end

function R_squared(y, f)
    e = y .- f
    y_mean = mean(y)
    
    SS_res = sum(e.^2)
    SS_tot = sum((y .- y_mean).^2)

    R_2 = 1 - SS_res / SS_tot

    return R_2
end