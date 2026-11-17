classdef Concept1_iteration
%CONCEPT1SIZINGSTEPS  Core fixed-point updates for Concept 1 sizing.
%
%   Preserves the professor's SizingSteps structure. The closure uses the
%   Concept 1 accounting convention:
%
%       W_TO = OEW + W_energy + W_payload
%       W_energy = W_fuel + W_battery
%
%   The mission/sizing code supplies W_energy at the current W_TO iterate.

    methods (Static)

        function [W_TO_new, denom] = togw_update(W_payload, W_OEW, ...
                W_energy, W_TO)
        %TOGW_UPDATE  One takeoff-weight fixed-point step [lbf].
        %
        %   Fractions are evaluated at the current guess W_TO:
        %
        %       denom = 1 - W_OEW/W_TO - W_energy/W_TO
        %       W_TO_new = W_payload / denom
        %
        %   W_energy must include all required mission fuel and battery
        %   weight, without adding battery weight to OEW as well. A
        %   nonpositive denominator means no positive takeoff-weight
        %   closure exists at this iterate; W_TO_new is returned as NaN.
            arguments
                W_payload (1,1) double {mustBePositive}
                W_OEW     (1,1) double {mustBeNonnegative}
                W_energy  (1,1) double {mustBeNonnegative}
                W_TO      (1,1) double {mustBePositive}
            end

            denom = 1 - W_OEW / W_TO - W_energy / W_TO;
            if denom <= 0
                W_TO_new = NaN;
            else
                W_TO_new = W_payload / denom;
            end
        end


        function x = relax(x_old, x_new, weight)
        %RELAX  Under-relaxed fixed-point update.
        %
        %       x = x_old + weight * (x_new - x_old)
        %
        %   weight is in (0,1]; smaller values damp each iteration.
            arguments
                x_old  (1,1) double
                x_new  (1,1) double
                weight (1,1) double {mustBeInRange(weight, 0, 1, ...
                    "exclude-lower")}
            end

            x = x_old + weight * (x_new - x_old);
        end

    end
end
