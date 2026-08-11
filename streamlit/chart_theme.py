"""
Hospital 360 — Chart Theme Module
Shared Plotly styling for all dashboard pages.
Provides a dark theme with gradients, glow effects, and polished styling.
"""

import plotly.graph_objects as go
import plotly.io as pio

# ---------------------------------------------------------------------------
# Color palette
# ---------------------------------------------------------------------------
COLORS = {
    "primary": "#29B5E8",       # Snowflake blue
    "secondary": "#1DB9C3",     # Teal
    "accent": "#7C3AED",        # Purple
    "danger": "#EF4444",        # Red
    "warning": "#F59E0B",       # Amber
    "success": "#10B981",       # Emerald
    "info": "#3B82F6",          # Blue
    "muted": "#6B7280",         # Gray
}

# Curated sequence for multi-series charts (high contrast on black)
COLOR_SEQ = [
    "#29B5E8",  # Snowflake blue
    "#10B981",  # Emerald
    "#F59E0B",  # Amber
    "#EF4444",  # Red
    "#7C3AED",  # Purple
    "#EC4899",  # Pink
    "#1DB9C3",  # Teal
    "#F97316",  # Orange
]

# Gradient-friendly sequences
BLUE_GRADIENT = ["#0D4F6B", "#127D9E", "#1AA3CC", "#29B5E8", "#5EC8EE", "#93DBF4"]
RED_GRADIENT = ["#7F1D1D", "#B91C1C", "#DC2626", "#EF4444", "#F87171", "#FCA5A5"]

# ---------------------------------------------------------------------------
# Custom Plotly template
# ---------------------------------------------------------------------------
_template = go.layout.Template()

_template.layout = go.Layout(
    # Backgrounds
    paper_bgcolor="#000000",
    plot_bgcolor="#000000",
    # Fonts
    font=dict(
        family="Inter, -apple-system, BlinkMacSystemFont, sans-serif",
        size=13,
        color="#FFFFFF",
    ),
    title=dict(
        font=dict(size=16, color="#FFFFFF"),
        x=0.0,
        xanchor="left",
    ),
    # Axes
    xaxis=dict(
        gridcolor="rgba(255,255,255,0.06)",
        linecolor="rgba(255,255,255,0.15)",
        zerolinecolor="rgba(255,255,255,0.08)",
        tickfont=dict(color="#A0A0A0", size=11),
        title_font=dict(color="#C0C0C0", size=12),
    ),
    yaxis=dict(
        gridcolor="rgba(255,255,255,0.06)",
        linecolor="rgba(255,255,255,0.15)",
        zerolinecolor="rgba(255,255,255,0.08)",
        tickfont=dict(color="#A0A0A0", size=11),
        title_font=dict(color="#C0C0C0", size=12),
    ),
    # Color defaults
    colorway=COLOR_SEQ,
    # Legend
    legend=dict(
        font=dict(color="#C0C0C0", size=11),
        bgcolor="rgba(0,0,0,0)",
        bordercolor="rgba(255,255,255,0.08)",
        borderwidth=1,
    ),
    # Hover
    hoverlabel=dict(
        bgcolor="#1A1A1A",
        bordercolor="rgba(255,255,255,0.2)",
        font=dict(color="#FFFFFF", size=12),
    ),
    # Margins
    margin=dict(l=10, r=10, t=30, b=10),
)

# Bar trace defaults
_template.data.bar = [
    go.Bar(
        marker=dict(
            line=dict(width=0.5, color="rgba(255,255,255,0.1)"),
            opacity=0.92,
        ),
        textfont=dict(color="#FFFFFF", size=11),
    )
]

# Scatter / line trace defaults
_template.data.scatter = [
    go.Scatter(
        line=dict(width=2.5),
    )
]

# Register the template
pio.templates["h360_dark"] = _template
pio.templates.default = "h360_dark"


# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
def apply_style(fig, height=350, legend_below=False):
    """Apply the H360 dark theme to any Plotly figure.

    Args:
        fig: Plotly figure object.
        height: Chart height in pixels.
        legend_below: If True, place legend below the chart.
    """
    fig.update_layout(
        template="h360_dark",
        height=height,
        margin=dict(l=10, r=10, t=30, b=10),
        hovermode="x unified",
    )
    if legend_below:
        fig.update_layout(
            legend=dict(orientation="h", y=-0.18, x=0.5, xanchor="center"),
        )
    return fig


