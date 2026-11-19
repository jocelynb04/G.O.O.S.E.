function [analysis,hist]=matchingdiagram(varargin)
%MATCHINGDIAGRAM OpenVSP-matched C4 study with Caravan-style constraint plots.
[analysis,hist]=run_concept4_study(Visible=true,varargin{:});
end
