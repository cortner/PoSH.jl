
# --------------------------------------------------------------------------
# ACE.jl and SHIPs.jl: Julia implementation of the Atomic Cluster Expansion
# Copyright (c) 2019 Christoph Ortner <christophortner0@gmail.com>
# All rights reserved.
# --------------------------------------------------------------------------



using SHIPs, SHIPs.SphericalHarmonics, StaticArrays, LinearAlgebra
using SHIPs: _mrange

module RotationCoeffs

   using SHIPs, SHIPs.SphericalHarmonics, StaticArrays, LinearAlgebra
   using SHIPs: _mrange

   struct CoeffArray{NMAX}
      vals::SVector{NMAX, Dict}
      cg::ClebschGordan{Float64}
   end

   dicttype(N::Integer) = dicttype(Val(N))
   dicttype(::Val{N}) where {N} =
         Dict{Tuple{SVector{N,Int8}, SVector{N,Int8}, SVector{N,Int8}}, Float64}


   function CoeffArray(Nmax, Lmax)
      vals = SVector{Nmax, Dict}([ dicttype(N)() for N = 1:Nmax ]...)
      cg = ClebschGordan(Lmax)
      return CoeffArray(vals, cg)
   end


   function get_vals(A::CoeffArray, ::Val{N}) where {N}
      return A.vals[N]::Dict{Tuple{SVector{N,Int8}, SVector{N,Int8}, SVector{N,Int8}}, Float64}
   end

   _key(ll::StaticVector{N}, mm::StaticVector{N}, kk::StaticVector{N}) where {N} =
         (SVector{N, Int8}(ll), SVector{N, Int8}(mm), SVector{N, Int8}(kk))

   function (A::CoeffArray)(ll::StaticVector{N},
                            mm::StaticVector{N},
                            kk::StaticVector{N}) where {N}
      vals = A.vals[N]::Dict{Tuple{SVector{N,Int8}, SVector{N,Int8}, SVector{N,Int8}}, Float64}
      key = _key(ll, mm, kk)
      if haskey(vals, key)
         val  = vals[key]
      else
         val = _compute_val(A, key...)
         vals[key] = val
      end
      return val
   end

   function _compute_val(A::CoeffArray, ll::StaticVector{N},
                                        mm::StaticVector{N},
                                        kk::StaticVector{N}) where {N}
      val = 0.0
      llp = ll[1:N-2]
      mmp = ll[1:N-2]
      kkp = ll[1:N-2]
      for j = abs(ll[N-1]-ll[N]):(ll[N-1]+ll[N])
         if abs(kk[N-1]+kk[N]) > j || abs(mm[N-1]+mm[N]) > j
            continue
         end
         val += A.cg(ll[N-1], kk[N-1], ll[N], kk[N], j, kk[N-1]+kk[N]) *
                A.cg(ll[N-1], mm[N-1], ll[N], mm[N], j, mm[N-1]+mm[N]) *
                      A( SVector(llp..., j),
                         SVector(mmp..., mm[N-1]+mm[N]),
                         SVector(kkp..., kk[N-1]+kk[N]) )
      end
      return val
   end

   _compute_val(A::CoeffArray, ll::StaticVector{2},
                               mm::StaticVector{2},
                               kk::StaticVector{2}) = (
      ll[1] == ll[2] ? 8 * pi^2 / (2*ll[1]+1) * (-1)^(kk[2]-mm[2]) : 0.0 )

   compute_Al(ll::SVector{N}) where {N} =
      compute_Al(CoeffArray(N, sum(ll)), ll)

   function compute_Al(A::CoeffArray, ll::SVector)
      len = 0
      for mm in _mrange(ll)
         len += 1
      end
      CC = zeros(len, len)
      for (im, mm) in enumerate(_mrange(ll)), (ik, kk) in enumerate(_mrange(ll))
         CC[ik, im] = A(ll, mm, kk)
      end
      return CC
   end
end

ll = SVector(3,2,4)
A = RotationCoeffs.CoeffArray(5, 12)
ll = SVector(3,2)
@time Cl = RotationCoeffs.compute_Al(A, ll)
ll = SVector(4,3,3,2)
@time Cl = RotationCoeffs.compute_Al(A, ll)
@time Cold = compute_Ckm_old(ll)

Ul = svd(Cl).U[:, 1:5]
Uo = svd(Cold).U[:, 1:5]

rank([Ul Uo])


ll = SVector(2, 2, 2, 2, 2)
Cl = RotationCoeffs.compute_Al(A, ll)
rank(Cl)
Matrix(svd(Cl).U)
A.vals[5]

