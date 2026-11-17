function [hist, converged, state] = sizing_mainloop(obj, opts)
%SIZING_MAINLOOP  Iterate sizing passes until weight and power stop moving.
%
%   [hist, converged, state] = sizing_mainloop(obj, opts)
%
%   Inputs
%     obj   discipline bundle from ttpa_disciplines. MUTATED: on return it
%           holds the converged airplane (P_SL and S_ref written).
%     opts  struct
%             .W0 .P0 .S0   starting guesses [lbf, hp, ft^2]
%             .WS_sweep     wing-loading sweep for the constraint analysis
%             .tol          relative tolerance on BOTH W and P
%             .max_iter     pass limit
%             .relax        under-relaxation factor w, 0 < w <= 1
%   Outputs
%     hist       1xN struct array, one sizing_pass row per pass
%     converged  true if both residuals fell below tol
%     state      struct .W0 .P0 .S0 (the returned airplane) and .n_iter
%
%   THE ITERATION
%
%     repeat
%        row = sizing_pass(obj, W0, P0, S0, WS_sweep)
%        stop if  |W_new - W0|/W_new < tol  AND  |P_new - P0|/P_new < tol
%        otherwise relax all three states:  x <- x + w (x_new - x)
%
%   S_ref is not tested separately but is relaxed along with W0 and P0.

    W0 = opts.W0;
    P0 = opts.P0;
    S0 = opts.S0;

    converged = false;

    for iter = 1:opts.max_iter
        % --- Milestone 1: one pass from the current states ---------------
        row = sizing_pass(obj, W0, P0, S0, opts.WS_sweep);
        row.iter = iter;
        if iter == 1
            hist = row;
        else
            hist(iter) = row;
        end

        % --- Milestone 2: stop when BOTH residuals are below opts.tol ----
        if row.res_W < opts.tol && row.res_P < opts.tol
            W0 = row.W_TO_new;
            P0 = row.P_SL_new;
            S0 = row.S_ref_new;
            converged = true;
            break;
        end

        % --- Milestone 3: otherwise relax all three states ---------------
        W0 = SizingSteps.relax(W0, row.W_TO_new, opts.relax);
        P0 = SizingSteps.relax(P0, row.P_SL_new, opts.relax);
        S0 = SizingSteps.relax(S0, row.S_ref_new, opts.relax);
    end

    % --- Milestone 4: leave the bundle holding the airplane returned -----
    obj.prop.P_SL = P0;
    obj.geom.S_ref = S0;

    state = struct('W0', W0, 'P0', P0, 'S0', S0, 'n_iter', iter);

    if ~converged
        warning('sizing_mainloop:notConverged', ...
            ['The main loop did not close in %d passes at relaxation %.2f. ', ...
             'Last W_TO = %.1f lbf, residuals %.2e (weight), %.2e (power).'], ...
            opts.max_iter, opts.relax, W0, hist(end).res_W, hist(end).res_P);
    end
end
