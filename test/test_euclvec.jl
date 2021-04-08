
@testset "EuclideanVector"  begin

#---


using ACE
using Random, Printf, Test, LinearAlgebra, ACE.Testing
using ACE: evaluate, evaluate_d, SymmetricBasis, NaiveTotalDegree, PIBasis
using ACE.Random: rand_rot, rand_refl


# construct the 1p-basis
D = NaiveTotalDegree()
maxdeg = 6
ord = 3

B1p = ACE.Utils.RnYlm_1pbasis(; maxdeg=maxdeg, D = D)

# generate a configuration
nX = 10
Xs = rand(EuclideanVectorState, B1p.bases[1], nX)
cfg = ACEConfig(Xs)

#---

@info("SymmetricBasis construction and evaluation: EuclideanVector")

φ = ACE.EuclideanVector(Complex{Float64})
pibasis = PIBasis(B1p, ord, maxdeg; property = φ, isreal=false)
basis = SymmetricBasis(pibasis, φ)

BB = evaluate(basis, cfg)

# a stupid but necessary test
BB1 = basis.A2Bmap * evaluate(basis.pibasis, cfg)
println(@test isapprox(BB, BB1, rtol=1e-10))

##

@info("Test equivariance properties")

tol = 1E-9

@info("check for rotation, permutation and inversion equivariance")
for ntest = 1:20
      Xs = rand(EuclideanVectorState, B1p.bases[1], nX)
      BB = evaluate(basis, ACEConfig(Xs))
      Q = rand([-1,1]) * ACE.Random.rand_rot()
      Xs_rot = Ref(Q) .* shuffle(Xs)
      BB_rot = evaluate(basis, ACEConfig(Xs_rot))
      print_tf(@test all([ norm(Q' * b1 - b2) < tol
                           for (b1, b2) in zip(BB_rot, BB)  ]))
end
println()

##


end