classdef TtpaWeights < WeightsBase
% TTPAWEIGHTS Concept 3 Level-2 weight model.
%   ------------------------------------------------------------------
%   THE COMPONENT BUILD-UP
%       W_wing      = rho * S_exposed                lb/ft^2 x EXPOSED area
%       W_v_tail    = rho * S_v_tail                 lb/ft^2 x area
%       W_fuselage  = rho * S_wet                    lb/ft^2 x WETTED area
%       W_wingtip_floats = 2 * rho * S_wet           lb/ft^2 x WETTED area
%       W_gear      = 0.057 * W_TO                   fraction of TOGW
%       W_engines   = 1.4   * W_bare_all_engines     x bare engine weight
%       W_all_else  = 0.10  * W_TO                   fraction of TOGW
%
%   Four rows follow the geometry (wing, v-tail, fuselage, floats), one follows
%   the engine (W_engines), and one follow the takeoff weight (all else)
%   ------------------------------------------------------------------
%   INJECTED GEOMETRY AND PROPULSION
%   TtpaWeights(json_path, geom, prop). Build prop, then geom, then aero,
%   then weights - see ttpa_disciplines.

    properties
        W_TO                 = NaN   % lbf, candidate gross takeoff weight
        W_energy             = NaN   % lbf, total internal fuel weight
        W_payload_expendable = 0     % lbf, expendable payload (stores)
        W_payload_fixed      = 1200  % lbf, fixed payload, including crew
    end

    properties (SetAccess = immutable)
        geom                         % injected TtpaGeom
        prop                         % injected TtpaProp

        % Declare variables
        rho_wing
        rho_v_tail
        rho_fuselage
        rho_wingtip_float
        f_landing_gear
        f_installed_engine
        f_all_else_empty
        k_OEW_statistical
        n_OEW_statistical
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

            % Find json file and weights section
            J = jsondecode(fileread(json_path));
            W = J.weights;

            % Pull values from json file
            obj.W_payload_fixed      = W.W_payload_fixed;
            obj.W_payload_expendable = W.W_payload_expendable;
            obj.rho_wing             = W.unit_weight_wing_psf;
            obj.rho_v_tail           = W.unit_weight_v_tail_psf;
            obj.rho_fuselage         = W.unit_weight_fuselage_psf;
            obj.rho_wingtip_float    = W.unit_weight_wingtip_float_psf;
            obj.f_landing_gear       = W.landing_gear_fraction;
            obj.f_installed_engine   = W.installed_engine_factor;
            obj.f_all_else_empty     = W.all_else_empty_fraction;
            obj.k_OEW_statistical    = W.statistical_OEW_coefficient;
            obj.n_OEW_statistical    = W.statistical_OEW_exponent;
            obj.rho_fuel             = W.fuel_density_lb_per_ft3;
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
                W_TO (1,1) double {mustBePositive}
            end
            bd  = obj.OEW_breakdown(W_TO);
            oew = bd.total;
        end


        %% Operating Empty Weight - itemised
        function bd = OEW_breakdown(obj, W_TO)
        %OEW_BREAKDOWN  The seven rows of the component build-up [lbf].
        %
        %   bd = OEW_breakdown(obj, W_TO) returns a struct with
        %   .wing .v_tail .fuselage .wingtip_float .landing_gear .installed_engine .all_else_empty .total
        %   plus, for reporting, .engine_bare_each / .engine_bare_total.
            arguments
                obj
                W_TO (1,1) double {mustBePositive}
            end
            % bare engine weights from propulsion model
            [W_bare_total, W_bare_each] = obj.prop.engine_weight();
            bd.engine_bare_each  = W_bare_each;
            bd.engine_bare_total = W_bare_total;

            % wing, tail, fuselage, and floats
            bd.wing           = obj.rho_wing * obj.geom.S_exposed_wing;
            bd.v_tail         = obj.rho_v_tail * obj.geom.S_v_tail;
            bd.fuselage       = obj.rho_fuselage * obj.geom.S_wet_fuselage;
            bd.wingtip_floats = 2 * obj.rho_wingtip_float * obj.geom.S_wet_wingtip_float;

            % landing gear, installed engines, all else
            bd.landing_gear     = 0.057*W_TO;
            bd.installed_engine = 1.4*W_bare_total;
            bd.all_else_empty   = 0.1*W_TO;

            % total
            bd.total = bd.wing+bd.v_tail+bd.fuselage+bd.wingtip_floats+bd.landing_gear+bd.installed_engine+bd.all_else_empty;
        end


        %% Payload
        function W = payload(obj)
        %PAYLOAD  Total payload [lbf]. The number the closure solves for.
            W = obj.W_payload_fixed + obj.W_payload_expendable;
        end

    end

end
