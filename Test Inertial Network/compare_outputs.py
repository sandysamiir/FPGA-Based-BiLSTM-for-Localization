import numpy as np

"""
# Read xyz_positions.txt (reference, space-separated)
xyz_ref = []
with open('xyz_positions_difficult.txt', 'r') as f:
    for i, line in enumerate(f):
        if i >= 100:
            break
        vals = [float(x) for x in line.strip().split()]
        xyz_ref.append(vals)
xyz_ref = np.array(xyz_ref)  # shape: (N, 3)

"""
# Read test_outputs_easy.txt (model output, comma-separated)
xyz_ref = []
with open('test_outputs_difficult.txt', 'r') as f:
    for i, line in enumerate(f):
        if i >= 100:
            break
        vals = [float(x) for x in line.strip().split(',')]
        xyz_ref.append(vals)
xyz_ref = np.array(xyz_ref) # shape: (N, 3) 


# Read test_labels_easy.txt (model output, comma-separated), only first 50 lines
xyz_model = []
with open('test_labels_difficult.txt', 'r') as f:
    for i, line in enumerate(f):
        if i >= 100:
            break
        vals = [float(x) for x in line.strip().split(',')]
        xyz_model.append(vals)
xyz_model = np.array(xyz_model)  # shape: (N, 3)

# Compute absolute differences
diff = np.abs(xyz_ref - xyz_model)

# Print difference for each line
for i, d in enumerate(diff):
    print(f"Line {i+1}: ΔX={d[0]:.6f}, ΔY={d[1]:.6f}, ΔZ={d[2]:.6f}")

# Print max difference summary
max_diff = np.max(diff, axis=0)
print(f"\nMax difference in X: {max_diff[0]:.6f}")
print(f"Max difference in Y: {max_diff[1]:.6f}")
print(f"Max difference in Z: {max_diff[2]:.6f}")

# Compute RMSE for each position
rmse = np.sqrt(np.mean((xyz_ref - xyz_model) ** 2, axis=0))
print(f"\nRMSE X: {rmse[0]:.6f}")
print(f"RMSE Y: {rmse[1]:.6f}")
print(f"RMSE Z: {rmse[2]:.6f}")

# Compute overall RMSE (average of the 3 RMSEs)
overall_rmse = np.mean(rmse)
print(f"\nOverall average RMSE: {overall_rmse:.6f}")