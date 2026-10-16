using Logging, Dates, YAML

const ROOT = @__DIR__

for parts in (("utils", "load_config.jl"),
              ("utils", "results.jl"),
              ("utils", "logger.jl"),
              ("simulation", "simulation_core.jl"),
              ("plotting", "plots.jl"),
              ("utils", "save.jl"),
              ("experiment", "exp_utils.jl"))
    include(joinpath(ROOT, "src", parts...))
end

function run_experiment(cfg::Config)
    @info "[INFO] $(now()) Starting experiment: $(cfg.experiment.id)"
    save(cfg)
    res = run_simulation(cfg)
    _save_experiment_outputs(res, cfg)
    @info "[INFO] $(now()) Experiment completed successfully"
    return res
end


#Main 


cfg = Config(joinpath(ROOT, "cfgs"), joinpath(ROOT, "experiments"))
out_folder = cfg.experiment.out_folder

for sub in ("cfgs", "log", "data", "ic", "plots")
    mkpath(joinpath(out_folder, sub))
end

logger_io = init_logger(joinpath(out_folder, "log", "run.log"))

try
    run_experiment(cfg)
finally
    close_logger(logger_io)
end
