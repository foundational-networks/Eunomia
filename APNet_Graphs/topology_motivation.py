import matplotlib
matplotlib.use("TkAgg")  # compatibility

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

sizes = ["5B", "25B", "125B", "630B", "3KB", "16KB", "79KB", "398KB", "2MB", "10MB"]  
labels = ["Fat Tree - ECMP", "Jellyfish - Flow KSP"] 
values = np.array([
    [0.056, 1.788],  # 5B
    [0.052, 2.308],  # 25B
    [0.054, 2.165],  # 125B
    [0.055, 2.262],  # 630B
    [0.055, 2.808],  # 3KB
    [0.058, 6.629],  # 16KB
    [0.085, 14.395],  # 79KB
    [0.224, 17.7],  # 398KB
    [2.344, 9.793],  # 2MB
    [18.588, 10.44]   # 10MB
])

custom_styles = {
    "Fat Tree - ECMP": ("#1f77b4", "o"),  
    "Jellyfish - Flow KSP": ("red", "s")  
}

plt.figure(figsize=(6, 4))

for i, label in enumerate(labels):
    color, marker = custom_styles[label]
    plt.plot(sizes, values[:, i], marker=marker, markersize=10, linestyle='-', color=color, label=label, linewidth=3.5, zorder=2)

# Apply log 
plt.yscale("log")

# Add reference lines 
yticks = [0.01, 0.1, 1, 10, 100]
plt.yticks(yticks, [str(y) for y in yticks], fontsize=14)
plt.xticks(rotation=-45, ha="center", fontsize=14)

for y_ref in yticks:
    plt.axhline(y=y_ref, color="lightgrey", linestyle="-", linewidth=1.5, zorder=1)

def format_ytick(y, _):
    if y == int(y):  
        return str(int(y))
    return str(float(f"{y:.3f}")) 

plt.gca().yaxis.set_major_formatter(mticker.FuncFormatter(format_ytick))

# Formatting
plt.xlabel("Flow Size", fontsize=18, labelpad=-7)
plt.ylabel("Avg FCT (log)", fontsize=18, labelpad=-5)  
#plt.title("TBD", fontsize=16)

plt.legend(
    loc="upper left", fontsize=17, ncol=1, frameon=False,
    handletextpad=0.3, borderpad=-0.2, labelspacing=0.3, columnspacing=0.5
)

# Ensure layout remains intact
plt.tight_layout(pad=2.0)

# Save the figure
plt.savefig("avg_fct_topologies_motivation.png", dpi=300, bbox_inches='tight')
plt.savefig("avg_fct_topologies_motivation.eps", format="eps", dpi=300, bbox_inches='tight')
plt.savefig("avg_fct_topologies_motivation.svg", format="svg", dpi=300, bbox_inches='tight')

# Show the plot
#plt.show()
