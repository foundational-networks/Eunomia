import matplotlib
import matplotlib.ticker as mticker

matplotlib.use("TkAgg")  # compatibility

import numpy as np
import matplotlib.pyplot as plt

# True to show tail FCT and False to show avg FCT
tail = True

load_percentages = ["40", "50", "60", "70", "80"]  # X-axis
labels = ["Conweave", "ECMP", "PO2 + LEFT", "PO2 + Eunomia"]  # Methods

if tail:
    values = np.array([
        [0.4667, 0.5768, 0.1895, 0.1895],  # 40%
        [0.5369, 0.7129, 0.2853, 0.2716],  # 50%
        [0.6107, 0.9679, 0.4331, 0.3949],  # 60%
        [0.7707, 1.4609, 0.573, 0.4837],   # 70%
        [1.1139, 2.3767, 0.9235, 0.5603]   # 80%
    ])
else:
    values = np.array([
        [0.0206, 0.0264, 0.0160, 0.0160],  # 40%
        [0.0241, 0.0355, 0.0182, 0.0178],  # 50%
        [0.0279, 0.0500, 0.0213, 0.0196],  # 60%
        [0.0359, 0.0862, 0.0286, 0.0229],  # 70%
        [0.0523, 0.1478, 0.04005, 0.0277]  # 80%
    ])

custom_colors = {
    "Conweave": "#ff7f0e",      
    "ECMP": "#1f77b4",          
    "PO2 + LEFT": "#ff00d9",    
    "PO2 + Eunomia": "#04bd98", 
}

hatch_patterns = {
    "Conweave": 'x',
    "ECMP": '',
    "PO2 + LEFT": 'o',
    "PO2 + Eunomia": '-'
}

x = np.arange(len(load_percentages))  
width = 0.2  

# bar plot
fig, ax = plt.subplots(figsize=(6, 4))

for i, label in enumerate(labels):
    ax.bar(
        x + i * width - (len(labels) * width / 2),
        values[:, i],
        width,
        label=label,
        color=custom_colors[label],
        hatch=hatch_patterns[label]
    )

# Set log
ax.set_yscale("log")

# horizontal line
ax.axhline(y=1 if tail else 0.1, color='lightgrey', linestyle='-', linewidth=1.5)

# Formatting
ax.set_xticks(x)
ax.set_xticklabels(load_percentages, fontsize=18)
ax.set_xlabel("Network Load (%)", fontsize=18)  # Removed labelpad
ax.set_ylabel("Avg FCT (log)" if not tail else "Tail FCT (log)", fontsize=18, labelpad=0)
plt.yticks(fontsize=14)

# Get original legend handles & labels
handles, legend_labels = ax.get_legend_handles_labels()

# Desired legend order
desired_order = ["Conweave", "PO2 + LEFT", "PO2 + Eunomia", "ECMP"]
reordered_handles = [handles[legend_labels.index(label)] for label in desired_order]

# reordered legend
ax.legend(
    reordered_handles, desired_order,
    loc="upper left", fontsize=18, ncol=1, frameon=False,
    handletextpad=0.1, borderpad=0.1, labelspacing=0.1, columnspacing=0.5
)

# Prevent layout shifting
plt.xticks(rotation=0)
plt.gca().yaxis.set_major_formatter(mticker.FuncFormatter(lambda y, _: f"{y:.1f}" if y < 1 else f"{int(y)} "))
fig.tight_layout(pad=2.0)

# Save figure
file_name = "tail_fct_acrossLB_eval.png" if tail else "avg_fct_acrossLB_eval.png"
plt.savefig(file_name, dpi=300, bbox_inches='tight')
file_name = "tail_fct_acrossLB_eval.eps" if tail else "avg_fct_acrossLB_eval.eps"
plt.savefig(file_name, format="eps", dpi=300, bbox_inches='tight')
file_name = "tail_fct_acrossLB_eval.svg" if tail else "avg_fct_acrossLB_eval.svg"
plt.savefig(file_name, format="svg", dpi=300, bbox_inches='tight')

# Show the plot
#plt.show()
