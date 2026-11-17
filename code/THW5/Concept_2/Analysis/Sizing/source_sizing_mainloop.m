function [hist,converged,state] = source_sizing_mainloop(obj,opts)
%SOURCE_SIZING_MAINLOOP Hybrid weight closure with independent source states.
% opts: W0, WS_sweep, contexts, energy_model, tol, max_iter, relax.
% Each pass fully re-sizes motor/inverter/pack at each sampled wing area.
% Only W_TO is relaxed: these source states are inner-solve outputs, not
% a fixed motor/turbine split or a scalar summed-power iterate.
    required={'W0','WS_sweep','contexts','energy_model','tol','max_iter','relax'};
    for k=1:numel(required)
        if ~isfield(opts,required{k})
            error('source_sizing_mainloop:InputRequired','Supply opts.%s.',required{k});
        end
    end
    validateattributes(opts.W0,{'numeric'},{'scalar','finite','positive'});
    validateattributes(opts.tol,{'numeric'},{'scalar','finite','positive'});
    validateattributes(opts.max_iter,{'numeric'},{'scalar','integer','positive'});
    validateattributes(opts.relax,{'numeric'},{'scalar','>',0,'<=',1});
    W=opts.W0; hist=struct([]); converged=false;
    previous=[];
    state=struct('status',"not converged",'W0',W,'n_iter',0);
    for iter=1:opts.max_iter
        b=source_constraint_sizing(obj,W,opts.WS_sweep,opts.contexts,opts.energy_model);
        if b.status~="pass"
            state.status=b.status; state.search=b; state.n_iter=iter;
            return;
        end
        % Component masses are absolute estimates, not fixed weight fractions.
        % A negative useful-load fraction at one guess does not prove that
        % no root exists. Iterate the actual mass balance with relaxation.
        Wnew=obj.wts.payload()+b.OEW_breakdown.total+b.mission.fuel_lb;
        denom=1-(b.OEW_breakdown.total+b.mission.fuel_lb)/W;
        if ~isfinite(Wnew)
            state.status="infeasible weight closure"; state.search=b;
            state.n_iter=iter; return;
        end
        r=b.ratings;
        values=[W,r.S_ref,r.P_motor_peak,r.P_motor_continuous, ...
            r.P_inverter_rated_kW,r.E_battery_nominal_kWh];
        delta=Inf;
        if ~isempty(previous)
            delta=max(abs(values-previous)./max(abs(values),1e-9));
        end
        row=struct('iter',iter,'W_TO',W,'W_TO_new',Wnew,'denom',denom, ...
            'res_W',abs(Wnew-W)/Wnew,'res_sources',delta,'WS',b.WS, ...
            'S_ref',r.S_ref,'P_turbine_TO',obj.prop.P_turbine_TO, ...
            'P_turbine_continuous',obj.prop.P_turbine_continuous, ...
            'P_motor_peak',r.P_motor_peak,'P_motor_continuous',r.P_motor_continuous, ...
            'P_inverter_rated_kW',r.P_inverter_rated_kW, ...
            'E_battery_nominal_kWh',r.E_battery_nominal_kWh, ...
            'W_fuel',b.mission.fuel_lb,'OEW',b.OEW_breakdown.total, ...
            'constraints',b.report,'mission',b.mission);
        if isempty(hist), hist=row;
        else, hist(iter)=row; end
        % Install exactly the evaluated aircraft. Do not substitute Wnew
        % without recomputing geometry, power margins, SOC and empty weight.
        obj.geom.W_TO=W; obj.geom.S_ref=r.S_ref; obj.wts.W_TO=W;
        obj.wts.W_energy=b.mission.fuel_lb;
        obj.prop.P_motor_peak=r.P_motor_peak;
        obj.prop.P_motor_continuous=r.P_motor_continuous;
        obj.prop.P_inverter_rated_kW=r.P_inverter_rated_kW;
        obj.wts.E_battery_nominal_kWh=r.E_battery_nominal_kWh;
        state=struct('status',"not converged",'W0',W,'S0',r.S_ref, ...
            'ratings',r,'n_iter',iter,'constraints',b.report,'mission',b.mission, ...
            'OEW_breakdown',b.OEW_breakdown);
        if row.res_W<opts.tol && delta<opts.tol
            converged=true; state.status="converged"; return;
        end
        previous=values;
        W=SizingSteps.relax(W,Wnew,opts.relax);
    end
end
