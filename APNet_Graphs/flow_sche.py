import matplotlib
import matplotlib.ticker as mticker

matplotlib.use("TkAgg")  # compatibility

import numpy as np
import matplotlib.pyplot as plt

def format_ytick(y, _):
    if y == int(y):  
        return str(int(y))
    return str(float(f"{y:.3f}"))

# Data
sizes = ["4B", "18B", "77B", "331B", "1KB", "6KB", "26KB", "110KB", "469KB", "2MB"]
labels = [
    "ECMP - FIFO",
    "ECMP + Eunomia - SRPT",
    "PO2 + Eunomia - FIFO",
    "PO2 + Eunomia - SRPT"
]
values = np.array([
    [0.058, 0.01, 0.012, 0.008],
    [0.053, 0.01, 0.012, 0.008],
    [0.055, 0.01, 0.012, 0.008],
    [0.056, 0.01, 0.012, 0.008],
    [0.056, 0.011, 0.012, 0.008],
    [0.058, 0.018, 0.013, 0.009],
    [0.062, 0.04, 0.014, 0.01],
    [0.094, 0.285, 0.022, 0.017],
    [0.276, 0.813, 0.057, 0.066],
    [3.996, 3.736, 0.593, 0.61]
])

custom_styles = {
    "ECMP - FIFO": ("#1f77b4", "o"),         
    "ECMP + Eunomia - SRPT": ("red", "s"),  
    "PO2 + Eunomia - FIFO": ("#04bd98", "^"),   
    "PO2 + Eunomia - SRPT": ("purple", "*") 
}

plt.figure(figsize=(6, 4))

lines = {}

for i, label in enumerate(labels):
    color, marker = custom_styles[label]
    line, = plt.plot(sizes, values[:, i], marker=marker, markersize=8, linestyle='-', color=color, 
                     label=label, linewidth=2.5, zorder=2)
    lines[label] = line  

plt.yscale("log")
yticks = [0.005, 0.05, 0.5, 5]

# Add reference lines at Y = 0.05, 0.5, and 5
for y_ref in yticks:
    plt.axhline(y=y_ref, color="lightgrey", linestyle="-", linewidth=1.5, zorder=1)

plt.yticks(yticks, [str(y) for y in yticks], fontsize=14)
plt.xticks(rotation=-45, ha="center", fontsize=14)
# Formatting
plt.xlabel("Flow Size", fontsize=16, labelpad=-7)
plt.ylabel("Avg FCT (log)", fontsize=16, labelpad=-7)

# Reorder legend:
ordered_legend_labels = [
    "ECMP + Eunomia - SRPT",  
    "PO2 + Eunomia - SRPT",   
    "PO2 + Eunomia - FIFO",            
    "ECMP - FIFO"                      
]
ordered_handles = [lines[label] for label in ordered_legend_labels]

plt.legend(
    ordered_handles, ordered_legend_labels,
    loc="upper left", fontsize=16, ncol=1, frameon=False,
    handletextpad=0.3, borderpad=0.2, labelspacing=0.3, columnspacing=0.5
)

# Apply formatted Y-axis tick labels
plt.gca().yaxis.set_major_formatter(mticker.FuncFormatter(format_ytick))

# Ensure layout remains intact
plt.tight_layout(pad=2.0)

# Save the figure
plt.savefig("avg_fct_FlowScheduling.png", dpi=300, bbox_inches='tight')
plt.savefig("avg_fct_FlowScheduling.eps", format="eps", dpi=300, bbox_inches='tight')
plt.savefig("avg_fct_FlowScheduling.svg", format="svg", dpi=300, bbox_inches='tight')

# Show the plot
#plt.show()
