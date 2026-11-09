function best = c4_required_climb_hp(weight_lb,area_ft2,alt_ft,roc_fpm,aero,eta_p,speed_samples)
a = isa_atmosphere_C4(alt_ft);
p = aero.get_config_polar(struct('alt_ft',alt_ft,'ktas',110),struct('config','clean'));
clmax = p.CLmax-aero.CL_stall_margin;
if clmax <= 0, error('C4:CLmax','CLmax with margin must be positive.'); end
v_stall = sqrt(2*weight_lb/(a.rho_slug_ft3*area_ft2*clmax));
v_min = max(45*1.687809857,1.15*v_stall);
v_max = max(185*1.687809857,v_min+50*1.687809857);
best = [];
for i = 1:speed_samples
    v = v_min+(v_max-v_min)*(i-1)/(speed_samples-1);
    q = 0.5*a.rho_slug_ft3*v^2;
    cl = weight_lb/(q*area_ft2);
    if cl > clmax, continue; end
    cd = p.CD0+p.K1*cl^2;
    drag = q*area_ft2*cd;
    hp = (drag*v+weight_lb*roc_fpm/60)/(550*eta_p);
    if isempty(best) || hp < best.hp
        best = struct('hp',hp,'speed_ktas',v/1.687809857,'CL',cl,'CD0',p.CD0);
    end
end
end
