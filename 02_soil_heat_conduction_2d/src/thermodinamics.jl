include("generate_ic.jl")

function simulation(sim_config::Dict)
    LOG && @info "[INFO] $(now()) Initializing simulation..."

    mods = sim_config["modules"]
    params = sim_config["parameters"]

    # Grid setup
    LOG && @info "[INFO] $(now()) Setting up computational grid..."
    dt = params["grid"]["dt"]
    run_len = params["grid"]["run_len"]
    n_ts = Int(round(run_len / dt))
    ts   = collect(1:n_ts) .* dt

    zlayers = params["grid"]["zlayers"]
    column_lenght = params["grid"]["L"]
    dz = column_lenght / zlayers
    depths = collect(1:zlayers) .* dz

    xlayers = params["grid"]["xlayers"]
    dx = params["grid"]["X"]   
    widths = collect(1:xlayers) .* dx
    
    LOG && @info "  - Grid dimensions: $(zlayers)×$(xlayers) cells"
    LOG && @info "  - Time steps: $n_ts (Δt = $dt s)"
    LOG && @info "  - Grid spacing: Δz = $dz m, Δx = $dx m"

    # Physical parameters
    if mods["thermodinamics"] == true 
        K  = params["physics"]["k"]
        C  = params["physics"]["rho"] * params["physics"]["cp"] * dz * dx
        
        LOG && @info "[INFO] $(now()) Loading thermal parameters..."
        LOG && @info "  - Thermal conductivity: $K W/(m·K)"
        LOG && @info "  - Volumetric heat capacity: $C J/(m²·K)"
    end

    if mods["thermodinamics"] == true
        # Boundary conditions
        LOG && @info "[INFO] $(now()) Setting up boundary conditions..."
        if mods["focus"] == "static"
            T_top_history = ones(n_ts) * params["initialisation"]["T_top"]
            T_bottom_history = ones(n_ts) * params["initialisation"]["T_bottom"]
            LOG && @info "  - Static boundary conditions"
            LOG && @info "  - T_top = $(params["initialisation"]["T_top"]) K"
            LOG && @info "  - T_bottom = $(params["initialisation"]["T_bottom"]) K"
            
        elseif mods["focus"] == "dynamic"
            T_top_history = @. params["initialisation"]["T_top"] + params["initialisation"]["T_top_amplitude"] * sin(2π * ts / params["initialisation"]["T_top_period"] - π / 2)
            T_bottom_history = ones(n_ts) * params["initialisation"]["T_bottom"]
            LOG && @info "  - Dynamic boundary conditions (sinusoidal top)"
            LOG && @info "  - T_top amplitude: $(params["initialisation"]["T_top_amplitude"]) K"
            LOG && @info "  - T_top period: $(params["initialisation"]["T_top_period"]) s"
        end

        # Initial conditions
        T = generate_ic_nc(params)
        qz = zeros(zlayers + 1, xlayers)
        qx = zeros(zlayers, xlayers + 1) 

        T_history           = zeros(n_ts, zlayers, xlayers)
        qz_history          = zeros(n_ts, zlayers + 1, xlayers)
        qx_history          = zeros(n_ts, zlayers, xlayers + 1)
        soil_energy_history = zeros(n_ts)

        # Time stepping
        LOG && @info "[INFO] $(now()) Starting time integration loop..."
        for i in 1:n_ts
            @views qz[1, :]          .= K .* (T_top_history[i] .- T[1, :]) ./ (dz / 2)
            @views qz[2:zlayers, :]  .= K .* (T[1:zlayers-1, :] .- T[2:zlayers, :]) ./ dz
            @views qz[zlayers+1, :]  .= K .* (T[zlayers, :] .- T_bottom_history[i]) ./ (dz / 2)
            
            if xlayers > 1
                @views qx[:, 2:xlayers] .= K .* (T[:, 1:xlayers-1] .- T[:, 2:xlayers]) ./ dx
            end

            @views T .+= (dt / C) .* (
                            (qz[1:zlayers, :] .- qz[2:zlayers+1, :]) ./ dz .+
                            (qx[:, 1:xlayers] .- qx[:, 2:xlayers+1]) ./ dx
                        )

            T_history[i, :, :]  .= T
            qz_history[i, :, :] .= qz
            qx_history[i, :, :] .= qx
            soil_energy_history[i] = C * sum(T) * (dx * dz)
            
        end
        
        LOG && @info "[INFO] $(now()) Simulation completed successfully"
    end

    return (
            T_top       = T_top_history,
            T_bottom    = T_bottom_history,
            T           = T_history,
            qz          = qz_history,
            qx          = qx_history,
            soil_energy = soil_energy_history,
            grid = (
                depths = depths,
                widths = widths,
                ts     = ts
            )
        )
end