function compute_Ckm_old(ll::SVector{4})
   cg = ClebschGordan(sum(ll))

   len = 0
   for mm in _mrange(ll)
      len += 1
   end
   @show len

   Ckm = zeros(len, len)

   for (im, mm) in enumerate(_mrange(ll)), (ik, kk) in enumerate(_mrange(ll))
      jlo = max(abs(ll[1]-ll[2]), abs(ll[3]-ll[4]))
      jhi = min(ll[1]+ll[2], ll[3]+ll[4])
      for j = jlo:jhi
         if (abs(mm[1]+mm[2]) > j) || (abs(mm[3]+mm[4]) > j) ||
            (abs(kk[1]+kk[2]) > j) || (abs(kk[3]+kk[4]) > j)
            continue
         end
         cg1 = cg(ll[1], mm[1], ll[2], mm[2], j, mm[1]+mm[2])
         cg2 = cg(ll[3], mm[3], ll[4], mm[4], j, mm[3]+mm[4])
         cg3 = cg(ll[1], kk[1], ll[2], kk[2], j, kk[1]+kk[2])
         # @show ll[3], kk[3], ll[4], kk[4], j, kk[3]+kk[4]
         cg4 = cg(ll[3], kk[3], ll[4], kk[4], j, kk[3]+kk[4])
         Ckm[ik,im] += 8 * pi^2 * (-1)^(mm[1]+mm[2]-kk[1]-kk[2]) / (2*j+1) *
                       cg(ll[1], mm[1], ll[2], mm[2], j, mm[1]+mm[2]) *
                       cg(ll[3], mm[3], ll[4], mm[4], j, mm[3]+mm[4]) *
                       cg(ll[1], kk[1], ll[2], kk[2], j, kk[1]+kk[2]) *
                       cg(ll[3], kk[3], ll[4], kk[4], j, kk[3]+kk[4])
      end
   end
   return Ckm
end


# CASE 1
ll1 = SVector(2,1,1,2)
Ckm = compute_Ckm(ll1)
@show rank(Ckm)
svdf = svd(Ckm)
@show svdf.S[1:5]
for i = 1:3
   @info("V[:,$i]")
   @show round.(svdf.Vt[i,:], digits=2)
end

# CASE 2
ll2 = SVector(2,3,4,3)
Ckm = compute_Ckm(ll2)
@show rank(Ckm)
@show svdvals(Ckm)[1:8]

# CASE 3
ll3 = SVector(5,4,4,3)
Ckm = compute_Ckm(ll3)
@show rank(Ckm)
@show svdvals(Ckm)[1:10]


