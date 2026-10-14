include("thermodinamics.jl")

function _experiment_setup!(cfg::Config)
    @info "[INFO] $(now()) Setting up computational grid & physics..."
    g, p, init = cfg.grid, cfg.physics, cfg.initialisation
    
    n_ts = Int(g.run_len ÷ g.dt)
    dz1  = g.r == 1.0 ? g.L / g.zlayers : g.L * (g.r - 1) / (g.r^g.zlayers - 1)
    dz   = dz1 .* (g.r .^ (0:g.zlayers-1))
    zlevels = [0.0; cumsum(dz)]
    depths  = (zlevels[1:end-1] .+ zlevels[2:end]) ./ 2
    
    grid = (dt=g.dt, L=g.L, X=g.X, zlayers=g.zlayers, xlayers=g.xlayers, n_ts=n_ts,
            dz=dz, dzc=diff(depths), zlevels=zlevels, depths=depths, dx=g.X/g.xlayers, widths=fill(g.X/g.xlayers, g.xlayers))
    
    phys = build_physics(p, grid)
    dt_max = stability_limit(grid, phys)
    grid.dt > dt_max && @warn "[WARN] dt ($(grid.dt)s) > dt_max ($(round(dt_max; digits=2))s)"

    forcing = boundary_forcing(init, grid, cfg.components.dry.focus)
    state   = init_state(cfg, grid)
    
    save_every = cfg.save.save_every
    n_saves = grid.n_ts ÷ save_every
    hist    = (T=zeros(grid.zlayers, grid.xlayers, n_saves),
               qz=zeros(grid.zlayers + 1, grid.xlayers, n_saves),
               qx=zeros(grid.zlayers, grid.xlayers + 1, n_saves),
               soil_energy=zeros(n_saves))

    log_every = isnothing(cfg.experiment.log_every) ? max(1, grid.n_ts ÷ 100) : cfg.experiment.log_every

    cfg.runtime = (
        grid = grid,
        phys = phys,
        forcing = forcing,
        state = state,
        hist = hist,
        save_every = save_every,
        log_every = log_every
    )

    return cfg
end


function _experiment_cycle!(cfg)
    @info "[INFO] $(now()) Starting time integration loop..."
    (; grid, phys, forcing, state, hist, save_every, log_every) = cfg.runtime
    
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
