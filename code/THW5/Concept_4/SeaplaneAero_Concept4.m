classdef SeaplaneAero_Concept4 < handle
    properties
        J
        geom
        A
        C
        ref
    end
    properties (Dependent)
        AR
        e
        K
        CD0
        LD_max
        CLmax_clean
        CLmax_takeoff
        CLmax_landing
        CL_stall_margin
    end
    methods
        function obj = SeaplaneAero_Concept4(J, geom)
            obj.J = J;
            obj.geom = geom;
            obj.A = J.aerodynamics;
            obj.C = J.concept4_geometry;
            obj.ref = J.aero_reference_condition;
            if obj.C.floats.count ~= 2 || obj.C.motor_nacelles.count < 2
                error('C4:AeroGeometry', 'Invalid float or motor nacelle count.');
            end
        end
        function v = get.AR(obj)
            v = obj.geom.AR;
        end
        function v = get.e(obj)
            v = 1.78*(1-0.045*obj.AR^0.68)-0.64;
            if v <= 0 || v > 1, error('C4:Oswald', 'Oswald factor outside (0,1].'); end
        end
        function v = get.K(obj)
            v = 1/(pi*obj.AR*obj.e);
        end
        function v = get.CD0(obj)
            d = obj.drag_breakdown();
            v = d.CD0_total;
        end
        function v = get.LD_max(obj)
            v = 1/(2*sqrt(obj.CD0*obj.K));
        end
        function v = get.CLmax_clean(obj)
            v = obj.A.CLmax_clean;
        end
        function v = get.CLmax_takeoff(obj)
            v = obj.A.CLmax_takeoff;
        end
        function v = get.CLmax_landing(obj)
            v = obj.A.CLmax_landing;
        end
        function v = get.CL_stall_margin(obj)
            v = obj.A.CL_stall_margin;
        end
        function result = drag_breakdown(obj, state)
            if nargin < 2 || isempty(state), state = struct(); end
            alt = c4_get(state, 'alt_ft', c4_get(state, 'altitude_ft', obj.ref.altitude_ft));
            speed = c4_get(state, 'ktas', c4_get(state, 'speed_ktas', obj.ref.speed_ktas));
            if speed <= 0 || obj.geom.S_ref <= 0
                error('C4:AeroInput', 'Positive speed and wing area are required.');
            end
            a = isa_atmosphere_C4(alt);
            v = speed*0.514444444444;
            mach = v/a.speed_of_sound_m_s;
            g = obj.geom;
            f = obj.C.floats;
            s = obj.C.float_struts;
            n = obj.C.motor_nacelles;
            names = {'wing','horizontal_tail','vertical_tail','fuselage', ...
                'pontoons','float_struts','motor_nacelles'};
            area = [g.S_wet_wing g.S_wet_ht g.S_wet_vt g.S_wet_fuselage ...
                g.S_wet_pontoons g.S_wet_float_struts g.S_wet_motor_nacelles];
            lengths = [g.MAC g.MAC_ht g.MAC_vt g.l_fus f.length_ft s.chord_ft n.length_ft];
            FF = [SeaplaneAero_Concept4.wingFF(g.tc_mean) ...
                SeaplaneAero_Concept4.wingFF(g.tc_ht) ...
                SeaplaneAero_Concept4.wingFF(g.tc_vt) ...
                SeaplaneAero_Concept4.bodyFF(g.l_fus,max(g.w_fus,g.h_fus)) ...
                SeaplaneAero_Concept4.bodyFF(f.length_ft,max(f.beam_ft,f.height_ft)) ...
                SeaplaneAero_Concept4.wingFF(s.thickness_ratio) ...
                SeaplaneAero_Concept4.bodyFF(n.length_ft,n.diameter_ft)];
            Q = obj.C.interference_factors;
            VSP = obj.C.openvsp_air_wetted_area_ft2;
            components = struct();
            total = c4_get(obj.J.concept4_aerodynamics,'additional_calibrated_cd0',0);
            total_area = 0;
            for i = 1:numel(names)
                name = names{i};
                if isfield(VSP,name)
                    swet = VSP.(name);
                    src = 'OpenVSP';
                else
                    swet = area(i);
                    src = 'geometric estimate';
                end
                re = a.rho_kg_m3*v*(lengths(i)*0.3048)/a.mu_Pa_s;
                if re <= 1e4, error('C4:Reynolds', 'Component Reynolds number too low.'); end
                cf = 0.455/(log10(re)^2.58*(1+0.144*mach^2)^0.65);
                qi = c4_get(Q,name,1);
                if qi < 1, error('C4:Interference', 'Interference Q cannot be below one.'); end
                cd = cf*FF(i)*qi*swet/g.S_ref;
                components.(name) = struct('S_wet_ft2',swet,'length_ft',lengths(i), ...
                    'Re',re,'Cf',cf,'FF',FF(i),'Q',qi,'CD0',cd,'area_source',src);
                total = total + cd;
                total_area = total_area + swet;
            end
            result = struct('components',components,'CD0_total',total,'reference_S_ft2',g.S_ref, ...
                'altitude_ft',alt,'speed_ktas',speed,'extra_cd0', ...
                c4_get(obj.J.concept4_aerodynamics,'additional_calibrated_cd0',0), ...
                'reference_CD0',obj.A.CD0_clean, ...
                'equivalent_friction_CD0',obj.A.Cfe*total_area/g.S_ref);
        end
        function p = drag_polar(obj,state)
            if nargin < 2, state = struct(); end
            d = obj.drag_breakdown(state);
            p = struct('CD0',d.CD0_total,'K1',obj.K,'K2',0);
        end
        function clmax = get_CLmax(obj, varargin)
            cfg = 'clean';
            if nargin >= 3 && ~isempty(varargin{2})
                cfg = c4_get(varargin{2}, 'config', 'clean');
            elseif nargin >= 2 && isstruct(varargin{1})
                cfg = c4_get(varargin{1}, 'config', 'clean');
            end
            if strcmp(cfg,'clean')
                clmax = obj.CLmax_clean;
            elseif startsWith(cfg,'takeoff_flaps_')
                clmax = obj.CLmax_takeoff;
            elseif startsWith(cfg,'landing_flaps_')
                clmax = obj.CLmax_landing;
            else
                error('C4:Config','Unknown configuration.');
            end
        end
        function p = get_config_polar(obj, state, con)
            if nargin < 2 || isempty(state), state = struct(); end
            if nargin < 3 || isempty(con), con = struct('config','clean'); end
            cfg = c4_get(con,'config','clean');
            if strcmp(cfg, 'clean')
                dcd = 0; de = 0;
            elseif strcmp(cfg, 'takeoff_flaps_gear_up')
                dcd = obj.A.delta_CD0_flaps_takeoff; de = obj.A.delta_e_flaps_takeoff;
            elseif strcmp(cfg, 'takeoff_flaps_gear_down')
                dcd = obj.A.delta_CD0_flaps_takeoff + obj.A.delta_CD0_gear_down;
                de = obj.A.delta_e_flaps_takeoff;
            elseif strcmp(cfg, 'landing_flaps_gear_up')
                dcd = obj.A.delta_CD0_flaps_landing; de = obj.A.delta_e_flaps_landing;
            elseif strcmp(cfg, 'landing_flaps_gear_down')
                dcd = obj.A.delta_CD0_flaps_landing + obj.A.delta_CD0_gear_down;
                de = obj.A.delta_e_flaps_landing;
            else
                error('C4:Config','Unsupported configuration.');
            end
            if c4_get(con,'propeller_stopped',false)
                increment = c4_get(con,'stopped_propeller_cd0_increment', ...
                    c4_get(obj.J.concept4_aerodynamics,'stopped_propeller_cd0_increment',[]));
                if isempty(increment)
                    error('C4:UnverifiedPropDrag', 'Failed propeller drag needs a validated value.');
                end
                dcd = dcd + increment;
            end
            ee = obj.e + de;
            if ee <= 0, error('C4:Oswald','Configuration Oswald factor is nonpositive.'); end
            base = obj.drag_polar(state);
            clmax = obj.get_CLmax(state,con);
            p = struct('config',cfg,'CD0',base.CD0+dcd,'e',ee, ...
                'K1',1/(pi*obj.AR*ee),'K2',0,'CLmax',clmax, ...
                'CL_climb',clmax-obj.CL_stall_margin);
        end
        function r = flight_forces(obj, weight_lb, speed_ktas, alt_ft, cfg, cl_override)
            if nargin < 5 || isempty(cfg), cfg = 'clean'; end
            if nargin < 6, cl_override = []; end
            if weight_lb <= 0 || speed_ktas <= 0
                error('C4:AeroInput','Positive weight and speed required.');
            end
            st = struct('alt_ft',alt_ft,'ktas',speed_ktas);
            atm = isa_atmosphere_C4(alt_ft);
            q = 0.5*atm.rho_slug_ft3*(speed_ktas*1.687809857)^2;
            p = obj.get_config_polar(st,struct('config',cfg));
            if isempty(cl_override)
                cl = weight_lb/(q*obj.geom.S_ref);
            else
                cl = cl_override;
            end
            if cl < 0, error('C4:CL','CL must be nonnegative.'); end
            cd = p.CD0 + p.K1*cl^2 + p.K2*cl;
            r = struct('q_psf',q,'CL',cl,'CD',cd,'lift_lb',q*obj.geom.S_ref*cl, ...
                'drag_lb',q*obj.geom.S_ref*cd,'L_over_D',cl/cd, ...
                'CLmax_config',p.CLmax,'CL_limit_exceeded',cl>p.CLmax);
        end
    end
    methods (Static)
        function v = wingFF(tc)
            if tc < 0 || tc >= 0.5, error('C4:Thickness','Invalid thickness ratio.'); end
            v = 1+2.7*tc+100*tc^4;
        end
        function v = bodyFF(length_ft,diameter_ft)
            f = length_ft/diameter_ft;
            if f < 3, error('C4:FormFactor','Body L/D must be at least three.'); end
            v = 1+60/f^3+f/400;
        end
    end
end
