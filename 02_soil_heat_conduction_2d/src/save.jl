using Plots
using NCDatasets
using Dates

"""
    save(res::NamedTuple, plots::Dict, scfg, experiment)

Saves simulation results to NetCDF format and plots to PNG images.
`scfg` is `cfg.save`; `experiment` is `cfg.experiment` (provides `out_folder` and `id`).
Arrays in `res` are time-last: T (z, x, time), qz (z+1, x, time), qx (z, x+1, time).
"""
function save(res::NamedTuple, plots::Dict, scfg, experiment)
    out_folder = experiment.out_folder
    id         = experiment.id

    # Save data to NetCDF
    if scfg.data
        @info "[INFO] $(now()) Saving data to NetCDF format..."
        nc_path = joinpath(out_folder, "data", "$(id)_data.nc")
        mkpath(dirname(nc_path))
        isfile(nc_path) && rm(nc_path)

        try
            NCDataset(nc_path, "c") do ds
                defDim(ds, "time", length(res.grid.ts))
                defDim(ds, "z", length(res.grid.depths))
                defDim(ds, "x", length(res.grid.widths))
                defDim(ds, "qz_interfaces", length(res.grid.depths) + 1)
                defDim(ds, "qx_interfaces", length(res.grid.widths) + 1)

                v_time  = defVar(ds, "time", Float64, ("time",), attrib = Dict("units" => "seconds", "long_name" => "Time"))
                v_depth = defVar(ds, "z", Float64, ("z",), attrib = Dict("units" => "meters", "long_name" => "Depth"))
                v_width = defVar(ds, "x", Float64, ("x",), attrib = Dict("units" => "meters", "long_name" => "Width"))

                v_time[:]  = res.grid.ts
                v_depth[:] = res.grid.depths
                v_width[:] = res.grid.widths

                v_T = defVar(ds, "T", Float64, ("z", "x", "time"), 
                             attrib = Dict("units" => "K", "long_name" => "Soil Temperature Field"))
                v_qz = defVar(ds, "qz", Float64, ("qz_interfaces", "x", "time"), 
                              attrib = Dict("units" => "W/m^2", "long_name" => "Vertical Heat Flux"))
                v_qx = defVar(ds, "qx", Float64, ("z", "qx_interfaces", "time"), 
                              attrib = Dict("units" => "W/m^2", "long_name" => "Horizontal Heat Flux"))
                v_E = defVar(ds, "soil_energy", Float64, ("time",), 
                             attrib = Dict("units" => "J", "long_name" => "Total Soil Heat Energy"))
                v_Ttop = defVar(ds, "T_top", Float64, ("time",), 
                                attrib = Dict("units" => "K", "long_name" => "Top Boundary Temperature"))
                v_Tbot = defVar(ds, "T_bottom", Float64, ("time",), 
                                attrib = Dict("units" => "K", "long_name" => "Bottom Boundary Temperature"))

                v_T[:, :, :]  = res.T
                v_qz[:, :, :] = res.qz
                v_qx[:, :, :] = res.qx
                v_E[:]        = res.soil_energy
                v_Ttop[:]     = res.T_top
                v_Tbot[:]     = res.T_bottom
            end
            @info "[INFO] $(now()) Data successfully saved to: $nc_path"
        catch e
            @error "[ERROR] $(now()) Failed to save data: $e"
            rethrow(e)
        end
    end

    # Save plots to PNG
    if scfg.plots && !isempty(plots)
        @info "[INFO] $(now()) Saving plots to PNG format..."
        plots_dir = joinpath(out_folder, "plots")
        
        try
            for (name, p) in plots
                filepath = joinpath(plots_dir, "$(id)_$(name).png")
                mkpath(dirname(filepath))
                savefig(p, filepath)
                @info "[INFO] $(now()) Saved plot: $name"
            end
            @info "[INFO] $(now()) All plots successfully saved to: $plots_dir"
        catch e
            @error "[ERROR] $(now()) Failed to save plots: $e"
            rethrow(e)
        end
    end
end