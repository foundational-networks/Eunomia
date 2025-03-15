import matplotlib
matplotlib.use("TkAgg")  # compatibility

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

sizes = ["10", "20", "30", "40", "50", "60", "70", "80"]  
labels = ["Fat Tree - ECMP", "Jellyfish - Flow KSP", "Jellyfish - PO2 + Eunomia"]  
values = np.array([
    [0.0388, 0.0387, 0.0279],  # 10%
    [0.0542, 0.0551, 0.0366],  # 20%
    [0.0691, 0.072, 0.0446],  # 30%
    [0.0977, 0.1108, 0.0585],  # 40%
    [0.1433, 0.162, 0.0779],  # 50%
    [0.2205, 3.4744, 0.1243],  # 60%
    [0.252, 4.0092, 0.1786],  # 70%
    [0.2689, 4.2768, 0.2312]   # 80%
])

custom_styles = {
    "Fat Tree - ECMP": ("#1f77b4", "o"),  
    "Jellyfish - Flow KSP": ("red", "s"), 
    "Jellyfish - PO2 + Eunomia": ("#04bd98", "^")  
}
plt.figure(figsize=(6, 4))

for i, label in enumerate(labels):
    color, marker = custom_styles[label]
    plt.plot(sizes, values[:, i], marker=marker, markersize=10, linestyle='-', color=color, label=label, linewidth=3, zorder=2)

# Apply log scale 
plt.yscale("log")

# Add reference lines 
yticks = [0.01, 0.1, 1, 10]
plt.yticks(yticks, [str(y) for y in yticks], fontsize=14)
plt.xticks(fontsize=14)

for y_ref in yticks:
    plt.axhline(y=y_ref, color="lightgrey", linestyle="-", linewidth=1.5, zorder=1)

# format y-axis labels removes trailing .0
def format_ytick(y, _):
    if y == int(y):  
        return str(int(y))
    return str(float(f"{y:.3f}"))  

# Apply custom y-axis formatting
plt.gca().yaxis.set_major_formatter(mticker.FuncFormatter(format_ytick))

# Formatting
plt.xlabel("Network Load (%)", fontsize=18, labelpad=5)
plt.ylabel("Avg FCT (log)", fontsize=18, labelpad=-5) 
#plt.title("TBD", fontsize=16)
legend_order = ["Jellyfish - PO2 + Eunomia", "Fat Tree - ECMP", "Jellyfish - Flow KSP"]
handles, labels = plt.gca().get_legend_handles_labels()
ordered_handles = [handles[labels.index(label)] for label in legend_order]
plt.legend(
    ordered_handles, legend_order,
    loc="upper left", fontsize=18, ncol=1, frameon=False,
    handletextpad=0.3, borderpad=-0.2, labelspacing=0.3, columnspacing=0.5
)

# Ensure layout remains intact
plt.tight_layout(pad=2.0)

# Save the figure
plt.savefig("avg_fct_topologies_evaluation.png", dpi=300, bbox_inches='tight')
plt.savefig("avg_fct_topologies_evaluation.eps", format="eps", dpi=300, bbox_inches='tight')
plt.savefig("avg_fct_topologies_evaluation.svg", format="svg", dpi=300, bbox_inches='tight')

# Show the plot
#plt.show()
