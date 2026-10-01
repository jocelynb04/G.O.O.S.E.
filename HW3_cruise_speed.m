clear;
clc;
close all;

% Cruise speed range
V = 100:10:180;     % KTAS

% Simple preliminary power model, 180 KTAS = 100% required power
P = 100 * (V/180).^3;

% Plot
figure
plot(V, P, '-o', 'LineWidth', 2)
grid on

xlabel('Cruise Speed (KTAS)')
ylabel('Required Power (% of 180 KTAS Power)')
title('Cruise Speed vs. Required Power')

% Mark RFP requirement
xline(180, '--', 'RFP Requirement');