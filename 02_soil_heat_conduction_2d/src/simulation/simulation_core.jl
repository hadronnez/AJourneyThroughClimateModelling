include("thermodinamics.jl")

# Parameters derived from `Config` (pure function of it). Immutable.
struct Derived
    grid::NamedTuple
    phys::NamedTuple
    forcing::NamedTuple
end


"""
    run_simulation(cfg::Config) -> SimulationResults

Builds the derived parameters, initialises `state` and `hist` (both internal to
the simulation), integrates in time and returns the results.
"""
function run_simulation(cfg::Config)
    drv   = _simulation_setup(cfg)
    state = init_state(cfg, drv.grid)
    hist  = init_history(drv.grid, drv.grid.n_ts ÷ cfg.experiment.save.save_every)

    _simulation_cycle!(state, hist, drv, cfg)

    return _simulation_results(hist, drv, cfg)
end


function _simulation_setup(cfg::Config)
    @info "[INFO] $(now()) Setting up computational grid & physics..."
    sim = cfg.simulation
    g, v, p = sim.grid, sim.vertical_coordinates, sim.physics
    
    n_ts = Int(g.run_len ÷ g.dt)
    dz1  = v.r == 1.0 ? g.L / g.zlayers : g.L * (v.r - 1) / (v.r^g.zlayers - 1)
    dz   = dz1 .* (v.r .^ (0:g.zlayers-1))
    zlevels = [0.0; cumsum(dz)]
    depths  = (zlevels[1:end-1] .+ zlevels[2:end]) ./ 2
    
    grid = (dt=g.dt, L=g.L, X=g.X, zlayers=g.zlayers, xlayers=g.xlayers, n_ts=n_ts,
            dz=dz, dzc=diff(depths), zlevels=zlevels, depths=depths, dx=g.X/g.xlayers, widths=fill(g.X/g.xlayers, g.xlayers))
    
    phys = build_physics(p, grid)
    dt_max = stability_limit(grid, phys)
    grid.dt > dt_max && @warn "[WARN] dt ($(grid.dt)s) > dt_max ($(round(dt_max; digits=2))s)"

    forcing = boundary_forcing(sim.initialisation, grid, sim.components.dry_thermodinamics.focus)

    return Derived(grid, phys, forcing)
end


function _simulation_cycle!(state, hist, drv::Derived, cfg::Config)
    @info "[INFO] $(now()) Starting time integration loop..."
    (; grid, phys, forcing) = drv

    save_every = cfg.experiment.save.save_every
    log_every  = something(cfg.experiment.log_every, max(1, grid.n_ts ÷ 100))
    
    k = 0
    for i in 1:grid.n_ts
        step!(state, grid, phys, forcing.T_top[i], forcing.T_bottom[i])
        if i % save_every == 0
            k += 1
            record!(hist, state, phys, k)
        end
        !isnothing(log_every) && i % log_every == 0 && @info "  - step $i/$(grid.n_ts)"
    end
end


function _simulation_results(hist, drv::Derived, cfg::Config)
    (; grid, forcing) = drv
    save_every = cfg.experiment.save.save_every
    idx = save_every:save_every:grid.n_ts

    return SimulationResults(
        T_top = forcing.T_top[idx],
        T_bottom = forcing.T_bottom[idx],
        T = hist.T,
        qz = hist.qz,
        qx = hist.qx,
        soil_energy = hist.soil_energy,
        grid = (depths=grid.depths, zlevels=grid.zlevels, widths=grid.widths, ts=(1:grid.n_ts)[idx] .* grid.dt)
    )
end
