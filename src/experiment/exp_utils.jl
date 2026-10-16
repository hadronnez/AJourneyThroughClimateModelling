function _save_experiment_outputs(res::SimulationResults, cfg::Config)
    plt = plotting(res, cfg.plotting, cfg.experiment)
    save(res, plt, cfg.experiment)
end
