function verify_concept1_openvsp_geometry()
%VERIFY_CONCEPT1_OPENVSP_GEOMETRY Check the active source and discipline geometry.
setup_jason_edits();
obj = concept1_disciplines();
g = obj.geom; r = g.imported;
assert(isfile(r.source_file),'The active Concept 1 OpenVSP model is missing.');
safePath = strrep(r.source_file,'''','''''');
ps = fullfile(getenv('SystemRoot'),'System32','WindowsPowerShell','v1.0','powershell.exe');
[status,hash] = system(sprintf(['"%s" -NoProfile -NonInteractive -Command "' ...
    '[System.BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().' ...
    'ComputeHash([System.IO.File]::ReadAllBytes(''%s''))).Replace(''-'','''')"'],ps,safePath));
assert(status == 0,'Cannot calculate the OpenVSP source hash: %s',hash);
hash = strtrim(hash);
assert(strcmpi(hash,r.source_sha256), ...
    'OpenVSP changed. Reimport dimensions and CompGeom areas before running.');
assert(abs(g.S_ref-r.wing.area_ft2)<1e-6);
assert(abs(g.b-r.wing.span_ft)<1e-6);
assert(abs(g.MAC-r.wing.MAC_ft)<1e-6);
assert(abs(g.S_ht-r.horizontal_tail.area_ft2)<1e-6);
assert(abs(g.S_vt-r.vertical_tail.area_ft2)<1e-6);
wet = r.wetted_areas_ft2;
expected = wet.WingGeom+wet.HorizontalTail+wet.VerticalTail+ ...
    wet.FuselageGeom+wet.EngineNacelle+wet.WingtipFloats+wet.FloatSupportStruts;
assert(abs(g.S_wet-expected)<1e-6);
assert(abs(obj.aero.CD0-obj.aero.Cfe*expected/g.S_ref)<1e-10);
S = g.S_ref;
g.S_ref = S*1.1;
assert(abs(g.S_wet_wing-wet.WingGeom*1.1)<1e-6);
assert(abs(g.S_ht-r.horizontal_tail.area_ft2)<1e-6);
g.S_ref = S;
fprintf('Concept 1 geometry verified: %.3f ft span, %.3f ft^2 wing, %.5f CD0.\n',g.b,S,obj.aero.CD0);
end
