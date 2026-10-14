using Plots
using Dates
import CairoMakie as CM
using YAML


function _load_labels(filepath::String)
    raw_data = YAML.load_file(filepath)
    Dict(
        lang => Dict(Symbol(k) => v for (k, v) in inner_dict)
        for (lang, inner_dict) in raw_data
    )
end

function _load_styles(filepath::String)
    raw_data = YAML.load_file(filepath)
    Dict(
        style_name => Dict(Symbol(k) => v for (k, v) in style_dict)
        for (style_name, style_dict) in raw_data
    )
end

const LABELS = _load_labels(joinpath(dirname(@__DIR__), "cfgs", "labels.yaml"))
const STYLES = _load_styles(joinpath(dirname(@__DIR__), "cfgs", "styles.yaml"))



function plotting(res::SimulationResults, p, experiment)
    (; style, dpi, language) = p

    plots_dict = Dict{Symbol, Any}()

    if p.layer_temperatures
        plots_dict[:soil_temperatures] = plot_temperatures(res; style = style, dpi = dpi, lang = language)
    end

    if p.heat_fluxes
        plots_dict[:soil_heat_fluxes] = plot_heat_fluxes(res; style = style, dpi = dpi, lang = language)
    end

    if p.total_energy
        plots_dict[:soil_energy] = plot_energy(res; style = style, dpi = dpi, lang = language)
    end

    if p.temperature_animation
        make_video(res, experiment.out_folder, experiment.id;
                   style = style, dpi = dpi, lang = language)
    end

    return plots_dict
end



function plot_temperatures(res::SimulationResults; style, dpi, lang)
    st  = _get_plot_theme(style, dpi, lang)
    t_h = res.grid.ts ./ 3600.0
    
    zlayers = length(res.grid.depths)
    xlayers = length(res.grid.widths)
    total_cells = zlayers * xlayers

    T_all = permutedims(reshape(res.T, total_cells, length(t_h)))

    labels = String[]
    for x in 1:xlayers
        for z in 1:zlayers
            push!(labels, "$(st.labels[:cell]) (z=$z, x=$x)")
        end
    end

    cols = palette(:viridis, total_cells + 1)[1:total_cells]
    show_legend = total_cells <= 12 ? :outerright : false

    p = plot(
        t_h, T_all;
        label     = permutedims(labels),
        color     = permutedims(cols),
        xlabel    = st.labels[:time],
        ylabel    = st.labels[:temp],
        title     = st.labels[:temp_title],
        linewidth = st.linewidth,
        grid      = true,
        legend    = show_legend,
        titlefont = st.titlefont, guidefont = st.guidefont, tickfont = st.tickfont, legendfont = st.legendfont,
        dpi       = dpi
    )
    plot!(p, t_h, res.T_top; label = st.labels[:top_border], color = :red, linestyle = :dash, linewidth = st.linewidth)
    plot!(p, t_h, res.T_bottom; label = st.labels[:bot_border], color = :blue, linestyle = :dash, linewidth = st.linewidth)

    return p
end

function plot_heat_fluxes(res::SimulationResults; style, dpi, lang)
    st  = _get_plot_theme(style, dpi, lang)
    t_h = res.grid.ts ./ 3600.0

    zlayers = length(res.grid.depths)
    xlayers = length(res.grid.widths)

    qz_total_interfaces = (zlayers + 1) * xlayers
    qz_all = permutedims(reshape(res.qz, qz_total_interfaces, length(t_h)))

    labels_qz = String[]
    for x in 1:xlayers
        for z in 1:(zlayers + 1)
            push!(labels_qz, "qz(z=$z, x=$x)")
        end
    end

    cols_qz = palette(:viridis, qz_total_interfaces + 1)[1:qz_total_interfaces]
    legend_qz = qz_total_interfaces <= 12 ? :outerright : false

    p1 = plot(
        t_h, qz_all;
        label     = permutedims(labels_qz),
        color     = permutedims(cols_qz),
        xlabel    = st.labels[:time], ylabel = "qz [W/m²]",
        title     = st.labels[:qz_title],
        linewidth = st.linewidth, legend = legend_qz,
        titlefont = st.titlefont, guidefont = st.guidefont, tickfont = st.tickfont, legendfont = st.legendfont,
        dpi       = dpi
    )

    if xlayers > 1
        qx_total_interfaces = zlayers * (xlayers + 1)
        qx_all = permutedims(reshape(res.qx, qx_total_interfaces, length(t_h)))

        labels_qx = String[]
        for x in 1:(xlayers + 1)
            for z in 1:zlayers
                push!(labels_qx, "qx(z=$z, x=$x)")
            end
        end

        cols_qx = palette(:plasma, qx_total_interfaces + 1)[1:qx_total_interfaces]
        legend_qx = qx_total_interfaces <= 12 ? :outerright : false

        p2 = plot(
            t_h, qx_all;
            label     = permutedims(labels_qx),
            color     = permutedims(cols_qx),
            xlabel    = st.labels[:time], ylabel = "qx [W/m²]",
            title     = st.labels[:qx_title],
            linewidth = st.linewidth, legend = legend_qx,
            titlefont = st.titlefont, guidefont = st.guidefont, tickfont = st.tickfont, legendfont = st.legendfont,
            dpi       = dpi
        )
        return plot(p1, p2, layout = (2, 1), dpi = dpi)
    else
        return p1
    end
