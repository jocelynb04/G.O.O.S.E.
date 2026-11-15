function r = constraint_cruise_speed_C4(weight_lb,area_ft2,altitude_ft,speed_ktas,aero,eta_p)
a = isa_atmosphere_C4(altitude_ft);
v = speed_ktas*1.687809857;
q = 0.5*a.rho_slug_ft3*v^2;
p = aero.get_config_polar(struct('alt_ft',altitude_ft,'ktas',speed_ktas),struct('config','clean'));
cl = weight_lb/(q*area_ft2);
if cl > p.CLmax
    r = [];
    return;
end
cd = p.CD0+p.K1*cl^2;
drag_lb = q*area_ft2*cd;
r = struct('hp',drag_lb*v/(550*eta_p),'drag_lb',drag_lb,'CL',cl,'L_over_D',cl/cd);
end
