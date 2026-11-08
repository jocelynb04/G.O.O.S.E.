classdef TtpaProp < PropulsionBase2
%TTPAPROP  Preliminary parallel-hybrid turboprop propulsion model.
%   Turbine and motor ratings are separate aircraft-total shaft powers.
%   Default catalog mode uses fixed GE reference-engine ratings, mass and
%   length, and public altitude/OAT charts with documented approximations.
%   turbine_power_available returns absolute aircraft-total turbine hp.
%   P_SL is a reporting sum, not universally available power.
%   Alternative assumed_ISA_flat_rating mode generates a sensitivity curve
%   via build_assumed_turbine_map and permits preliminary engine scaling.
%   Legacy combined-power performance methods intentionally reject calls
%   until mission and constraint callers use source-specific power.
%
    properties
        engine_type = "Parallel Hybrid Turboprop"
        
        % Total ratings across both propulsors (shaft hp)

        P_turbine_TO = NaN
        P_turbine_continuous = NaN

        P_motor_peak = NaN
        P_motor_continuous = NaN

        P_inverter_rated_kW = NaN
        % Total inverter DC-side electrical throughput rating in kW.
        % Must cover motoring and generating operation.

        % Hybrid inputs from the requirements JSON
        hybrid

        % ISA map: altitude_ft, takeoff_fraction, continuous_fraction.
        % Each curve is normalized by its OWN reference sea-level rating.
        % Empty arrays mean engine data are still required, not zero power.
        turbine_map = []

        % Nonempty in catalog_engine mode: actual fixed hardware dimensions,
        % nominal ratings and source-chart data, rather than a scaled engine.
        reference_engine = []

        n_engines
        % Number of engines [-].

        BSFC
        % Brake-specific fuel consumption [lbm/(hp*hr)].

        eta_p_cruise
        eta_p_loiter
        eta_p_climb
        % Propeller efficiencies [-].

        P_TO_over_P_max_continuous
        % Takeoff power / maximum continuous power [-].

        % --- engine-size regression, Raymer Table 10.4 (NEW IN IHW3) ---
        engine_scaling_class        % <- J.propulsion.engine_scaling_class
        k_W_engine                  % <- J.propulsion.engine_weight_coefficient
        n_W_engine                  % <- J.propulsion.engine_weight_exponent
        k_L_engine                  % <- J.propulsion.engine_length_coefficient
        n_L_engine                  % <- J.propulsion.engine_length_exponent
        bhp_range                   % <- J.propulsion.bhp_range_of_validity
    end

    properties (Dependent)
        P_SL
        P_engine
        % Takeoff-rated power of ONE turbine [hp].
    end

    methods

        function available = constraint_power_available(obj, state, con, context)
        %CONSTRAINT_POWER_AVAILABLE Source limits at a declared operating case.
        % Context is explicit operating/installation data, not hidden sizing
        % defaults. See SOURCE_POWER_CONSTRAINTS.md for units and boundaries.
            available = source_power_available(obj, state, con, context);
        end

        %% Regression Guard
        function bhp = rated_bhp_per_engine(obj)
        %RATED_BHP_PER_ENGINE  Power per engine, range-checked [hp].
        %   Warns, and does not error, outside the band Raymer Table 10.4
        %   is printed for: a sizing iterate can pass through an
        %   unreasonable power on its way to the answer.
        %
        %   PUBLIC. Turbine rating is an OUTPUT of sizing, not a fixed input, so
        %   whether the CONVERGED engine falls inside the band the
        %   regression is printed for is a post-convergence check a driver
        %   has to be able to make. Keeping the guard private forced every
        %   driver to re-implement the comparison against bhp_range, which
        %   is the class's own business.
            bhp = obj.P_engine;

            if ~(isscalar(bhp) && isfinite(bhp) && bhp > 0)
                error('TtpaProp:TurbinePowerNotSet', 'Set a finite, positive total P_turbine_TO before sizing turbines')
            end

            if bhp < obj.bhp_range(1) || bhp > obj.bhp_range(2)
                warning('TtpaProp:BhpOutOfRange', ...
                    ['Rated turbine power is %.1f hp per engine, outside ', ...
                     'the %.0f-%.0f hp range for the configured %s regression.'], ...
                    bhp, obj.bhp_range(1), obj.bhp_range(2), char(obj.engine_scaling_class));
            end
        end

    end

    methods

        %% Constructor
        function obj = TtpaProp(json_path, engine_id)
            arguments
                json_path {mustBeTextScalar, mustBeNonzeroLengthText}
                engine_id (1,1) string = ""
            end

            % Read requirements JSON
            J = jsondecode(fileread(json_path));

            % Read propulsion-owned data
            P = J.propulsion;

            if isfield(P, 'turbine_power_model') && ...
                    string(P.turbine_power_model) == "assumed_ISA_flat_rating"
                % Generate the selected sensitivity case once at construction.
                % This keeps all study parameters in the requirements JSON.
                obj.turbine_map = build_assumed_turbine_map(P.assumed_turbine_map);
            elseif isfield(P, 'turbine_map')
                obj.turbine_map = P.turbine_map;
            end

            if ~isfield(J, 'hybrid') || string(J.hybrid.architecture) ~= "parallel"
                error('TtpaProp:UnsupportedArchitecture', 'This model requires a parallel-hybrid requirements block.');
            end

            obj.hybrid       = J.hybrid;
            obj.n_engines    = P.n_engines;
            obj.BSFC         = P.BSFC_lb_per_hp_hr;
            obj.eta_p_cruise = P.eta_p_cruise;
            obj.eta_p_loiter = P.eta_p_loiter;
            obj.eta_p_climb  = P.eta_p_climb;

            obj.P_TO_over_P_max_continuous = P.P_TO_over_P_max_continuous;

            % Engine-size regression
            obj.engine_scaling_class = string(P.engine_scaling_class);
            obj.k_W_engine = P.engine_weight_coefficient;
            obj.n_W_engine = P.engine_weight_exponent;
            obj.k_L_engine = P.engine_length_coefficient;
            obj.n_L_engine = P.engine_length_exponent;
            obj.bhp_range  = P.bhp_range_of_validity;

            if isfield(P, 'turbine_power_model') && ...
                    string(P.turbine_power_model) == "catalog_engine"
                % Resolve beside the requirements file so cwd does not matter.
                catalog_path = char(P.engine_catalog_file);
                % Variant requirements may carry an absolute catalog path.
                % MATLAB fullfile does not discard a preceding directory
                % for every absolute Windows path, so resolve explicitly.
                if isempty(regexp(catalog_path,'^([A-Za-z]:[\\/]|[\\/]{2}|/)','once'))
                    catalog_path = fullfile(fileparts(char(json_path)),catalog_path);
                end
                catalog = jsondecode(fileread(catalog_path));
                if engine_id == ""
                    engine_id = string(P.selected_engine);
                end
                if ~isfield(catalog.engines, char(engine_id))
                    error('TtpaProp:UnknownCatalogEngine', ...
                        'Engine %s is not an executable catalog entry.', engine_id);
                end
                obj.reference_engine = catalog.engines.(char(engine_id));
                obj.P_turbine_TO = obj.n_engines * obj.reference_engine.takeoff_hp_each;
                obj.P_turbine_continuous = ...
                    obj.n_engines * obj.reference_engine.continuous_hp_each;
                obj.P_TO_over_P_max_continuous = ...
                    obj.P_turbine_TO / obj.P_turbine_continuous;
                % An empty legacy fraction map avoids suggesting that the
                % old hypothetical ISA curve supplied the catalog results.
                obj.turbine_map = [];
            elseif engine_id ~= ""
                error('TtpaProp:CatalogModeRequired', ...
                    'An engine_id override requires catalog_engine mode.');
            end
        end


        %% Power Per Engine
        function val = get.P_SL(obj)
        % Combined installed takeoff/peak rating (hp)
        % Reporting value, not power universally available in flight
            val = obj.P_turbine_TO + obj.P_motor_peak;
        end

        function val = get.P_engine(obj)
        % Takeoff-rated shaft power of one turbine (hp)
            val = obj.P_turbine_TO / obj.n_engines;
        end


        %% Power Lapse
        function alpha = power_lapse(obj, state, rating)
            % Legacy callers multiply this by combined P_SL: reject that basis.
            error('TtpaProp:SourceSpecificPowerRequired', ...
                ['The piston lapse model has been removed. Use ', ...
                 'turbine_power_available(state, rating) for turbine shaft hp; ', ...
                 'electric phases require motor/battery availability.']);
        end


        %% Turbine Power Availability (catalog OAT charts or assumed ISA map)
        function P_hp = turbine_power_available(obj, state, rating)
            % Aircraft-total turbine shaft hp, all turbines already running.
            % No motor, shutdown/restart, OEI, or shared gearbox credit here.
            % Fractions must incorporate the documented installation boundary;
            % do not subtract included accessory/installation losses twice.
            if ~isempty(obj.reference_engine)
                obj.check_catalog_ratings();
                P_hp = obj.n_engines * ...
                    catalog_turbine_power(obj.reference_engine, state, rating);
                return;
            end
            m = obj.turbine_map;
            fields = {'altitude_ft', 'takeoff_fraction', 'continuous_fraction'};
            if isempty(m)
                error('TtpaProp:TurbineMapRequired', ...
                    'Load documented ISA turbine power-map data first.');
            end
            if ~isstruct(m) || ~isscalar(m) || ~all(isfield(m, fields))
                error('TtpaProp:InvalidTurbineMap', ...
                    'The map requires altitude_ft, takeoff_fraction and continuous_fraction.');
            end
            if isempty(m.altitude_ft) || isempty(m.takeoff_fraction) || ...
                    isempty(m.continuous_fraction)
                error('TtpaProp:TurbineMapRequired', ...
                    'The turbine map is a placeholder; populate all three arrays from engine data.');
            end

            h = m.altitude_ft;
            to = m.takeoff_fraction;
            cont = m.continuous_fraction;
            if ~(isnumeric(h) && isreal(h) && isvector(h) && numel(h) >= 2 && ...
                    all(isfinite(h(:))) && all(h(:) >= 0) && all(diff(h(:)) > 0) && ...
                    isnumeric(to) && isreal(to) && isvector(to) && numel(to) == numel(h) && ...
                    all(isfinite(to(:))) && all(to(:) >= 0) && ...
                    isnumeric(cont) && isreal(cont) && isvector(cont) && numel(cont) == numel(h) && ...
                    all(isfinite(cont(:))) && all(cont(:) >= 0))
                error('TtpaProp:InvalidTurbineMap', ...
                    ['Map arrays must have matching lengths, finite nonnegative values, ', ...
                     'and at least two strictly increasing altitudes.']);
            end
            validateattributes(state.alt, {'numeric'}, ...
                {'real', 'scalar', 'finite', 'nonnegative'}, mfilename, 'state.alt');

            switch string(rating)
                case "takeoff"
                    P_rated = obj.P_turbine_TO;
                    fractions = to;
                case "max_continuous"
                    P_rated = obj.P_turbine_continuous;
                    fractions = cont;
                otherwise
                    error('TtpaProp:UndefinedRating', ...
                        'Unsupported turbine rating: %s.', string(rating));
            end
            if ~(isnumeric(P_rated) && isreal(P_rated) && isscalar(P_rated) && ...
                    isfinite(P_rated) && P_rated > 0)
                error('TtpaProp:TurbinePowerNotSet', ...
                    'Set a finite, positive turbine rating before evaluating available power.');
            end
            f = interp1(h(:), fractions(:), state.alt, 'linear', NaN);
            if ~isfinite(f)
                error('TtpaProp:OutsideTurbineMap', ...
                    'No ISA turbine power data at %.0f ft; map covers %.0f-%.0f ft.', ...
                    state.alt, h(1), h(end));
            end
            P_hp = P_rated * f;
        end

        function fuel_lb_hr = turbine_fuel_flow(obj, state, P_shaft_hp, rating)
            % Estimated aircraft-total fuel flow at a POSITIVE shaft demand.
            % Constant BSFC is a study input, not manufacturer fuel data.
            % No extra thermal-efficiency division: BSFC already relates
            % fuel mass to shaft energy. Idle flow requires separate data.
            validateattributes(P_shaft_hp, {'numeric'}, ...
                {'real', 'scalar', 'finite', 'positive'});
            P_available = obj.turbine_power_available(state, rating);
            if P_shaft_hp > P_available + 1e-9
                error('TtpaProp:InsufficientTurbinePower', ...
                    'Demand %.1f hp exceeds available turbine power %.1f hp.', ...
                    P_shaft_hp, P_available);
            end
            fuel_lb_hr = obj.C_bhp(state) * P_shaft_hp;
        end

        function check_catalog_ratings(obj)
            % A catalog engine cannot acquire extra power by changing a
            % sizing iterate. Select another engine if its rating is short.
            e = obj.reference_engine;
            if ~isequal(obj.P_turbine_TO, obj.n_engines * e.takeoff_hp_each) || ...
                    ~isequal(obj.P_turbine_continuous, obj.n_engines * e.continuous_hp_each)
                error('TtpaProp:CatalogRatingChanged', ...
                    'Catalog ratings are fixed hardware; select another engine instead of scaling them.');
            end
        end


        %% Power Ratio at a Constraint Condition
        function kP = power_ratio(obj, state, con)
            error('TtpaProp:SourceSpecificConstraintsRequired', ...
                ['Evaluate constraints against their electric, turbine, or combined ', ...
                 'source rating; combined P_SL is only a reporting value.']);

        end


        %% Engine Weight
        function [W_total, W_each] = engine_weight(obj)
        %ENGINE_WEIGHT  BARE engine weight [lbf].
        %
        %   [W_total, W_each] = engine_weight(obj)
        %
        %     W_each   bare weight of ONE engine [lbf]
        %     W_total  bare weight of ALL engines [lbf]
        %
        %   Configured turbine regression, applied to one turbine rating.
        %       W_engine = k_W_engine * bhp^n_W_engine
        %
        %   with bhp the rated power of ONE engine. This is the BARE
        %   engine. TtpaWeights multiplies it by the Raymer Table 15.2
        %   installed-engine factor, 1.4 for general aviation, to get the
        %   installed weight - do NOT apply that factor here as well.
            if ~isempty(obj.reference_engine)
                obj.check_catalog_ratings();
                % EASA dry mass, converted to the project's lb/lbf convention.
                W_each = obj.reference_engine.dry_mass_kg_each * 2.20462262185;
                W_total = obj.n_engines * W_each;
                return;
            end
            bhp = obj.rated_bhp_per_engine();

            W_each  = obj.k_W_engine * bhp .^ obj.n_W_engine;
            W_total = obj.n_engines * W_each;
        end


        %% Engine Length  (NEW IN IHW3)
        function L = engine_length(obj)
        %ENGINE_LENGTH  Bare length of ONE engine [ft].
        %
        %   Configured turbine regression, applied to one turbine rating.
        %       L_engine = k_L_engine * bhp^n_L_engine
        %
        %   TtpaGeom stretches this into a nacelle length and turns that
        %   into wetted area. The engine WIDTH and HEIGHT are not scaled:
        %   Raymer Table 10.3 states that both vary insignificantly over a
        %   +50 percent power change, which is why the nacelle diameter is
        %   a fixed input in the geometry block.
            if ~isempty(obj.reference_engine)
                obj.check_catalog_ratings();
                L = obj.reference_engine.length_mm_each / 304.8;
                return;
            end
            bhp = obj.rated_bhp_per_engine();

            L = obj.k_L_engine * bhp .^ obj.n_L_engine;
        end


        %% BSFC
        function C_bhp = C_bhp(obj, state)
            %C_BHP  Returns brake-specific fuel consumption [lbm/(hp*hr)].
            %
            %   Uses a preliminary constant BSFC appropriate for the
            %   turbine study. Not an altitude/part-load fuel-flow map.

            C_bhp = obj.BSFC;
        end


        %% Propeller Efficiency
        function eta_p = prop_eff(obj, state, miss_seg)
            %PROP_EFF  Returns propeller efficiency [-].
            %
            %   Efficiency is selected based on the current mission
            %   segment. A constraint condition is accepted in place of a
            %   mission segment: both carry a type field, and the climb
            %   gradient conditions use the climb value. Unchanged from
            %   IHW2.

            switch lower(string(miss_seg.type))

                case "loiter"
                    eta_p = obj.eta_p_loiter;

                case "cruise"
                    eta_p = obj.eta_p_cruise;

                case {"climb", "climb_gradient"}
                    eta_p = obj.eta_p_climb;

                otherwise
                    error('TtpaProp:UndefinedSegment', ...
                        'Propeller efficiency is not defined for segment "%s".', ...
                        string(miss_seg.type));

            end

        end

    end


end
