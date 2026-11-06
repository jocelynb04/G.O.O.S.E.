function [WP,info] = constraint_climb_path(WS,obj,condition)
%CONSTRAINT_CLIMB_PATH Constant flight-path-angle or optional constant-ROC constraint.
% WS lbf/ft2, WP lbf/shp. Angle branch uses L=W*cos(gamma), not L=W.
validateattributes(WS,{'numeric'},{'positive','finite','vector'});
WS=reshape(WS,1,[]); st=get_state(condition.altitude_ft);
con=struct('type','climb','config',condition.config,'propeller_stopped',false, ...
    'max_continuous',condition.max_continuous,'oei',condition.oei,'power_setting',condition.power_setting);
validateattributes(condition.beta,{'numeric'},{'scalar','>',0,'<=',1,'finite'});
validateattributes(condition.power_setting,{'numeric'},{'scalar','>',0,'<=',1,'finite'});
cfg=obj.aero.get_config_polar(st,con); eta=obj.prop.prop_eff(st,con);
kP=obj.prop.power_ratio(st,con); beta=condition.beta;
CLcap=cfg.CLmax-obj.aero.CL_stall_margin;
assert(CLcap>0,'Constraints:LiftMargin','CLmax must exceed the configured stall margin.');
if string(condition.requirement_type)=="angle"
    validateattributes(condition.angle_deg,{'numeric'},{'scalar','>',0,'<',30,'finite'});
    gamma=deg2rad(condition.angle_deg); G=tan(gamma);
    % Minimum shaft power at fixed angle and W/S, limited by available CL.
    CL=min(CLcap,(G+sqrt(G^2+12*cfg.K1*cfg.CD0))/(2*cfg.K1));
    CD=cfg.CD0+cfg.K1*CL^2;
    V=sqrt(2*beta*WS*cos(gamma)/(st.rho*CL));
    specific_work=V.*(cos(gamma)*CD/CL+sin(gamma));
    ROC=60*V*sin(gamma);
elseif string(condition.requirement_type)=="rate"
    validateattributes(condition.roc_fpm,{'numeric'},{'scalar','positive','finite'});
    CL=min(CLcap,sqrt(3*cfg.CD0/cfg.K1)); CD=cfg.CD0+cfg.K1*CL^2;
    V=sqrt(2*beta*WS/(st.rho*CL));
    ROC=condition.roc_fpm*ones(size(WS));
    specific_work=V*CD/CL+ROC/60; % Quasi-steady small-angle L~W approximation.
else
    error('Constraints:ClimbType','Climb requirement type must be angle or rate.');
end
WP=550*eta*kP./(beta*specific_work);
info=struct('CL',CL,'CD',CD,'V_fps',V,'roc_fpm',ROC,'kP',kP, ...
    'eta_p',eta,'altitude_ft',condition.altitude_ft,'requirement_type',string(condition.requirement_type));
end
