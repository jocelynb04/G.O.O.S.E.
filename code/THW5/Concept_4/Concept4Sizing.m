classdef Concept4Sizing < handle
    properties
        J
        assumptions
        prop
        geom
        aero
        hydro
        weights
        mission
        initial
    end
    methods
        function obj = Concept4Sizing(J,assumptions)
            obj.J = J;
            obj.assumptions = assumptions;
            obj.prop = SeaplaneProp_Concept4(J);
            obj.geom = SeaplaneGeom(J,obj.prop);
            obj.aero = SeaplaneAero_Concept4(J,obj.geom);
            obj.hydro = SeaplaneHydro_Concept4(J,obj.geom,obj.aero);
            obj.weights = SeaplaneWeights(J,obj.geom,obj.prop);
            obj.mission = Concept4Mission(J,obj.geom,obj.aero,obj.prop,assumptions);
            S = J.sizing;
            obj.initial = struct('W_TO_lb',S.W_TO_guess_lbf, ...
                'S_ref_ft2',S.S_ref_guess_ft2,'motor_shaft_hp',S.P_SL_guess_hp, ...
                'generator_engine_hp_each',S.generator_engine_shaft_power_guess_hp_each, ...
                'battery_capacity_kwh',S.battery_capacity_guess_kwh);
        end
        function write_design(obj,state)
            obj.geom.S_ref = state.S_ref_ft2;
            obj.prop.P_SL = state.motor_shaft_hp;
            obj.prop.engine_shaft_power_sl_hp_each = state.generator_engine_hp_each;
            obj.prop.battery_capacity_kwh = state.battery_capacity_kwh;
        end
        function row = sizing_pass(obj,state)
            W = state.W_TO_lb;
            obj.write_design(state);
            env = matching_envelope_C4(obj.J,obj.geom,obj.aero,obj.prop,W,obj.assumptions);
            if isempty(env.selected)
                error('C4:SizingInfeasible','%s',env.status);
            end
            best = env.selected;
            proposed = struct('W_TO_lb',W,'S_ref_ft2',best.wing_area_ft2, ...
                'motor_shaft_hp',best.required_motor_hp, ...
                'generator_engine_hp_each',best.required_turboshaft_hp_each, ...
                'battery_capacity_kwh',state.battery_capacity_kwh);
            obj.write_design(proposed);
            energy_probe = obj.mission.run(W,'std_mission',true);
            usable = obj.prop.battery_initial_soc-obj.prop.battery_min_soc;
            energy_required = energy_probe.peak_cumulative_pack_deficit_kwh/usable;
            minimum_capacity = c4_get(obj.assumptions,'minimum_battery_capacity_kwh',80);
            proposed.battery_capacity_kwh = max(minimum_capacity,energy_required * ...
                (1+obj.assumptions.battery_energy_margin_fraction));
            obj.write_design(proposed);
            real = obj.mission.run(W);
            bd = obj.weights.OEW_breakdown(W);
            payload_lb = obj.weights.payload();
            fuel_lb = real.total_fuel_lb;
            gross = bd.total+payload_lb+fuel_lb;
            if ~isfinite(gross) || gross <= 0
                error('C4:SizingInfeasible','Weight closure is nonphysical.');
            end
            if gross > obj.assumptions.max_gross_weight_search_lb
                error('C4:SizingInfeasible','Gross weight exceeds user-configured search ceiling.');
            end
            proposed.W_TO_lb = gross;
            names = fieldnames(state);
            res = struct();
            for i = 1:numel(names)
                key = names{i};
                res.(key) = abs(proposed.(key)-state.(key))/max(abs(proposed.(key)),1e-12);
            end
            vals = struct2cell(res);
            max_residual = max(cell2mat(vals));
            limit = obj.J.rfp_performance_requirements.maximum_wingspan_ft_strictly_below;
            if obj.geom.b < limit, span_screen = 'PRELIMINARY_PASS';
            else, span_screen = 'FAIL'; end
            row = struct('current',state,'proposed',proposed, ...
                'residuals',res,'max_residual',max_residual,'OEW_lb',bd.total, ...
                'payload_lb',payload_lb,'mission_fuel_lb',fuel_lb, ...
                'mission_soc_end',real.soc_end, ...
                'energy_probe_peak_deficit_kwh',energy_probe.peak_cumulative_pack_deficit_kwh, ...
                'minimum_capacity_kwh_before_margin',energy_required, ...
                'span_ft',obj.geom.b,'span_screen',span_screen, ...
                'chosen_aero_constraints',best);
        end
        function result = run(obj,max_iter,tol,relaxation)
            S = obj.J.sizing;
            if nargin < 2 || isempty(max_iter), max_iter = S.max_iter; end
            if nargin < 3 || isempty(tol), tol = S.tol_rel; end
            if nargin < 4 || isempty(relaxation), relaxation = S.relaxation; end
            if relaxation <= 0 || relaxation > 1
                error('C4:Sizing','Relaxation must be in (0,1].');
            end
            state = obj.initial;
            hist = struct([]);
            converged = false;
            reason = '';
            names = fieldnames(state);
            for k = 1:max_iter
                try
                    row = obj.sizing_pass(state);
                catch ME
                    reason = sprintf('Iteration %d: %s',k,ME.message);
                    break;
                end
                row.iteration = k;
                if isempty(hist), hist = row; else, hist(end+1) = row; end
                if row.max_residual < tol
                    state = row.proposed;
                    converged = true;
                    break;
                end
                for i = 1:numel(names)
                    key = names{i};
                    state.(key) = state.(key)+relaxation*(row.proposed.(key)-state.(key));
                end
            end
            if ~converged && isempty(reason)
                reason = sprintf('Maximum iterations (%d) reached.',max_iter);
            end
            obj.write_design(state);
            final = [];
            final_error = '';
            try
                mission_result = obj.mission.run(state.W_TO_lb);
                bd = obj.weights.OEW_breakdown(state.W_TO_lb);
                closure = state.W_TO_lb-bd.total-obj.weights.payload()-mission_result.total_fuel_lb;
                buoyancy = obj.hydro.buoyancy_screen(state.W_TO_lb);
                drag = obj.aero.drag_breakdown(struct('alt_ft',10000,'ktas',180));
                final = struct('mission',mission_result,'OEW_breakdown_lb',bd, ...
                    'payload_lb',obj.weights.payload(),'mass_closure_residual_lb',closure, ...
                    'wingspan_ft',obj.geom.b,'CD0_reference_180kt',drag.CD0_total, ...
                    'buoyancy',buoyancy);
                if converged && abs(closure) > 2*tol*state.W_TO_lb
                    converged = false;
                    reason = 'Final unrelaxed mass closure outside tolerance.';
                end
            catch ME
                final_error = ME.message;
                if converged
                    converged = false;
                    reason = ['Final mission check failed: ' final_error];
                end
            end
            if converged, status = 'NUMERICALLY_CONVERGED_PRELIMINARY_ONLY';
            else, status = 'NOT_CONVERGED'; end
            result = struct('status',status,'converged',converged, ...
                'failure_reason',reason,'final_mission_error',final_error, ...
                'iterations_completed',numel(hist),'state',state,'history',hist, ...
                'final',final,'limitations',{{ ...
                'Water takeoff and landing distances not verified', ...
                'OEI drag and yaw control not verified', ...
                'Battery and turboshaft performance maps not validated', ...
                'Float flooding and 20 degree heel not verified', ...
                'Dock clearance sea state 3 FIKI and noise not verified', ...
                'Aircraft and component dimensions provisional'}});
        end
    end
end
