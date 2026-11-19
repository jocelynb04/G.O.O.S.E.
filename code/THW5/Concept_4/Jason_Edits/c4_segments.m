function segments = c4_segments(value)
if iscell(value)
    segments = value;
elseif isstruct(value)
    segments = num2cell(value);
else
    error('C4:InvalidSegments', 'Mission segments must be a struct or cell array.');
end
end
