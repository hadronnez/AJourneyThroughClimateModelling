Base.@kwdef struct SimulationResults
    T_top::Vector{Float64}
    T_bottom::Vector{Float64}
    T::Array{Float64,3}
    qz::Array{Float64,3}
    qx::Array{Float64,3}
    soil_energy::Vector{Float64}
    grid::NamedTuple
end
