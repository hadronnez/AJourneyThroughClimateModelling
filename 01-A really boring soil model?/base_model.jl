using Plots
using DelimitedFiles     # standard library, nothing to install
import CairoMakie as CM  # only used for the video (namespaced to avoid clashes with Plots)

const KELVIN = 273.15

# =========================
# Simulation
# =========================

function simulate(; m = 4,                       # number of layers
                    L = 0.8,                     # total depth, m
                    K = 1.0,                     # thermal conductivity, W/(m K)  <- example value, use yours
                    rho = 1800.0,                # kg/m³
                    cp = 800.0,                  # J/(kg K)
                    dt = 60.0,                   # s
                    t_total = 10 * 24 * 3600.0,  # s
                    T_top_mean = KELVIN + 30.0,  # K
                    T_amp = 0.0,                 # K
                    period = 24 * 3600.0,        # s
                    T_bot = KELVIN)              # K

    # Discretization
    n  = round(Int, t_total / dt)
    dz = L / m
    C  = rho * cp * dz                 # heat capacity per layer, J/(m² K)

    # Stability check (explicit Euler)
    α      = K / (rho * cp)
    dt_max = dz^2 / (2α)
    dt <= dt_max || error("Unstable: dt = $dt s > dt_max = $(round(dt_max, digits = 1)) s")

    # Time and surface boundary condition (known in advance, so no need to compute it in the loop)
    t_s   = collect(1:n) .* dt
    T_top = @. T_top_mean + T_amp * sin(2π * t_s / period - π / 2)

    # State
    T = fill(T_bot, m)                 # layer temperatures, K (initial condition)
    q = zeros(m + 1)                   # fluxes at the m+1 interfaces, W/m²

    # Histories
    T_history           = zeros(n, m)
    q_history           = zeros(n, m + 1)
    soil_energy_history = zeros(n)

    for i in 1:n
        # Heat fluxes (positive downwards)
        q[1]   = K * (T_top[i] - T[1]) / (dz / 2)            # surface -> center of layer 1
        @views q[2:m] .= K .* (T[1:m-1] .- T[2:m]) ./ dz     # between layers k-1 and k
        q[m+1] = K * (T[m] - T_bot) / (dz / 2)               # center of layer m -> bottom

        # Energy balance + Euler
        @views T .+= (dt / C) .* (q[1:m] .- q[2:m+1])

        # Save results
        T_history[i, :]       .= T .- KELVIN
        q_history[i, :]       .= q
        soil_energy_history[i] = C * sum(T)
    end

    return (;
        time                = t_s ./ 3600.0,                 # h
        T_top_history       = T_top .- KELVIN,               # °C
        T_bot_history       = fill(T_bot - KELVIN, n),       # °C
        T_history,                                           # °C, n × m
        q_history,                                           # W/m², n × (m+1)
        soil_energy_history,                                 # J/m²
        m, L, dz, dt,
    )
end

# =========================
# Plots
# =========================

function make_plots(res; dpi = 200, figsize = (800, 450))
    # The "logical" size (figsize) is close to the width of a blog column, so the text stays
    # readable when the browser scales the image; a high dpi keeps the export sharp
    # (800 x 450 at dpi 200 -> 1600 x 900 px). Small margins remove the white border.
    default(size = figsize, margin = 2mm,
            titlefontsize = 13, guidefontsize = 11, tickfontsize = 9, legendfontsize = 8)

    t  = res.time
    m  = res.m
    dz = res.dz

    # Legends are only readable for a small number of layers
    legend_T = m     <= 10 ? :outerright : false
    legend_q = m + 1 <= 10 ? :outerright : false

    # Colors: one per layer (the "+ 1" avoids the pale yellow end of viridis)
    cols_T = palette(:viridis, m + 1)[1:m]
    cols_q = palette(:viridis, m + 2)[1:m+1]

    # Temperatures
    layer_labels = ["$(round((k - 1) * dz * 100, digits = 1)) - $(round(k * dz * 100, digits = 1)) cm"
                    for k in 1:m]

    T_plot = plot(
        t, res.T_history;
        label        = permutedims(layer_labels),
        color        = permutedims(cols_T),
        xlabel       = "Time [h]",
        ylabel       = "Temperature [°C]",
        title        = "Basic soil temperature model",
        linewidth    = 2,
        grid         = true,
        legend       = legend_T,
        legend_title = "Layer depth",
        dpi          = dpi,
    )
    plot!(T_plot, t, res.T_top_history; label = "Surface", color = :red,  linestyle = :dash, linewidth = 2)
    plot!(T_plot, t, res.T_bot_history; label = "Bottom",  color = :blue, linestyle = :dash, linewidth = 2)

    # Heat fluxes
    q_labels = ["q$k" for k in 1:m+1]

    q_plot = plot(
        t, res.q_history;
        label     = permutedims(q_labels),
        color     = permutedims(cols_q),
        xlabel    = "Time [h]",
        ylabel    = "Heat flux [W/m²]",
        title     = "Heat fluxes in soil layers",
        linewidth = 2,
        grid      = true,
        legend    = legend_q,
        dpi       = dpi,
    )

    # Soil energy
    energy_plot = plot(
        t, res.soil_energy_history;
        label     = "Soil energy",
        xlabel    = "Time [h]",
        ylabel    = "Soil energy [J/m²]",
        title     = "Soil energy",
        linewidth = 2,
        grid      = true,
        legend    = false,
        dpi       = dpi,
    )

    return (; soil_temperatures = T_plot,
              soil_heat_fluxes  = q_plot,
              soil_energy       = energy_plot)
