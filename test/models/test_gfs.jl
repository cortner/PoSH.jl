using LinearAlgebra: length

#@testset "GfsModel"  begin

    ##
    
    using ACE, ACEbase
    using Printf, Test, LinearAlgebra, ACE.Testing, Random
    using ACE: evaluate, evaluate_d, SymmetricBasis, NaiveTotalDegree, PIBasis
    using ACEbase.Testing: fdtest
    
    ##
    
    # ------------------------------------------------------------------------
    #    construct basis
    # ------------------------------------------------------------------------

    @info("Basic test of GFS model construction and evaluation")
    
    # construct the 1p-basis
    D = NaiveTotalDegree()
    maxdeg = 6
    ord = 3
    
    B1p = ACE.Utils.RnYlm_1pbasis(; maxdeg=maxdeg, D = D)

    φ = ACE.Invariant()
    pibasis = PIBasis(B1p, ord, maxdeg; property = φ)
    basis = SymmetricBasis(pibasis, φ)
    
    # ------------------------------------------------------------------------
    #    make training data -> configs
    # ------------------------------------------------------------------------

    # generate a configuration
    nX = 10
    Xs = rand(EuclideanVectorState, B1p.bases[1], nX)
    cfg = ACEConfig(Xs)
    
    # ------------------------------------------------------------------------
    #    Test the evaluation
    # ------------------------------------------------------------------------
    
    
    BB = evaluate(basis, cfg)
    c = rand(length(BB),2) .- 0.5
    
    fun = ACE.Models.FinnisSinclair(1/10)
    #fun = ACE.Models.ToyExp()

    #giving up for now
    #naive = ACE.Models.GfsModel(basis, c, evaluator = :naive, F = fun) 
    standard = ACE.Models.GfsModel(basis, c, evaluator = :standard, F = fun) 
    evaluate_ref(basis, cfg, c, F) = F([sum(evaluate(basis, cfg) .* c[:,1]).val, sum(evaluate(basis, cfg) .* c[:,2]).val])
    
    @show evaluate(standard, cfg) - evaluate_ref(basis,cfg,c,fun)
    #@show ACE.Models.nparams(standard)
    #@show ACE.Models.params(standard)
    #c_new = ones(length(BB),2)
    #ACE.Models.set_params!(standard,c_new)
    #@show evaluate(standard, cfg) - evaluate_ref(basis,cfg,c_new,fun)

    # ------------------------------------------------------------------------
    #    Test derivatives
    # ------------------------------------------------------------------------

    ϕ2 = evaluate(ACE.LinearACEModel(basis, c[:,2], ACE.PIEvaluator(basis, c[:,2])), cfg).val
    grad_params_ref_sqrt(basis,cfg) = [evaluate(basis, cfg), 
        (1/2)*(1/(sqrt((1/10)^2 + abs(ϕ2))))*(ϕ2/abs(ϕ2)) * evaluate(basis, cfg)]
    grad_params_ref_exp(basis,cfg) = [evaluate(basis, cfg), 
        -2*ϕ2*exp(-ϕ2^2)*evaluate(basis,cfg)]
    
    # g = ACE.Models.grad_params(standard,cfg)
    # g_ref = grad_params_ref_sqrt(basis, cfg)
    # for i in 1:length(c[:,1])
    #     @show g[1][i].val-g_ref[1][i].val
    #     @show g[2][i].val-g_ref[2][i].val
    # end
    
    ##
    
    # ------------------------------------------------------------------------
    #    Test optimizing
    # ------------------------------------------------------------------------

    #create random configs, basis and initialize params
    # construct the 1p-basis
    D = NaiveTotalDegree()
    maxdeg = 6
    ord = 3
    B1p = ACE.Utils.RnYlm_1pbasis(; maxdeg=maxdeg, D = D)
    φ = ACE.Invariant()
    pibasis = PIBasis(B1p, ord, maxdeg; property = φ)
    basis = SymmetricBasis(pibasis, φ)
    # generate a configurations
    cfgs = [ACEConfig(rand(EuclideanVectorState, B1p.bases[1], 10)) for _ in 1:20]

    BB = evaluate(basis, cfgs[1])
    c = rand(length(BB),2) .- 0.5 #notice the 2 indicates the number of models, it's a matrix

    #create a model
    FS = ACE.Models.FinnisSinclair(1/10)
    gfsModel = ACE.Models.GfsModel(basis, c, evaluator = :standard, F = FS) 
    y = ones(length(cfgs))
    
    # generate a loss function
    L(θ) = norm([evaluate(ACE.Models.set_params!(gfsModel,θ),cfgs[i]) - 
                y[i] for i in 1:length(cfgs)] ,2)^2

    #stochastic gradient descent
    θ = ones(length(BB),2)
    h = 0.00001
    @show L(θ)
    for _ in 1:500
        curr_loss = L(θ)
        #@show curr_loss
        i = rand(1:length(cfgs)) #choose a random config
        grad_loss = theta -> 2* (evaluate(ACE.Models.set_params!(gfsModel,θ),cfgs[i]) - y[i]) .* 
                        ACE.Models.grad_params(ACE.Models.set_params!(gfsModel,theta),cfgs[i])
        g = [collect(Iterators.flatten(grad_loss(θ)))[i].val for i in 1:length(θ[:])]
        θ[:] = θ[:] .- h .* g
        
    end

    @show L(θ)


    # ------------------------------------------------------------------------
    #    Finite difference test
    # ------------------------------------------------------------------------

    using StaticArrays

    @show "grad_config tests"
    for ntest = 1:30
        Us = randn(SVector{3, Float64}, length(Xs))
        F = t ->  evaluate(standard, ACEConfig(Xs + t[1] * Us))
        dF = t -> [sum([ dot(u, g) for (u, g) in zip(Us, ACE.Models.grad_config(standard,ACEConfig(Xs + t[1] * Us))) ])]
        print_tf(@test fdtest(F, dF, [0.0], verbose=false))
     end
     println()


     @show "grad_param tests"
     cfg = ACEConfig(Xs)
     for ntest = 1:30
         c_tst = rand(length(BB),2) .- 0.5
         F = t ->  evaluate(ACE.Models.set_params!(standard,c_tst[:] + t), cfg)
         dF = t -> [collect(Iterators.flatten(ACE.Models.grad_params(ACE.Models.set_params!(standard,c_tst[:] + t),cfg)))[i].val for i in 1:length(c_tst[:])]
         print_tf(@test fdtest(F, dF, zeros(length(c_tst)), verbose=false))
      end
      println()
     

    ##Possible code for working with Flux

    ##sample nonlinearity
    # struct GfsNonLin{nonLin, M<:AbstractMatrix}
    #     σ::nonLin #the nonlinearity, sigma is activation fucntion notation.
    #     θ::M #matrix of parameters with one column one linear model.
    # end
    # #basis params is the length of the linear models, for now all same size
    # #len_rho is the number of linear models 
    # function GfsNonLin(basis_params, len_rho, σ = ϕ -> sum(ϕ))
    #     θ = ones(basis_params,len_rho)
    #     return(GfsNonLin(σ,θ))
    # end
    # #for now x is any but should be ::LinearACEModel
    # function (a::GfsNonLin)(x::Vector{any}) #trying to take a vector of ace models
    #     θ, σ = a.params, a.σ
    #     return σ([evaluate(set_params!(x[i],θ[:,i])).val for i in 1:length(x)])
    # end
    #F = GfsNonLin(5, 2, fun)

#end
