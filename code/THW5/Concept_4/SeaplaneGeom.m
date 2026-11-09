classdef SeaplaneGeom < handle
    properties
        J
        prop
        S_ref = NaN
    end
    properties (Dependent)
        AR
        taper
        b
        c_root
        c_tip
        MAC
        tc_mean
        S_exposed_wing
        S_ht
        b_ht
        MAC_ht
        S_vt
        b_vt
        MAC_vt
        tc_ht
        tc_vt
        w_fus
        h_fus
        l_fus
        S_wet_fuselage
        S_wet_wing
        S_wet_ht
        S_wet_vt
        S_wet_pontoons
        S_wet_float_struts
        S_wet_motor_nacelles
        S_wet_nacelle
        S_wet
        S_wet_over_S_ref
        float_data
        strut_data
        pod_data
        cruciform_tail_height_ft
    end
    methods
        function obj = SeaplaneGeom(J, prop)
            obj.J = J;
            obj.prop = prop;
            if J.concept4_geometry.floats.count ~= 2
                error('C4:FloatCount', 'Concept 4 requires exactly two pontoons.');
            end
            if J.concept4_geometry.motor_nacelles.count ~= prop.n_motors
                error('C4:MotorCount', 'Motor and nacelle counts must agree.');
            end
        end
        function v = get.AR(obj)
            v = obj.J.geometry.AR;
        end
        function v = get.taper(obj)
            v = obj.J.geometry.taper_ratio;
        end
        function v = get.b(obj)
            v = sqrt(obj.AR * obj.S_ref);
        end
        function v = get.c_root(obj)
            v = 2 * obj.S_ref / (obj.b * (1 + obj.taper));
        end
        function v = get.c_tip(obj)
            v = obj.taper * obj.c_root;
        end
        function v = get.MAC(obj)
            t = obj.taper;
            v = 2/3 * obj.c_root * (1 + t + t^2) / (1 + t);
        end
        function v = get.tc_mean(obj)
            G = obj.J.geometry;
            v = (G.thickness_ratio_root + G.thickness_ratio_tip)/2;
        end
        function v = get.w_fus(obj)
            v = obj.J.geometry.fuselage.width_ft;
        end
        function v = get.h_fus(obj)
            v = obj.J.geometry.fuselage.height_ft;
        end
        function v = get.l_fus(obj)
            F = obj.J.geometry.fuselage;
            v = F.nose_length_ft + F.constant_length_ft + F.tailcone_length_ft;
        end
        function v = get.S_exposed_wing(obj)
            covered = obj.c_root * obj.w_fus * (1 - (1 - obj.taper) * obj.w_fus/(2*obj.b));
            v = obj.S_ref - covered;
        end
        function v = get.S_ht(obj)
            H = obj.J.geometry.horizontal_tail;
            v = H.volume_coefficient * obj.S_ref * obj.MAC / H.arm_ft;
        end
        function v = get.b_ht(obj)
            v = sqrt(obj.J.geometry.horizontal_tail.AR * obj.S_ht);
        end
        function v = get.MAC_ht(obj)
            H = obj.J.geometry.horizontal_tail;
            t = H.taper_ratio;
            root = 2 * obj.S_ht / (obj.b_ht * (1 + t));
            v = 2/3 * root * (1+t+t^2)/(1+t);
        end
        function v = get.S_vt(obj)
            V = obj.J.geometry.vertical_tail;
            v = V.volume_coefficient * obj.S_ref * obj.b / V.arm_ft;
        end
        function v = get.b_vt(obj)
            v = sqrt(obj.J.geometry.vertical_tail.AR * obj.S_vt);
        end
        function v = get.MAC_vt(obj)
            V = obj.J.geometry.vertical_tail;
            t = V.taper_ratio;
            root = 2 * obj.S_vt / (obj.b_vt * (1+t));
            v = 2/3 * root * (1+t+t^2)/(1+t);
        end
        function v = get.tc_ht(obj)
            v = obj.J.geometry.horizontal_tail.thickness_ratio;
        end
        function v = get.tc_vt(obj)
            v = obj.J.geometry.vertical_tail.thickness_ratio;
        end
        function v = get.S_wet_fuselage(obj)
            F = obj.J.geometry.fuselage;
            top = 0.5*F.width_ft*F.nose_length_ft + F.width_ft*F.constant_length_ft + ...
                0.5*(F.width_ft+F.tailcone_end_width_ft)*F.tailcone_length_ft;
            side = 0.5*F.height_ft*F.nose_length_ft + F.height_ft*F.constant_length_ft + ...
                0.5*(F.height_ft+F.tailcone_end_height_ft)*F.tailcone_length_ft;
            v = 3.4*(top+side)/2;
        end
        function v = get.S_wet_wing(obj)
            v = SeaplaneGeom.wetted(obj.S_exposed_wing, obj.tc_mean);
        end
        function v = get.S_wet_ht(obj)
            v = SeaplaneGeom.wetted(obj.S_ht, obj.tc_ht);
        end
        function v = get.S_wet_vt(obj)
            v = SeaplaneGeom.wetted(obj.S_vt, obj.tc_vt);
        end
        function v = get.float_data(obj)
            v = obj.J.concept4_geometry.floats;
        end
        function v = get.strut_data(obj)
            v = obj.J.concept4_geometry.float_struts;
        end
        function v = get.pod_data(obj)
            v = obj.J.concept4_geometry.motor_nacelles;
        end
        function v = get.S_wet_pontoons(obj)
            F = obj.float_data;
            a = F.beam_ft/2;
            bval = F.height_ft/2;
            perimeter = pi*(3*(a+bval)-sqrt((3*a+bval)*(a+3*bval)));
            v = F.count * (perimeter*F.length_ft + 2*pi*a*bval);
        end
        function v = get.S_wet_float_struts(obj)
            F = obj.strut_data;
            v = F.count*F.length_ft*F.chord_ft*(1.977+0.52*F.thickness_ratio);
        end
        function v = get.S_wet_motor_nacelles(obj)
            P = obj.pod_data;
            v = P.count*pi*P.diameter_ft*P.length_ft;
        end
        function v = get.S_wet_nacelle(obj)
            v = obj.S_wet_motor_nacelles;
        end
        function v = get.S_wet(obj)
            v = obj.S_wet_wing + obj.S_wet_ht + obj.S_wet_vt + obj.S_wet_fuselage + ...
                obj.S_wet_pontoons + obj.S_wet_float_struts + obj.S_wet_motor_nacelles;
        end
        function v = get.S_wet_over_S_ref(obj)
            v = obj.S_wet / obj.S_ref;
        end
        function v = get.cruciform_tail_height_ft(obj)
            v = obj.J.concept4_geometry.cruciform_tail.height_fraction_of_fin * obj.b_vt;
        end
        function v = get_S_ref(obj)
            v = obj.S_ref;
        end
        function v = get_S_wet(obj, varargin)
            v = obj.S_wet;
        end
        function v = wing_fuel_volume(obj)
            G = obj.J.geometry;
            tau = G.thickness_ratio_tip / G.thickness_ratio_root;
            t = obj.taper;
            v = 0.54*(obj.S_ref^2/obj.b)*G.thickness_ratio_root* ...
                (1+t*sqrt(tau)+t^2*tau)/(1+t)^2;
        end
    end
    methods (Static)
        function v = wetted(area, tc)
            if tc < 0.05
                v = 2.003*area;
            else
                v = area*(1.977+0.52*tc);
            end
        end
    end
end
