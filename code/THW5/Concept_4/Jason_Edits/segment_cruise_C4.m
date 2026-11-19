function r = segment_cruise_C4(weight_lb, speed_ktas, altitude_ft, aero, eta_p)
if eta_p <= 0 || eta_p > 1
    error('C4:Efficiency', 'Propeller efficiency must be in (0,1].');
end
f = aero.flight_forces(weight_lb, speed_ktas, altitude_ft, 'clean');
if f.CL_limit_exceeded
    error('C4:Stall', 'Cruise lift exceeds clean CLmax.');
end
r = struct('shaft_hp', f.drag_lb*speed_ktas*1.687809857/(550*eta_p), ...
    'CL',f.CL,'L_over_D',f.L_over_D,'drag_lb',f.drag_lb);
end
