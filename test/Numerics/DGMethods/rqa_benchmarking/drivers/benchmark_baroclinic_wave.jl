#!/usr/bin/env julia --project
include("../interface/utilities/boilerplate.jl")

########
# Set up parameters
########
parameters = (
    a    = 6.371e6,
    Ω    = 7.2921159e-5,
    g    = 9.81,
    H    = 30e3,
    R_d  = 287.0024093890231,
    pₒ   = 1.01325e5,
    k    = 3.0,
    Γ    = 0.005,
    T_E  = 310.0,
    T_P  = 240.0,
    b    = 2.0,
    z_t  = 15e3,
    λ_c  = π / 9,
    ϕ_c  = 2 * π / 9,
    V_p  = 1.0,
    κ    = 2/7,
)

########
# Set up domain
########
domain = SphericalShell(
    radius = planet_radius(param_set),
    height = 30e3,
)
grid = DiscretizedDomain(
    domain;
    elements = (vertical = 5, horizontal = 6),
    polynomial_order = (vertical = 3, horizontal = 6),
    overintegration_order = (vertical = 0, horizontal = 0),
)

########
# Set up inital condition
########
# additional initial condition parameters
T_0(𝒫)  = 0.5 * (𝒫.T_E + 𝒫.T_P)
A(𝒫)    = 1.0 / 𝒫.Γ
B(𝒫)    = (T_0(𝒫) - 𝒫.T_P) / T_0(𝒫) / 𝒫.T_P
C(𝒫)    = 0.5 * (𝒫.k + 2) * (𝒫.T_E - 𝒫.T_P) / 𝒫.T_E / 𝒫.T_P
H(𝒫)    = 𝒫.R_d * T_0(𝒫) / 𝒫.g
d_0(𝒫)  = 𝒫.a / 6

# convenience functions that only depend on height
τ_z_1(𝒫,r)   = exp(𝒫.Γ * (r - 𝒫.a) / T_0(𝒫))
τ_z_2(𝒫,r)   = 1 - 2 * ((r - 𝒫.a) / 𝒫.b / H(𝒫))^2
τ_z_3(𝒫,r)   = exp(-((r - 𝒫.a) / 𝒫.b / H(𝒫))^2)
τ_1(𝒫,r)     = 1 / T_0(𝒫) * τ_z_1(𝒫,r) + B(𝒫) * τ_z_2(𝒫,r) * τ_z_3(𝒫,r)
τ_2(𝒫,r)     = C(𝒫) * τ_z_2(𝒫,r) * τ_z_3(𝒫,r)
τ_int_1(𝒫,r) = A(𝒫) * (τ_z_1(𝒫,r) - 1) + B(𝒫) * (r - 𝒫.a) * τ_z_3(𝒫,r)
τ_int_2(𝒫,r) = C(𝒫) * (r - 𝒫.a) * τ_z_3(𝒫,r)
F_z(𝒫,r)     = (1 - 3 * ((r - 𝒫.a) / 𝒫.z_t)^2 + 2 * ((r - 𝒫.a) / 𝒫.z_t)^3) * ((r - 𝒫.a) ≤ 𝒫.z_t)

# convenience functions that only depend on longitude and latitude
d(𝒫,λ,ϕ)     = 𝒫.a * acos(sin(ϕ) * sin(𝒫.ϕ_c) + cos(ϕ) * cos(𝒫.ϕ_c) * cos(λ - 𝒫.λ_c))
c3(𝒫,λ,ϕ)    = cos(π * d(𝒫,λ,ϕ) / 2 / d_0(𝒫))^3
s1(𝒫,λ,ϕ)    = sin(π * d(𝒫,λ,ϕ) / 2 / d_0(𝒫))
cond(𝒫,λ,ϕ)  = (0 < d(𝒫,λ,ϕ) < d_0(𝒫)) * (d(𝒫,λ,ϕ) != 𝒫.a * π)

