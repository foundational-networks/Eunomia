import matplotlib
import matplotlib.ticker as mticker
matplotlib.use("TkAgg")  # compatibility

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

links_failed = ["1%", "2%", "4%", "6%", "8%", "10%"]  
labels = ["ECMP", "PO2 + Eunomia"]  
values = np.array([
    [1.963, 1.208],  # 1%
    [2.079, 1.212],  # 2%
    [2.318, 1.218],  # 4%
    [2.472, 1.223],  # 6%
    [2.798, 1.235],  # 8%
    [4.204, 1.254]   # 10%
])

custom_styles = {
    "ECMP": ("#1f77b4", "o"),  
    "PO2 + Eunomia": ("#04bd98", "^")  
}

plt.figure(figsize=(6, 4))

for i, label in enumerate(labels):
    color, marker = custom_styles[label]
    plt.plot(links_failed, values[:, i], marker=marker, markersize=10, linestyle='-', color=color, label=label, linewidth=4, zorder=2)

plt.yscale("log")

yticks = [1, 10]  

# Apply only these ticks and remove all others
plt.yticks(yticks, fontsize=14)
plt.gca().yaxis.set_major_locator(mticker.FixedLocator(yticks))  # Force only these ticks
plt.xticks(fontsize=14)

def format_ytick(y, _):
    return f"{int(y)}"  # Convert to integer (removes decimals and scientific notation)

plt.gca().yaxis.set_major_formatter(mticker.FuncFormatter(format_ytick))
plt.gca().yaxis.set_minor_formatter(mticker.NullFormatter())  
# Formatting
plt.xlabel("Links Failed", fontsize=18, labelpad=10)
plt.ylabel("Avg FCT Slowdown (log)", fontsize=18, labelpad=0)  
#plt.title("TBD", fontsize=16)

legend_order = ["PO2 + Eunomia", "ECMP"]
handles, labels = plt.gca().get_legend_handles_labels()
ordered_handles = [handles[labels.index(label)] for label in legend_order]

plt.legend(
    ordered_handles, legend_order,
    loc="upper left", fontsize=18, ncol=1, frameon=False,
    handletextpad=0.3, borderpad=0.2, labelspacing=0.3, columnspacing=0.5
)

# Ensure layout remains intact
plt.tight_layout(pad=2.0)

# Save the figure
plt.savefig("avg_fct_failure_evaluation.png", dpi=300, bbox_inches='tight')
plt.savefig("avg_fct_failure_evaluation.eps", format="eps", dpi=300, bbox_inches='tight')
plt.savefig("avg_fct_failure_evaluation.svg", format="svg", dpi=300, bbox_inches='tight')

# Show the plot
#plt.show()
