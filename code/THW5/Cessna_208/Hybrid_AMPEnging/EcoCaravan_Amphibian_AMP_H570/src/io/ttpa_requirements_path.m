function p = ttpa_requirements_path()
p = fullfile(eco_project_root(),'config', 'GrandCaravanEX_requirements_IHW3.json');
assert(isfile(p), 'Caravan:MissingJSON', 'Requirements JSON is missing.');
end
