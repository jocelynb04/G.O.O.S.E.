function report=verify_openvsp_geometry(writeResults)
%VERIFY_OPENVSP_GEOMETRY Check code against native exports and source checksum.
if nargin<1,writeResults=true;end
root=fileparts(mfilename('fullpath'));J=jsondecode(fileread(fullfile(root,'concept4_aero_hydro_requirements.json')));
ref=jsondecode(fileread(fullfile(root,'OpenVSP_Import','openvsp_reference.json')));
p=SeaplaneProp_Concept4(J);g=SeaplaneGeom(J,p);
file=fullfile(root,'OpenVSP_Import','Seaplane_Concept04.vsp3');
command=sprintf('"%s" -hashfile "%s" SHA256',fullfile(getenv('SystemRoot'),'System32','certutil.exe'),file);
[status,output]=system(command);
hash=regexp(output,'[A-Fa-f0-9]{64}','match','once');
assert(status==0 && ~isempty(hash),'C4:HashCheck','Could not compute source file checksum: %s',output);
hash=lower(hash);
assert(strcmp(hash,ref.source.sha256),'C4:StaleGeometry','OpenVSP file changed; regenerate native exports and geometry inputs.');
externalChecked=false;
if isfile(ref.source.source_file)
 externalCommand=sprintf('"%s" -hashfile "%s" SHA256',fullfile(getenv('SystemRoot'),'System32','certutil.exe'),ref.source.source_file);
 [externalStatus,externalOutput]=system(externalCommand);
 externalHash=regexp(externalOutput,'[A-Fa-f0-9]{64}','match','once');
 assert(externalStatus==0 && strcmpi(externalHash,hash),'C4:StaleExternalGeometry','Original OpenVSP source changed; refresh the imported geometry.');
 externalChecked=true;
end
metric={'wing_area_ft2','wing_span_ft','wing_AR','wing_MAC_ft','horizontal_tail_area_ft2','horizontal_tail_span_ft', ...
 'vertical_tail_area_ft2','vertical_tail_height_ft','fuselage_length_ft','fuselage_width_ft','fuselage_height_ft', ...
 'pontoon_length_ft','pontoon_beam_ft','pontoon_height_ft','nacelle_length_ft','nacelle_diameter_ft','motor_count'};
actual=[g.S_ref,g.b,g.AR,g.MAC,g.S_ht,g.b_ht,g.S_vt,g.b_vt,g.l_fus,g.w_fus,g.h_fus, ...
 g.float_data.length_ft,g.float_data.beam_ft,g.float_data.height_ft,g.pod_data.length_ft,g.pod_data.diameter_ft,p.n_motors];
expected=[ref.wing.area_ft2,ref.wing.span_ft,ref.wing.AR,ref.wing.MAC_ft,ref.horizontal_tail.area_ft2,ref.horizontal_tail.span_ft, ...
 ref.vertical_tail.area_ft2,ref.vertical_tail.span_ft,ref.fuselage.length_ft,ref.fuselage.width_ft,ref.fuselage.height_ft, ...
 ref.floats.length_ft,ref.floats.beam_ft,ref.floats.height_ft,ref.motor_nacelles.length_ft,ref.motor_nacelles.diameter_ft,ref.motor_nacelles.count];
areas={'wing','horizontal_tail','vertical_tail','fuselage','pontoons','float_struts','motor_nacelles'};
values=[g.S_wet_wing,g.S_wet_ht,g.S_wet_vt,g.S_wet_fuselage,g.S_wet_pontoons,g.S_wet_float_struts,g.S_wet_motor_nacelles];
for k=1:numel(areas),metric{end+1}=['wetted_' areas{k} '_ft2'];actual(end+1)=values(k);expected(end+1)=ref.wetted_areas_ft2.(areas{k});end %#ok<AGROW>
passed=abs(actual-expected)<=1e-6.*max(1,abs(expected));
T=table(string(metric(:)),actual(:),expected(:),actual(:)-expected(:),passed(:), ...
 'VariableNames',{'metric','code_value','OpenVSP_value','difference','pass'});
report=struct('all_pass',all(passed),'source_sha256',hash,'external_source_checked',externalChecked,'checks',T,'scope','Geometry agreement only; not aerodynamic or structural validation.');
assert(report.all_pass,'C4:GeometryMismatch','Code differs from the native OpenVSP reference.');
if writeResults
 out=fullfile(root,'Results','Current');if ~isfolder(out),mkdir(out);end
 writetable(T,fullfile(out,'OpenVSP_geometry_check.csv'));
 write_json_C4(fullfile(out,'OpenVSP_geometry_check.json'),rmfield(report,'checks'));
end
end