end

function save_plots(plots; outdir, prefix)
    mkpath(outdir)
    for (name, p) in pairs(plots)
        savefig(p, joinpath(outdir, "$(prefix)_$(name).png"))
    end
    println("Plots saved to:\n", outdir)
end

# =========================
# Video
# =========================

# Animation of the temperature profile vs depth: each layer is a horizontal
# band colored by its temperature (blue = cold, red = hot).
# The figure is built ONCE; between frames only the data (Observables) change.
function make_video(res; outdir, prefix,
                    every_h      = 1.0,      # one frame every `every_h` simulated hours
                    fps          = 12,
                    video_size   = (1280, 720),  # width x height in px (landscape, 16:9; keep both even)
                    T_lims       = nothing,  # (T_min, T_max) in °C; nothing = automatic
                    profile_line = true)     # overlay the T(z) profile as a black line

    mkpath(outdir)

    m, L, dz = res.m, res.L, res.dz
    t        = res.time
    zc_cm    = collect(((1:m) .- 0.5) .* dz .* 100)     # layer centers, cm
    L_cm     = L * 100
    z_line   = [0.0; zc_cm; L_cm]                       # surface, layer centers, bottom

    # Fixed color range for the whole video
    if T_lims === nothing
        all_T  = [vec(res.T_history); res.T_top_history; res.T_bot_history]
        T_lims = (floor(minimum(all_T)), ceil(maximum(all_T)))
    end
    T_min, T_max = T_lims

    # Frames: every `every_h` hours of simulated time
    step   = max(1, round(Int, every_h * 3600 / res.dt))
    frames = step:step:length(t)

    # Observables: the only things that change from frame to frame
    band_obs  = CM.Observable(zeros(2, m))                                  # 2 x m (x, layers)
    line_obs  = CM.Observable(CM.Point2f.(zeros(m + 2), z_line))            # profile points
    title_obs = CM.Observable("")

    # Figure (built once)
    fig = CM.Figure(size = video_size, fontsize = 18, figure_padding = 8)   # small padding: the plot fills the canvas
    ax  = CM.Axis(fig[1, 1];
        xlabel    = "Temperature [°C]",
        ylabel    = "Depth [cm]",
        title     = title_obs,
        limits    = (T_min, T_max, 0, L_cm),
        yreversed = true,
    )

    # Layers as colored bands (the two x values just stretch the color across the axis)
    hm = CM.heatmap!(ax, [T_min, T_max], zc_cm, band_obs;
        colormap   = [:blue, :white, :red],
        colorrange = (T_min, T_max),
    )
    CM.Colorbar(fig[1, 2], hm; label = "Temperature [°C]")

    if profile_line
        CM.lines!(ax, line_obs; color = :black, linewidth = 2)
        CM.scatter!(ax, line_obs; color = :black, markersize = 6)
    end

    # Record: each frame is written straight to the video (no frames kept in memory)
    path = joinpath(outdir, "$(prefix)_soil_temperatures.mp4")

    CM.record(fig, path, frames; framerate = fps) do i
        T_row = res.T_history[i, :]

        band_obs[]  = repeat(reshape(T_row, 1, :), 2, 1)
        line_obs[]  = CM.Point2f.([res.T_top_history[i]; T_row; res.T_bot_history[i]], z_line)
        title_obs[] = "Soil temperature profile · t = $(round(t[i]; digits = 1)) h"
    end

    println("Video saved to:\n", path)
end

# =========================
# Data
# =========================

# Writes a CSV file with a header line
function write_table(path, header, data)
    open(path, "w") do io
        println(io, join(header, ","))
        writedlm(io, data, ',')
    end
end

function save_data(res; outdir, prefix)
    mkpath(outdir)
    m = res.m

    # Temperatures: time, surface, m layers, bottom
    write_table(
        joinpath(outdir, "$(prefix)_soil_temperatures.csv"),
        ["time_h"; "T_surface_C"; ["T_layer$(k)_C" for k in 1:m]; "T_bottom_C"],
        hcat(res.time, res.T_top_history, res.T_history, res.T_bot_history),
    )

    # Heat fluxes: time, m+1 interfaces
    write_table(
        joinpath(outdir, "$(prefix)_soil_heat_fluxes.csv"),
        ["time_h"; ["q$(k)_W_m2" for k in 1:m+1]],
        hcat(res.time, res.q_history),
    )

    # Soil energy: time, energy
    write_table(
        joinpath(outdir, "$(prefix)_soil_energy.csv"),
        ["time_h", "soil_energy_J_m2"],
        hcat(res.time, res.soil_energy_history),
    )

    println("Data saved to:\n", outdir)
end

# =========================
# Main
# =========================

function main()
    results_dir = "01_Projects/01_soil_heat_conduction_1d/results"
    prefix      = "EXP1+"

    res   = simulate(m = 32, dt=100)     # change the number of layers here
    plots = make_plots(res)

    save_data(res;     outdir = joinpath(results_dir, "data"),  prefix = prefix)
    save_plots(plots;  outdir = joinpath(results_dir, "plots"), prefix = prefix)
    make_video(res;    outdir = joinpath(results_dir, "plots"), prefix = prefix)
    return res
end

main()