# base-state thermodynamic variables
I_T(𝒫,ϕ,r)   = (cos(ϕ) * r / 𝒫.a)^𝒫.k - 𝒫.k / (𝒫.k + 2) * (cos(ϕ) * r / 𝒫.a)^(𝒫.k + 2)
T(𝒫,ϕ,r)     = (τ_1(𝒫,r) - τ_2(𝒫,r) * I_T(𝒫,ϕ,r))^(-1) * (𝒫.a/r)^2
p(𝒫,ϕ,r)     = 𝒫.pₒ * exp(-𝒫.g / 𝒫.R_d * (τ_int_1(𝒫,r) - τ_int_2(𝒫,r) * I_T(𝒫,ϕ,r)))
θ(𝒫,ϕ,r)     = T(𝒫,ϕ,r) * (𝒫.pₒ / p(𝒫,ϕ,r))^𝒫.κ

# base-state velocity variables
U(𝒫,ϕ,r)  =  𝒫.g * 𝒫.k / 𝒫.a * τ_int_2(𝒫,r) * T(𝒫,ϕ,r) * ((cos(ϕ) * r / 𝒫.a)^(𝒫.k - 1) - (cos(ϕ) * r / 𝒫.a)^(𝒫.k + 1))
u(𝒫,ϕ,r)  = -𝒫.Ω * r * cos(ϕ) + sqrt((𝒫.Ω * r * cos(ϕ))^2 + r * cos(ϕ) * U(𝒫,ϕ,r))
v(𝒫,ϕ,r)  = 0.0
w(𝒫,ϕ,r)  = 0.0

# velocity perturbations
δu(𝒫,λ,ϕ,r)  = -16 * 𝒫.V_p / 3 / sqrt(3) * F_z(𝒫,r) * c3(𝒫,λ,ϕ) * s1(𝒫,λ,ϕ) * (-sin(𝒫.ϕ_c) * cos(ϕ) + cos(𝒫.ϕ_c) * sin(ϕ) * cos(λ - 𝒫.λ_c)) / sin(d(𝒫,λ,ϕ) / 𝒫.a) * cond(𝒫,λ,ϕ)
δv(𝒫,λ,ϕ,r)  =  16 * 𝒫.V_p / 3 / sqrt(3) * F_z(𝒫,r) * c3(𝒫,λ,ϕ) * s1(𝒫,λ,ϕ) * cos(𝒫.ϕ_c) * sin(λ - 𝒫.λ_c) / sin(d(𝒫,λ,ϕ) / 𝒫.a) * cond(𝒫,λ,ϕ)
δw(𝒫,λ,ϕ,r)  = 0.0

# CliMA prognostic variables
# compute the total energy
uˡᵒⁿ(𝒫,λ,ϕ,r)   = u(𝒫,ϕ,r) + δu(𝒫,λ,ϕ,r)
uˡᵃᵗ(𝒫,λ,ϕ,r)   = v(𝒫,ϕ,r) + δv(𝒫,λ,ϕ,r)
uʳᵃᵈ(𝒫,λ,ϕ,r)   = w(𝒫,ϕ,r) + δw(𝒫,λ,ϕ,r)

e_int(𝒫,λ,ϕ,r)  = (𝒫.R_d / 𝒫.κ - 𝒫.R_d) * T(𝒫,ϕ,r)
e_kin(𝒫,λ,ϕ,r)  = 0.5 * ( uˡᵒⁿ(𝒫,λ,ϕ,r)^2 + uˡᵃᵗ(𝒫,λ,ϕ,r)^2 + uʳᵃᵈ(𝒫,λ,ϕ,r)^2 )
e_pot(𝒫,λ,ϕ,r)  = 𝒫.g * r

ρ₀(𝒫,λ,ϕ,r)    = p(𝒫,ϕ,r) / 𝒫.R_d / T(𝒫,ϕ,r)
ρuˡᵒⁿ(𝒫,λ,ϕ,r) = ρ₀(𝒫,λ,ϕ,r) * uˡᵒⁿ(𝒫,λ,ϕ,r)
ρuˡᵃᵗ(𝒫,λ,ϕ,r) = ρ₀(𝒫,λ,ϕ,r) * uˡᵃᵗ(𝒫,λ,ϕ,r)
ρuʳᵃᵈ(𝒫,λ,ϕ,r) = ρ₀(𝒫,λ,ϕ,r) * uʳᵃᵈ(𝒫,λ,ϕ,r)

if total_energy
    ρe(𝒫,λ,ϕ,r) = ρ₀(𝒫,λ,ϕ,r) * (e_int(𝒫,λ,ϕ,r) + e_kin(𝒫,λ,ϕ,r) + e_pot(𝒫,λ,ϕ,r))
