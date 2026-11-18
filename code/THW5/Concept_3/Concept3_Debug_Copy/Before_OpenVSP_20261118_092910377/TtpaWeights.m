classdef TtpaWeights < WeightsBase
% DHBWEIGHTS Distributed hybrid boat Aircraft Level-2 weight model.
%
%   ------------------------------------------------------------------
%   THE COMPONENT BUILD-UP.  [Raymer Table 15.2, General Aviation column]
%       W_wing           = rho_wing * S_exposed_wing          lb/ft^2 x EXPOSED area
%       W_v_tail         = rho_v_tail * S_v_tail              lb/ft^2 x area
%       W_fuselage       = rho_fuselage * S_wet_fuselage      lb/ft^2 x WETTED area
%       W_wingtip_floats = 2 * rho_wingtip_floats * S_wet     lb/ft^2 x WETTED area
%       W_gear           = f_gear * W_TO                      fraction of TOGW
%       W_engines        = f_engines * W_bare_all_engines     x bare engine weight
%       W_all_else       = f_all_else * W_TO                  fraction of TOGW
%
%   Four rows follow the geometry (wing, tail, fuselage, floats), one follows
%   the engine (W_engines), and two follow the takeoff weight (gear, all
%   else). That is what lets the sizing loop see the airplane it has drawn.
%   ------------------------------------------------------------------
    properties
        W_TO                 = NaN   % lbf, candidate gross takeoff weight
        W_energy             = NaN   % lbf, total internal fuel weight
        W_payload_expendable = 0     % lbf, expendable payload (stores)
        W_payload_fixed      = 1200  % lbf, fixed payload, including crew
    end

    properties (SetAccess = immutable)
        geom                         % injected geometry model
        prop                         % injected propulsion model

        % Declare Variables
        rho_wing
        rho_v_tail
        rho_fuselage
        rho_wingtip_float
        f_landing_gear
        f_installed_engine
        f_all_else_empty
        rho_fuel
    end

    methods

        %% Constructor
        function obj = TtpaWeights(json_path, geom, prop)
            % set up geometry and propulsion models
            arguments
                json_path {mustBeTextScalar, mustBeNonzeroLengthText}
                geom (1,1) GeometryBase
                prop (1,1) PropulsionBase2
            end
            obj.geom = geom;
            obj.prop = prop;

            % find JSON file and weights section
            J = jsondecode(fileread(json_path));
            W = J.weights;

            % pull values from JSON file
            obj.W_payload_fixed      = W.W_payload_fixed;
            obj.W_payload_expendable = W.W_payload_expendable;
            obj.rho_wing             = W.unit_weight_wing_psf;
            obj.rho_v_tail           = W.unit_weight_v_tail_psf;
            obj.rho_fuselage         = W.unit_weight_fuselage_psf;
            obj.rho_wingtip_float    = W.unit_weight_wingtip_float_psf;
            obj.f_landing_gear       = W.landing_gear_fraction;
            obj.f_installed_engine   = W.installed_engine_factor;
            obj.f_all_else_empty     = W.all_else_empty_fraction;
            obj.rho_fuel             = W.fuel_density_lb_per_ft3;
        end


        %% Operating Empty Weight - the model
        function oew = OEW(obj, W_TO)
            arguments
                obj
                W_TO (1,1) double {mustBePositive}
            end
            bd = obj.OEW_breakdown(W_TO); %call the breakdown function
            oew = bd.total;
        end


        %% Operating Empty Weight - itemised
        function bd = OEW_breakdown(obj, W_TO)
            arguments
                obj
                W_TO (1,1) double {mustBePositive}
            end

            % engines (from propulsion model)
            [W_bare_total, W_bare_each] = obj.prop.engine_weight();
            bd.engine_bare_each  = W_bare_each;
            bd.engine_bare_total = W_bare_total;

            masses = obj.prop.installed_mass_breakdown();
            bd.battery          = masses.battery_lb;
            bd.motors           = masses.motors_lb;
            bd.motor_inverters  = masses.motor_inverters_lb;
            bd.generators       = masses.generators_lb;
            bd.turboshafts      = masses.turboshafts_lb;
            bd.propellers       = masses.propellers_lb;

            % wing, tail, fuselage, and floats
            bd.wing             = obj.rho_wing * obj.geom.S_exposed_wing;
            bd.v_tail           = obj.rho_v_tail * obj.geom.S_v_tail;
            bd.fuselage         = obj.rho_fuselage * obj.geom.S_wet_fuselage;
            bd.wingtip_floats   = 2 * obj.rho_wingtip_float * obj.geom.S_wet_wingtip_float;

            % gear, installed engines, hybrid electrical systems, and all else
            bd.landing_gear     = obj.f_landing_gear * W_TO;
            bd.installed_engine = obj.f_installed_engine * W_bare_total;
            bd.all_else_empty   = obj.f_all_else_empty * W_TO;

            % total
            bd.total = bd.wing + bd.v_tail + bd.fuselage + bd.wingtip_floats + ...
                       bd.landing_gear + bd.all_else_empty + ...
                       bd.battery + bd.motors + bd.motor_inverters + ...
                       bd.generators + bd.turboshafts + bd.propellers;
        end

        %% Payload
        function W = payload(obj)
            %PAYLOAD  Total payload [lbf]. The number the closure solves for.
            W = obj.W_payload_fixed + obj.W_payload_expendable;
        end
    end

end
