function verify_openvsp_geometry()
%VERIFY_OPENVSP_GEOMETRY Verify the source snapshot and active model dimensions.
    setup_concept2();
    [obj,opts]=build_concept2_study();
    g=obj.geom; r=g.openvsp_reference;
    assert(~isempty(fieldnames(r)),'No OpenVSP reference is installed.');
    assert(isfile(r.source_file),'The source OpenVSP file is missing.');
    snapshot=fullfile(concept2_project_root(),'OpenVSP_Import','Concept_2.vsp3');
    assert(isequal(read_bytes(r.source_file),read_bytes(snapshot)), ...
        'OpenVSP changed; reimport its geometry.');
    pairs=[g.S_ref,r.wing.area_ft2;g.b,r.wing.span_ft;g.MAC,r.wing.MAC_ft; ...
        g.c_root,r.wing.root_chord_ft;g.c_tip,r.wing.tip_chord_ft; ...
        g.S_ht,r.horizontal_tail.area_ft2;g.b_ht,r.horizontal_tail.span_ft; ...
        g.S_vt,r.vertical_tail.area_ft2;g.b_vt,r.vertical_tail.span_ft; ...
        g.MAC_vt,r.vertical_tail.MAC_ft;g.l_fus,r.fuselage.length_ft; ...
        g.l_nacelle,r.nacelle.length_ft;g.d_nacelle,r.nacelle.diameter_ft; ...
        g.l_float,r.floats.length_ft;g.b_float,r.floats.beam_ft; ...
        g.d_float,r.floats.depth_ft;g.V_enclosed_each,r.floats.enclosed_volume_each_ft3];
    assert(all(abs(pairs(:,1)-pairs(:,2))<1e-7),'Imported geometry mismatch.');
    assert(abs(g.S_rudder_vt-r.vertical_tail.rudder_planform_ft2)<1e-7);
    expected=sum(cell2mat(struct2cell(r.wetted_areas_ft2)));
    assert(abs(g.S_wet-expected)<1e-7,'Wetted-area sum mismatch.');
    assert(abs(obj.aero.CD0-obj.aero.Cfe*expected/g.S_ref)<1e-10);
    assert(obj.prop.n_engines==r.propellers.count);
    originalS=g.S_ref; originalW=g.W_TO;
    g.S_ref=originalS*1.1; g.W_TO=originalW*1.1;
    assert(abs(g.S_wet_wing-r.wetted_areas_ft2.WingGeom*1.1)<1e-7);
    assert(abs(g.S_ht-r.horizontal_tail.area_ft2)<1e-7);
    assert(abs(g.S_wet_floats-r.wetted_areas_ft2.Pontoon)<1e-7);
    assert(abs(g.V_enclosed_each-r.floats.enclosed_volume_each_ft3)<1e-7);
    g.S_ref=originalS;g.W_TO=originalW;
    check=concept2_geometry_validation(obj,opts.W0);
    assert(~check.intact_buoyancy_met,'Expected the imported float-volume shortfall.');
    fprintf('OPENVSP_GEOMETRY_VERIFIED: wing %.4f ft2; span %.3f ft; HT %.4f ft2; VT %.4f ft2; CD0 %.5f.\n', ...
        g.S_ref,g.b,g.S_ht,g.S_vt,obj.aero.CD0);
    fprintf('Float volume %.2f / %.2f ft3 required; buoyancy screen passes: %d.\n', ...
        check.float_volume_available_ft3,check.float_volume_required_ft3,check.intact_buoyancy_met);
end

function bytes=read_bytes(path)
    fid=fopen(path,'rb'); assert(fid>=0,'Cannot read geometry source: %s',path);
    cleanup=onCleanup(@() fclose(fid));
    bytes=fread(fid,Inf,'*uint8');
end
