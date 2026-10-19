# bash-p10k

**Powerlevel10k for bash.** The famous zsh theme's look and its interactive `p10k configure` wizard, rebuilt in pure bash: one file, no Starship, no oh-my-posh, no dependencies.

<!-- Add a screenshot here: ![screenshot](screenshot.png) -->

## Features

- **The real wizard.** `p10k configure` asks the same questions as the original (style, separators, heads, tails, frame, spacing, icons…) and shows a live preview of every option. Every question explains what it changes, and you can go back with `b`.
- **Four styles:** Lean, Classic, Rainbow and Pure.
- **Matches your terminal.** The wizard reads your terminal's background and color scheme, so backgrounds, frames and the smooth "blurred" fades blend in. You can also pick Tokyo Night, Catppuccin or the original p10k colors.
- **Right-hand prompt**, two-line layout with frames, a dotted or solid connection line, and a transient prompt (old prompts shrink to `❯ command`).
- **21 elements** you can put on the left or right, or turn off: OS logo, folder, git status, exit code, command duration, background jobs, Python venv, toolbox/distrobox, Nix shell, Python, Node.js, Go and Rust versions, AWS profile, RAM, CPU load, disk usage, battery, nested shell level, time, user@host.
- **Git status like p10k:** `main ⇣1⇡2 *1 merge ~1 +2 !3 ?4`, with the color changing when there are uncommitted changes.
- **Your own segments** with a few lines of bash.
- **Fast.** Everything is plain bash, apart from a single `git status` call inside repositories.

## Install

```bash
curl -fsSLo p10k.bash https://raw.githubusercontent.com/NerixGO/p10k/main/p10k.bash && bash p10k.bash
```

The wizard starts right away. When you finish it:

- copies itself to `~/.local/share/bash-p10k/`
- saves your settings to `~/.p10k.bash`
- with your permission, adds one line to `~/.bashrc` and turns off old prompt tools there (oh-my-posh, starship…). A backup of `~/.bashrc` is made first.

Then open a new terminal or run `exec bash`.

> `curl … | bash` does not work, because the wizard needs your keyboard. Download the file first, as shown above.

### Requirements

- **bash 4.4 or newer.** On macOS, run `brew install bash`, because the built-in bash is 3.2.
- **A Nerd Font** for icons and arrows, for example [MesloLGS NF](https://github.com/romkatv/powerlevel10k#meslo-nerd-font-patched-for-powerlevel10k) or JetBrainsMono Nerd Font, selected in your terminal's settings. Without one, the wizard offers a no-icon or plain ASCII look.
- **git**, for the git segment only.

## Commands

| Command          | What it does                                                    |
|------------------|-----------------------------------------------------------------|
| `p10k configure` | Run the wizard again                                            |
| `p10k reload`    | Apply changes after editing `~/.p10k.bash` by hand              |
| `p10k doctor`    | Explain why the prompt isn't showing or looks wrong             |

## Customizing

`~/.p10k.bash` is a commented config file. You can:

- reorder elements with `P10K_LEFT_SEGMENTS` / `P10K_RIGHT_SEGMENTS`
- change any color with `P10K_COLOR[...]`
- tweak every option from the wizard

Run `p10k reload` afterwards.

### Custom segments

Write a function that sets `REPLY` (the text) and optionally `REPLY_ICON`, then add it to a segment list:

```bash
p10k_custom_weather() { REPLY='22°C'; REPLY_ICON='☀'; }
P10K_RIGHT_SEGMENTS+=(custom_weather)
P10K_COLOR[custom_weather_bg]='#f9e2af'   # Rainbow style
P10K_COLOR[custom_weather_fg]='#1e1e2e'
P10K_COLOR[custom_weather_lc]='#f9e2af'   # Lean / Classic
```

Return 1 from the function to hide the segment.

## Troubleshooting

- **The old prompt comes back, or there are stray lines.** Run `p10k doctor`. It shows which other prompt code still runs (and in which file), so you can comment that line out.
- **Squares or question marks instead of icons.** Your terminal isn't using a Nerd Font. Install one, select it in the terminal, and run `p10k configure`.
- **kitty:** if the prompt misbehaves, set `shell_integration no-prompt-mark` in `kitty.conf`.
- **Fedora: typos take seconds to fail.** That delay is Fedora's command-not-found helper searching the repositories, not this prompt. To remove it: `sudo dnf remove PackageKit-command-not-found`.

## Uninstall

```bash
sed -i '/# >>> bash-p10k >>>/,/# <<< bash-p10k <<</d' ~/.bashrc
rm -rf ~/.local/share/bash-p10k ~/.p10k.bash
exec bash
```

The prompt lines it disabled in `~/.bashrc` start with `# [disabled by bash-p10k]`. Remove that prefix to restore them, or restore the backup `~/.bashrc.bak.p10k-*`.

## Credits

Inspired by [Powerlevel10k](https://github.com/romkatv/powerlevel10k) by Roman Perepelitsa. This is an independent re-implementation for bash, not affiliated with the original project.

## License

[MIT](LICENSE)
