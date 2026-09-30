# config.jl

# -------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------

function req(d, key, section)
    if !haskey(d, key)
        @error "[ERROR] Falta '$key' en '$section'"
    end
    return d[key]
end


function positive(x, name)
    if x <= 0
        @error "[ERROR] $name debe ser > 0 (recibido: $x)"
    end

    return x
end


# -------------------------------------------------------------------
# Experiment
# -------------------------------------------------------------------

function read_experiment(d, root)
    id = String(req(d, "id", "experiment"))

    log_every = get(d, "log_every", nothing)
    log_every === nothing || log_every >= 1 ||
        @error "[ERROR] experiment.log_every debe ser >= 1"

    return (
        id = id,
        logging = Bool(req(d, "logging", "experiment")),
        log_every = log_every,
        out_folder = abspath(joinpath(root, "experiments", id)),
    )
end

# -------------------------------------------------------------------
# Grid
# -------------------------------------------------------------------

function read_grid(sim)
    g = req(sim, "grid", "simulation")
    v = req(sim, "vertical_coordinates", "simulation") # O usa get() si r es opcional

    return (
        dt = positive(Float64(req(g, "dt", "grid")), "grid.dt"),
        L = positive(Float64(req(g, "L", "grid")), "grid.L"),
        X = positive(Float64(req(g, "X", "grid")), "grid.X"),
        zlayers = positive(Int(req(g, "zlayers", "grid")), "grid.zlayers"),
        xlayers = positive(Int(req(g, "xlayers", "grid")), "grid.xlayers"),
        run_len = positive(Int(req(g, "run_len", "grid")), "grid.run_len"), # <--- Movido aquí
        r = positive(Float64(req(v, "r", "vertical_coordinates")), "vertical_coordinates.r"),
    )
end

# -------------------------------------------------------------------
# Physics
# -------------------------------------------------------------------

function read_physics(sim)
    d = req(sim, "physics", "simulation")

    return (
        k = positive(Float64(req(d, "k", "physics")), "physics.k"),
        rho = positive(Float64(req(d, "rho", "physics")), "physics.rho"),
        cp = positive(Float64(req(d, "cp", "physics")), "physics.cp"),
    )
end

# -------------------------------------------------------------------
# Initialisation
# -------------------------------------------------------------------

function read_initialisation(sim)
    d = req(sim, "initialisation", "simulation")

    profile = String(req(d, "synthetic_initial_conditions", "initialisation"))

    profile in ("homogeneous", "horizontal_gradient", "vertical_gradient") ||
        @error "[ERROR] Perfil inicial desconocido: '$profile'"

    T_i = Float64(req(d, "T_i", "initialisation"))

    return (
        profile = Symbol(profile),
        ic_path = String(get(d, "initial_conditions_path", "ic/ic.nc")),
        T_i = T_i,
        T_top = Float64(get(d, "T_top", T_i + 5)),
        T_bottom = Float64(get(d, "T_bottom", T_i - 5)),
        T_top_period = Float64(get(d, "T_top_period", NaN)),
        T_top_amplitude = Float64(get(d, "T_top_amplitude", NaN)),
    )
end

# -------------------------------------------------------------------
# Components
# -------------------------------------------------------------------

function read_components(sim)
    d = req(sim, "components", "simulation")

    for name in keys(d)
        name in ("dry_thermodinamics", "wet_thermodinamics") ||
            @error "[ERROR] Componente desconocido: '$name'"
    end

    dry = get(d, "dry_thermodinamics", Dict())
    wet = get(d, "wet_thermodinamics", Dict())

    focus = String(get(dry, "focus", "static"))

    focus in ("static", "dynamic") ||
        @error "[ERROR] dry_thermodinamics.focus desconocido: '$focus'"

    return (
        dry = (
            active = Bool(get(dry, "active", false)),
            focus = Symbol(focus),
        ),
        wet = (
            active = Bool(get(wet, "active", false)),
        ),
    )
end

# -------------------------------------------------------------------
# Plotting
# -------------------------------------------------------------------

function read_plotting(d)
    language = String(get(d, "language", "english"))
    style = String(get(d, "style", "paper"))
    dpi = Int(get(d, "dpi", 300))

    language in ("english", "spanish", "catalan") ||
        @error "[ERROR] plotting.language desconocido: '$language'"

    style in ("paper", "presentation") ||
        @error "[ERROR] plotting.style desconocido: '$style'"

    return (
        layer_temperatures = Bool(get(d, "layer_temperatures", false)),
        heat_fluxes = Bool(get(d, "heat_fluxes", false)),
        total_energy = Bool(get(d, "total_energy", false)),
        temperature_animation = Bool(get(d, "temperature_animation", false)),
        language = language,
        style = style,
        dpi = positive(dpi, "plotting.dpi"),
    )
end

# -------------------------------------------------------------------
# Save
# -------------------------------------------------------------------

function read_save(d)
    save_every = Int(get(d, "save_every", 1))

    return (
        plots = Bool(get(d, "plots", false)),
        data = Bool(get(d, "data", false)),
        save_every = positive(save_every, "save.save_every"),
    )
end

# -------------------------------------------------------------------
# Complete configuration
# -------------------------------------------------------------------

struct Config
    experiment
    grid
    physics
    initialisation
    components
    plotting
    save
end

function load_config(path::AbstractString;
                     root::AbstractString = dirname(dirname(abspath(path))))

    y = YAML.load_file(path)

    experiment = req(y, "experiment", "root")
    sim = req(y, "simulation", "root")
    plotting = req(y, "plotting", "root")
    save = req(y, "save", "root")

    return Config(
        read_experiment(experiment, root),
        read_grid(sim),
        read_physics(sim),
        read_initialisation(sim),
        read_components(sim),
        read_plotting(plotting),
        read_save(save),
    )
end