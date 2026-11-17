function cases=hybrid_mission_schedule(obj,W_TO,cfg,J)
%HYBRID_MISSION_SCHEDULE Compile independent normal/reserve/failure routes.
% Profile structure comes from Concept2 requirements. Quantitative speed,
% climb/descent/time and restart policies come from concept2_study_inputs.
% Standard869 nmi missions retain full cruise distance per their JSON flag;
% short-leg route distance subtracts modeled airborne climb/descent distance.
    routes=J.mission_validation_cases.repeated_short_legs.route_distance_nm_cases;
    standard=json_as_struct_array(J.missions.std_mission.segments);
    cruise=standard(find(string({standard.type})=="cruise",1));
    reserveSegment=standard(find(string({standard.type})=="loiter",1));
    designRange=cruise.distance_nm; normalSpeed=cruise.ktas;
    specs={"normal",designRange,normalSpeed,false,1,false; ...
        "go_around_reserve",designRange,normalSpeed,true,1,false; ...
        "electric_departure_OEI",min(routes),normalSpeed,true,1,true};
    if cfg.include_high_speed_mission
        fast=json_as_struct_array(J.missions.high_speed_mission.segments);
        fast=fast(find(string({fast.type})=="cruise",1));
        specs(end+1,:)={"high_speed_reserve",fast.distance_nm,fast.ktas,true,1,false};
    end
    for route=reshape(routes,1,[])
        specs(end+1,:)={"repeated_"+route,route,normalSpeed,false,cfg.repeated_legs,false}; %#ok<AGROW>
    end
    cases=struct([]);
    for ic=1:size(specs,1)
        name=specs{ic,1}; route=specs{ic,2}; speed=specs{ic,3};
        reserve=specs{ic,4}; nlegs=specs{ic,5}; failed=specs{ic,6};
        steps=struct([]); distance_other=0; good=true; reason="";
        for leg=1:nlegs
            f=1; fb=1;
            if leg>1
                % Ground waiting is battery energy too. Associate it with
                % the following leg so periodic checkpoints consistently
                % compare arrivals, before the next turnaround interval.
                fraction("Turnaround without ground charging",cfg.turnaround_min,0,false,1);
            end
            taxi("Taxi out",obj.prop.hybrid.taxi_out_min,1);
            fraction("Electric takeoff",cfg.takeoff_min,1,true,1);
            if failed
                climb("Departure climb to failure",0,400,"electric", ...
                    cfg.electric_climb_ktas,cfg.electric_climb_fpm,"takeoff_flaps_gear_up");
                f=.5;
                fb=cfg.failure_battery_fraction; % loss occurs at the failure, not before takeoff
                % Surviving continuous power sets the sustainable OEI ROC.
                z=coeff(400,cfg.electric_climb_ktas,"takeoff_flaps_gear_up",f);
                level=z.a+z.b*W_TO^2;
                roc=(f*obj.prop.P_motor_continuous-level)*550*obj.prop.eta_p_climb ...
                    *cfg.shaft_efficiency/W_TO*60;
                requiredGradientROC=.01*cfg.electric_climb_ktas*6076.115/3600*60;
                if roc<requiredGradientROC
                    good=false; reason="OEI sustainable ROC below1% checkpoint";
                end
                climb("Electric OEI escape climb",400,1500,"electric", ...
                    cfg.electric_climb_ktas,max(1,min(cfg.electric_climb_fpm,.9*roc)), ...
                    "takeoff_flaps_gear_up");
            else
                climb("Electric departure climb",0,1500,"electric", ...
                    cfg.electric_climb_ktas,cfg.electric_climb_fpm,"takeoff_flaps_gear_up");
            end
            restart("Departure turbine restart");
            cruiseAltitude=cruise.alt_ft; turbineROC=cfg.turbine_climb_fpm;
            if failed
                cruiseAltitude=5000; turbineROC=cfg.oei_turbine_climb_fpm;
            end
            climb("Turbine departure climb",1500,cruiseAltitude,"turbine", ...
                cfg.turbine_climb_ktas,turbineROC,"clean");
            if ~failed && nlegs==1 && ~J.missions.std_mission.credit_climb_distance
                cruiseDistance=route; % conservative full cruise per JSON
            else
                arrivalDistance=cfg.descent_ktas*(cruiseAltitude-1500)/cfg.descent_fpm/60 ...
                    +cfg.approach_ktas*1500/cfg.approach_fpm/60;
                cruiseDistance=route-distance_other-arrivalDistance;
            end
            if cruiseDistance<0
                good=false; reason="route shorter than modeled climb/descent";
            end
            phase("Cruise",max(0,cruiseDistance)/speed*60,cruiseAltitude,cruiseAltitude, ...
                "turbine",speed,0,"clean",false,-1,0,0);
            if failed
                phase("OEI reserve",reserveSegment.time_min,5000,5000,"turbine",speed,0,"clean",false,-1,0,0);
            end
            climb("Turbine descent",cruiseAltitude,1500,"turbine", ...
                cfg.descent_ktas,-cfg.descent_fpm,"clean");
            climb("Electric approach",1500,0,"electric", ...
                cfg.approach_ktas,-cfg.approach_fpm,"landing_flaps_gear_up");
            if reserve && ~failed
                climb("Electric go-around",0,1500,"electric", ...
                    cfg.electric_climb_ktas,cfg.electric_climb_fpm,"landing_flaps_gear_up");
                restart("Go-around turbine restart");
                climb("Reserve turbine climb",1500,5000,"turbine", ...
                    cfg.turbine_climb_ktas,cfg.turbine_climb_fpm,"clean");
                phase("Reserve loiter",reserveSegment.time_min,5000,5000,"turbine",speed,0,"clean",false,-1,0,0);
                climb("Reserve turbine descent",5000,1500,"turbine", ...
                    cfg.descent_ktas,-cfg.descent_fpm,"clean");
                climb("Final electric approach",1500,0,"electric", ...
                    cfg.approach_ktas,-cfg.approach_fpm,"landing_flaps_gear_up");
            end
            fraction("Electric landing",cfg.landing_min,cfg.landing_motor_fraction,false,f);
            taxi("Taxi in",obj.prop.hybrid.taxi_in_min,f);
            distance_other=0; % fresh route distance on the next refuelled leg
        end
        row=struct('name',name,'steps',steps,'schedule_feasible',good,'schedule_reason',reason, ...
            'route_distance_nm',route,'cruise_ktas',speed,'legs',nlegs,'reserve_case',reserve);
        if isempty(cases), cases=row; else, cases(end+1)=row; end %#ok<AGROW>
    end

    function taxi(label,t,ff)
        fraction(label,t,cfg.taxi_motor_fraction,false,ff);
    end
    function fraction(label,t,p,peak,ff)
        prior=f; f=ff;
        phase(label,t,0,0,"electric",0,0,"clean",peak,p,0,0);
        f=prior;
    end
    function restart(label)
        % Turbine credit begins after an explicit level electric hold.
        t=cfg.restart_delay_s/60;
        extraDC=cfg.restart_stored_energy_kWh_each*obj.prop.n_engines*f ...
            *obj.prop.hybrid.battery_efficiency/(t/60);
        startFuel=cfg.restart_fuel_lb_each*obj.prop.n_engines*f/(t/60);
        phase(label,t,1500,1500,"electric",cfg.electric_climb_ktas,0, ...
            "clean",false,-1,extraDC,startFuel);
    end
    function climb(label,h0,h1,src,v,roc,config)
        t=abs(h1-h0)/abs(roc);
        phase(label,t,h0,h1,src,v,roc,config,false,-1,0,0);
        distance_other=distance_other+v*t/60;
    end
    function phase(label,t,h0,h1,src,v,roc,config,peak,p,starter,fuel)
        if t<=0, return; end
        n=max(1,ceil(t/cfg.integration_step_min));
        for it=1:n
            h=h0+(h1-h0)*(it-.5)/n;
            z=coeff(h,v,config,f);
            if v>0
                % source native hp: propulsive power / prop efficiency /
                % additional shaft efficiency. No thermal-efficiency factor.
                z.c=roc/60/(550*z.eta*cfg.shaft_efficiency);
            end
            z.name=label; z.source=src; z.dt_min=t/n; z.peak=peak;
            z.fraction=p; z.f=f; z.fb=fb; z.leg=leg; z.W_TO=W_TO;
            z.accessory_dc_kW=sum([cfg.accessories.kW].*[cfg.accessories.duty]);
            z.restart_dc_kW=starter; z.start_fuel_lb_hr=fuel;
            if isempty(steps), steps=z; else, steps(end+1)=z; end %#ok<AGROW>
        end
    end
    function z=coeff(h,v,config,ff)
        s=get_state(h);
        c=struct('config',config,'propeller_stopped',false, ...
            'failed_propeller_state',[],'type',"climb");
        if ff<1, c.failed_propeller_state="feathered"; end
        polar=constraint_polar(obj,s,c);
        eta=obj.prop.eta_p_climb;
        if config=="clean" && v>=150, eta=obj.prop.eta_p_cruise; end
        V=v*6076.115/3600; q=.5*s.rho*V^2;
        a=0; b=0;
        if V>0
            a=q*obj.geom.S_ref*polar.CD0*V/(550*eta*cfg.shaft_efficiency);
            b=polar.K1*V/(q*obj.geom.S_ref*550*eta*cfg.shaft_efficiency);
        else
            q=NaN;
        end
        z=struct('a',a,'b',b,'c',0,'q',q,'CLmax',polar.CLmax,'eta',eta, ...
            'alt',h,'turbine_hp',ff*obj.prop.turbine_power_available(s,"max_continuous"));
    end
end
