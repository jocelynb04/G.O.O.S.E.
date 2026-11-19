classdef Concept2RangeTest < matlab.unittest.TestCase
 methods(Test)
  function correctedRangeDefinition(t)
   [o,~,~,J]=build_concept2_study();s=json_as_struct_array(J.missions.std_mission.segments);
   c=find(string({s.type})=="cruise",1);
   t.verifyEqual(s(c).distance_nm*1.150779448,1000,AbsTol=1e-8);
   t.verifyEqual(o.wts.payload(),2430);
  end
  function failedDesignDoesNotPublishSearchBoundAsRange(t)
   r=run_concept2_range(WriteResults=false,DistanceStepMi=1000,MaximumRangeMi=1000,CapacityPoints=2);
   t.verifyEqual(r.payload_lb,2430);t.verifyFalse(r.rfp_compliance_established);
   t.verifyTrue(isnan(r.maximum_range_statute_mi));
   t.verifyLessThan(r.maximum_pack_with_zero_fuel_kWh,3000);
   t.verifyLessThanOrEqual(max(r.packs_searched_kWh),r.maximum_pack_with_zero_fuel_kWh);
  end
 end
end
