using Plots
import CairoMakie as CM

# ==========================================
# 0. Estilos e Idiomas
# ==========================================
const LABELS = Dict(
    "spanish" => Dict(
        :cell => "Celda",
        :time => "Tiempo [h]",
        :temp => "Temperatura [K]",
        :temp_title => "Evolución Temporal de Temperatura (Todas las Celdas Z x X)",
        :top_border => "Borde Sup. (T_top)",
        :bot_border => "Borde Inf. (T_bot)",
        :qz_title => "Flujos Verticales qz (Todas las Interfaces)",
        :qx_title => "Flujos Horizontales qx (Todas las Interfaces)",
        :energy_label => "Energía Suelo",
        :energy_title => "Energía Acumulada",
        :energy_unit => "Energía [J]",
        :video_x => "Ancho X [m]",
        :video_z => "Profundidad Z [m]",
        :video_title => "Campo 2D de Temperatura · t = "
    ),
    "english" => Dict(
        :cell => "Cell",
        :time => "Time [h]",
        :temp => "Temperature [K]",
        :temp_title => "Temporal Temperature Evolution (All Z x X Cells)",
        :top_border => "Top Boundary (T_top)",
        :bot_border => "Bottom Boundary (T_bot)",
        :qz_title => "Vertical Heat Fluxes qz (All Interfaces)",
        :qx_title => "Horizontal Heat Fluxes qx (All Interfaces)",
        :energy_label => "Soil Energy",
        :energy_title => "Accumulated Energy",
        :energy_unit => "Energy [J]",
        :video_x => "Width X [m]",
        :video_z => "Depth Z [m]",
        :video_title => "2D Temperature Field · t = "
    ),
    "catalan" => Dict(
        :cell => "Cel·la",
        :time => "Temps [h]",
        :temp => "Temperatura [K]",
        :temp_title => "Evolució Temporal de Temperatura (Totes les Cel·les Z x X)",
        :top_border => "Llímit Sup. (T_top)",
        :bot_border => "Llímit Inf. (T_bot)",
        :qz_title => "Fluxos Verticals qz (Totes les Interfícies)",
        :qx_title => "Fluxos Horitzontals qx (Totes les Interfícies)",
        :energy_label => "Energia Sòl",
        :energy_title => "Energia Acumulada",
        :energy_unit => "Energia [J]",
        :video_x => "Amplada X [m]",
        :video_z => "Profunditat Z [m]",
        :video_title => "Camp 2D de Temperatura · t = "
    )
)

function get_plot_theme(style::String, dpi::Int, lang::String = "english")
    labels = LABELS[lang]

    if style == "paper"
        return (
            titlefont  = font(10, "DejaVu Sans"),
            guidefont  = font(9, "DejaVu Sans"),
            tickfont   = font(8, "DejaVu Sans"),
            legendfont = font(7, "DejaVu Sans"),
            linewidth  = 1.5,
            dpi        = dpi,
            labels     = labels
        )
    elseif style == "presentation"
        return (
            titlefont  = font(14, "DejaVu Sans Bold"),
            guidefont  = font(12, "DejaVu Sans"),
            tickfont   = font(10, "DejaVu Sans"),
            legendfont = font(9, "DejaVu Sans"),
            linewidth  = 2.5,
            dpi        = dpi,
            labels     = labels
        )
    else 
        LOG && @error "[ERROR] Not a valid style."
    end
end


function plot_temperatures(res; style = "paper", dpi = 300, lang = "spanish")
    st  = get_plot_theme(style, dpi, lang)
    t_h = res.grid.ts ./ 3600.0
    
    zlayers = length(res.grid.depths)
    xlayers = length(res.grid.widths)
    total_cells = zlayers * xlayers

    # Desenrollamos la matriz 3D (n_ts, zlayers, xlayers) a 2D (n_ts, zlayers * xlayers)
    # manteniendo cada celda (z, x) independiente
    T_all = reshape(res.T, length(t_h), total_cells)

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

function plot_heat_fluxes(res; style = "paper", dpi = 300, lang = "spanish")
    st  = get_plot_theme(style, dpi, lang)
    t_h = res.grid.ts ./ 3600.0

    zlayers = length(res.grid.depths)
    xlayers = length(res.grid.widths)

    # 1. Flujos Verticales qz: (n_ts, zlayers + 1, xlayers)
    qz_total_interfaces = (zlayers + 1) * xlayers
    qz_all = reshape(res.qz, length(t_h), qz_total_interfaces)

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

    # 2. Flujos Horizontales qx: (n_ts, zlayers, xlayers + 1)
    if xlayers > 1
        qx_total_interfaces = zlayers * (xlayers + 1)
        qx_all = reshape(res.qx, length(t_h), qx_total_interfaces)

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

function plot_energy(res; style = "paper", dpi = 300, lang = "spanish")
    st  = get_plot_theme(style, dpi, lang)
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

# ==========================================
# 2. Animación MP4 2D
# ==========================================

function make_video(res; style = "paper", dpi = 300, lang = "spanish")
    st     = get_plot_theme(style, dpi, lang)
    outdir = joinpath(OUT_FOLDER, "plots")
    prefix = ID
    mkpath(outdir)

    zlayers = length(res.grid.depths)
    xlayers = length(res.grid.widths)
    t_h     = res.grid.ts ./ 3600.0
    depths  = res.grid.depths
    widths  = res.grid.widths

    dt     = res.grid.ts[2] - res.grid.ts[1]
    step   = max(1, round(Int, 3600 / dt))
    frames = 1:step:length(t_h)

    T_min, T_max = floor(minimum(res.T)), ceil(maximum(res.T))

    T_obs     = CM.Observable(zeros(xlayers, zlayers))
    title_obs = CM.Observable("")

    fig = CM.Figure(size = (600, 700), fontsize = 14)
    ax  = CM.Axis(fig[1, 1];
        xlabel    = st.labels[:video_x],
        ylabel    = st.labels[:video_z],
        title     = title_obs,
        limits    = (0, widths[end], 0, depths[end]),  # ascending order (ymin <= ymax)
        yreversed = true                               # flips the axis: z = 0 at the top
    )

    hm = CM.heatmap!(ax, widths, depths, T_obs;
        colormap   = :thermal,
        colorrange = (T_min, T_max)
    )
    CM.Colorbar(fig[1, 2], hm; label = st.labels[:temp])

    path = joinpath(outdir, "$(prefix)_temperature_animation.mp4")

    CM.record(fig, path, frames; framerate = 12) do i
        T_obs[]     = permutedims(res.T[i, :, :], (2, 1))
        title_obs[] = "$(st.labels[:video_title])$(round(t_h[i]; digits = 1)) h"
    end

    println("✓ Video MP4 guardado en: ", path)
end


function plotting(res::NamedTuple, config::Dict)
    style = config["style"]
    dpi   = config["dpi"]
    lang  = config["language"]

    plots_dict = Dict{Symbol, Any}()

    if config["layer_temperatures"] == true
        plots_dict[:soil_temperatures] = plot_temperatures(res; style = style, dpi = dpi, lang = lang)
    end

    if config["heat_fluxes"] == true
        plots_dict[:soil_heat_fluxes] = plot_heat_fluxes(res; style = style, dpi = dpi, lang = lang)
    end

    if config["total_energy"] == true
        plots_dict[:soil_energy] = plot_energy(res; style = style, dpi = dpi, lang = lang)
    end

    if config["temperature_animation"] == true
        make_video(res; style = style, dpi = dpi, lang = lang)
    end

    return plots_dict
end