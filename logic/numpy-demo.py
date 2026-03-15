# /// script
# requires-python = ">=3.10"
# dependencies = ["numpy"]
# ///

import numpy as np
import base64
import sys
import platform

print("set lblStatus.Foreground #888")
print("set lblStatus.Text NumPy computing...")
sys.stdout.flush()

lines = []
lines.append(f"Platform: {platform.platform()}")
lines.append(f"Python:   {platform.python_version()}")
lines.append(f"NumPy:    {np.__version__}")
lines.append("")

# 1. Random matrix
rng = np.random.default_rng(42)
A = rng.standard_normal((4, 4))
lines.append("=== 4x4 Random Matrix ===")
for row in A:
    lines.append("  " + "  ".join(f"{x:+.4f}" for x in row))

# 2. Eigenvalues
eigvals = np.linalg.eigvals(A)
lines.append("")
lines.append("=== Eigenvalues ===")
for v in eigvals:
    if np.isreal(v):
        lines.append(f"  {v.real:+.6f}")
    else:
        lines.append(f"  {v.real:+.6f} {v.imag:+.6f}j")

# 3. SVD
U, S, Vt = np.linalg.svd(A)
lines.append("")
lines.append("=== Singular Values (SVD) ===")
lines.append("  " + "  ".join(f"{s:.6f}" for s in S))

# 4. Basic stats
lines.append("")
lines.append("=== Statistics ===")
lines.append(f"  Mean:   {A.mean():.6f}")
lines.append(f"  Std:    {A.std():.6f}")
lines.append(f"  Min:    {A.min():.6f}")
lines.append(f"  Max:    {A.max():.6f}")
lines.append(f"  Det:    {np.linalg.det(A):.6f}")
lines.append(f"  Rank:   {np.linalg.matrix_rank(A)}")
lines.append(f"  Norm:   {np.linalg.norm(A):.6f}")

# 5. Matrix operations
lines.append("")
lines.append("=== A @ A^T diagonal ===")
AAt = A @ A.T
lines.append("  " + "  ".join(f"{AAt[i,i]:.4f}" for i in range(4)))

result = "\n".join(lines)
encoded = base64.b64encode(result.encode()).decode()

print(f"setb64 txtResponse.Text {encoded}")
print("set lblStatus.Foreground #4CAF50")
pyver = platform.python_version()
print(f"set lblStatus.Text NumPy {np.__version__} (Python {pyver}) - demo complete")
print("enable btnSend")
print("enable btnNumpy")
print("disable btnCancel")
