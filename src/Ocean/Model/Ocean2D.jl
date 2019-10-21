module Ocean2D

export HB2DModel, HB2DProblem

using StaticArrays
using ..VariableTemplates
using LinearAlgebra: I, dot
using ..PlanetParameters: grav

import CLIMA.DGmethods: BalanceLaw, vars_aux, vars_state, vars_gradient,
                        vars_diffusive, vars_integrals, flux_nondiffusive!,
                        flux_diffusive!, source!, wavespeed,
                        boundary_state!,
                        gradvariables!, init_aux!, init_state!,
                        LocalGeometry, diffusive!

using ..DGmethods.NumericalFluxes: Rusanov, CentralFlux, CentralGradPenalty,
                                   CentralNumericalFluxDiffusive

import ..DGmethods.NumericalFluxes: update_penalty!, numerical_flux_diffusive!,
                                    NumericalFluxNonDiffusive

×(a::SVector, b::SVector) = StaticArrays.cross(a, b)
∘(a::SVector, b::SVector) = StaticArrays.dot(a, b)
⊗(a::SVector, b::SVector) = a * b'

abstract type HB2DProblem end

struct HB2DModel{P, S} <: BalanceLaw
  problem::P
  cʰ::S
  cᶻ::S
end

function vars_state(m::HB2DModel, T)
  @vars begin
    θ::T
  end
end

function vars_aux(m::HB2DModel, T)
  @vars begin
    u::SVector{3, T}
  end
end

function vars_gradient(m::HB2DModel, T)
  @vars begin
    θ::SVector{3, T}
  end
end

function vars_diffusive(m::HB2DModel, T)
  @vars begin
    κ∇θ::SMatrix{3, 3, T, 9}
  end
end

@inline function flux_nondiffusive!(m::HB2DModel, F::Grad, Q::Vars,
                                    α::Vars, t::Real)
  θ = Q.θ
  u = α.u

  F.θ += u * θ

  return nothing
end

@inline wavespeed(m::HB2DModel, n⁻, _...) = abs(SVector(m.cʰ, m.cᶻ, 0)' * n⁻)

function update_penalty!(::Rusanov, ::HB2DModel, ΔQ::Vars,
                         n⁻, λ, Q⁻, Q⁺, α⁻, α⁺, t)
  θ⁻ = Q⁻.θ
  u⁻ = α⁻.u
  n̂_u⁻ = n⁻∘u⁻

  θ⁺ = Q⁺.θ
  u⁺ = α⁺.u
  n̂_u⁺ = n⁻∘u⁺

  # max velocity
  # n̂∘u = (abs(n̂∘u⁺) > abs(n̂∘u⁻) ? n̂∘u⁺ : n̂∘u⁻

  # average velocity
  n̂_u = (n̂_u⁻ + n̂_u⁺) / 2

  ΔQ.θ = ((n̂_u > 0) ? 1 : -1) * (n̂_u⁻ * θ⁻ - n̂_u⁺ * θ⁺)
  # ΔQ.θ = abs(n̂_u⁻) * θ⁻ - abs(n̂_u⁺) * θ⁺

  return nothing
end

gradvariables!(m::HB2DModel, f::Vars, Q::Vars, α::Vars, t::Real) = nothing

diffusive!(m::HB2DModel, σ::Vars, ∇G::Grad, Q::Vars, α::Vars, t::Real) = nothing

flux_diffusive!(m::HB2DModel, G::Grad, Q::Vars, σ::Vars, α::Vars, t::Real) = nothing

source!(m::HB2DModel, S::Vars, Q::Vars, α::Vars,
                         t::Real) = nothing

function hb2d_init_aux! end
function init_aux!(m::HB2DModel, α::Vars, geom::LocalGeometry)
  return hb2d_init_aux!(m.problem, α, geom)
end

function hb2d_init_state! end
function init_state!(m::HB2DModel, Q::Vars, α::Vars, coords, t)
  return hb2d_init_state!(m.problem, Q, α, coords, t)
end

function boundary_state!(nf, m::HB2DModel, Q⁺::Vars, α⁺::Vars, n⁻,
                         Q⁻::Vars, α⁻::Vars, bctype, t, _...)
  return hb2d_boundary_state!(nf, m, Q⁺, α⁺, n⁻, Q⁻, α⁻, t)
end

@inline function hb2d_boundary_state!(::Rusanov, m::HB2DModel,
                                         Q⁺, α⁺, n⁻, Q⁻, α⁻, t)
  Q⁺.θ = -Q⁻.θ

  return nothing
end

hb2d_boundary_state!(::CentralGradPenalty, m::HB2DModel, _...) = nothing

hb2d_boundary_state!(::CentralNumericalFluxDiffusive, m::HB2DModel, _...) = nothing

function boundary_state!(nf, m::HB2DModel, Q⁺::Vars, σ⁺::Vars, α⁺::Vars, n⁻,
                         Q⁻::Vars, σ⁻::Vars, α⁻::Vars, bctype, t, _...)
  return hb2d_boundary_state!(nf, m, Q⁺, σ⁺, α⁺, n⁻, Q⁻, σ⁻, α⁻, t)
end

end
