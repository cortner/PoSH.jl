
@testset "1-Particle Basis"  begin

##

using ACE
using Printf, Test, LinearAlgebra
using ACE: evaluate, evaluate_d, Rn1pBasis, Ylm1pBasis,
      EuclideanVectorState, Product1pBasis
using Random: shuffle

##

@info "Build a 1p basis from scratch"

maxdeg = 5
r0 = 1.0
rcut = 3.0

trans = PolyTransform(1, r0)
J = transformed_jacobi(maxdeg, trans, rcut; pcut = 2)
Rn = Rn1pBasis(J)
Ylm = Ylm1pBasis(maxdeg)
B1p = Product1pBasis( (Rn, Ylm) )
ACE.init1pspec!(B1p)

nX = 10
Xs = rand(EuclideanVectorState, Rn, nX)
cfg = ACEConfig(Xs)

A = evaluate(B1p, cfg)
# evaluate_d(B1p, Xs, X0)

@info("test against manual summation")
A1 = sum( evaluate(B1p, X) for X in Xs )
println(@test A1 ≈ A)

@info("test permutation invariance")
println(@test A ≈ evaluate(B1p, ACEConfig(shuffle(Xs))))

##

@info("basic evaluate_ed! tests")

tmp_d = ACE.alloc_temp_d(B1p)
A1 = ACE.alloc_B(B1p)
A2 = ACE.alloc_B(B1p)
ACE.evaluate!(A1, tmp_d, B1p, cfg)
dA = ACE.alloc_dB(B1p, length(cfg))
ACE.evaluate_ed!(A2, dA, tmp_d, B1p, cfg)
println(@test A1 ≈ A2)

##



##

end
