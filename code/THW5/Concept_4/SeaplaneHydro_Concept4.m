classdef SeaplaneHydro_Concept4 < handle
    properties
        J
        geom
        aero
        H
    end
    methods
        function obj = SeaplaneHydro_Concept4(J, geom, aero)
            if nargin < 3, aero = []; end
            obj.J = J;
            obj.geom = geom;
            obj.aero = aero;
            obj.H = J.hydrodynamics;
        end
        function result = buoyancy_screen(obj,weight_lb)
            if weight_lb <= 0, error('C4:HydroWeight','Positive weight required.'); end
            f = obj.geom.float_data;
            maxvol = f.count*f.length_ft*f.beam_ft*f.height_ft*obj.H.float_block_coefficient;
            needed = 1.8*weight_lb/obj.H.fresh_water_specific_weight_lb_ft3;
            fraction = c4_get(obj.H,'verified_below_cabin_floor_volume_fraction',[]);
            if isempty(fraction)
                eligible = [];
                status = 'NOT_ASSESSED';
            else
                eligible = maxvol*fraction + obj.H.verified_other_below_cabin_floor_volume_ft3;
                if eligible >= needed
                    status = 'PASS_VOLUME_ONLY';
                else
                    status = 'FAIL_VOLUME';
                end
            end
            result = struct('weight_lb',weight_lb,'required_180pct_displacement_ft3',needed, ...
                'external_float_volume_ft3',maxvol,'external_float_only_screen_pass',maxvol>=needed, ...
                'verified_eligible_volume_ft3',eligible,'rfp_below_cabin_floor_screen',status, ...
                'adjacent_compartments_flooding','NOT_ASSESSED','heel_20deg','NOT_ASSESSED');
        end
        function result = hydrostatics(obj,weight_lb)
            f = obj.geom.float_data;
            gamma = obj.H.fresh_water_specific_weight_lb_ft3;
            displaced = weight_lb/gamma;
            draft = displaced/(f.count*f.length_ft*f.beam_ft*obj.H.float_block_coefficient);
            wp = f.count*f.length_ft*f.beam_ft*obj.H.float_waterplane_coefficient;
            I = f.count * (f.length_ft*f.beam_ft^3*obj.H.float_waterplane_coefficient/12 ...
                + f.length_ft*f.beam_ft*obj.H.float_waterplane_coefficient*(f.centerline_spacing_ft/2)^2);
            KB = draft/2;
            BM = I/displaced;
            GM = KB+BM-obj.H.cg_height_above_float_keel_ft;
            result = struct('weight_lb',weight_lb,'displaced_volume_ft3',displaced, ...
                'estimated_draft_ft',draft,'float_height_ft',f.height_ft, ...
                'float_submergence_screen_pass',draft<=f.height_ft, ...
                'waterplane_area_ft2',wp,'waterplane_I_transverse_ft4',I, ...
                'KB_ft',KB,'BM_ft',BM,'KG_ft',obj.H.cg_height_above_float_keel_ft, ...
                'small_angle_GM_ft',GM,'small_angle_GM_positive',GM>0, ...
                'approx_float_emergence_heel_deg',atan2d(2*draft,f.centerline_spacing_ft), ...
                'heel_20deg_requirement','NOT_ASSESSED');
        end
        function result = planing_resistance(obj,speed_kt,weight_lb,aerodynamic_lift_lb,trim_deg)
            if nargin < 4, aerodynamic_lift_lb = 0; end
            if nargin < 5 || isempty(trim_deg), trim_deg = obj.H.trim_angle_deg; end
            if speed_kt <= 0 || weight_lb <= 0 || aerodynamic_lift_lb < 0
                error('C4:HydroInput','Invalid speed, weight, or lift.');
            end
            water_load = max(0,weight_lb-aerodynamic_lift_lb);
            if water_load == 0
                result = struct('speed_kt',speed_kt,'regime','airborne','water_load_lb',0, ...
                    'hydrodynamic_drag_lb',0,'lambda',0,'wetted_length_ft',0);
                return;
            end
            if trim_deg < 2 || trim_deg > 15
                error('C4:PlaningValidity','Planing trim must be 2 through 15 degrees.');
            end
            f = obj.geom.float_data;
            v = speed_kt*0.514444444444;
            b = f.beam_ft*0.3048;
            cv = v/sqrt(9.80665*b);
            if cv < 0.6 || cv > 13
                error('C4:PlaningValidity','Planing Cv outside correlation screen.');
            end
            loadN = water_load/f.count*4.4482216153;
            cl_required = loadN/(0.5*obj.H.fresh_water_density_kg_m3*v^2*b^2);
            lo = 1e-5; hi = 4.0;
            deadrise = obj.H.deadrise_deg;
            if obj.savitsky_lift_coefficient(hi,cv,trim_deg,deadrise) < cl_required || ...
                    obj.savitsky_lift_coefficient(lo,cv,trim_deg,deadrise) > cl_required
                error('C4:PlaningValidity','Wetted-length ratio outside correlation screen.');
            end
            for k = 1:90
                mid = (lo+hi)/2;
                calculated = obj.savitsky_lift_coefficient(mid,cv,trim_deg,deadrise);
                if calculated < cl_required, lo = mid; else, hi = mid; end
            end
            lam = (lo+hi)/2;
            wetted_m = lam*b;
            if wetted_m > f.length_ft*0.3048
                error('C4:PlaningValidity','Wetted length exceeds float length.');
            end
            re = v*wetted_m/obj.H.water_kinematic_viscosity_m2_s;
            if re <= 1e5
                error('C4:PlaningValidity','Planing Reynolds number too low.');
            end
            cf = 0.075/(log10(re)-2)^2;
            tau = deg2rad(trim_deg);
            beta = deg2rad(deadrise);
            q = 0.5*obj.H.fresh_water_density_kg_m3*v^2;
            pressureN = loadN*tan(tau);
            frictionN = q*lam*b^2*cf/(cos(beta)*cos(tau));
            drag = f.count*(pressureN+frictionN)/4.4482216153;
            result = struct('speed_kt',speed_kt,'regime','prismatic_planing_screen', ...
                'water_load_lb',water_load,'Cv',cv,'CLbeta_required',cl_required, ...
                'lambda',lam,'wetted_length_ft',wetted_m/0.3048,'trim_deg',trim_deg, ...
                'deadrise_deg',deadrise,'water_reynolds',re,'Cf_ittc1957',cf, ...
                'pressure_drag_lb',f.count*pressureN/4.4482216153, ...
                'friction_drag_lb',f.count*frictionN/4.4482216153, ...
                'hydrodynamic_drag_lb',drag,'verified_50ft_obstacle_takeoff','NOT_ASSESSED');
        end
        function result = water_run_point(obj,speed_kt,weight_lb,wing_cl)
            if nargin < 4, wing_cl = 0.6; end
            if isempty(obj.aero)
                error('C4:HydroAero','Aerodynamic model is required for water run.');
            end
            a = obj.aero.flight_forces(weight_lb,speed_kt,0,'takeoff_flaps_gear_up',wing_cl);
            h = obj.planing_resistance(speed_kt,weight_lb,a.lift_lb);
            result = h;
            result.aero_lift_lb = a.lift_lb;
            result.aero_drag_lb = a.drag_lb;
            result.combined_drag_lb = a.drag_lb+h.hydrodynamic_drag_lb;
            result.wing_CL_assumed = wing_cl;
            result.wing_CLmax_takeoff = a.CLmax_config;
        end
    end
    methods (Static)
        function cl = savitsky_lift_coefficient(lam,cv,trim_deg,deadrise_deg)
            cl0 = trim_deg^1.1*(0.012*sqrt(lam)+0.0055*lam^2.5/cv^2);
            cl = cl0-0.0065*deadrise_deg*cl0^0.6;
        end
    end
end
