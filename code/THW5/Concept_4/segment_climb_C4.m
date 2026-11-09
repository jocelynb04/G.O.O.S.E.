function best = segment_climb_C4(weight_lb, altitude_ft, roc_fpm, aero, eta_p, cfg)
if nargin < 6 || isempty(cfg), cfg = 'clean'; end
if roc_fpm <= 0 || eta_p <= 0 || eta_p > 1
    error('C4:Climb', 'Positive ROC and valid efficiency required.');
end
a = isa_atmosphere_C4(altitude_ft);
p = aero.get_config_polar(struct('alt_ft',altitude_ft,'ktas',110),struct('config',cfg));
vs_fps = sqrt(2*weight_lb/(a.rho_slug_ft3*aero.geom.S_ref*p.CLmax));
lo = max(45,1.20*vs_fps/1.687809857);
hi = max(180,lo+45);
best = [];
for i = 1:35
    speed = lo+(hi-lo)*(i-1)/34;
    f = aero.flight_forces(weight_lb,speed,altitude_ft,cfg);
    if f.CL_limit_exceeded, continue; end
    hp = (f.drag_lb*speed*1.687809857+weight_lb*roc_fpm/60)/(550*eta_p);
    if isempty(best) || hp < best.shaft_hp
        best = struct('shaft_hp',hp,'ktas',speed,'CL',f.CL,'L_over_D',f.L_over_D);
    end
end
if isempty(best), error('C4:MissionInfeasible','No valid climb speed above stall.'); end
end
