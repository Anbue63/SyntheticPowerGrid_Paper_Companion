function plot_fluc_results(solution::PowerGridSolution, fluc_node_idxs, ω_indices)
    plt_active_power = plot(solution, fluc_node_idxs, :p, lw = 3, ylabel = L"P[p.u.]", xlabel = L"t[s]", legend = false)

    plt_frequency = plot(solution, ω_indices, :x_1, legend = false, ylabel = L"ω[rad / s]", xlabel = L"t[s]")

    plt_voltage = plot(solution, :, :v, legend = false, ylabel = L"V [p.u.]", xlabel = L"t[s]")

    
    return plt_active_power, plt_frequency, plt_voltage
end

function plot_histograms(solution::PowerGridSolution, ω_indices)
    hist_voltage = histogram(vcat(solution(solution.dqsol.t, :, :v)...), legend = false, xlabel = L"V [p.u.]", color = colorant"darkgoldenrod1", linecolor = :match)
    hist_frequency = histogram(vcat(solution(solution.dqsol.t, ω_indices, :x_1)...), legend = false, xlabel =  L"ω[rad / s]", color = colorant"turquoise3", linecolor = :match)

    return hist_voltage, hist_frequency
end

"""
    function my_graph_plot(pg::PowerGrid, label_nodes = [])

Using GraphMakie to plot the power grid topology.
"""
function my_graph_plot(pg::PowerGrid, label_nodes = [])
    num_nodes = length(pg.nodes)
    load_idxs = findall(typeof.(pg.nodes) .== PQAlgebraic)

    node_color = fill(colorant"coral", num_nodes)
    node_color[load_idxs] .= colorant"teal"

    node_marker = fill(:circle, num_nodes)
    node_marker[load_idxs] .= :utriangle

    if label_nodes != []
        node_label = fill("", num_nodes)
        if length(label_nodes) == 1
            node_label[label_nodes] = string(label_nodes)
        else    
            map(n -> node_label[n] = string(n), label_nodes)
        end
        f, ax, p = graphplot(pg.graph, node_marker = node_marker, nlabels = node_label, node_color = node_color)
        hidedecorations!(ax); hidespines!(ax)
    else
        f, ax, p = graphplot(pg.graph, node_marker = node_marker, node_color = node_color)
        hidedecorations!(ax); hidespines!(ax)
    end
    return f
end