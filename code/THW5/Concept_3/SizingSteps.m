classdef SizingSteps
%SIZINGSTEPS  Static numerical steps for the aircraft sizing loop.
%
%   SizingSteps.togw_update(...) computes the takeoff gross weight
%   closure at a candidate weight. SizingSteps.relax(...) applies
%   under-relaxation to stabilize fixed-point iteration.

    methods (Static)

        function [W0_new, denom] = togw_update(W_payload, W_OEW, W_fuel, W_TO)
        %TOGW_UPDATE  One takeoff-gross-weight fixed-point step [lbf].
        %   The fractions are evaluated at the CURRENT W_TO guess.
            arguments
                W_payload (1,1) double {mustBePositive}
                W_OEW     (1,1) double {mustBeNonnegative}
                W_fuel    (1,1) double {mustBeNonnegative}
                W_TO      (1,1) double {mustBePositive}
            end

            denom = 1 - W_fuel/W_TO - W_OEW/W_TO;

            if denom <= 0
                W0_new = NaN;
            else
                W0_new = W_payload/denom;
            end
        end

        function x = relax(x_old, x_new, w)
        %RELAX  Under-relaxed update x = x_old + w*(x_new-x_old).
            arguments
                x_old (1,1) double
                x_new (1,1) double
                w     (1,1) double {mustBeInRange(w, 0, 1, "exclude-lower")}
            end

            x = x_old + w*(x_new - x_old);
        end

    end
end
