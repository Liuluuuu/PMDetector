import matplotlib.pyplot as plt
import numpy as np

# Set a font style that resembles the original image (e.g., a serif font)
plt.rcParams['font.family'] = 'serif'
plt.rcParams['font.serif'] = ['Times New Roman', 'DejaVu Serif'] # Use Times New Roman or a default serif font
plt.rcParams['mathtext.fontset'] = 'dejavuserif'

# 1. Data extracted from the chart
categories = ['PMDetector-NoFP', 'PMDetector-NoAS', 'PMDetector-NoLLM', 'PMDetector-NoSC', 'PMDetector']
labels = ['Precison', 'Recall', 'F1-Score']

# Estimated values from the bars
gpt4_data =    [0.4, 0.68, 0.4, 0.83, 0.9]
gpt35_data =   [0.85, 0.59, 0.73, 0.88, 0.88]
# Note: The bar for GPT-o1 in the 'FR' category appears to be zero or missing.
gpto1_data =   [0.54, 0.63, 0.52, 0.86, 0.9]

# 2. Chart setup
x = np.arange(len(categories))  # the label locations
width = 0.25  # the width of the bars
n_groups = len(labels)

fig, ax = plt.subplots(figsize=(12, 7))

# Define colors to match the shades of blue in the original chart
colors = ['#4d7aa7', '#8cb4d8', '#c4d9ea']

# 3. Plotting the bars
# We iterate through the models to plot their bars side-by-side
all_data = [gpt4_data, gpt35_data, gpto1_data]
for i, model_data in enumerate(all_data):
    # Calculate the offset for each bar in a group to center them over the tick
    offset = width * (i - (n_groups - 1) / 2)
    ax.bar(x + offset, model_data, width, label=labels[i], color=colors[i], edgecolor='black')

# 4. Customizing the plot to match the style of the original image
# Y-axis customization
# ax.set_ylabel('Repair Rate(%)', fontsize=16, weight='bold')
ax.set_ylim(0, 1.1) # Set y-limit to give some space at the top
ax.set_yticks(np.arange(0, 1.1, 0.1))
ax.tick_params(axis='y', labelsize=14)

# X-axis customization
ax.set_xticks(x)
ax.set_xticklabels(categories, rotation=-5, fontsize=14)
ax.tick_params(axis='x', which='both', bottom=False) # Hide x-axis ticks

# Legend customization
ax.legend(
    ncol=3,
    loc='upper center',
    bbox_to_anchor=(0.5, 1.12),
    frameon=True,
    edgecolor='black',
    fontsize=14
)

# Spines customization to remove top and right borders
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)

# Figure caption at the bottom
# fig.suptitle('Fig. 5. Compile Rate for o1', y=0.02, fontsize=16)

# Adjust layout to prevent labels from overlapping and make space for the caption
plt.tight_layout(rect=[0, 0.05, 1, 0.93])

# 5. Display the plot
plt.show()