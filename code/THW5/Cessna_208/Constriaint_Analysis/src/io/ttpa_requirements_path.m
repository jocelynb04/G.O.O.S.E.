function p = ttpa_requirements_path()
% Resolve active input from the checkout, independent of Current Folder.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
p=fullfile(root,'config','GrandCaravanEX_requirements_IHW3.json');
assert(isfile(p),'Caravan:MissingJSON','Requirements JSON is missing.');
end