def style_bars(fig, color=None):
    """Style bar traces with gradient effect and rounded appearance.

    Args:
        fig: Plotly figure with bar traces.
        color: Optional base color. If None, uses primary blue.
    """
    base = color or COLORS["primary"]
    fig.update_traces(
        marker=dict(
            color=base,
            line=dict(width=0.8, color="rgba(255,255,255,0.15)"),
            opacity=0.9,
        ),
        selector=dict(type="bar"),
    )
    return fig


def style_bars_gradient(fig, color_col=None, colorscale=None):
    """Apply a continuous color gradient to bar traces.

    Args:
        fig: Plotly figure with bar traces.
        color_col: Column name used for color mapping (already set via px.bar color=).
        colorscale: Custom colorscale. Defaults to blue gradient.
    """
    scale = colorscale or [
        [0.0, "#0D4F6B"],
        [0.5, "#29B5E8"],
        [1.0, "#93DBF4"],
    ]
    fig.update_traces(
        marker=dict(
            colorscale=scale,
            line=dict(width=0.8, color="rgba(255,255,255,0.12)"),
            showscale=False,
        ),
        selector=dict(type="bar"),
    )
    return fig


def glow_line(fig, trace_idx=0, color=None, width=2.5, glow_width=8):
    """Add a glow effect behind a line trace.

    Inserts a wider, semi-transparent copy of the trace behind the original.

    Args:
        fig: Plotly figure.
        trace_idx: Index of the trace to add glow to.
        color: Glow color. Defaults to the trace's line color.
        width: Original line width.
        glow_width: Width of the glow line.
    """
    trace = fig.data[trace_idx]
    glow_color = color or getattr(trace.line, "color", COLORS["primary"])

    # Convert color to rgba for the glow
    if glow_color.startswith("#"):
        r = int(glow_color[1:3], 16)
        g = int(glow_color[3:5], 16)
        b = int(glow_color[5:7], 16)
        glow_rgba = f"rgba({r},{g},{b},0.2)"
    else:
        glow_rgba = glow_color.replace("rgb(", "rgba(").replace(")", ",0.2)")

    # Add the glow as a new trace behind the original
    fig.add_trace(go.Scatter(
        x=trace.x,
        y=trace.y,
        mode="lines",
        line=dict(color=glow_rgba, width=glow_width),
        showlegend=False,
        hoverinfo="skip",
    ))

    # Move the glow trace (last added) to before the original trace
    # by reordering: put glow trace at trace_idx position
    traces = list(fig.data)
    glow = traces.pop()  # remove the just-added glow from end
    traces.insert(trace_idx, glow)  # insert before the original
    fig.data = traces  # reassign as permutation of existing traces

    # Update the original trace (now shifted by 1) with crisp line
    fig.data[trace_idx + 1].line.width = width

    return fig


def style_area(fig, color=None, fill_opacity=0.15):
    """Style area chart traces with gradient fill.

    Args:
        fig: Plotly figure with scatter/area traces.
        color: Base color for the area fill.
        fill_opacity: Opacity of the fill area.
    """
    base = color or COLORS["primary"]
    if base.startswith("#"):
        r = int(base[1:3], 16)
        g = int(base[3:5], 16)
        b = int(base[5:7], 16)
        fill_rgba = f"rgba({r},{g},{b},{fill_opacity})"
    else:
        fill_rgba = base

    fig.update_traces(
        fillcolor=fill_rgba,
        line=dict(color=base, width=2.5),
        selector=dict(fill="tozeroy"),
    )
    return fig


def style_pie(fig, pull=0.03):
    """Style pie/donut charts for dark theme.

    Args:
        fig: Plotly figure with pie traces.
        pull: How much to pull slices outward (0-0.1).
    """
    fig.update_traces(
        marker=dict(
            line=dict(color="#000000", width=2),
        ),
        pull=[pull] * 20,  # enough for any number of slices
        textfont=dict(color="#FFFFFF", size=12),
        selector=dict(type="pie"),
    )
    return fig


def style_heatmap(fig):
    """Style heatmap for dark theme with better text contrast."""
    fig.update_traces(
        textfont=dict(color="#FFFFFF", size=11),
        selector=dict(type="heatmap"),
    )
    fig.update_layout(
        coloraxis=dict(
            colorbar=dict(
                tickfont=dict(color="#A0A0A0"),
                title_font=dict(color="#C0C0C0"),
            )
        )
    )
    return fig
