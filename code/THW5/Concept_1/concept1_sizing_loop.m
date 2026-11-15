function [hist, converged, state] = concept1_sizing_loop(obj, opts)
%CONCEPT1_SIZING_LOOP  Iterate Concept 1 takeoff weight, power, and wing area.
%
%   This is Step 12, adapted from the professor's sizing_mainloop.m. Each
%   iteration calls concept1_sizing_pass, then checks takeoff-weight and
%   reference-power residuals. The three states are under-relaxed between
%   passes. The pass itself closes weight with W_energy = W_fuel + W_battery.
%
%   Required opts fields:
%     W0         initial takeoff-weight guess [lbf]
%     P0         initial reference-power guess [hp]
%     S0         initial wing-area guess [ft^2]
%     WS_sweep   wing-loading sweep [lbf/ft^2]
%     tol        relative convergence tolerance for weight and power [-]
%     max_iter   maximum number of passes
%     relax      under-relaxation factor in (0,1]
%
%   Outputs
%     hist       one Concept 1 sizing-pass record per iteration
%     converged  true when weight and power residuals are below tolerance
%     state      final guesses and number of passes

    arguments
        obj (1,1) struct
        opts (1,1) struct
    end

    required = {'W0','P0','S0','WS_sweep','tol','max_iter','relax'};
    for k = 1:numel(required)
        if ~isfield(opts, required{k})
            error('concept1_sizing_loop:MissingOption', ...
                'Sizing options are missing required field "%s".', required{k});
        end
    end

    validateattributes(opts.W0, {'numeric'}, ...
        {'scalar','real','finite','positive'}, mfilename, 'opts.W0');
    validateattributes(opts.P0, {'numeric'}, ...
        {'scalar','real','finite','positive'}, mfilename, 'opts.P0');
    validateattributes(opts.S0, {'numeric'}, ...
        {'scalar','real','finite','positive'}, mfilename, 'opts.S0');
    validateattributes(opts.WS_sweep, {'numeric'}, ...
        {'vector','real','finite','positive','nonempty'}, mfilename, 'opts.WS_sweep');
    validateattributes(opts.tol, {'numeric'}, ...
        {'scalar','real','finite','positive'}, mfilename, 'opts.tol');
    validateattributes(opts.max_iter, {'numeric'}, ...
        {'scalar','real','finite','positive','integer'}, mfilename, 'opts.max_iter');
    validateattributes(opts.relax, {'numeric'}, ...
        {'scalar','real','finite','>',0,'<=',1}, mfilename, 'opts.relax');

    W0 = opts.W0;
    P0 = opts.P0;
    S0 = opts.S0;
    converged = false;
    hist = struct([]);

    for iter = 1:opts.max_iter
        row = concept1_sizing_pass(obj, W0, P0, S0, opts.WS_sweep);
        row.iter = iter;
        if iter == 1
            hist = row;
        else
            hist(iter) = row;
        end

        % Match the professor's stopping rule: weight and power must settle.
        if row.res_W < opts.tol && row.res_P < opts.tol
            W0 = row.W_TO_new;
            P0 = row.P_SL_new;
            S0 = row.S_ref_new;
            converged = true;
            break;
        end

        W0 = Concept1_iteration.relax(W0, row.W_TO_new, opts.relax);
        P0 = Concept1_iteration.relax(P0, row.P_SL_new, opts.relax);
        S0 = Concept1_iteration.relax(S0, row.S_ref_new, opts.relax);
    end

    % Leave the shared handle objects at the final sizing state.
    obj.prop.P_SL = P0;
    obj.geom.S_ref = S0;
    state = struct('W0', W0, 'P0', P0, 'S0', S0, ...
        'n_iter', numel(hist));

    if ~converged
        warning('concept1_sizing_loop:NotConverged', ...
            ['Sizing did not converge in %d passes. Last recorded residuals: ', ...
             'weight %.3g, power %.3g.'], ...
            opts.max_iter, hist(end).res_W, hist(end).res_P);
    end
end
