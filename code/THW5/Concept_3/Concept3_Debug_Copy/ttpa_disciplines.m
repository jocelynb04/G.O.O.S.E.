function obj = ttpa_disciplines(json_path)
%TTPA_DISCIPLINES Initialize the Concept 3 models from the supplied JSON.
    if nargin == 0
        json_path = fullfile(fileparts(mfilename('fullpath')), 'concept3.json');
    end
    addpath(fullfile(fileparts(mfilename('fullpath')), 'framework'));
    J = jsondecode(fileread(json_path));

    prop = TtpaProp(json_path);
    geom = TtpaGeom(json_path, prop);
    geom.S_ref = J.sizing.S_ref_guess_ft2;
    aero = TtpaAero(json_path, geom);
    wts = TtpaWeights(json_path, geom, prop);
    wts.W_TO = J.sizing.W_TO_guess_lbf;

    obj = struct('prop', prop, 'geom', geom, 'aero', aero, 'wts', wts, ...
        'miss', MissionProfileReader.read_profile(json_path, 'std_mission'), ...
        'cons', ConstraintSetImporter.read_conditions(json_path), ...
        'constraint_settings', J.constraints, 'sizing', J.sizing, ...
        'mission_assumptions',J.mission_assumptions,'range_analysis',J.range_analysis);
end