else
    ρe(𝒫,λ,ϕ,r) = ρ₀(𝒫,λ,ϕ,r) * (e_int(𝒫,λ,ϕ,r) + e_kin(𝒫,λ,ϕ,r))
end

# Cartesian Representation (boiler plate really)
ρ₀ᶜᵃʳᵗ(𝒫, x...)  = ρ₀(𝒫, lon(x...), lat(x...), rad(x...))
ρu⃗₀ᶜᵃʳᵗ(𝒫, x...) = (   ρuʳᵃᵈ(𝒫, lon(x...), lat(x...), rad(x...)) * r̂(x...)
                     + ρuˡᵃᵗ(𝒫, lon(x...), lat(x...), rad(x...)) * ϕ̂(x...)
                     + ρuˡᵒⁿ(𝒫, lon(x...), lat(x...), rad(x...)) * λ̂(x...) )
ρeᶜᵃʳᵗ(𝒫, x...) = ρe(𝒫, lon(x...), lat(x...), rad(x...))

########
# Set up model physics
########
FT = Float64

ref_state = DryReferenceState(DecayingTemperatureProfile{FT}(param_set, FT(290), FT(220), FT(8e3)))

# total energy
eos     = TotalEnergy(γ = 1 / (1 - parameters.κ))
physics = Physics(
    orientation = SphericalOrientation(),
    ref_state   = ref_state,
    eos         = eos,
    lhs         = (
        ESDGNonLinearAdvection(eos = eos),
        PressureDivergence(eos = eos),
    ),
    sources     = sources = (
        DeepShellCoriolis{FT}(Ω = parameters.Ω),
    ),
)

linear_eos = linearize(physics.eos)
linear_physics = Physics(
    orientation = physics.orientation,
    ref_state   = physics.ref_state,
    eos         = linear_eos,
    lhs         = (
                ESDGLinearAdvection(),
        PressureDivergence(eos = linear_eos),
    ),
    sources     = (
        ThinShellGravityFromPotential(),
    ),
)

linear_esdg_physics = Physics(
    orientation = physics.orientation,
    ref_state   = physics.ref_state,
    eos         = linear_eos,
    lhs         = (
        ESDGLinearAdvection(),
        PressureDivergence(eos = linear_eos),
    ),
    sources = (),
)

########
# Set up model
########
model = DryAtmosModel(
    physics = physics,
    boundary_conditions = (5, 6),
    initial_conditions = (ρ = ρ₀ᶜᵃʳᵗ, ρu = ρu⃗₀ᶜᵃʳᵗ, ρe = ρeᶜᵃʳᵗ),
    numerics = (
        flux = RusanovNumericalFlux(),
    ),
    parameters = parameters,
)


linear_model = DryAtmosLinearModel(
    physics = linear_physics,
    boundary_conditions = model.boundary_conditions,
    initial_conditions = nothing,
    numerics = (
        flux = model.numerics.flux,
        direction = VerticalDirection()
    ),
    parameters = model.parameters,
)

# CentralNumericalFluxFirstOrder, RusanovNumericalFlux()
linear_esdg_model = DryAtmosLinearESDGModel(
    physics = linear_esdg_physics,
    boundary_conditions = (5, 6),
    initial_conditions = (ρ = ρ₀ᶜᵃʳᵗ, ρu = ρu⃗₀ᶜᵃʳᵗ, ρe = ρeᶜᵃʳᵗ),
    numerics = (
        flux = RusanovNumericalFlux(),
    ),
    parameters = parameters,
)



########
# Set up time steppers (could be done automatically in simulation)
########
# determine the time step construction
# element_size = (domain_height / numelem_vert)
# acoustic_speed = soundspeed_air(param_set, FT(330))
dx = min_node_distance(grid.numerical)
cfl = 9 # maybe 2
Δt = cfl * dx / 330.0
start_time = 0
end_time = 10 * 86400 # Δt
method = ARK2GiraldoKellyConstantinescu #ARK2ImplicitExplicitMidpoint # ARK2GiraldoKellyConstantinescu, 
callbacks = (
  Info(),
  CFL(),
  )

########
# Set up simulation, linear_model, linear_esdg_model
########
simulation = Simulation(
    (model, linear_esdg_model);
    grid = grid,
    timestepper = (method = method, timestep = Δt),
    time        = (start = start_time, finish = end_time),
    callbacks   = callbacks,
);

