using YAML
using Logging
using Dates
include(joinpath(@__DIR__, "src", "logger.jl"))
include(joinpath(@__DIR__, "src", "thermodinamics.jl"))
include(joinpath(@__DIR__, "src", "plots.jl"))
include(joinpath(@__DIR__, "src", "save.jl"))

function run_experiment(config::Dict)
    LOG && @info "[INFO] $(now()) Starting experiment: $ID"
    LOG && @info "[INFO] $(now()) Running simulation..."
    res = simulation(config["simulation"])
    LOG && @info "[INFO] $(now()) Generating plots..."
    plots = plotting(res, config["plotting"])
    LOG && @info "[INFO] $(now()) Saving results..."
    save(res, plots, config["save"])
    LOG && @info "[INFO] $(now()) Experiment completed successfully"
end

#---------------------------------------------------------------------------------

cfg = YAML.load_file(joinpath(@__DIR__, "cfgs", "EXP5.yaml"))

global OUT_FOLDER = joinpath(@__DIR__, "experiments", cfg["experiment"]["id"])
global LOG = cfg["experiment"]["logging"]
global ID = cfg["experiment"]["id"]
global LOGGER_IO = nothing

if LOG == true
    log_path = joinpath(OUT_FOLDER, "log", "run.log")
    global LOGGER_IO = init_logger(log_path)
    @info "═════════════════════════════════════════════════════════════"
    @info "Experiment $ID started at $(now())"
    @info "═════════════════════════════════════════════════════════════"
end

run_experiment(cfg)

if LOG == true
    @info "═════════════════════════════════════════════════════════════"
    @info "Experiment $ID finished at $(now())"
    @info "═════════════════════════════════════════════════════════════"
    close_logger(LOGGER_IO)
end