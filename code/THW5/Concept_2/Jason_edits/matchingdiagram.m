function [analysis,hist] = matchingdiagram(varargin)
%MATCHINGDIAGRAM Run Concept 2 and display its hybrid constraint diagrams.
%   analysis = matchingdiagram() evaluates the starting aircraft.
%   [analysis,hist] = matchingdiagram('sizing',true) attempts mass closure.
%   Additional options are forwarded to run_concept2_study.
    [analysis,hist]=run_concept2_study('plot_visible',true,varargin{:});
end
