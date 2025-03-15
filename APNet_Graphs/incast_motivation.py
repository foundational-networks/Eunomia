import matplotlib
import matplotlib.ticker as mticker

matplotlib.use("TkAgg")  # compatibility

import numpy as np
import matplotlib.pyplot as plt

# Data from the table
categories = ["10", "20", "30", "40", "50"]  
labels = ["IRN", "DIBS+IRN", "DIBS+Ideal OL"]  
values = np.array([
    [0.343, 0.342, 0.342],  # Load 10%
    [0.769, 0.425, 0.41],  # Load 20%
    [0.886, 0.546, 0.512],  # Load 30%
    [2.505, 2.848, 0.911],  # Load 40%
    [2.866, 27.816, 1.503]   # Load 50%
])

custom_colors = {
    "IRN": "#9467bd",      
    "DIBS+IRN": "#ff7f0e",  
    "DIBS+Ideal OL": "#04bd98",  
}

hatch_patterns = ['.', '/', 'o']  
# Bar width and x locations
x = np.arange(len(categories))  
width = 0.2  

fig, ax = plt.subplots(figsize=(6, 4))  
for i, (label, color) in enumerate(custom_colors.items()):
    ax.bar(
        x + i * width - (len(labels) * width / 2),
        values[:, i],
        width,
        label=label,
        color=color, 
        hatch=hatch_patterns[i % len(hatch_patterns)]  
    )

# Set log
ax.set_yscale("log")

# Add horizontal line 
ax.axhline(y=0.1, color='lightgrey', linestyle='-', linewidth=1.5)
ax.axhline(y=1, color='lightgrey', linestyle='-', linewidth=1.5)
ax.axhline(y=10, color='lightgrey', linestyle='-', linewidth=1.5)

# Formatting
ax.set_xticks(x)
plt.yticks(fontsize=14)
plt.xticks(fontsize=14)

ax.set_xticklabels(categories, fontsize=18)

ax.set_xlabel("Network Load (%)", fontsize=18)
ax.set_ylabel("Tail QCT (log)", fontsize=18)


#ax.set_title("TBD", fontsize=16)

# Adjust legend
ax.legend(
    loc="upper left", fontsize=18, ncol=1, frameon=False,
    handletextpad=0.1,  
    borderpad=0.1,     
    labelspacing=0.1,    
    columnspacing=0.5
)


# Prevent layout shifting issues
plt.xticks(rotation=0)
plt.gca().yaxis.set_major_formatter(mticker.FuncFormatter(lambda y, _: f"{y:.1f}" if y < 1 else f"{int(y)} "))
fig.tight_layout(pad=2.0)  # Adjust
plt.savefig("qct_incast_motivation.png", dpi=300, bbox_inches='tight')  
plt.savefig("qct_incast_motivation.eps", format="eps", dpi=300, bbox_inches='tight')
plt.savefig("qct_incast_motivation.svg", format="svg", dpi=300, bbox_inches='tight')

# Show the plot
#plt.show()
