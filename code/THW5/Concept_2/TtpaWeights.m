classdef TtpaWeights < WeightsBase
%TTPAWEIGHTS  Test Twin Propeller Aircraft Level-2 weight model.
%
%   IHW3
%   In IHW1 and IHW2 the whole empty weight was one line, OEW =
%   0.911*W_TO^0.947, a statistical regression on light propeller airplanes.
%   It is a good first estimate, but it knows ONLY the takeoff weight: double
%   the wing area, fit a bigger engine, stretch the tails, and it returns the
%   same number. Inside a sizing loop that is fatal, because the loop exists
%   to work out what the airplane weighs after it has been laid out.
%
%   ------------------------------------------------------------------
%   THE COMPONENT BUILD-UP.  [Raymer Table 15.2, General Aviation column]
%       W_wing      = 2.5   * S_exposed_wing        lb/ft^2 x EXPOSED area
%       W_ht        = 2.0   * S_ht                  lb/ft^2 x area
%       W_vt        = 2.0   * S_vt                  lb/ft^2 x area
%       W_fuselage  = 1.4   * S_wet_fuselage        lb/ft^2 x WETTED area
%       W_floats    = f_float_structure * W_TO     complete straight-float system
%       W_gear      = f_landing_gear * W_TO        amphibious increment
%       W_engines   = 1.4   * W_bare_all_engines    x bare engine weight
%       W_all_else  = f_all_else_empty * W_TO      fraction of TOGW
%       W_hybrid    = motors + inverters + battery + electrical installation
%
%   Coefficients come from the requirements JSON. Hybrid masses use total
%   installed source ratings and nominal beginning-of-life pack capacity.
%   Battery mass is part of OEW and remains aboard after discharge;
%   W_energy is fuel ONLY. Mission/SOC/rate feasibility is checked elsewhere.
%
%   ------------------------------------------------------------------
%   THE OLD REGRESSION IS STILL HERE, as OEW_statistical. It is a
%   weak conventional-seaplane cross-check, not a calibrated hybrid model.
%
%   OEW(W_TO) TAKES THE WEIGHT AS AN ARGUMENT and evaluates every
%   W_TO-dependent term at the PASSED value, never at obj.W_TO. The sizing
%   loop calls it at a trial weight that is not yet the object's weight, so
%   reading obj.W_TO inside would silently return the previous iterate.
%
%   INJECTED GEOMETRY AND PROPULSION
%   TtpaWeights(json_path, geom, prop). Build prop, then geom, then aero,
%   then weights - see ttpa_disciplines.

    properties
        W_TO                 = NaN   % lbf, candidate gross takeoff weight
        W_energy             = NaN   % lbf, total internal fuel weight
        E_battery_nominal_kWh = NaN   % installed beginning-of-life pack capacity
        W_additional_powertrain = 0  % lbf: custom coupling/gearbox beyond turbine installation
        W_payload_expendable = 0     % lbf, expendable payload (stores)
        W_payload_fixed      = 1200  % lbf, fixed payload, including crew
    end

    properties (SetAccess = immutable)
        geom                         % injected TtpaGeom
        prop                         % injected TtpaProp

        % --- Raymer Table 15.2, General Aviation column ---
        rho_wing
        rho_ht
        rho_vt
        rho_fuselage
        f_float_structure
        f_landing_gear
        f_installed_engine
        f_all_else_empty

        % --- IHW1 regression, kept as a cross-check ---
        k_OEW_statistical
        n_OEW_statistical

        % --- post-sizing fuel-volume check ---
        rho_fuel
    end

    methods

        %% Constructor
        function obj = TtpaWeights(json_path, geom, prop)
            arguments
                json_path {mustBeTextScalar, mustBeNonzeroLengthText}
                geom (1,1) GeometryBase
                prop (1,1) PropulsionBase2
            end

            obj.geom = geom;
            obj.prop = prop;

            J = jsondecode(fileread(json_path));
            W = J.weights;

            obj.W_payload_fixed      = W.W_payload_fixed;
            obj.W_payload_expendable = W.W_payload_expendable;

            obj.rho_wing           = W.unit_weight_wing_psf;
            obj.rho_ht             = W.unit_weight_horizontal_tail_psf;
            obj.rho_vt             = W.unit_weight_vertical_tail_psf;
            obj.rho_fuselage       = W.unit_weight_fuselage_psf;
            obj.f_float_structure = W.float_structure_fraction;
            obj.f_landing_gear     = W.landing_gear_fraction;
            obj.f_installed_engine = W.installed_engine_factor;
            obj.f_all_else_empty   = W.all_else_empty_fraction;

            obj.k_OEW_statistical = W.statistical_OEW_coefficient;
            obj.n_OEW_statistical = W.statistical_OEW_exponent;

            obj.rho_fuel = W.fuel_density_lb_per_ft3;
            coefficient_names = {'rho_wing','rho_ht','rho_vt','rho_fuselage', ...
                'f_float_structure','f_landing_gear','f_installed_engine', ...
                'f_all_else_empty','W_payload_fixed','W_payload_expendable'};
            for k = 1:numel(coefficient_names)
                validateattributes(obj.(coefficient_names{k}), {'numeric'}, ...
                    {'scalar','real','finite','nonnegative'}, ...
                    mfilename, coefficient_names{k});
            end
        end


        %% Operating Empty Weight - the model
        function oew = OEW(obj, W_TO)
        %OEW  Operating empty weight [lbf] at a candidate takeoff weight.
        %   Use OEW_breakdown for the individual rows; this returns only the
        %   total, which is all the WeightsBase contract promises and all the
        %   sizing loop needs. Every W_TO-dependent term is evaluated at the
        %   PASSED W_TO, not at obj.W_TO.
            arguments
                obj
                W_TO (1,1) double {mustBePositive, mustBeFinite}
            end

            bd = obj.OEW_breakdown(W_TO);
            oew = bd.total;
        end


        %% Operating Empty Weight - itemised
        function bd = OEW_breakdown(obj, W_TO)
        %OEW_BREAKDOWN  Component empty-weight build-up [lbf].
        %
        %   bd = OEW_breakdown(obj, W_TO) returns a struct with
        %       .wing .horizontal_tail .vertical_tail .fuselage .floats
        %       .landing_gear .installed_engine .all_else_empty .total
        %       .motors .inverters .battery .electrical_installation
        %   plus, for reporting, .engine_bare_each / .engine_bare_total.
            arguments
                obj
                W_TO (1,1) double {mustBePositive, mustBeFinite}
            end

            [W_bare_total, W_bare_each] = obj.prop.engine_weight();
            bd.engine_bare_each  = W_bare_each;
            bd.engine_bare_total = W_bare_total;

            % Raymer Table 15.2 asks for EXPOSED PLANFORM area on the wing
            % and tail rows and WETTED area on the fuselage row.
            %
            % KNOWN APPROXIMATION ON THE TWO TAIL ROWS. The wing row uses the
            % true exposed area. The tail rows use the THEORETICAL area,
            % because that is what the volume-coefficient method produces -
            % Raymer defines horizontal-tail area to the aircraft centreline -
            % and an exposed tail area would need a fuselage width at the tail
            % station, which the cabin-driven fuselage model does not carry.
            % The resulting bias has not been quantified for Concept 2.
            bd.wing             = obj.rho_wing     * obj.geom.S_exposed_wing;
            bd.horizontal_tail  = obj.rho_ht       * obj.geom.S_ht;
            bd.vertical_tail    = obj.rho_vt       * obj.geom.S_vt;
            bd.fuselage         = obj.rho_fuselage * obj.geom.S_wet_fuselage;
            bd.floats = obj.f_float_structure * W_TO;
            bd.landing_gear     = obj.f_landing_gear   * W_TO;
            bd.installed_engine = obj.f_installed_engine * W_bare_total;
            bd.all_else_empty   = obj.f_all_else_empty * W_TO;

            hw = obj.hybrid_weight_breakdown();
            bd.motors = hw.motors;
            bd.inverters = hw.inverters;
            bd.battery = hw.battery;
            bd.electrical_installation = hw.electrical_installation;
            validateattributes(obj.W_additional_powertrain,{'numeric'}, ...
                {'scalar','real','finite','nonnegative'});
            bd.additional_powertrain = obj.W_additional_powertrain;

            bd.total = bd.wing + bd.horizontal_tail + bd.vertical_tail ...
                     + bd.fuselage + bd.floats + bd.landing_gear ...
                     + bd.installed_engine + bd.all_else_empty ...
                     + bd.motors + bd.inverters + bd.battery ...
                     + bd.electrical_installation + bd.additional_powertrain;
            validateattributes(bd.total, {'numeric'}, ...
                {'scalar','real','finite','positive'}, mfilename, 'OEW total');
        end

        function bd = hybrid_weight_breakdown(obj)
        %HYBRID_WEIGHT_BREAKDOWN  Aircraft-total installed hybrid weights [lbf].
        %   Recomputed from current ratings on every call. These preliminary
        %   mass estimates do not establish peak-duration, SOC, thermal,
        %   charging or continuous-discharge feasibility.
            H = obj.prop.hybrid;
            fields = {'motor_specific_power_kW_per_kg', ...
                'motor_continuous_specific_power_kW_per_kg', ...
                'inverter_specific_power_kW_per_kg', ...
                'battery_specific_energy_WH_per_kg'};
            for k = 1:numel(fields)
                validateattributes(H.(fields{k}), {'numeric'}, ...
                    {'scalar','real','finite','positive'}, mfilename, fields{k});
            end
            for name = {'motor_efficiency','inverter_efficiency'}
                validateattributes(H.(name{1}), {'numeric'}, ...
                    {'scalar','real','finite','positive','<=',1}, mfilename, name{1});
            end
            validateattributes(H.electrical_installation_fraction, {'numeric'}, ...
                {'scalar','real','finite','nonnegative'});
            if ~isequal(H.inverter_integrated_with_motor, false)
                error('TtpaWeights:IntegratedMotorMassRequired', ...
                    ['This regression requires separate motor/inverter masses. ', ...
                     'Supply an integrated hardware mass model before selecting an integrated unit.']);
            end
            inputs = {obj.prop.P_motor_peak, obj.prop.P_motor_continuous, ...
                obj.prop.P_inverter_rated_kW, obj.E_battery_nominal_kWh};
            for k = 1:numel(inputs)
                value = inputs{k};
                if ~(isnumeric(value) && isscalar(value) && isreal(value) ...
                        && isfinite(value) && value > 0)
                    error('TtpaWeights:HybridSizingInputsRequired', ...
                        ['Set positive finite total P_motor_peak/P_motor_continuous [hp], ', ...
                         'P_inverter_rated_kW [DC kW], and E_battery_nominal_kWh [BOL kWh].']);
                end
            end
            if obj.prop.P_motor_continuous > obj.prop.P_motor_peak
                error('TtpaWeights:InvalidMotorRatings', ...
                    'Continuous motor power cannot exceed peak motor power.');
            end
            peak_kW = 0.7457 * obj.prop.P_motor_peak;
            continuous_kW = 0.7457 * obj.prop.P_motor_continuous;
            required_DC_kW = peak_kW / (H.motor_efficiency * H.inverter_efficiency);
            if obj.prop.P_inverter_rated_kW < required_DC_kW - 1e-9 * required_DC_kW
                error('TtpaWeights:InsufficientInverterRating', ...
                    'Inverter rating must be at least %.3f DC kW for peak motoring.', required_DC_kW);
            end
            % Inputs are already totals across both propulsors. Do not
            % multiply by engine count or the installed-turbine factor.
            kg_to_lb = 2.20462262185;
            bd.motors = kg_to_lb * max( ...
                peak_kW / H.motor_specific_power_kW_per_kg, ...
                continuous_kW / H.motor_continuous_specific_power_kW_per_kg);
            bd.inverters = kg_to_lb * obj.prop.P_inverter_rated_kW ...
                / H.inverter_specific_power_kW_per_kg;
            % Capacity is nominal BOL capacity, already sized for SOC,
            % aging and power by the battery model; no second margin here.
            bd.battery = kg_to_lb * 1000 * obj.E_battery_nominal_kWh ...
                / H.battery_specific_energy_WH_per_kg;
            bd.electrical_installation = H.electrical_installation_fraction ...
                * (bd.motors + bd.inverters + bd.battery);
        end

        %% Operating Empty Weight - the IHW1 cross-check
        function oew = OEW_statistical(obj, W_TO)
        %OEW_STATISTICAL  JSON-selected statistical regression [lbf].
        %   Concept 2 uses a conventional flying-boat trend as a weak
        %   cross-check, without calibration to hybrid twin-float aircraft.
        %   It is not called by the sizing
        %   loop and must not be: it cannot see the geometry, so a loop built
        %   on it would converge on weight alone.
            arguments
                obj
                W_TO (1,1) double {mustBePositive, mustBeFinite}
            end
            oew = obj.k_OEW_statistical * W_TO ^ obj.n_OEW_statistical;
        end


        %% Payload
        function W = payload(obj)
        %PAYLOAD  Total payload [lbf]. The number the closure solves for.
            W = obj.W_payload_fixed + obj.W_payload_expendable;
        end

    end

end
