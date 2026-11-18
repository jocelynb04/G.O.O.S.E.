# Wing and tail feasibility trade

The MATLAB sweep compares 60 and 64.5 ft projected spans, design weights of
9,000 to 12,490 lb, wing loading 17.5 lb/ft², two battery assumptions, and
original or doubled tail areas. All cases use the imported hull, nacelles,
floats and struts, full 2,430 lb payload, 1,000 statute miles, 45-minute reserve,
and immediate turbine assistance during the modeled missed approach.

The 12,490 lb / 64.5 ft case uses 713.7 ft² of wing, aspect ratio 5.829,
14.75 ft root chord and 7.38 ft tip chord at taper ratio 0.5. A tail area
factor of 2 gives horizontal area 105 ft² and vertical area 60 ft². These
areas are geometric sensitivities and require CG, trim, stability, OEI yaw
control, structure, and packaging validation.

With doubled tails, estimated installed mission weight is 12,106.7 lb for
the 300 Wh/kg, 8C battery assumption, or 12,427.4 lb for 250 Wh/kg, 6C.
The electric system requires about 563.7 hp including the modeled takeoff
power margin. A 130 lb hybrid installation allowance is included. Pack
sizing allows for 80% retained capacity. Supplier confirmation is required
for each joint energy, power, thermal and life assumption.

The sweep credits no Cfe reduction. Wing/tail wetted areas scale with their
planform areas. OpenVSP intersection analysis must be rerun after creating
an actual revised shape. Motor ratings are resized per case, rather than
held at the imported baseline. Engine power remains 1,500 shp with the
existing simplified altitude/BSFC model. Tail arms follow quarter-MAC
stations, with no CG-based stability validation. The water performance uses
the existing resistance and deceleration correlations and CLmax target 2.6.

The PreliminaryFeasible column means that constraint power, landing wing
loading, span, repeat-cycle energy, early-return motor/battery limits and
the estimated mission weight budget pass. It does not establish complete
RFP compliance. New nacelle engine/coupling fit and stability margins need
to be resolved before selecting a final geometry.

Run run_concept1_feasibility_trade in Jason_Edits to regenerate the CSV.
The import baseline JSON continues to describe the supplied OpenVSP model.
