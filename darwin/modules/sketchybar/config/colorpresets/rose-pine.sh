#!/usr/bin/env sh

# Color Palette -- Rosé Pine

# Base colors
export BASE=0xff191724
export SURFACE=0xff1f1d2e
export OVERLAY=0xff26233a
export MUTED=0xff6e6a86
export SUBTLE=0xff908caa
export TEXT=0xffe0def4

# Accent colors
export ROSE=0xffebbcba
export GOLD=0xfff6c177
export LOVE=0xffeb6f92
export PINE=0xff31748f
export FOAM=0xff9ccfd8
export IRIS=0xffc4a7e7

# Map to existing variables
export BLACK=$BASE
export WHITE=$TEXT
export RED=$LOVE
export GREEN=$PINE
export BLUE=$FOAM
export YELLOW=$GOLD
export MAGENTA=$IRIS
export PINK=$ROSE
export GREY=$MUTED
export SKY=$FOAM

export TRANSPARENT=0x00000000

# General bar colors
export BAR_COLOR=$TRANSPARENT # Transparent bar
export ITEM_COLOR=$SURFACE
export ICON_COLOR=$WHITE  # Color of all icons
export LABEL_COLOR=$WHITE # Color of all labels
export ALT_LABEL_COLOR=$SUBTLE

export SPACE_BACKGROUND=$SURFACE
export SPACE_BACKGROUND2=$OVERLAY
export SPACE_SELECTED=$IRIS
export SPACE_DESELECTED=$MUTED
export OPEN_APPS_BACKGROUND=$SURFACE
export CALENDAR_BACKGROUND=$SURFACE

export POPUP_BACKGROUND_COLOR=$OVERLAY
export POPUP_BORDER_COLOR=$IRIS

export SHADOW_COLOR=$BLACK
