function _experiment_results(cfg::Config)
    (; grid, forcing, hist, save_every) = cfg.runtime
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

function _save_experiment_outputs(res::SimulationResults, cfg::Config)
    plt = plotting(res, cfg.plotting, cfg.experiment)
    save(res, plt, cfg.save, cfg.experiment)
end
