classdef TtpaAero < AerodynamicsBase
% DHBAERO  Distributed hybrid boat Aircraft Level-2 aerodynamic model.

    properties
        % Declare variables
        CD0_reference            
        Cfe                         
        CLmax_clean             
        CLmax_takeoff           
        CLmax_landing           
        CL_stall_margin         
        dCD0_flaps_takeoff       
        dCD0_flaps_landing       
        dCD0_gear_down           
        dCD0_propeller_stopped  
        de_flaps_takeoff         
        de_flaps_landing
    end

    properties (SetAccess = immutable)
        geom          %injected geometry model
    end

    properties (Dependent)
        AR              % Wing aspect ratio, read from the geometry
        CD0             % Clean zero-lift drag coefficient, from S_wet/S_ref
        e               % Oswald efficiency factor
        K               % Induced drag factor
        LD_max          % Maximum lift-to-drag ratio
    end

    methods

        %% Constructor
        function obj = TtpaAero(json_path, geom)
            % set up geometry model
            arguments
                json_path {mustBeTextScalar, mustBeNonzeroLengthText}
                geom (1,1) GeometryBase
            end
            obj.geom = geom;

            % find JSON file and aerodynamics section
            J = jsondecode(fileread(json_path));
            A = J.aerodynamics;

            % pull values from JSON file
            obj.CD0_reference   = A.CD0_clean;
            obj.Cfe = A.Cfe;
            obj.CLmax_clean     = A.CLmax_clean;
            obj.CLmax_takeoff   = A.CLmax_takeoff;
            obj.CLmax_landing   = A.CLmax_landing;
            obj.CL_stall_margin = A.CL_stall_margin;
            obj.dCD0_flaps_takeoff     = A.delta_CD0_flaps_takeoff;
            obj.dCD0_flaps_landing     = A.delta_CD0_flaps_landing;
            obj.dCD0_gear_down         = A.delta_CD0_gear_down;
            obj.dCD0_propeller_stopped = A.delta_CD0_propeller_stopped;
            obj.de_flaps_takeoff = A.delta_e_flaps_takeoff;
            obj.de_flaps_landing = A.delta_e_flaps_landing;
        end


        %% Aspect Ratio
        function AR = get.AR(obj)
            AR = obj.geom.AR;
        end


        %% Clean Zero-Lift Drag Coefficient
        function CD0 = get.CD0(obj)
            CD0 = obj.Cfe * obj.geom.S_wet_over_S_ref;
        end


        %% Oswald Efficiency
        function e = get.e(obj)
            e = 1.78 * (1 - 0.045 * obj.AR^0.68) - 0.64;
        end


        %% Induced Drag Factor
        function K = get.K(obj)
            if isnan(obj.e) || obj.e <= 0 || obj.e > 1
                error('DhbAero:InvalidOswaldEfficiency', ...
                    'Computed Oswald efficiency e = %.4f is invalid.', obj.e);
            end
            K = 1 / (pi * obj.AR * obj.e);
        end


        %% Drag Polar
        function polar = drag_polar(obj, ~)
            polar.CD0 = obj.CD0;
            polar.K1  = obj.K;
            polar.K2  = 0;
        end


        %% Maximum Lift Coefficient
        function CLmax = get_CLmax(obj, ~, con)
            switch string(con.config)

                case "clean"
                    CLmax = obj.CLmax_clean;

                case {"takeoff_flaps_gear_up", "takeoff_flaps_gear_down"}
                    CLmax = obj.CLmax_takeoff;

                case {"landing_flaps_gear_up", "landing_flaps_gear_down"}
                    CLmax = obj.CLmax_landing;

                otherwise
                    error('DhbAero:UndefinedConfiguration', ...
                        'CLmax is not defined for configuration "%s".', ...
                        string(con.config));

            end

        end


        %% Configuration Polar
        function cfg = get_config_polar(obj, state, con)
            polar = obj.drag_polar(state);

            switch string(con.config)

                case "clean"
                    dCD0 = 0;
                    de   = 0;

                case "takeoff_flaps_gear_up"
                    dCD0 = obj.dCD0_flaps_takeoff;
                    de   = obj.de_flaps_takeoff;

                case "takeoff_flaps_gear_down"
                    dCD0 = obj.dCD0_flaps_takeoff + obj.dCD0_gear_down;
                    de   = obj.de_flaps_takeoff;

                case "landing_flaps_gear_up"
                    dCD0 = obj.dCD0_flaps_landing;
                    de   = obj.de_flaps_landing;

                case "landing_flaps_gear_down"
                    dCD0 = obj.dCD0_flaps_landing + obj.dCD0_gear_down;
                    de   = obj.de_flaps_landing;

                otherwise
                    error('DhbAero:UndefinedConfiguration', ...
                        'Drag polar is not defined for configuration "%s".', ...
                        string(con.config));

            end

            % Failed engine: the stopped propeller of the dead engine drags
            if con.propeller_stopped
                dCD0 = dCD0 + obj.dCD0_propeller_stopped;
            end

            cfg.config = string(con.config);
            cfg.CD0    = polar.CD0 + dCD0;
            cfg.e      = obj.e + de;
            cfg.K1     = 1 / (pi * obj.AR * cfg.e);
            cfg.K2     = polar.K2;
            cfg.CLmax  = obj.get_CLmax(state, con);

            cfg.CL_climb = cfg.CLmax - obj.CL_stall_margin;

        end


        %% Maximum L/D
        function LD_max = get.LD_max(obj)
            LD_max = 1 / (2 * sqrt(obj.CD0 * obj.K));

        end

    end

end
