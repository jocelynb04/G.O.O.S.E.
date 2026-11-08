function opts = grand_caravan_ex_initial_opts(obj)
%GRAND_CARAVAN_EX_INITIAL_OPTS  Initial guesses; NOT validated closure.
% Uses bundled helpers; water/land constraints remain surrogates.
    p = grand_caravan_ex_params();
    opts.W0 = p.MTOW_lb;
    opts.P0 = p.P_SL_shp;
    opts.S0 = p.S_ref_ft2;
    opts.WS_sweep = wing_loading_sweep(obj);
    opts.tol = 1e-5;
    opts.max_iter = 150;
    opts.relax = 0.10;  % numerical starting trial, not verified stable
end