########
# Run the simulation
########
initialize!(simulation)
tic = Base.time()
MA = Array(view(grid.numerical.vgeo, :, grid.numerical.Mid, :));
QA = Array(copy(simulation.state));
ρᴮ = sum(MA .* QA[:,1,:]) / sum(MA);
evolve!(simulation)
QA = Array(copy(simulation.state));
ρᴬ = sum(MA .* QA[:,1,:]) / sum(MA);
toc = Base.time()
println("The time for the simulation is ", (toc-tic)/60 , " minutes")
println("before ", ρᴮ, " after ", ρᴬ, " abs difference ", abs(ρᴬ - ρᴮ)/ρᴮ)
println("yep")

println("the extrema of the state are")
for i in 1:5
    println("For state $i = ", extrema(Array(simulation.state)[:,i,:]))
end

#=
Q = copy(simulation.state);
Q_array = Array(Q);
Q_tend = copy(simulation.state);
Q_tend .= 0.0;
Q .= 1.0;
simulation.rhs[1](Q_tend, Q, nothing, true);
Q_tend_array_1 = Array(Q_tend)

Q_tend .= 0.0;
simulation.rhs[2](Q_tend, Q, nothing, true);
Q_tend_array_2 = Array(Q_tend)

norm(Q_tend_array_1 - Q_tend_array_2)

# simulation.rhs[3](dQ1, Q, nothing, 0; increment = false)

dg = simulation.rhs[1];
vdg = simulation.rhs[3]; 

α = FT(1 // 10);
function closure_op(vdg, α)
    function op!(LQ, Q)
        vdg(LQ, Q, nothing, 0; increment = false)
        @. LQ = Q + α * LQ
        return nothing
    end
end
lin_op! = closure_op(vdg, α);

using ClimateMachine.SystemSolvers
using ClimateMachine.SystemSolvers: band_lu!, band_forward!, band_back!
using ClimateMachine.SystemSolvers: banded_matrix, banded_matrix_vector_product!

A_banded = banded_matrix(
    lin_op!,
    vdg,
    MPIStateArray(vdg),
    MPIStateArray(vdg)
)


Q = init_ode_state(vdg, FT(0));
Q = init_ode_state(dg, FT(0); init_on_cpu = true);
dQ1 = MPIStateArray(vdg);
dQ2 = MPIStateArray(vdg);

lin_op!(dQ1, Q);
banded_matrix_vector_product!(A_banded, dQ2, Q);
ΔQ = abs.(Array(dQ1.realdata) - Array(dQ2.realdata));
maximum(ΔQ)
indmax = argmax(ΔQ)
Array(dQ1.realdata)[indmax]
Array(dQ2.realdata)[indmax]

##
# Matrix Version
banded_matrix_vector_product!(A_banded, dQ1,  Q);
twice_Q = 2 .* Q;
banded_matrix_vector_product!(A_banded, dQ2, twice_Q);
ΔQ = abs.(2 .* Array(dQ1.realdata) - Array(dQ2.realdata))
maximum(ΔQ)

# Operator Version, simulation.rhs[1](dQ1, zero_Q, nothing, 0; increment = false)
zero_Q = 0 .* Q;
lin_op!(dQ1, zero_Q); # check that 0 gives 0 
lin_op!(dQ1, Q);
twice_Q = 2 .* Q;
lin_op!(dQ2, twice_Q);
ΔQ = abs.(2 .* Array(dQ1.realdata) - Array(dQ2.realdata))
maximum(ΔQ)


##
##

    tendency::MPIStateArray,
    state_prognostic::MPIStateArray,
    ::Nothing,
    t,
    α = true,
    β = false,

i = 3
Q = copy(simulation.state);
Q_tend = copy(simulation.state);
Q_tend .= 0.0;
simulation.rhs[i](Q_tend, Q, nothing, 0, 1, 0);
# simulation.rhs[i](Q_tend, Q, nothing, 0; increment = false)
Q_tend_array_1 = Array(Q_tend)

Q .= 2 .* Q;
simulation.rhs[i](Q_tend, Q, nothing, 0, 1, 0);
Q_tend_array_2 = Array(Q_tend)

norm(2 .* Q_tend_array_1-Q_tend_array_2)


function testingf(a,b, c = 1)
    return a+b+c
end



=#
nothing

