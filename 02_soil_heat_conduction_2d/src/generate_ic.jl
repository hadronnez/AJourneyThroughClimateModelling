using NCDatasets
using Dates

"""
    generate_ic_nc(grid, init, out_folder) -> Matrix{Float64}

Loads the initial temperature field from `init.ic_path` if it exists and matches
the grid; otherwise generates it from `init.profile` and saves it to NetCDF.

- `grid`       : `cfg.grid`           (needs `zlayers`, `xlayers`)
- `init`       : `cfg.initialisation` (needs `profile::Symbol`, `ic_path`, `T_i`, `T_top`, `T_bottom`)
- `out_folder` : `cfg.experiment.out_folder`

A relative `ic_path` is resolved inside `out_folder`.
"""
function generate_ic_nc(grid, init, out_folder::AbstractString)
    (; zlayers, xlayers) = grid
    (; T_i, T_top, T_bottom) = init
    profile = Symbol(init.profile)                       # acepta String o Symbol
    T_grad  = hasproperty(init, :T_gradient) ? init.T_gradient : 10.0   # ΔT izq→der = 2·T_grad
    signature = "profile=$(profile);T_i=$(T_i);T_top=$(T_top);T_bottom=$(T_bottom);T_grad=$(T_grad);z=$(zlayers);x=$(xlayers)"

    ic_path = isabspath(init.ic_path) ? init.ic_path : joinpath(out_folder, init.ic_path)

    if isfile(ic_path)
        try
            T, saved_sig = NCDataset(ic_path, "r") do ds
                (Array{Float64}(ds["T"][:, :]), get(ds.attrib, "signature", ""))
            end
            if size(T) != (zlayers, xlayers)
                @warn "[WARN] $(now()) Cached IC size $(size(T)) != grid ($zlayers, $xlayers). Regenerating..."
            elseif saved_sig != signature
                @warn "[WARN] $(now()) Cached IC was built with different settings. Regenerating... (saved: [$saved_sig] | requested: [$signature])"
            else
                @info "[INFO] $(now()) Loaded cached initial conditions from: $ic_path ($signature)"
                return T
            end
        catch e
            @warn "[WARN] $(now()) Failed to load existing IC: $e. Regenerating..."
        end
    end

    @info "[INFO] $(now()) Generating initial conditions (profile: $profile)..."
    mkpath(dirname(ic_path))
    isfile(ic_path) && rm(ic_path)

    T_init = zeros(Float64, zlayers, xlayers)

    if profile === :homogeneous
        T_init .= T_i
        @info "  - Profile type: homogeneous (T = $T_i K)"

    elseif profile === :horizontal_gradient
        if xlayers == 1
            T_init .= T_i
            @warn "[WARN] $(now()) profile = horizontal_gradient but xlayers = 1: there is no horizontal direction, so the field is homogeneous (T = $T_i K). Set grid.xlayers > 1."
        else
            T_left, T_right = T_i + T_grad, T_i - T_grad
            for x in 1:xlayers
                factor = (x - 1) / max(1, xlayers - 1)
                T_init[:, x] .= T_left * (1.0 - factor) + T_right * factor
            end
            @info "  - Profile type: horizontal_gradient (T_left = $T_left K, T_right = $T_right K)"
        end

    elseif profile === :vertical_gradient
        T_vec = range(T_top, T_bottom, length = zlayers)
        for x in 1:xlayers
            T_init[:, x] .= T_vec
        end
        @info "  - Profile type: vertical_gradient (T_top = $T_top K, T_bottom = $T_bottom K)"

    else
        error("Unknown initial profile: $profile")
    end

    try
        NCDataset(ic_path, "c") do ds
            defDim(ds, "zlayers", zlayers)
            defDim(ds, "xlayers", xlayers)
            ds.attrib["signature"] = signature
            v = defVar(ds, "T", Float64, ("zlayers", "xlayers"))
            v.attrib["units"]     = "K"
            v.attrib["long_name"] = "Initial Soil Temperature Field ($profile)"
            v[:, :] = T_init
        end
        @info "[INFO] $(now()) Initial conditions saved to: $ic_path"
    catch e
        @error "[ERROR] $(now()) Failed to save initial conditions: $e"
        rethrow(e)
    end

    return T_init
end