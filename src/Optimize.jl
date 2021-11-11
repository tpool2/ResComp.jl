include("ResComp.jl")
module Optimize
using LinearAlgebra
using Hyperopt
using Base.Threads


function f(system, nₛ, γ, σ, ρ, α)
        nᵣ::Int = 20;
        untrained = ResComp.initialize_rescomp(system, tanh, γ, σ, ρ, nᵣ, nₛ, α)
            
        r₀ = 2*rand(Float64, nᵣ).-0.5

        vpt = 0.0;

        try
                train_tspan = (0.0, 100.0);
                test_tspan = (0.0, 100.0) .+ train_tspan[2]
                trained, train_sol = ResComp.train(untrained, r₀, train_tspan);
                test_sol = ResComp.test(trained, train_sol.u[end], test_tspan);
                vpt = test_sol.t[end] - test_tspan[1];
        catch e
                if isa(e, LinearAlgebra.SingularException)
                        @warn "Could not solve least squares formulation"
                else
                        rethrow()
                end
        end;

        return -vpt
end;

function optimize_rescomp(system,nₛ)
        ho = @phyperopt for i = 100,
                γ = LinRange(0.01,25,100),
                σ = LinRange(0.01, 5.0,100),
                ρ = LinRange(0.01, 25, 100),
                α = LinRange(0.001, 0.5, 10)

                @show f(system,nₛ,γ,σ,ρ,α)
        end;
end;

end;