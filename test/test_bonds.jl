using ACE, Test, LinearAlgebra
using ACE: State, CylindricalBondEnvelope
using StaticArrays
using ACEbase.Testing: print_tf

## Use a specific example to test the Cylindrical cutoff

@info("Testing Cylindrical Bond Envelope")

r0cut = 8.0
rcut = 4.0
zcut = 2.0
env = CylindricalBondEnvelope(r0cut, rcut, zcut)

@info("Test :bond")

for i = 1:30
    rr = rand(SVector{3, Float64}) * 2 * r0cut / sqrt(3)
    r = norm(rr)
    X = State(rr = rr, rr0 = rr, be=:bond)
    print_tf(@test( filter(env, X) == (r <= r0cut) ))
end

##


@info ("Test :env")

r0 = SA[r0cut/2, 0.0, 0.0]
r_centre = r0 / 2
for i = 1:30
    rr = rand(SVector{3, Float64}) * env.rcut + r_centre
    X = State(rr = rr, rr0 = r0, be=:env)
    z = rr[1] - r_centre[1]
    r = sqrt(rr[2]^2 + rr[3]^2)
    filt = (abs(z) <= env.zcut+r_centre[1]) * (r <= env.rcut)
    print_tf(@test( filter(env, X) == (filt != 0) ))

    zeff = env.zcut + norm(r_centre)
    val = ((r/env.rcut)^2 - 1)^env.pr * ( (z/zeff)^2 - 1 )^env.pz * filt
    print_tf(@test( ACE._inner_evaluate(env, X) ≈ val ))
end


#%%

@info("Testing Elipsoid Bond Envelope")


r0cut = 2.0
rcut = 1.0
zcut = 2.0
for floppy = [false, true]
    env = ElipsoidBondEnvelope(r0cut, rcut, zcut;floppy=floppy)

    @info("Test :bond", floppy)

    for i = 1:30
        rr = rand(SVector{3, Float64}) * 2 * r0cut / sqrt(3)
        r = norm(rr)
        X = State(rr = rr, rr0 = rr, be=:bond)
        print_tf(@test( filter(env, X) == (r <= r0cut) ))
    end

    ##


    @info ("Test :env")

    r0 = @SVector [r0cut/2, 0.0, 0.0]
    r_centre = r0 / 2
    for i = 1:30
        rr = rand(SVector{3, Float64}) * env.rcut + r_centre
        X = State(rr = rr, rr0 = r0, be=:env)
        z = rr[1] - r_centre[1]
        r = sqrt(rr[2]^2 + rr[3]^2)
        zeff = env.zcut + env.floppy*norm(r_centre)

        filt = (((z/ zeff)^2 + (r/env.rcut)^2) <=1)
        print_tf(@test( filter(env, X) == (filt != 0) ))

        val = ( (z/zeff)^2 +  (r/env.rcut)^2 - 1.0)^env.pr * filt
        print_tf(@test( ACE._inner_evaluate(env, X) ≈ val ))
    end
end
