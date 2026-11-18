function results = run_concept1_feasibility_trade()
%RUN_CONCEPT1_FEASIBILITY_TRADE Screen wing changes on the imported airframe.
% Candidate wetted wing area scales with planform area. Tails and hull stay
% fixed. New OpenVSP shapes and aerodynamic/structural validation are required.
here = fileparts(mfilename('fullpath'));
setup_jason_edits();
source = jsondecode(fileread(concept1_requirements_path()));
W = [9000,10000,11000,12000,12490];
spanCases = [60,64.5];
results = table();
for span = spanCases
    for weight = W
        for conservativeBattery = [false,true]
          for tailScale = [1,2]
            wingLoading = 17.5;
            S = weight/wingLoading;
            cfg = source;
            original = source.geometry.openvsp.wing;
            w = original;
            w.area_ft2 = S;
            w.span_ft = span;
            w.AR = span^2/S;
            w.root_chord_ft = 2*S/(span*(1+w.taper_ratio));
            w.tip_chord_ft = w.root_chord_ft*w.taper_ratio;
            w.MAC_ft = 2*w.root_chord_ft/3*(1+w.taper_ratio+w.taper_ratio^2)/(1+w.taper_ratio);
            yMac = span*(1+2*w.taper_ratio)/(6*(1+w.taper_ratio));
            w.x_quarter_MAC_ft = w.origin_ft(1)+yMac*tand(3)+0.25*w.MAC_ft;
            cfg.geometry.openvsp.wing = w;
            cfg.geometry.openvsp.wetted_areas_ft2.WingGeom = ...
                source.geometry.openvsp.wetted_areas_ft2.WingGeom*S/original.area_ft2;
            for name = ["horizontal_tail","vertical_tail"]
                tail = cfg.geometry.openvsp.(name);
                tail.area_ft2 = tail.area_ft2*tailScale;
                tail.span_ft = tail.span_ft*sqrt(tailScale);
                tail.root_chord_ft = tail.root_chord_ft*sqrt(tailScale);
                tail.tip_chord_ft = tail.tip_chord_ft*sqrt(tailScale);
                tail.MAC_ft = tail.MAC_ft*sqrt(tailScale);
                if name == "horizontal_tail"
                    yTail = tail.span_ft*(1+2*tail.taper_ratio)/(6*(1+tail.taper_ratio));
                    leSweep = 10;
                else
                    yTail = tail.span_ft*(1+2*tail.taper_ratio)/(3*(1+tail.taper_ratio));
                    leSweep = 25;
                end
                tail.x_quarter_MAC_ft = tail.origin_ft(1)+yTail*tand(leSweep)+0.25*tail.MAC_ft;
                cfg.geometry.(name).arm_ft = tail.x_quarter_MAC_ft-w.x_quarter_MAC_ft;
                cfg.geometry.openvsp.(name) = tail;
            end
            cfg.geometry.openvsp.wetted_areas_ft2.HorizontalTail = ...
                source.geometry.openvsp.wetted_areas_ft2.HorizontalTail*tailScale;
            cfg.geometry.openvsp.wetted_areas_ft2.VerticalTail = ...
                source.geometry.openvsp.wetted_areas_ft2.VerticalTail*tailScale;
            cfg.geometry.AR = w.AR;
            cfg.geometry.reference_area_ft2 = S;
            cfg.geometry.reference_span_ft = span;
            candidate = [tempname() '.json'];
            fid = fopen(candidate,'w');
            assert(fid>=0);
            fprintf(fid,'%s',jsonencode(cfg));
            fclose(fid);
            cleanup = onCleanup(@() delete(candidate));
            whkg = 300; dischargeC = 8;
            if conservativeBattery, whkg = 250; dischargeC = 6; end
            try
                [~,mission,early,obj] = run_concept1_energy_trade( ...
                    RequirementsPath=candidate,DesignWeight=weight,AspectRatio=w.AR, ...
                    LandingCLmax=2.6,CombustionRating=1500,EngineDryWeight=340, ...
                    EngineBSFC=0.595*783/750,AssistDelaySeconds=0,PackWhPerKg=whkg, ...
                    DischargeC=dischargeC,CapacityRetention=0.8,SkinFrictionFactor=1, ...
                    RequireFeasible=true,WriteResults=false);
                motorBare = mission.MotorRated_shp*.745699872 / ...
                    cfg.propulsion.motor_specific_power_kW_kg*2.20462262;
                oldAllowance = motorBare*(cfg.weights.concept1.motor_installation_factor-1);
                installedWeight = mission.WeightBuildup_lbf-oldAllowance+130;
                powerPass = true;
                earlyPass = early.MotorWithinRating && early.BatteryWithinPowerLimit && early.SOCAboveMinimum;
                Vh = obj.geom.S_ht*obj.geom.L_ht/(obj.geom.S_ref*obj.geom.MAC);
                Vv = obj.geom.S_vt*obj.geom.L_vt/(obj.geom.S_ref*obj.geom.b);
                motorHp = mission.MotorRated_shp;
                batteryWeight = mission.Battery_lbf;
                fuel = mission.MissionFuel_lbf;
                status = "Calculated";
            catch problem
                installedWeight=NaN; motorHp=NaN; batteryWeight=NaN; fuel=NaN;
                Vh=NaN; Vv=NaN; powerPass=false; earlyPass=false;
                status = string(problem.identifier)+" "+string(problem.message);
            end
            row = table(weight,span,S,w.AR,w.root_chord_ft,w.tip_chord_ft,whkg,dischargeC,tailScale, ...
                installedWeight,weight-installedWeight,motorHp,batteryWeight,fuel, ...
                Vh,Vv,powerPass,earlyPass,powerPass&&earlyPass&&installedWeight<=weight,status, ...
                'VariableNames',{'DesignWeight_lbf','Span_ft','WingArea_ft2','AspectRatio', ...
                'RootChord_ft','TipChord_ft','Pack_Wh_kg','Discharge_C','TailAreaFactor','InstalledMissionWeight_lbf', ...
                'WeightMargin_lbf','ElectricRating_hp','Battery_lbf','MissionFuel_lbf', ...
                'HorizontalTailVolume','VerticalTailVolume','ConstraintPass','EarlyReturnPass', ...
                'PreliminaryFeasible','Status'});
            results = [results;row];
            clear cleanup
          end
        end
    end
end
out = fullfile(here,'results');
if ~isfolder(out), mkdir(out); end
writetable(results,fullfile(out,'OpenVSP_feasibility_trade.csv'));
disp(results(:,{'DesignWeight_lbf','Span_ft','WingArea_ft2','Pack_Wh_kg','TailAreaFactor', ...
    'InstalledMissionWeight_lbf','WeightMargin_lbf','ElectricRating_hp','PreliminaryFeasible'}));
end
