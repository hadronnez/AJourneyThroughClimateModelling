using Logging, Dates, YAML

include(joinpath(@__DIR__, "src", "config.jl"))
include(joinpath(@__DIR__, "src", "logger.jl"))
include(joinpath(@__DIR__, "src", "thermodinamics.jl"))
include(joinpath(@__DIR__, "src", "plots.jl"))
include(joinpath(@__DIR__, "src", "save.jl"))

function experiment_setup(cfg::Config)
    @info "[INFO] $(now()) Setting up computational grid & physics..."
    g, p, init = cfg.grid, cfg.physics, cfg.initialisation
    
    # 1. Grid
    n_ts = Int(g.run_len ÷ g.dt)
    dz1  = g.r == 1.0 ? g.L / g.zlayers : g.L * (g.r - 1) / (g.r^g.zlayers - 1)
    dz   = dz1 .* (g.r .^ (0:g.zlayers-1))
    zlevels = [0.0; cumsum(dz)]
    depths  = (zlevels[1:end-1] .+ zlevels[2:end]) ./ 2
    
    grid = (dt=g.dt, L=g.L, X=g.X, zlayers=g.zlayers, xlayers=g.xlayers, n_ts=n_ts,
            dz=dz, dzc=diff(depths), zlevels=zlevels, depths=depths, dx=g.X/g.xlayers, widths=fill(g.X/g.xlayers, g.xlayers))
    
    # 2. Physics & Stability
    phys = build_physics(p, grid)
    dt_max = stability_limit(grid, phys)
    grid.dt > dt_max && @warn "[WARN] dt ($(grid.dt)s) > dt_max ($(round(dt_max; digits=2))s)"

    # 3. Forcing, State & History
    forcing = boundary_forcing(init, grid, cfg.components.dry.focus)
    state   = init_state(cfg, grid)
    
    n_saves = grid.n_ts ÷ cfg.save.save_every
    hist    = (T=zeros(grid.zlayers, grid.xlayers, n_saves),
               qz=zeros(grid.zlayers + 1, grid.xlayers, n_saves),
               qx=zeros(grid.zlayers, grid.xlayers + 1, n_saves),
               soil_energy=zeros(n_saves))

    return grid, phys, forcing, state, hist, cfg.save.save_every
end

function experiment_cycle!(state, hist, grid, phys, forcing, save_every, log_every)
    @info "[INFO] $(now()) Starting time integration loop..."
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

function experiment_results(grid, forcing, hist, save_every)
    idx = save_every:save_every:grid.n_ts
    return (T_top=forcing.T_top[idx], T_bottom=forcing.T_bottom[idx], T=hist.T,
            qz=hist.qz, qx=hist.qx, soil_energy=hist.soil_energy,
            grid=(depths=grid.depths, zlevels=grid.zlevels, widths=grid.widths, ts=(1:grid.n_ts)[idx] .* grid.dt))
end

function run_experiment(cfg::Config)
    @info "[INFO] $(now()) Starting experiment: $(cfg.experiment.id)"
    grid, phys, forcing, state, hist, save_every = experiment_setup(cfg)
    log_every = isnothing(cfg.experiment.log_every) ? max(1, grid.n_ts ÷ 100) : cfg.experiment.log_every

    experiment_cycle!(state, hist, grid, phys, forcing, save_every, log_every)
    res = experiment_results(grid, forcing, hist, save_every)
    
    @info "[INFO] $(now()) Saving results and generating plots..."
    save(res, plotting(res, cfg.plotting, cfg.experiment), cfg.save, cfg.experiment)
    @info "[INFO] $(now()) Experiment completed successfully"
    return res
end


# ------------

ROOT = @__DIR__   
                          
cfg = load_config(joinpath(ROOT, "cfgs", "EXP1.yaml"); root = ROOT)
out = cfg.experiment.out_folder                   

mkpath(joinpath(out, "log"))
logger_io = init_logger(joinpath(out, "log", "run.log"))

try
    run_experiment(cfg)
finally
    close_logger(logger_io)
end