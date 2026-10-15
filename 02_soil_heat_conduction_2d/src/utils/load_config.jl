mutable struct Config
    experiment
    grid
    physics
    initialisation
    components
    plotting
    save
    runtime
end


function Config(cfg_dir::AbstractString)

    exp_cfg  = YAML.load_file(joinpath(cfg_dir, "exp_cfg.yaml"))
    sim      = YAML.load_file(joinpath(cfg_dir, "sim_cfg.yaml"))
    plot_cfg = YAML.load_file(joinpath(cfg_dir, "plot_cfg.yaml"))

    return Config(
        _read_experiment(exp_cfg["experiment"]),
        _read_grid(sim),
        _read_physics(sim),
        _read_initialisation(sim),
        _read_components(sim),
        _read_plotting(plot_cfg),
        _read_save(exp_cfg["save"]),
        nothing, 
    )
end


function _read_experiment(d)
    return (
        id = String(d["id"]),
        log_every = haskey(d, "log_every") ? _positive(Int(d["log_every"]), "experiment.log_every") : nothing,
    )
end


function _read_grid(sim)
    g = sim["grid"]
    v = sim["vertical_coordinates"]

    return (
        dt = _positive(Float64(g["dt"]), "grid.dt"),
        L = _positive(Float64(g["L"]), "grid.L"),
        X = _positive(Float64(g["X"]), "grid.X"),
        zlayers = _positive(Int(g["zlayers"]), "grid.zlayers"),
        xlayers = _positive(Int(g["xlayers"]), "grid.xlayers"),
        run_len = _positive(Int(g["run_len"]), "grid.run_len"),
        r = _positive(Float64(v["r"]), "vertical_coordinates.r"),
    )
end


function _read_physics(sim)
    d = sim["physics"]

    return (
        k = _positive(Float64(d["k"]), "physics.k"),
        rho = _positive(Float64(d["rho"]), "physics.rho"),
        cp = _positive(Float64(d["cp"]), "physics.cp"),
    )
end


function _read_initialisation(sim)
    d = sim["initialisation"]

    profile = String(d["synthetic_initial_conditions"])

    profile in ("homogeneous", "horizontal_gradient", "vertical_gradient") ||
        @error "[ERROR] Unknown initial temperature profile: '$profile'"

    T_i = Float64(d["T_i"])

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


function _read_components(sim)
    d = sim["components"]

    for name in keys(d)
        name in ("dry_thermodinamics", "wet_thermodinamics") ||
            @error "[ERROR] Unknown component: '$name'"
    end

    dry = get(d, "dry_thermodinamics", Dict())
    wet = get(d, "wet_thermodinamics", Dict())

    focus = String(get(dry, "focus", "static"))

    focus in ("static", "dynamic") ||
        @error "[ERROR] dry_thermodinamics.focus unknown: '$focus'"

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


function _read_plotting(d)
    language = String(get(d, "language", "english"))
    style = String(get(d, "style", "presentation"))
    dpi = Int(get(d, "dpi", 300))
    render = get(d, "render", Dict())

    language in ("english", "spanish", "catalan") ||
        @error "[ERROR] plotting.language unknown: '$language'"

    style in ("paper", "presentation") ||
        @error "[ERROR] plotting.style unknown: '$style'"

    return (
        layer_temperatures = Bool(get(render, "layer_temperatures", false)),
        heat_fluxes = Bool(get(render, "heat_fluxes", false)),
        total_energy = Bool(get(render, "total_energy", false)),
        temperature_animation = Bool(get(render, "temperature_animation", false)),
        language = language,
        style = style,
        dpi = _positive(dpi, "plotting.dpi"),
    )
end


function _read_save(d)
    save_every = Int(get(d, "save_every", 1))

    return (
        plots = Bool(get(d, "plots", false)),
        data = Bool(get(d, "data", false)),
        save_every = _positive(save_every, "save.save_every"),
    )
end


function _positive(x, name)
    if x <= 0
        @error "[ERROR] $name must be > 0 ($x)"
    end
    return x
end
