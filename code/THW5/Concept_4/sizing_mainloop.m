function result = sizing_mainloop(solver,max_iter,tol,relaxation)
if nargin < 2, max_iter = []; end
if nargin < 3, tol = []; end
if nargin < 4, relaxation = []; end
result = solver.run(max_iter,tol,relaxation);
end
