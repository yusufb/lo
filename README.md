# lo - macOS Window Layout Manager

Minimal macOS CLI tool to arrange windows into grid rows.

## Install

```sh
make install
```

Installs `lo` to `~/.local/bin/lo`. Grant Accessibility permission to your terminal app in **System Settings > Privacy & Security > Accessibility**.

## Usage

Each argument is a row; its value is the number of windows in that row.
A single slash-separated argument arranges one row with relative widths.

```sh
lo        # 2 windows side by side (default)
lo 2      # 2 windows side by side
lo 3      # 3 windows side by side
lo 2/3    # 2 windows side by side with 2:3 widths
lo 1/1/3  # 3 windows side by side with 1:1:3 widths
lo 2 2    # 2x2 grid
lo 1 1    # 2 windows stacked
lo 1 2    # 1 full-width window on top, 2 below
```