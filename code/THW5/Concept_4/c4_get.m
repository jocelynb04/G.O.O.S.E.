function value = c4_get(s, field, fallback)
if nargin < 3
    fallback = [];
end
if isstruct(s) && isscalar(s) && isfield(s, field)
    value = s.(field);
else
    value = fallback;
end
end
