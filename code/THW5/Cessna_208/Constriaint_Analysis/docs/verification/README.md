# Reviewed verification records

- REV0_VERIFICATION.txt: user's existing source-folder record, preserved unchanged.
- ORGANIZED_VERIFICATION.txt: fresh MATLAB R2025a Update 1 verification after organization: 10 passed, 0 failed, no incomplete tests; MATLAB-only dependency audit; 1550.3-lb baseline fuel and 127-pass sizing convergence.
- A separate fresh MATLAB process ran a reduced 26-file mission runtime without constraint calculations, sizing, tests, legacy examples, the L1 implementation, benchmark helpers or saved MAT outputs. It returned the same 1550.3-lb mission fuel. This verifies the optional-file classification for the active L2 profile; it is not a claim that 26 is the mathematically smallest possible file set.

Current runs regenerate logs and binary results under outputs/, which is excluded from Git. These reviewed text records are intentionally kept for reproducibility.
