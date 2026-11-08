
def sizing_mainloop(solver, *, max_iter=None, tol=None, relaxation=None):
    return solver.run(
        max_iter=max_iter,
        tol=tol,
        relaxation=relaxation
    )
