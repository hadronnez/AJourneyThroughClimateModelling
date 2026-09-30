include("generate_ic.jl")

# `grid` and `phys` are NamedTuples built in run.jl / build_physics (no Grid/Physics structs).
# Array layout: time is always the LAST dimension in histories (z, x, time).

"""
    build_physics(p, grid) -> NamedTuple

Extends the physical parameters (`cfg.physics`) with the per-layer quantities
needed by `step!` and `record!`, for a 2D cell of size dz[i] × dx (per unit length in y):

- `C`         : heat capacity of each layer's cell [J/K]   (vector, length zlayers)
- `dt_over_C` : dt / C                                      (vector, length zlayers)
"""
function build_physics(p, grid)
    C = (p.rho * p.cp) .* grid.dz .* grid.dx
    return (K = p.k, ρcp = p.rho * p.cp, k = p.k, rho = p.rho, cp = p.cp,
            C = C, dt_over_C = grid.dt ./ C)
end

"""
    stability_limit(grid, phys) -> dt_max [s]

Estimación del paso de tiempo máximo estable para el esquema explícito.
"""
function stability_limit(grid, phys)
    dup  = [grid.dz[1] / 2; grid.dzc]
    ddn  = [grid.dzc; grid.dz[end] / 2]
    coef = (phys.K / phys.ρcp) .* (1 ./ (grid.dz .* dup) .+
                                   1 ./ (grid.dz .* ddn) .+
                                   2 / grid.dx^2)
    return 1 / maximum(coef)
end

"""
    boundary_forcing(init, grid, focus = nothing) -> (T_top, T_bottom)

Boundary temperature series of length `grid.n_ts`, at times t_i = i·dt
(the same times used for `res.grid.ts` in run.jl).

- `init`  : `cfg.initialisation`
- `focus` : `cfg.components.dry.focus` (`:static` or `:dynamic`). If omitted, it is
            inferred: `:dynamic` when both `T_top_amplitude` and `T_top_period` are set.
"""
function boundary_forcing(init, grid, focus::Union{Symbol,Nothing} = nothing)
    A, P = init.T_top_amplitude, init.T_top_period
    focus === nothing && (focus = (isnan(A) || isnan(P)) ? :static : :dynamic)

    if focus === :static
        top = fill(init.T_top, grid.n_ts)
    elseif focus === :dynamic
        (isnan(A) || isnan(P)) &&
            error("focus = dynamic requires initialisation.T_top_amplitude and T_top_period")
        P > 0 || error("initialisation.T_top_period must be > 0 (got $P)")
        ts  = (1:grid.n_ts) .* grid.dt
        top = @. init.T_top + A * sin(2π * ts / P - π / 2)
    else
        error("Unknown dry_thermodinamics focus: $focus")
    end

    return (T_top = top, T_bottom = fill(init.T_bottom, grid.n_ts))
end

"""
    init_state(cfg, grid) -> (T, qz, qx)

Initial state; T comes from the synthetic profile / `ic.nc` (see generate_ic.jl).
"""
function init_state(cfg, grid)
    T  = generate_ic_nc(cfg.grid, cfg.initialisation, cfg.experiment.out_folder)
    qz = zeros(grid.zlayers + 1, grid.xlayers)
    qx = zeros(grid.zlayers, grid.xlayers + 1)
    return (T = T, qz = qz, qx = qx)
end

function init_history(grid, n_out::Int)
    return (T           = zeros(grid.zlayers, grid.xlayers, n_out),
            qz          = zeros(grid.zlayers + 1, grid.xlayers, n_out),
            qx          = zeros(grid.zlayers, grid.xlayers + 1, n_out),
            soil_energy = zeros(n_out))
end

function step!(state, grid, phys, T_top::Float64, T_bot::Float64)
    (; T, qz, qx) = state
    (; K, dt_over_C) = phys
    (; zlayers, xlayers, dz, dzc, dx) = grid

    @views begin
        qz[1, :]         .= K .* (T_top .- T[1, :]) ./ (dz[1] / 2)
        qz[2:zlayers, :] .= K .* (T[1:zlayers-1, :] .- T[2:zlayers, :]) ./ dzc
        qz[zlayers+1, :] .= K .* (T[zlayers, :] .- T_bot) ./ (dz[end] / 2)
        if xlayers > 1
            qx[:, 2:xlayers] .= K .* (T[:, 1:xlayers-1] .- T[:, 2:xlayers]) ./ dx
        end

        T .+= dt_over_C .* (
            (qz[1:zlayers, :] .- qz[2:zlayers+1, :]) .* dx .+
            (qx[:, 1:xlayers] .- qx[:, 2:xlayers+1]) .* dz
        )
    end
    return nothing
end

function record!(hist, state, phys, k::Int)
    hist.T[:, :, k]  .= state.T
    hist.qz[:, :, k] .= state.qz
    hist.qx[:, :, k] .= state.qx
    hist.soil_energy[k] = sum(phys.C .* state.T)
    return nothing
end