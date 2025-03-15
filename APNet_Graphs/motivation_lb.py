import matplotlib
import matplotlib.ticker as mticker

matplotlib.use("TkAgg")  # compatibility

import numpy as np
import matplotlib.pyplot as plt

categories = ["<=100KB", "<=2MB"]
labels = [
    "PO2 Ideal OL",
    "Conweave",
    "MP-RDMA",
    "PO2 + LEFT",  
    "ECMP",
    "PO2 + IRN",   
    "PO2"
]
values = np.array([
    [0.015, 0.025, 0.052, 0.021, 0.062, 0.664, 0.516],
    [0.301, 0.623, 0.397, 0.43, 1.953, 7.59, 14.822]
])

custom_colors = {
    "PO2 Ideal OL": "#9467bd",  
    "Conweave": "#ff7f0e",      
    "MP-RDMA": "#7f7f7f",       
    "PO2 + LEFT": "#ff00d9",    
    "ECMP": "#1f77b4",          
    "PO2 + IRN": "#ff0000",     
    "PO2": "green"           
}

hatch_patterns = ['\\', 'x', '|', 'o', '', '/', '.']

# Bar width and x locations
x = np.arange(len(categories))  
width = 0.1  

fig, ax = plt.subplots(figsize=(6, 4)) 
bars = []  
for i, (label, color) in enumerate(custom_colors.items()):
    bar = ax.bar(
        x + i * width - (len(labels) * width / 2),
        values[:, i],
        width,
        label=label,
        color=color,
        hatch=hatch_patterns[i % len(hatch_patterns)]
    )
    bars.append((label, bar[0]))  

# Set log
ax.set_yscale("log")

# Add horizontal line
ax.axhline(y=1, color='lightgrey', linestyle='-', linewidth=1.5)

# Formatting
ax.set_xticks(x)
ax.set_xticklabels(categories, fontsize=18)
ax.set_xlabel("Flow Size", fontsize=18)
ax.set_ylabel("Avg FCT (log)", fontsize=18)
plt.yticks(fontsize=14)

ordered_legend_labels = [
    "PO2 Ideal OL", "PO2 + LEFT",
    "Conweave", "MP-RDMA", 
    "PO2 + IRN", "ECMP",
    "PO2"
]

handles_dict = {label: handle for label, handle in bars}
ordered_handles = [handles_dict[label] for label in ordered_legend_labels] 

ax.legend(
    ordered_handles, ordered_legend_labels,
    loc="upper left", fontsize=18, ncol=2, frameon=False,
    handletextpad=0.1,
    borderpad=0.1,
    labelspacing=0.1,
    columnspacing=0.5
)

# Prevent layout shifting issues
plt.xticks(rotation=0)
plt.gca().yaxis.set_major_formatter(mticker.FuncFormatter(lambda y, _: f"{y:.1f}" if y < 1 else f"{int(y)} "))
fig.tight_layout(pad=2.0)
plt.savefig("avg_fct_acrossLB_motivation.png", dpi=300, bbox_inches='tight')
plt.savefig("avg_fct_acrossLB_motivation.eps", format="eps", dpi=300, bbox_inches='tight')
plt.savefig("avg_fct_acrossLB_motivation.svg", format="svg", dpi=300, bbox_inches='tight')

# Show the plot
#plt.show()
