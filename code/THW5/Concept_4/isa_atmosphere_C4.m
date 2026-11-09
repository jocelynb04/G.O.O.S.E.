function a = isa_atmosphere_C4(alt_ft)
if ~isscalar(alt_ft) || ~isfinite(alt_ft) || alt_ft < 0 || alt_ft > 36089
    error('C4:Atmosphere', 'ISA model supports altitude from 0 through 36089 ft.');
end
h = alt_ft * 0.3048;
T = 288.15 - 0.0065 * h;
p = 101325 * (T / 288.15)^5.2558797;
rho = p / (287.05287 * T);
mu = 1.716e-5 * (T / 273.15)^1.5 * (273.15 + 110.4) / (T + 110.4);
a = struct('T_K', T, 'pressure_Pa', p, 'rho_kg_m3', rho, ...
    'rho_slug_ft3', rho * 0.00194032033, 'mu_Pa_s', mu, ...
    'speed_of_sound_m_s', sqrt(1.4 * 287.05287 * T));
end
