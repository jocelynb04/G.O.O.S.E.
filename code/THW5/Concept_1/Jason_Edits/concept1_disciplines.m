function [obj] = concept1_disciplines()
%CONCEPT1_DISCIPLINES  Build the Concept 1 discipline bundle.
%
%   obj = concept1_disciplines() returns the same struct layout as
%   ttpa_disciplines, with the Concept 1 classes:
%
%       obj.prop   Concept1HybridProp   power ratios, efficiencies, battery
%       obj.geom   Concept1Geom         planform, wetted areas (needs prop)
%       obj.aero   Concept1Aero         polar from geometry (needs geom)
%       obj.wts    Concept1Weights      OEW build-up (needs geom and prop)
%       obj.miss   struct               mission profile from the JSON
%       obj.cons   struct array         RFP constraint conditions
%
%   BUILD ORDER MATTERS: prop first, then geom, then aero and wts, because
%   each is injected into the next (see the headers of Concept1Geom and
%   Concept1Aero).
%
%   The constraint conditions come from concept1_rfp_constraints so the RFP
%   numbers live in one file. To use conditions from the JSON instead,
%   replace that line with
%       cons = ConstraintSetImporter.read_conditions(json_path);
%   but note that the Concept 1 climb, takeoff and landing functions read
%   the extra fields roc_fpm and mu from each condition.
%
%   The JSON comes from concept1_requirements_path (the Concept 1 file, not the
%   TTPA one).
%
%   The discipline objects are handle objects, so the sizing loop's writes
%   to obj.prop.P_SL and obj.geom.S_ref are seen by every caller.

    setup_jason_edits();
    json_path = concept1_requirements_path();

    prop = Concept1HybridProp(json_path);
    geom = Concept1Geom(json_path, prop);
    aero = Concept1Aero(json_path, geom);
    wts  = Concept1Weights(json_path, geom, prop);
    miss = MissionProfileReader.read_profile(json_path, 'std_mission');
    cons = concept1_rfp_constraints();
    J = jsondecode(fileread(json_path));
    if isfield(J,'analysis_design')
        prop.P_SL = J.analysis_design.turbine_rating_hp;
        prop.electric_power_ratio = J.analysis_design.electric_rating_hp / prop.P_SL;
    end

    obj = struct('aero', aero, 'prop', prop, 'wts', wts, 'geom', geom, ...
        'miss', miss, 'cons', cons, 'constraint_settings', J.constraints, ...
        'sizing', J.sizing, 'analysis_design', J.analysis_design);
end
