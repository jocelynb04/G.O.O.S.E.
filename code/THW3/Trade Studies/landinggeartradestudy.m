clear;
clc;
close all;

% Maximum aircraft weight from RFP (lb)
MTOW = 12500;
% Landing gear weights investigated (lb)
W_LG = [300 350 400 450 500 550 600 650 700 750];
% Clculate landing gear weight as percentage of MTOW
WeightPenalty = (W_LG ./ MTOW) .* 100;
figure;
plot(W_LG, WeightPenalty, '-o')
xlabel('Landing Gear Weight (lb)');
ylabel('Landing Gear Weight (% of MTOW)');
title('Landing Gear Weight vs. Aircraft Weight Penalty');
grid on;
box on;
