import matplotlib
matplotlib.use("TkAgg")  # compatibility

import numpy as np
import matplotlib.pyplot as plt

network_load = np.array([10, 20, 30, 40, 50])  

# Average QCT values (Left Y-axis)
avg_qct = {
    "IRN": np.array([0.185, 0.204, 0.227, 0.296, 0.39]),
    "DIBS+IRN": np.array([0.183, 0.193, 0.205, 0.426, 10.446]),
    "DIBS+Eunomia": np.array([0.183, 0.191, 0.202, 0.239, 0.366])
}

# Tail QCT values (Right Y-axis)
tail_qct = {
    "IRN": np.array([0.343, 0.769, 0.886, 2.505, 2.866]),
    "DIBS+IRN": np.array([0.342, 0.425, 0.546, 2.848, 27.816]),
    "DIBS+Eunomia": np.array([0.342, 0.41, 0.512, 0.911, 1.503])
}

# Colors and markers 
styles = {
    "IRN": {"color": "purple", "marker": "s"},  
    "DIBS+IRN": {"color": "#ff7f0e", "marker": "^"},  
    "DIBS+Eunomia": {"color": "#04bd98", "marker": "o"}  
}

# Create figure and primary Y-axis (Avg QCT)
fig, ax1 = plt.subplots(figsize=(6, 4))

# Store line objects for legend reordering
lines = {}

# Plot the Average QCT (solid lines, left Y-axis)
for key, data in avg_qct.items():
    line, = ax1.plot(network_load, data, linestyle='-', marker=styles[key]["marker"],
                     markersize=8, color=styles[key]["color"], linewidth=3, label=f"{key} (Avg)")
    lines[f"{key} (Avg)"] = line  

# Create secondary Y-axis (Tail QCT)
ax2 = ax1.twinx()

# Plot the Tail QCT (dotted lines, right Y-axis)
for key, data in tail_qct.items():
    line, = ax2.plot(network_load, data, linestyle=':', marker=styles[key]["marker"],
                     markersize=8, color=styles[key]["color"], linewidth=3, label=f"{key} (Tail)")
    lines[f"{key} (Tail)"] = line  # Store for legend

# Add grey reference lines at 10^1 and 10^0 on the left Y-axis
ax1.axhline(y=10, color='grey', linestyle='-', linewidth=1)  # Line at 10^1
ax1.axhline(y=1, color='grey', linestyle='-', linewidth=1)   # Line at 10^0

# Formatting
ax1.set_xlabel("Network Load (%)", fontsize=18)
ax1.set_ylabel("Avg QCT (ms)", fontsize=18, labelpad=10, color="black")  # Left Y-axis
ax2.set_ylabel("Tail QCT (ms)", fontsize=18, labelpad=10, color="black")  # Right Y-axis

# Ensure different y-scales are visible
ax1.set_yscale("log")  
ax2.set_yscale("log") 

# Define desired legend order
ordered_legend_labels = [
    "DIBS+Eunomia (Tail)",  
    "DIBS+Eunomia (Avg)",   
    "DIBS+IRN (Tail)",      
    "DIBS+IRN (Avg)",       
    "IRN (Tail)",           
    "IRN (Avg)"             
]

# Retrieve handles in the correct order
ordered_handles = [lines[label] for label in ordered_legend_labels]

# Combine legends for both Y-axes
ax1.legend(ordered_handles, ordered_legend_labels,
           loc="upper left", fontsize=15, frameon=False, ncol=1)

# Ensure layout remains intact while resizing
plt.xticks(fontsize=14)
plt.yticks(fontsize=14)
fig.tight_layout(pad=2.0)
ax1.tick_params(axis='x', labelsize=14)  # X-axis tick labels
ax1.tick_params(axis='y', labelsize=14)  # Left Y-axis tick labels
ax2.tick_params(axis='y', labelsize=14)  # Right Y-axis tick labels
plt.savefig("incast_eval.png", dpi=300, bbox_inches='tight')
plt.savefig("incast_eval.eps", format="eps", dpi=300, bbox_inches='tight')
plt.savefig("incast_eval.svg", format="svg", dpi=300, bbox_inches='tight')

# Show the plot
#plt.show()