end

function plot_energy(res::SimulationResults; style, dpi, lang)
    st  = _get_plot_theme(style, dpi, lang)
    t_h = res.grid.ts ./ 3600.0

    return plot(
        t_h, res.soil_energy;
        label     = st.labels[:energy_label],
        xlabel    = st.labels[:time], ylabel = st.labels[:energy_unit],
        title     = st.labels[:energy_title],
        linewidth = st.linewidth, grid = true, legend = false,
        titlefont = st.titlefont, guidefont = st.guidefont, tickfont = st.tickfont, dpi = dpi
    )
end

function make_video(res::SimulationResults, out_folder::AbstractString, id::AbstractString; style, dpi, lang)
    st     = _get_plot_theme(style, dpi, lang)
    outdir = joinpath(out_folder, "plots")
    prefix = id
    mkpath(outdir)

    ts  = res.grid.ts
    t_h = ts ./ 3600.0

    widths  = res.grid.widths
    xlayers = length(widths)
    zlayers = length(res.grid.depths)

    xedges = [0.0; cumsum(collect(Float64, widths))]
    zedges = collect(Float64, res.grid.zlevels)

    n_saves = size(res.T, 3)
    dt_save = length(ts) > 1 ? (ts[2] - ts[1]) : 1.0
    step    = max(1, round(Int, 3600 / dt_save))
    frames  = 1:step:n_saves

    T_min, T_max = floor(minimum(res.T)), ceil(maximum(res.T))

    frame_matrix(i) = permutedims(res.T[:, :, i], (2, 1))

    T_obs     = CM.Observable(frame_matrix(first(frames)))
    title_obs = CM.Observable("")

    fig = CM.Figure(size = (600, 700), fontsize = 14)
    ax  = CM.Axis(fig[1, 1];
        xlabel    = st.labels[:video_x],
        ylabel    = st.labels[:video_z],
        title     = title_obs,
        limits    = (xedges[1], xedges[end], zedges[1], zedges[end]),
        yreversed = true
    )

    hm = CM.heatmap!(ax, xedges, zedges, T_obs;
        colormap    = :thermal,
        colorrange  = (T_min, T_max),
        interpolate = false
    )
    CM.Colorbar(fig[1, 2], hm; label = st.labels[:temp])

    path = joinpath(outdir, "$(prefix)_temperature_animation.mp4")

    CM.record(fig, path, frames; framerate = 12) do i
        T_obs[]     = frame_matrix(i)
        title_obs[] = "$(st.labels[:video_title])$(round(t_h[i]; digits = 1)) h"
    end

    @info "[INFO] MP4 animation saved to: $path"
end



function _get_plot_theme(style::String, dpi::Int, lang::String)
    labels = LABELS[lang]
    cfg = STYLES[style]

    return (
        titlefont  = font(cfg[:titlefont_size], cfg[:titlefont_family]),
        guidefont  = font(cfg[:guidefont_size], cfg[:guidefont_family]),
        tickfont   = font(cfg[:tickfont_size], cfg[:tickfont_family]),
        legendfont = font(cfg[:legendfont_size], cfg[:legendfont_family]),
        linewidth  = cfg[:linewidth],
        dpi        = dpi,
        labels     = labels
    )
end

function _fine_index_map(edges::AbstractVector, n_fine::Int)
    lo, hi = first(edges), last(edges)
    n      = length(edges) - 1
    pix    = range(lo, hi; length = n_fine + 1)
    mid    = (pix[1:end-1] .+ pix[2:end]) ./ 2
    idx    = [clamp(searchsortedlast(edges, m), 1, n) for m in mid]
    return lo, hi, idx
end