# MAIN EXAMPLE:
ll = SVector(1,1,1,1)
Ckm = compute_Ckm(ll)
Ckm_sym = [0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 15.7914 0.0 -7.89568 -7.89568 2.63189 5.26379 2.63189 0.0 -7.89568 -7.89568 5.26379 10.5276 5.26379 -7.89568 -7.89568 0.0 2.63189 5.26379 2.63189 -7.89568 -7.89568 0.0 15.7914 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 -7.89568 0.0 10.5276 -2.63189 -7.89568 -2.63189 5.26379 0.0 -2.63189 10.5276 -2.63189 -5.26379 -2.63189 10.5276 -2.63189 0.0 5.26379 -2.63189 -7.89568 -2.63189 10.5276 0.0 -7.89568 0.0 0.0; 0.0 0.0 -7.89568 0.0 -2.63189 10.5276 5.26379 -2.63189 -7.89568 0.0 10.5276 -2.63189 -2.63189 -5.26379 -2.63189 -2.63189 10.5276 0.0 -7.89568 -2.63189 5.26379 10.5276 -2.63189 0.0 -7.89568 0.0 0.0; 0.0 0.0 2.63189 0.0 -7.89568 5.26379 15.7914 -7.89568 2.63189 0.0 5.26379 -7.89568 -7.89568 10.5276 -7.89568 -7.89568 5.26379 0.0 2.63189 -7.89568 15.7914 5.26379 -7.89568 0.0 2.63189 0.0 0.0; 0.0 0.0 5.26379 0.0 -2.63189 -2.63189 -7.89568 10.5276 -7.89568 0.0 -2.63189 -2.63189 10.5276 -5.26379 10.5276 -2.63189 -2.63189 0.0 -7.89568 10.5276 -7.89568 -2.63189 -2.63189 0.0 5.26379 0.0 0.0; 0.0 0.0 2.63189 0.0 5.26379 -7.89568 2.63189 -7.89568 15.7914 0.0 -7.89568 5.26379 -7.89568 10.5276 -7.89568 5.26379 -7.89568 0.0 15.7914 -7.89568 2.63189 -7.89568 5.26379 0.0 2.63189 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 -7.89568 0.0 -2.63189 10.5276 5.26379 -2.63189 -7.89568 0.0 10.5276 -2.63189 -2.63189 -5.26379 -2.63189 -2.63189 10.5276 0.0 -7.89568 -2.63189 5.26379 10.5276 -2.63189 0.0 -7.89568 0.0 0.0; 0.0 0.0 -7.89568 0.0 10.5276 -2.63189 -7.89568 -2.63189 5.26379 0.0 -2.63189 10.5276 -2.63189 -5.26379 -2.63189 10.5276 -2.63189 0.0 5.26379 -2.63189 -7.89568 -2.63189 10.5276 0.0 -7.89568 0.0 0.0; 0.0 0.0 5.26379 0.0 -2.63189 -2.63189 -7.89568 10.5276 -7.89568 0.0 -2.63189 -2.63189 10.5276 -5.26379 10.5276 -2.63189 -2.63189 0.0 -7.89568 10.5276 -7.89568 -2.63189 -2.63189 0.0 5.26379 0.0 0.0; 0.0 0.0 10.5276 0.0 -5.26379 -5.26379 10.5276 -5.26379 10.5276 0.0 -5.26379 -5.26379 -5.26379 15.7914 -5.26379 -5.26379 -5.26379 0.0 10.5276 -5.26379 10.5276 -5.26379 -5.26379 0.0 10.5276 0.0 0.0; 0.0 0.0 5.26379 0.0 -2.63189 -2.63189 -7.89568 10.5276 -7.89568 0.0 -2.63189 -2.63189 10.5276 -5.26379 10.5276 -2.63189 -2.63189 0.0 -7.89568 10.5276 -7.89568 -2.63189 -2.63189 0.0 5.26379 0.0 0.0; 0.0 0.0 -7.89568 0.0 10.5276 -2.63189 -7.89568 -2.63189 5.26379 0.0 -2.63189 10.5276 -2.63189 -5.26379 -2.63189 10.5276 -2.63189 0.0 5.26379 -2.63189 -7.89568 -2.63189 10.5276 0.0 -7.89568 0.0 0.0; 0.0 0.0 -7.89568 0.0 -2.63189 10.5276 5.26379 -2.63189 -7.89568 0.0 10.5276 -2.63189 -2.63189 -5.26379 -2.63189 -2.63189 10.5276 0.0 -7.89568 -2.63189 5.26379 10.5276 -2.63189 0.0 -7.89568 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 2.63189 0.0 5.26379 -7.89568 2.63189 -7.89568 15.7914 0.0 -7.89568 5.26379 -7.89568 10.5276 -7.89568 5.26379 -7.89568 0.0 15.7914 -7.89568 2.63189 -7.89568 5.26379 0.0 2.63189 0.0 0.0; 0.0 0.0 5.26379 0.0 -2.63189 -2.63189 -7.89568 10.5276 -7.89568 0.0 -2.63189 -2.63189 10.5276 -5.26379 10.5276 -2.63189 -2.63189 0.0 -7.89568 10.5276 -7.89568 -2.63189 -2.63189 0.0 5.26379 0.0 0.0; 0.0 0.0 2.63189 0.0 -7.89568 5.26379 15.7914 -7.89568 2.63189 0.0 5.26379 -7.89568 -7.89568 10.5276 -7.89568 -7.89568 5.26379 0.0 2.63189 -7.89568 15.7914 5.26379 -7.89568 0.0 2.63189 0.0 0.0; 0.0 0.0 -7.89568 0.0 -2.63189 10.5276 5.26379 -2.63189 -7.89568 0.0 10.5276 -2.63189 -2.63189 -5.26379 -2.63189 -2.63189 10.5276 0.0 -7.89568 -2.63189 5.26379 10.5276 -2.63189 0.0 -7.89568 0.0 0.0; 0.0 0.0 -7.89568 0.0 10.5276 -2.63189 -7.89568 -2.63189 5.26379 0.0 -2.63189 10.5276 -2.63189 -5.26379 -2.63189 10.5276 -2.63189 0.0 5.26379 -2.63189 -7.89568 -2.63189 10.5276 0.0 -7.89568 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 15.7914 0.0 -7.89568 -7.89568 2.63189 5.26379 2.63189 0.0 -7.89568 -7.89568 5.26379 10.5276 5.26379 -7.89568 -7.89568 0.0 2.63189 5.26379 2.63189 -7.89568 -7.89568 0.0 15.7914 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0]

badI = [1,2,4,10, 18, 24, 26, 27]
goodI = setdiff(1:27, badI)
Ckm_sym = Ckm_sym[goodI, goodI]


display(Ckm_sym[:, [1,2,3]])
display(Ckm[:, [1,2,3]])

norm(Ckm_sym - Ckm, Inf)
svdvals(Ckm)
svdvals(Ckm_sym)

ll = SVector(2,1,1,1)
Ckm = compute_Ckm(ll)
rank(Ckm)
c1 = Ckm[:,1]
c2 = Ckm[:,3]
c1 /= norm(c1)
c2 /= norm(c2)
[sort(c1) sort(c2)]

U = svd(Ckm).U[:,1:2]
[ sort(U[:,1]) sort(U[:,2]) ]
U' * U

svd(Ckm)

for l = 1:6
   ll = SVector(l,l,l,l)
   Ckm = compute_Ckm(ll)
   @show l, rank(Ckm)
end
