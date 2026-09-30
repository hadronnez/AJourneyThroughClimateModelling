using NCDatasets

function generate_ic_nc(config_grid::Dict, config_init::Dict)
    zlayers = config_grid["zlayers"]
    xlayers = config_grid["xlayers"]
    profile = config_init["synthetic_initial_conditions"]
    T_i      = Float64(config_init["T_i"])
    T_top    = Float64(get(config_init, "T_top", T_i + 5.0))
    T_bottom = Float64(get(config_init, "T_bottom", T_i - 5.0))

    ic_path = joinpath(OUT_FOLDER, "ic", "ic.nc")
    
    # Load existing IC if available
    if isfile(ic_path)
        LOG && @info "[INFO] $(now()) Loading existing initial conditions from: $ic_path"
        try
            T = NCDataset(ic_path, "r") do ds
                return Array{Float64}(ds["T"][:, :])
            end
            LOG && @info "[INFO] $(now()) Initial conditions loaded successfully (profile: $profile)"
            return T
        catch e
            LOG && @warn "[WARN] $(now()) Failed to load existing IC: $e. Regenerating..."
        end
    end

    LOG && @info "[INFO] $(now()) Generating initial conditions (profile: $profile)..."
    mkpath(dirname(ic_path))
    isfile(ic_path) && rm(ic_path)
    
    T_init = zeros(Float64, zlayers, xlayers)

    if profile == "homogeneous"
        T_init .= T_i
        LOG && @info "  - Profile type: homogeneous (T = $T_i K)"
        
    elseif profile == "horizontal_gradient"
        if xlayers == 1
            T_init .= T_i
            LOG && @info "  - Profile type: horizontal_gradient (single column, T = $T_i K)"
        else
            T_left, T_right = T_i + 10.0, T_i - 10.0
            for x in 1:xlayers
                factor = (x - 1) / max(1, xlayers - 1)
                T_init[:, x] .= T_left * (1.0 - factor) + T_right * factor
            end
            LOG && @info "  - Profile type: horizontal_gradient (T_left = $T_left K, T_right = $T_right K)"
        end
        
    elseif profile == "vertical_gradient"
        T_vec = range(T_top, T_bottom, length = zlayers)
        for x in 1:xlayers
            T_init[:, x] .= T_vec
        end
        LOG && @info "  - Profile type: vertical_gradient (T_top = $T_top K, T_bottom = $T_bottom K)"
    end

    # Save to NetCDF
    try
        NCDataset(ic_path, "c") do ds
            defDim(ds, "zlayers", zlayers)
            defDim(ds, "xlayers", xlayers)
            v = defVar(ds, "T", Float64, ("zlayers", "xlayers"))
            v.attrib["units"]     = "K"
            v.attrib["long_name"] = "Initial Soil Temperature Field ($profile)"
            v[:, :] = T_init
        end
        LOG && @info "[INFO] $(now()) Initial conditions saved to: $ic_path"
    catch e
        LOG && @error "[ERROR] $(now()) Failed to save initial conditions: $e"
        rethrow(e)
    end

    return T_init
end