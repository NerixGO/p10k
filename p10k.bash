#!/usr/bin/env bash
# bash-p10k: Powerlevel10k for bash.
#
#   bash p10k.bash        run the configuration wizard (installs itself when you finish)
#   p10k configure        re-run the wizard from a shell where it's installed
#   p10k reload           re-read ~/.p10k.bash after editing it by hand
#
# Pure bash (needs 4.4+), no Starship / oh-my-posh. git is used for the git segment.

if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4) )); then
  echo "bash-p10k needs bash 4.4 or newer." >&2
  return 1 2>/dev/null || exit 1
fi

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then  # executed as a script: make sure glyphs decode
  case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
    *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) ;;
    *) export LC_ALL=C.UTF-8 ;;
  esac
fi

__P10K_SRC=${BASH_SOURCE[0]}
[[ $__P10K_SRC == /* ]] || __P10K_SRC=$PWD/$__P10K_SRC
__P10K_HOME=${XDG_DATA_HOME:-$HOME/.local/share}/bash-p10k
__P10K_CONFIG=${P10K_CONFIG:-$HOME/.p10k.bash}
__p10k_O=$'\001' __p10k_C=$'\002'
__p10k_demo=0 __p10k_short=0 __p10k_first=1 __p10k_ran=0 __p10k_dur=0 __p10k_ec=0
__p10k_pipe=() __p10k_jobs=0 __p10k_nlines=0 __p10k_cmd=''
__p10k_anchors=(.git .hg .svn .bzr package.json Cargo.toml go.mod pyproject.toml composer.json
                stack.yaml .python-version .node-version .tool-versions .shorten_folder_marker)

# =====================================================================================
# Colors
# =====================================================================================
# Keys: <segment>_bg/<segment>_fg are used by Rainbow, <segment>_lc by Lean/Classic/Pure.
__p10k_palette() {
  local p=${P10K_PALETTE:-original}; [[ $p == 256 ]] && p=original
  if [[ $P10K_STYLE == pure ]]; then [[ $p == snazzy ]] || p=pure
  elif [[ $p == pure || $p == snazzy ]]; then p=original; fi
  unset __C; declare -gA __C
  case $p in
    original) __C=(
      [os_bg]=7 [os_fg]=232 [os_lc]=''
      [dir_bg]=4 [dir_fg]=254 [dir_rshort]=250 [dir_ranchor]=255 [dir_lc]=31 [dir_short]=103 [dir_anchor]=39
      [vcs_rclean]=2 [vcs_rmod]=3 [vcs_runtr]=2 [vcs_rconf]=3 [vcs_fg]=0
      [vcs_clean]=76 [vcs_mod]=178 [vcs_untr]=39 [vcs_conf]=196
      [status_bg]=1 [status_fg]=3 [status_lc]=160
      [exec_bg]=3 [exec_fg]=0 [exec_lc]=101
      [jobs_bg]=0 [jobs_fg]=6 [jobs_lc]=70
      [venv_bg]=4 [venv_fg]=0 [venv_lc]=37
      [ctx_bg]=0 [ctx_fg]=3 [ctx_lc]=180 [ctx_root]=178 [ctx_rroot]=1
      [time_bg]=7 [time_fg]=0 [time_lc]=66
      [ok]=76 [err]=196
      [cbg1]=238 [cbg2]=237 [cbg3]=236 [cbg4]=235 [frm1]=244 [frm2]=242 [frm3]=240 [frm4]=238 ) ;;
    terminal) __C=(  # only the 16 ANSI colors, so it follows your terminal's color scheme
      [os_bg]=7 [os_fg]=0 [os_lc]=''
      [dir_bg]=4 [dir_fg]=0 [dir_rshort]=0 [dir_ranchor]=0 [dir_lc]=4 [dir_short]=8 [dir_anchor]=12
      [vcs_rclean]=2 [vcs_rmod]=3 [vcs_runtr]=2 [vcs_rconf]=1 [vcs_fg]=0
      [vcs_clean]=2 [vcs_mod]=3 [vcs_untr]=4 [vcs_conf]=1
      [status_bg]=1 [status_fg]=0 [status_lc]=1
      [exec_bg]=3 [exec_fg]=0 [exec_lc]=3
      [jobs_bg]=6 [jobs_fg]=0 [jobs_lc]=6
      [venv_bg]=5 [venv_fg]=0 [venv_lc]=5
      [ctx_bg]=8 [ctx_fg]=3 [ctx_lc]=3 [ctx_root]=1 [ctx_rroot]=1
      [time_bg]=7 [time_fg]=0 [time_lc]=8
      [ok]=2 [err]=1
      [cbg1]=8 [cbg2]=8 [cbg3]=0 [cbg4]=0 [frm1]=7 [frm2]=8 [frm3]=8 [frm4]=0 ) ;;
    tokyonight) __C=(
      [os_bg]='#c0caf5' [os_fg]='#1a1b26' [os_lc]='#c0caf5'
      [dir_bg]='#7aa2f7' [dir_fg]='#1a1b26' [dir_rshort]='#2f3a5e' [dir_ranchor]='#1a1b26'
      [dir_lc]='#7aa2f7' [dir_short]='#565f89' [dir_anchor]='#7dcfff'
      [vcs_rclean]='#9ece6a' [vcs_rmod]='#e0af68' [vcs_runtr]='#9ece6a' [vcs_rconf]='#f7768e' [vcs_fg]='#1a1b26'
      [vcs_clean]='#9ece6a' [vcs_mod]='#e0af68' [vcs_untr]='#7dcfff' [vcs_conf]='#f7768e'
      [status_bg]='#f7768e' [status_fg]='#1a1b26' [status_lc]='#f7768e'
      [exec_bg]='#e0af68' [exec_fg]='#1a1b26' [exec_lc]='#e0af68'
      [jobs_bg]='#414868' [jobs_fg]='#7dcfff' [jobs_lc]='#7dcfff'
      [venv_bg]='#bb9af7' [venv_fg]='#1a1b26' [venv_lc]='#bb9af7'
      [ctx_bg]='#414868' [ctx_fg]='#e0af68' [ctx_lc]='#e0af68' [ctx_root]='#f7768e' [ctx_rroot]='#f7768e'
      [time_bg]='#c0caf5' [time_fg]='#1a1b26' [time_lc]='#565f89'
      [ok]='#9ece6a' [err]='#f7768e'
      [cbg1]='#3b4261' [cbg2]='#2f354f' [cbg3]='#24283b' [cbg4]='#1f2335'
      [frm1]='#737aa2' [frm2]='#565f89' [frm3]='#414868' [frm4]='#3b4261' ) ;;
    catppuccin) __C=(
      [os_bg]='#cdd6f4' [os_fg]='#1e1e2e' [os_lc]='#cdd6f4'
      [dir_bg]='#89b4fa' [dir_fg]='#1e1e2e' [dir_rshort]='#313244' [dir_ranchor]='#11111b'
      [dir_lc]='#89b4fa' [dir_short]='#6c7086' [dir_anchor]='#74c7ec'
      [vcs_rclean]='#a6e3a1' [vcs_rmod]='#f9e2af' [vcs_runtr]='#a6e3a1' [vcs_rconf]='#f38ba8' [vcs_fg]='#1e1e2e'
      [vcs_clean]='#a6e3a1' [vcs_mod]='#f9e2af' [vcs_untr]='#74c7ec' [vcs_conf]='#f38ba8'
      [status_bg]='#f38ba8' [status_fg]='#1e1e2e' [status_lc]='#f38ba8'
      [exec_bg]='#fab387' [exec_fg]='#1e1e2e' [exec_lc]='#fab387'
      [jobs_bg]='#45475a' [jobs_fg]='#94e2d5' [jobs_lc]='#94e2d5'
      [venv_bg]='#cba6f7' [venv_fg]='#1e1e2e' [venv_lc]='#cba6f7'
      [ctx_bg]='#45475a' [ctx_fg]='#f9e2af' [ctx_lc]='#f9e2af' [ctx_root]='#f38ba8' [ctx_rroot]='#f38ba8'
      [time_bg]='#b4befe' [time_fg]='#1e1e2e' [time_lc]='#6c7086'
      [ok]='#a6e3a1' [err]='#f38ba8'
      [cbg1]='#45475a' [cbg2]='#3a3b4f' [cbg3]='#313244' [cbg4]='#282839'
      [frm1]='#7f849c' [frm2]='#6c7086' [frm3]='#585b70' [frm4]='#45475a' ) ;;
    pure) __C=(
      [dir_lc]=4 [vcs_lc]=242 [vcs_dirty]=218 [vcs_arrows]=6 [exec_lc]=3 [ctx_lc]=242 [ctx_root]=7
      [venv_lc]=242 [time_lc]=242 [status_lc]=1 [jobs_lc]=242 [os_lc]=''
      [ok]=5 [err]=1 [frm1]=244 [frm2]=242 [frm3]=240 [frm4]=238 ) ;;
    snazzy) __C=(
      [dir_lc]='#57c7ff' [vcs_lc]='#686868' [vcs_dirty]='#ff6ac1' [vcs_arrows]='#9aedfe' [exec_lc]='#f3f99d'
      [ctx_lc]='#686868' [ctx_root]='#f1f1f0' [venv_lc]='#686868' [time_lc]='#686868' [status_lc]='#ff5c57'
      [jobs_lc]='#686868' [os_lc]='' [ok]='#ff6ac1' [err]='#ff5c57'
      [frm1]='#868686' [frm2]='#686868' [frm3]='#4e4e4e' [frm4]='#3a3a3a' ) ;;
  esac
  # Newer segments borrow colors from existing roles so every theme stays cohesive.
  local a n o x
  for a in ram:exec load:jobs batt:jobs toolbox:ctx nix:dir python:venv go:dir rust:exec aws:exec \
           disk:exec shlvl:jobs custom:time; do
    n=${a%%:*} o=${a#*:}
    for x in bg fg lc; do [[ -n ${__C[${n}_$x]+set} ]] || __C[${n}_$x]=${__C[${o}_$x]-}; done
  done
  [[ -n ${__C[node_bg]+set} ]] || __C[node_bg]=${__C[vcs_rclean]-} __C[node_fg]=${__C[vcs_fg]-} \
                                  __C[node_lc]=${__C[vcs_clean]:-${__C[vcs_lc]-}}
  if [[ -n ${P10K_ACCENT:-} ]]; then
    local ac=$P10K_ACCENT dk=${P10K_TERM_BG:-}
    [[ $dk == '#'?????? ]] && (( (16#${dk:1:2} * 299 + 16#${dk:3:2} * 587 + 16#${dk:5:2} * 114) / 1000 < 100 )) || dk='#1e1e2e'
    __C[dir_bg]=$ac __C[dir_fg]=$dk __C[dir_ranchor]=$dk __C[dir_lc]=$ac __C[dir_anchor]=$ac
    __p10k_mix "$dk" "$ac" 300; __C[dir_rshort]=$REPLY
    if [[ ${P10K_TERM_BG:-} == '#'?????? ]]; then __p10k_mix "$P10K_TERM_BG" "$ac" 600; __C[dir_short]=$REPLY; fi
  fi
  if declare -p P10K_COLOR &>/dev/null; then
    local k; for k in "${!P10K_COLOR[@]}"; do __C[$k]=${P10K_COLOR[$k]}; done
  fi
}

__p10k_sgr() { # 38|48 color -> REPLY (raw escape)
  local c=$2
  if [[ -z $c ]]; then [[ $1 == 38 ]] && REPLY=$'\e[39m' || REPLY=$'\e[49m'
  elif [[ $c == '#'* ]]; then REPLY=$'\e['"$1;2;$((16#${c:1:2}));$((16#${c:3:2}));$((16#${c:5:2}))m"
  else REPLY=$'\e['"$1;5;${c}m"; fi
}
__p10k_f() { __p10k_sgr 38 "$1"; REPLY=$__p10k_O$REPLY$__p10k_C; }
__p10k_b() { __p10k_sgr 48 "$1"; REPLY=$__p10k_O$REPLY$__p10k_C; }

__p10k_blend() { # '#rrggbb' pct -> REPLY (pct>0 lighter, pct<0 darker)
  local c=$1 p=$2 t=255 r g b
  (( p < 0 )) && { t=0; p=$(( -p )); }
  r=$((16#${c:1:2})) g=$((16#${c:3:2})) b=$((16#${c:5:2}))
  r=$(( r + (t - r) * p / 100 )) g=$(( g + (t - g) * p / 100 )) b=$(( b + (t - b) * p / 100 ))
  printf -v REPLY '#%02x%02x%02x' "$r" "$g" "$b"
}

# =====================================================================================
# Glyphs & layout settings
# =====================================================================================
__p10k_detect_os() {
  local id='' k v
  if [[ $OSTYPE == darwin* ]]; then __p10k_os_glyph=$''; return; fi
  if [[ -r /etc/os-release ]]; then
    while IFS='=' read -r k v; do [[ $k == ID ]] && { id=${v//\"/}; break; }; done < /etc/os-release
  fi
  case $id in
    arch) __p10k_os_glyph=$'' ;;       debian) __p10k_os_glyph=$'' ;;
    ubuntu) __p10k_os_glyph=$'' ;;     fedora) __p10k_os_glyph=$'' ;;
    manjaro) __p10k_os_glyph=$'' ;;    linuxmint) __p10k_os_glyph=$'' ;;
    opensuse*) __p10k_os_glyph=$'' ;;  gentoo) __p10k_os_glyph=$'' ;;
    alpine) __p10k_os_glyph=$'' ;;     centos) __p10k_os_glyph=$'' ;;
    rhel) __p10k_os_glyph=$'' ;;       nixos) __p10k_os_glyph=$'' ;;
    elementary) __p10k_os_glyph=$'' ;; pop) __p10k_os_glyph=$'' ;;
    kali) __p10k_os_glyph=$'' ;;       void) __p10k_os_glyph=$'' ;;
    endeavouros) __p10k_os_glyph=$'' ;; raspbian) __p10k_os_glyph=$'' ;;
    *) __p10k_os_glyph=$'' ;;
  esac
}

__p10k_setup() {
  : "${P10K_STYLE:=lean}" "${P10K_HEIGHT:=2}" "${P10K_SPACING:=compact}" "${P10K_FLOW:=concise}"
  : "${P10K_CHARSET:=unicode}" "${P10K_ICONS:=many}" "${P10K_TIME_FORMAT:=none}"
  __p10k_palette
  __p10k_frm=${P10K_FRAME_COLOR:-${__C[frm2]}}
  __p10k_cbg=${P10K_CLASSIC_BG:-${__C[cbg3]}}
  local uni=1 nerd=1 many=0
  [[ $P10K_CHARSET == ascii ]] && uni=0
  [[ $uni == 0 || $P10K_ICONS == none || $P10K_STYLE == pure ]] && nerd=0
  [[ $nerd == 1 && $P10K_ICONS == many ]] && many=1

  __p10k_osicon='' __p10k_i_home='' __p10k_i_homesub='' __p10k_i_etc='' __p10k_i_dir=''
  __p10k_i_lock='' __p10k_i_branch='' __p10k_i_exec='' __p10k_i_time='' __p10k_i_jobs='' __p10k_i_venv=''
  __p10k_i_ram='' __p10k_i_load='' __p10k_i_box='' __p10k_i_nix='' __p10k_i_aws='' __p10k_i_shell=''
  __p10k_i_disk='' __p10k_i_user=''
  if (( nerd )); then __p10k_i_lock=$'' __p10k_i_jobs=$''; fi
  if (( many )); then
    __p10k_osicon=$__p10k_os_glyph
    __p10k_i_home=$'' __p10k_i_homesub=$'' __p10k_i_etc=$'' __p10k_i_dir=$''
    __p10k_i_branch=$'' __p10k_i_exec=$'' __p10k_i_time=$'' __p10k_i_venv=$''
    __p10k_i_ram=$'\uf2db' __p10k_i_load=$'\uf080' __p10k_i_box=$'\uf1b2' __p10k_i_nix=$'\uf313'
    __p10k_i_aws=$'\uf270' __p10k_i_shell=$'\uf120' __p10k_i_disk=$'\uf0a0' __p10k_i_user=$'\uf007'
  fi
  if (( uni )); then __p10k_char=${P10K_PROMPT_CHAR:-❯} __p10k_x='✘' __p10k_up='⇡' __p10k_down='⇣' __p10k_okg='✔' __p10k_dot='●'
  else __p10k_char='>' __p10k_x='x' __p10k_up='^' __p10k_down='v' __p10k_okg='ok' __p10k_dot='*'; fi
  [[ $P10K_CHARSET == ascii && -n ${P10K_PROMPT_CHAR:-} && $P10K_PROMPT_CHAR != *[!\ -~]* ]] && __p10k_char=$P10K_PROMPT_CHAR

  __p10k_lsep='' __p10k_rsep='' __p10k_lsub='|' __p10k_rsub='|'
  __p10k_lhead='' __p10k_rhead='' __p10k_ltail='' __p10k_rtail=''
  if (( uni )); then
    case ${P10K_SEPARATOR:-angled} in
      angled)   __p10k_lsep=$'' __p10k_lsub=$'' __p10k_rsep=$'' __p10k_rsub=$'' ;;
      vertical) __p10k_lsub='│' __p10k_rsub='│' ;;
      slanted)  __p10k_lsep=$'' __p10k_lsub='╱' __p10k_rsep=$'' __p10k_rsub='╱' ;;
      round)    __p10k_lsep=$'' __p10k_lsub=$'' __p10k_rsep=$'' __p10k_rsub=$'' ;;
    esac
    case ${P10K_HEAD:-sharp} in
      sharp)   __p10k_lhead=$'' __p10k_rhead=$'' ;;
      blurred) __p10k_lhead='▓▒░' __p10k_rhead='░▒▓' ;;
      slanted) __p10k_lhead=$'' __p10k_rhead=$'' ;;
      round)   __p10k_lhead=$'' __p10k_rhead=$'' ;;
    esac
    case ${P10K_TAIL:-flat} in
      blurred) __p10k_ltail='░▒▓' __p10k_rtail='▓▒░' ;;
      sharp)   __p10k_ltail=$'' __p10k_rtail=$'' ;;
      slanted) __p10k_ltail=$'' __p10k_rtail=$'' ;;
      round)   __p10k_ltail=$'' __p10k_rtail=$'' ;;
    esac
  fi
  case ${P10K_CONNECTION:-none} in
    dotted) (( uni )) && __p10k_gap='·' || __p10k_gap='.' ;;
    solid)  (( uni )) && __p10k_gap='─' || __p10k_gap='-' ;;
    *) __p10k_gap=' ' ;;
  esac
  [[ $P10K_STYLE == pure ]] && __p10k_gap=' '   # Pure has no connection line
  __p10k_ftl='' __p10k_fbl='' __p10k_ftr='' __p10k_fbr=''
  if (( uni )) && [[ $P10K_HEIGHT == 2 && $P10K_STYLE != pure ]]; then
    case ${P10K_FRAME:-none} in
      left)  __p10k_ftl='╭─' __p10k_fbl='╰─' ;;
      right) __p10k_ftr='─╮' __p10k_fbr='─╯' ;;
      full)  __p10k_ftl='╭─' __p10k_fbl='╰─' __p10k_ftr='─╮' __p10k_fbr='─╯' ;;
    esac
  fi

  local -a l r
  if declare -p P10K_LEFT_SEGMENTS &>/dev/null; then l=("${P10K_LEFT_SEGMENTS[@]}")
  elif [[ $P10K_STYLE == pure ]]; then l=(context dir vcs command_execution_time virtualenv)
  else l=(os_icon dir vcs); fi
  if declare -p P10K_RIGHT_SEGMENTS &>/dev/null; then r=("${P10K_RIGHT_SEGMENTS[@]}")
  elif [[ $P10K_STYLE == pure ]]; then r=(time)
  else r=(status command_execution_time background_jobs virtualenv context time); fi
  __p10k_left=() __p10k_right=()
  local s
  for s in "${l[@]}"; do { declare -F "__p10k_seg_$s" || [[ $s == custom_* ]]; } >/dev/null && __p10k_left+=("$s"); done
  for s in "${r[@]}"; do { declare -F "__p10k_seg_$s" || [[ $s == custom_* ]]; } >/dev/null && __p10k_right+=("$s"); done
  return 0
}

# =====================================================================================
# Segments
# =====================================================================================
__p10k_begin() {
  S_T='' S_W=0
  case $P10K_STYLE in
    rainbow) S_BG=${__C[${1}_bg]} S_FG=${__C[${1}_fg]} ;;
    classic) S_BG=$__p10k_cbg S_FG=${__C[${1}_lc]} ;;
    *)       S_BG='' S_FG=${__C[${1}_lc]} ;;
  esac
}
__p10k_put() { # color text [bold]
  [[ -n $2 ]] || return 0
  __p10k_f "$1"; S_T+=$REPLY
  if [[ -n $3 ]]; then S_T+=$__p10k_O$'\e[1m'$__p10k_C$2$__p10k_O$'\e[22m'$__p10k_C
  else S_T+=$2; fi
  S_W=$(( S_W + ${#2} ))
  return 0
}
__p10k_ico() { # color glyph  (icon + space, or + 2 spaces with icon padding)
  [[ -n $2 ]] || return 0
  __p10k_put "$1" "$2"
  if [[ ${P10K_ICON_PADDING:-0} == 1 ]]; then S_T+='  '; S_W=$(( S_W + 2 ))
  else S_T+=' '; S_W=$(( S_W + 1 )); fi
  return 0
}
__p10k_pre() { # fluent-flow prefix ("on", "took", "at", ...)
  [[ $P10K_FLOW == fluent ]] || return 0
  local c=''
  case $P10K_STYLE in classic) c=$__p10k_frm ;; rainbow) c=$S_FG ;; esac
  __p10k_put "$c" "$1"
}

__p10k_seg_os_icon() {
  [[ -n $__p10k_osicon ]] || return 1
  __p10k_begin os
  __p10k_put "$S_FG" "$__p10k_osicon"
  [[ ${P10K_ICON_PADDING:-0} == 1 ]] && { S_T+=' '; S_W=$(( S_W + 1 )); }
  return 0
}

__p10k_anchor() {
  local f
  for f in "${__p10k_anchors[@]}"; do [[ -e $1/$f ]] && return 0; done
  return 1
}
__p10k_unique() { # parent name -> REPLY: shortest prefix of name unique among sibling dirs
  local parent=$1 name=$2 l ng=0
  local -a m
  REPLY=$name
  (( ${#name} > 2 )) || return 0
  shopt -q nullglob && ng=1
  shopt -s nullglob
  for (( l = 1; l < ${#name}; l++ )); do
    m=("$parent/${name:0:l}"*/)
    (( ${#m[@]} <= 1 )) && { REPLY=${name:0:l}; break; }
  done
  (( ng )) || shopt -u nullglob
  return 0
}

__p10k_seg_dir() {
  __p10k_begin dir
  local cs ca pwd=$PWD style=${P10K_DIR_STYLE:-smart} short=$__p10k_short
  case $P10K_STYLE in
    rainbow) cs=${__C[dir_rshort]} ca=${__C[dir_ranchor]} ;;
    pure)    cs=$S_FG ca=$S_FG ;;
    *)       cs=${__C[dir_short]} ca=${__C[dir_anchor]} ;;
  esac
  case $style in unique) short=1 ;; full|last|last2) short=0 ;; esac
  (( __p10k_demo )) && pwd=$HOME/src/github/project
  if [[ -n $__p10k_i_home ]]; then
    case $pwd in
      "$HOME") __p10k_ico "$S_FG" "$__p10k_i_home" ;;
      "$HOME"/*) __p10k_ico "$S_FG" "$__p10k_i_homesub" ;;
      /etc|/etc/*) __p10k_ico "$S_FG" "$__p10k_i_etc" ;;
      *) __p10k_ico "$S_FG" "$__p10k_i_dir" ;;
    esac
  fi
  if (( ! __p10k_demo )) && [[ ! -w $pwd ]]; then __p10k_ico "$S_FG" "$__p10k_i_lock"; fi
  if [[ $pwd == "$HOME" ]]; then __p10k_put "$ca" '~' 1; return 0; fi
  if [[ $pwd == / ]]; then __p10k_put "$ca" / 1; return 0; fi
  local base rest tilde=0
  if [[ $pwd == "$HOME"/* ]]; then base=$HOME rest=${pwd#"$HOME"/} tilde=1
  else base='' rest=${pwd#/}; fi
  local -a parts
  IFS=/ read -ra parts <<< "$rest"
  local n=${#parts[@]} i name start=0
  case $style in last) start=$(( n - 1 )) ;; last2) start=$(( n - 2 )) ;; esac
  (( start < 0 )) && start=0
  if (( start > 0 )); then
    for (( i = 0; i < start; i++ )); do base+=/${parts[i]}; done
    [[ $style == last2 ]] && __p10k_put "$S_FG" '…'
  elif (( tilde )); then __p10k_put "$S_FG" '~'; fi
  for (( i = start; i < n; i++ )); do
    name=${parts[i]}
    [[ $style == last && $i == "$start" && $start -gt 0 ]] || __p10k_put "$S_FG" /
    if (( i == n - 1 )); then __p10k_put "$ca" "$name" 1
    elif (( __p10k_demo )); then
      if (( short )); then __p10k_put "$cs" "${name:0:1}"; else __p10k_put "$S_FG" "$name"; fi
    elif __p10k_anchor "$base/$name"; then __p10k_put "$ca" "$name" 1
    elif (( short )); then __p10k_unique "$base" "$name"; __p10k_put "$cs" "$REPLY"
    else __p10k_put "$S_FG" "$name"; fi
    base+=/$name
  done
  return 0
}

__p10k_git_update() {
  __p10k_g_ok=0
  (( __p10k_has_git )) || return 0
  [[ " ${__p10k_left[*]} ${__p10k_right[*]} " == *' vcs '* ]] || return 0
  local d=$PWD gd=''
  while :; do
    if [[ -e $d/.git ]]; then gd=$d/.git; break; fi
    [[ -n $d ]] || return 0
    d=${d%/*}
  done
  if [[ -f $gd ]]; then
    local l; IFS= read -r l < "$gd"; l=${l#gitdir: }
    [[ $l == /* ]] || l=$d/$l
    gd=$l
  fi
  local out rc
  out=$(GIT_OPTIONAL_LOCKS=0 command git status --porcelain=v2 --branch --show-stash 2>/dev/null); rc=$?
  if (( rc == 129 )); then
    out=$(GIT_OPTIONAL_LOCKS=0 command git status --porcelain=v2 --branch 2>/dev/null) || return 0
  elif (( rc )); then return 0; fi
  __p10k_g_branch='' __p10k_g_oid='' __p10k_g_ahead=0 __p10k_g_behind=0 __p10k_g_stash=0
  __p10k_g_staged=0 __p10k_g_unstaged=0 __p10k_g_untracked=0 __p10k_g_conflict=0 __p10k_g_action=''
  local line xy
  while IFS= read -r line; do
    case $line in
      '# branch.oid '*)  __p10k_g_oid=${line#'# branch.oid '} ;;
      '# branch.head '*) __p10k_g_branch=${line#'# branch.head '} ;;
      '# branch.ab '*)   line=${line#'# branch.ab +'}; __p10k_g_ahead=${line%% *}; __p10k_g_behind=${line##*-} ;;
      '# stash '*)       __p10k_g_stash=${line#'# stash '} ;;
      [12]' '*) xy=${line:2:2}
                [[ ${xy:0:1} != . ]] && (( ++__p10k_g_staged ))
                [[ ${xy:1:1} != . ]] && (( ++__p10k_g_unstaged )) ;;
      'u '*) (( ++__p10k_g_conflict )) ;;
      '? '*) (( ++__p10k_g_untracked )) ;;
    esac
  done <<< "$out"
  if [[ -d $gd/rebase-merge ]]; then
    [[ -f $gd/rebase-merge/interactive ]] && __p10k_g_action=rebase-i || __p10k_g_action=rebase-m
  elif [[ -d $gd/rebase-apply ]]; then
    if [[ -f $gd/rebase-apply/rebasing ]]; then __p10k_g_action=rebase
    elif [[ -f $gd/rebase-apply/applying ]]; then __p10k_g_action=am
    else __p10k_g_action=am/rebase; fi
  elif [[ -f $gd/MERGE_HEAD ]]; then __p10k_g_action=merge
  elif [[ -f $gd/CHERRY_PICK_HEAD ]]; then __p10k_g_action=cherry-pick
  elif [[ -f $gd/REVERT_HEAD ]]; then __p10k_g_action=revert
  elif [[ -f $gd/BISECT_LOG ]]; then __p10k_g_action=bisect; fi
  __p10k_g_ok=1
}

__p10k_seg_vcs() {
  (( __p10k_g_ok )) || return 1
  __p10k_begin vcs
  local b=$__p10k_g_branch gs=${P10K_GIT_STYLE:-full}
  [[ $b == '(detached)' ]] && b="@${__p10k_g_oid:0:8}"
  (( ${#b} > 32 )) && b="${b:0:12}…${b: -12}"
  local dirty=$(( __p10k_g_staged + __p10k_g_unstaged + __p10k_g_conflict ))
  if [[ $P10K_STYLE == pure ]]; then
    __p10k_put "$S_FG" "$b"
    [[ $gs == branch ]] && return 0
    (( dirty + __p10k_g_untracked )) && __p10k_put "${__C[vcs_dirty]}" '*'
    if (( __p10k_g_behind || __p10k_g_ahead )); then
      local a=' '
      (( __p10k_g_behind )) && a+=$__p10k_down
      (( __p10k_g_ahead )) && a+=$__p10k_up
      __p10k_put "${__C[vcs_arrows]}" "$a"
    fi
    [[ -n $__p10k_g_action ]] && __p10k_put "${__C[vcs_dirty]}" " $__p10k_g_action"
    return 0
  fi
  local cc cm cu cx
  if [[ $P10K_STYLE == rainbow ]]; then
    if (( __p10k_g_conflict )); then S_BG=${__C[vcs_rconf]}
    elif (( dirty )); then S_BG=${__C[vcs_rmod]}
    elif (( __p10k_g_untracked )); then S_BG=${__C[vcs_runtr]}
    else S_BG=${__C[vcs_rclean]}; fi
    S_FG=${__C[vcs_fg]}; cc=$S_FG cm=$S_FG cu=$S_FG cx=$S_FG
  else
    S_FG=${__C[vcs_clean]}; cc=$S_FG cm=${__C[vcs_mod]} cu=${__C[vcs_untr]} cx=${__C[vcs_conf]}
  fi
  __p10k_pre 'on '
  __p10k_ico "$cc" "$__p10k_i_branch"
  __p10k_put "$cc" "$b"
  [[ $gs == branch ]] && return 0
  if [[ $gs == compact ]]; then
    local a=''
    (( __p10k_g_behind )) && a+=$__p10k_down
    (( __p10k_g_ahead )) && a+=$__p10k_up
    [[ -n $a ]] && __p10k_put "$cc" " $a"
    [[ -n $__p10k_g_action ]] && __p10k_put "$cx" " $__p10k_g_action"
    if (( __p10k_g_conflict )); then __p10k_put "$cx" " $__p10k_dot"
    elif (( dirty )); then __p10k_put "$cm" " $__p10k_dot"
    elif (( __p10k_g_untracked )); then __p10k_put "$cu" " $__p10k_dot"; fi
    return 0
  fi
  local s=''
  (( __p10k_g_behind )) && s+=" $__p10k_down$__p10k_g_behind"
  if (( __p10k_g_ahead )); then (( __p10k_g_behind )) || s+=' '; s+="$__p10k_up$__p10k_g_ahead"; fi
  (( __p10k_g_stash )) && s+=" *$__p10k_g_stash"
  __p10k_put "$cc" "$s"
  [[ -n $__p10k_g_action ]] && __p10k_put "$cx" " $__p10k_g_action"
  (( __p10k_g_conflict )) && __p10k_put "$cx" " ~$__p10k_g_conflict"
  (( __p10k_g_staged )) && __p10k_put "$cm" " +$__p10k_g_staged"
  (( __p10k_g_unstaged )) && __p10k_put "$cm" " !$__p10k_g_unstaged"
  (( __p10k_g_untracked )) && __p10k_put "$cu" " ?$__p10k_g_untracked"
  return 0
}

__p10k_seg_status() {
  local mode=${P10K_STATUS:-error}
  [[ $mode == never ]] && return 1
  if (( ! __p10k_ec )); then
    [[ $mode == always ]] || return 1
    __p10k_begin status
    if [[ $P10K_STYLE == rainbow ]]; then S_BG=${__C[ok]} S_FG=${__C[vcs_fg]:-0}; else S_FG=${__C[ok]}; fi
    __p10k_put "$S_FG" "$__p10k_okg"
    return 0
  fi
  __p10k_begin status
  if [[ $mode == cross ]]; then __p10k_put "$S_FG" "$__p10k_x"; return 0; fi
  local t
  if (( ${#__p10k_pipe[@]} > 1 )); then printf -v t '%s|' "${__p10k_pipe[@]}"; t=${t%|}
  else
    t=$__p10k_ec
    case $__p10k_ec in
      129) t=SIGHUP ;; 130) t=SIGINT ;; 131) t=SIGQUIT ;; 134) t=SIGABRT ;; 137) t=SIGKILL ;;
      139) t=SIGSEGV ;; 141) t=SIGPIPE ;; 143) t=SIGTERM ;;
    esac
  fi
  __p10k_ico "$S_FG" "$__p10k_x"
  __p10k_put "$S_FG" "$t"
  return 0
}

__p10k_seg_command_execution_time() {
  (( __p10k_dur >= ${P10K_EXEC_THRESHOLD:-3} )) || return 1
  __p10k_begin exec
  local d=$__p10k_dur h m s t
  h=$(( d / 3600 )) m=$(( d % 3600 / 60 )) s=$(( d % 60 ))
  if (( h )); then t="${h}h ${m}m ${s}s"; elif (( m )); then t="${m}m ${s}s"; else t="${s}s"; fi
  __p10k_pre 'took '
  __p10k_ico "$S_FG" "$__p10k_i_exec"
  __p10k_put "$S_FG" "$t"
  return 0
}

__p10k_seg_background_jobs() {
  (( __p10k_jobs > 0 )) || return 1
  __p10k_begin jobs
  if [[ -n $__p10k_i_jobs ]]; then
    __p10k_put "$S_FG" "$__p10k_i_jobs"
    (( __p10k_jobs > 1 )) && __p10k_put "$S_FG" " $__p10k_jobs"
  else __p10k_put "$S_FG" "&$__p10k_jobs"; fi
  return 0
}

__p10k_seg_virtualenv() {
  local v=${VIRTUAL_ENV:-${CONDA_DEFAULT_ENV:-}}
  [[ -n $v ]] || return 1
  v=${v%/}; v=${v##*/}
  __p10k_begin venv
  __p10k_pre 'via '
  __p10k_ico "$S_FG" "$__p10k_i_venv"
  __p10k_put "$S_FG" "$v"
  return 0
}

__p10k_seg_context() {
  local mode=${P10K_CONTEXT:-remote} t
  [[ $mode == never ]] && return 1
  if [[ $mode == remote ]]; then
    (( __p10k_demo )) && return 1
    [[ -n ${SSH_CONNECTION:-}${SSH_CLIENT:-}${SSH_TTY:-} || $EUID == 0 ]] || return 1
  fi
  case $mode in user) t=$__p10k_user ;; host) t=$__p10k_host ;; *) t=$__p10k_user@$__p10k_host ;; esac
  __p10k_begin ctx
  local bold=''
  if (( EUID == 0 )); then
    bold=1
    [[ $P10K_STYLE == rainbow ]] && S_FG=${__C[ctx_rroot]} || S_FG=${__C[ctx_root]}
  fi
  __p10k_pre 'with '
  __p10k_ico "$S_FG" "$__p10k_i_user"
  __p10k_put "$S_FG" "$t" "$bold"
  return 0
}

__p10k_seg_time() {
  [[ ${P10K_TIME_FORMAT:-none} != none ]] || return 1
  __p10k_begin time
  local t
  if (( __p10k_demo )); then [[ $P10K_TIME_FORMAT == 12 ]] && t='04:23:42 PM' || t='16:23:42'
  elif [[ $P10K_TIME_FORMAT == 12 ]]; then printf -v t '%(%I:%M:%S %p)T' -1
  else printf -v t '%(%H:%M:%S)T' -1; fi
  __p10k_pre 'at '
  __p10k_ico "$S_FG" "$__p10k_i_time"
  __p10k_put "$S_FG" "$t"
  return 0
}

# ---- extra segments -------------------------------------------------------------------
__p10k_level() { # seg-key level(ok|warn|crit): color the segment by severity
  local c
  case $2 in ok) c=${__C[ok]} ;; warn) c=${__C[exec_lc]:-${__C[exec_bg]}} ;; *) c=${__C[err]} ;; esac
  [[ $2 == warn && $P10K_STYLE == rainbow ]] && c=${__C[exec_bg]}
  if [[ $P10K_STYLE == rainbow ]]; then S_BG=$c S_FG=${__C[vcs_fg]:-0}; else S_FG=$c; fi
}

__p10k_seg_ram() {
  local k v u kb=0 g
  if (( __p10k_demo )); then kb=5452595
  else
    [[ -r /proc/meminfo ]] || return 1
    while read -r k v u; do [[ $k == MemAvailable: ]] && { kb=$v; break; }; done < /proc/meminfo
  fi
  (( kb )) || return 1
  g=$(( kb * 10 / 1048576 ))
  __p10k_begin ram
  __p10k_ico "$S_FG" "$__p10k_i_ram"
  __p10k_put "$S_FG" "$(( g / 10 )).$(( g % 10 ))G"
  return 0
}

__p10k_seg_load() {
  local l1 rest
  if (( __p10k_demo )); then l1=0.42
  else [[ -r /proc/loadavg ]] || return 1; read -r l1 rest < /proc/loadavg; fi
  local x=${l1/./} pct
  x=$(( 10#${x:-0} ))
  pct=$(( x / ${__p10k_ncpu:-1} ))
  __p10k_begin load
  if (( pct > 90 )); then __p10k_level load crit; elif (( pct > 70 )); then __p10k_level load warn; fi
  __p10k_ico "$S_FG" "$__p10k_i_load"
  __p10k_put "$S_FG" "$l1"
  return 0
}

__p10k_seg_battery() {
  local cap='' st='' b
  if (( __p10k_demo )); then cap=85 st=Discharging
  else
    for b in /sys/class/power_supply/BAT*; do
      [[ -r $b/capacity ]] || continue
      read -r cap < "$b/capacity"; [[ -r $b/status ]] && read -r st < "$b/status"
      break
    done
  fi
  [[ -n $cap ]] || return 1
  __p10k_begin batt
  if (( cap < 20 )); then __p10k_level batt crit; elif (( cap < 40 )); then __p10k_level batt warn; else __p10k_level batt ok; fi
  local ic=''
  if [[ -n $__p10k_i_ram ]]; then
    if [[ $st == Charging ]]; then ic=$''
    elif (( cap >= 90 )); then ic=$''; elif (( cap >= 65 )); then ic=$''
    elif (( cap >= 40 )); then ic=$''; elif (( cap >= 15 )); then ic=$''; else ic=$''; fi
  elif [[ $st == Charging ]]; then cap="+$cap"; fi
  __p10k_ico "$S_FG" "$ic"
  __p10k_put "$S_FG" "$cap%"
  return 0
}

__p10k_seg_toolbox() {
  local n='' k v
  if (( __p10k_demo == 2 )); then n=fedora-toolbox-40
  elif (( __p10k_demo )); then return 1
  elif [[ -f /run/.containerenv ]]; then
    while IFS='=' read -r k v; do [[ $k == name ]] && { n=${v//\"/}; break; }; done < /run/.containerenv
    [[ -n $n ]] || n=container
  elif [[ -n ${CONTAINER_ID:-} ]]; then n=$CONTAINER_ID
  elif [[ -f /.dockerenv ]]; then n=docker; fi
  [[ -n $n ]] || return 1
  __p10k_begin toolbox
  __p10k_ico "$S_FG" "$__p10k_i_box"
  __p10k_put "$S_FG" "$n"
  return 0
}

__p10k_seg_nix_shell() {
  local n=${IN_NIX_SHELL:-}
  (( __p10k_demo == 2 )) && n=pure
  (( __p10k_demo == 1 )) && return 1
  [[ -n $n ]] || return 1
  __p10k_begin nix
  __p10k_ico "$S_FG" "$__p10k_i_nix"
  __p10k_put "$S_FG" "$n"
  return 0
}

__p10k_seg_aws() {
  local p=${AWS_VAULT:-${AWS_PROFILE:-}}
  (( __p10k_demo == 2 )) && p=prod
  (( __p10k_demo == 1 )) && return 1
  [[ -n $p ]] || return 1
  __p10k_begin aws
  __p10k_ico "$S_FG" "$__p10k_i_aws"
  [[ -z $__p10k_i_aws ]] && p="aws:$p"
  __p10k_put "$S_FG" "$p"
  return 0
}

__p10k_seg_shell_level() {
  local l=${SHLVL:-1}
  (( __p10k_demo == 2 )) && l=2
  (( __p10k_demo == 1 )) && return 1
  (( l > 1 )) || return 1
  __p10k_begin shlvl
  __p10k_ico "$S_FG" "$__p10k_i_shell"
  [[ -z $__p10k_i_shell ]] && l="lvl $l"
  __p10k_put "$S_FG" "$l"
  return 0
}

__p10k_seg_disk_usage() {
  local u
  if (( __p10k_demo )); then u=47
  else
    local out; out=$(command df -P . 2>/dev/null) || return 1
    out=${out##*$'\n'}; read -r _ _ _ _ u _ <<< "$out"; u=${u%\%}
    [[ $u =~ ^[0-9]+$ ]] || return 1
  fi
  __p10k_begin disk
  if (( u >= 95 )); then __p10k_level disk crit; elif (( u >= 90 )); then __p10k_level disk warn; fi
  __p10k_ico "$S_FG" "$__p10k_i_disk"
  __p10k_put "$S_FG" "$u%"
  return 0
}

__p10k_findup() { # name... -> 0 if PWD or a parent contains one of them
  local d=$PWD f
  while :; do
    for f; do [[ -e $d/$f ]] && return 0; done
    [[ -n $d ]] || return 1
    d=${d%/*}
  done
}
declare -gA __p10k_vcache 2>/dev/null
__p10k_version() { # cmd -> REPLY version (cached per binary path), 1 if not installed
  local d bin='' v IFS=:
  for d in $PATH; do [[ -n $d && -x $d/$1 && ! -d $d/$1 ]] && { bin=$d/$1; break; }; done
  [[ -n $bin ]] || return 1
  if [[ -z ${__p10k_vcache[$bin]:-} ]]; then
    case $1 in
      node)    v=$(command "$bin" -v 2>/dev/null); v=${v#v} ;;
      python3|python) v=$(command "$bin" --version 2>&1); v=${v#Python } ;;
      go)      v=$(command "$bin" version 2>/dev/null); v=${v#go version go}; v=${v%% *} ;;
      rustc)   v=$(command "$bin" --version 2>/dev/null); v=${v#rustc }; v=${v%% *} ;;
    esac
    __p10k_vcache[$bin]=${v:-?}
  fi
  REPLY=${__p10k_vcache[$bin]}
}
__p10k_lang() { # key cmd icon label demo-version anchors...
  local key=$1 cmd=$2 ic=$3 label=$4 dv=$5 v; shift 5
  if (( __p10k_demo == 2 )); then v=$dv
  elif (( __p10k_demo )); then return 1
  else
    __p10k_findup "$@" || return 1
    __p10k_version "$cmd" || return 1
    v=$REPLY
  fi
  __p10k_begin "$key"
  if [[ -n $ic && -n $__p10k_i_branch ]]; then __p10k_ico "$S_FG" "$ic"; else __p10k_put "$S_FG" "$label "; fi
  __p10k_put "$S_FG" "$v"
  return 0
}
__p10k_seg_node_version()   { __p10k_lang node node $'' node 20.11.0 package.json; }
__p10k_seg_python_version() { __p10k_lang python python3 $'' py 3.12.4 pyproject.toml requirements.txt setup.py .python-version Pipfile; }
__p10k_seg_go_version()     { __p10k_lang go go $'' go 1.22.1 go.mod; }
__p10k_seg_rust_version()   { __p10k_lang rust rustc $'' rust 1.77.0 Cargo.toml; }

__p10k_custom() { # name: user segment p10k_custom_<name> sets REPLY (+ optional REPLY_ICON)
  declare -F "p10k_custom_$1" >/dev/null || return 1
  local REPLY_ICON=''
  REPLY=''
  "p10k_custom_$1" || return 1
  [[ -n $REPLY ]] || return 1
  local t=$REPLY ic=$REPLY_ICON k
  __p10k_begin "custom_$1"
  [[ -n ${__C[custom_${1}_bg]+x} ]] || S_BG=${__C[custom_bg]:-}
  if [[ -z ${__C[custom_${1}_fg]+x}${__C[custom_${1}_lc]+x} ]]; then
    case $P10K_STYLE in rainbow) S_FG=${__C[custom_fg]:-} ;; classic|lean|pure) S_FG=${__C[custom_lc]:-} ;; esac
  fi
  [[ $P10K_STYLE == classic ]] && S_BG=$__p10k_cbg
  __p10k_ico "$S_FG" "$ic"
  __p10k_put "$S_FG" "$t"
  return 0
}

# =====================================================================================
# Smooth "blurred" heads/tails: a 6-step truecolor gradient into the terminal background
# =====================================================================================
__p10k_rgb() { # color -> REPLY '#rrggbb' or '' if unknown
  local c=$1 v=(0 95 135 175 215 255) n
  REPLY=''
  if [[ $c == '#'* ]]; then REPLY=$c
  elif [[ $c =~ ^[0-9]+$ ]]; then
    n=$c
    if (( n < 16 )); then REPLY=${P10K_TERM_PALETTE[n]:-}
    elif (( n < 232 )); then n=$(( n - 16 )); printf -v REPLY '#%02x%02x%02x' "${v[n/36]}" "${v[n/6%6]}" "${v[n%6]}"
    else n=$(( 8 + (n - 232) * 10 )); printf -v REPLY '#%02x%02x%02x' "$n" "$n" "$n"; fi
  fi
}
__p10k_mix() { # '#a' '#b' t(0..1000) -> REPLY
  local a=$1 b=$2 t=$3 r g bl
  r=$(( 16#${a:1:2} + (16#${b:1:2} - 16#${a:1:2}) * t / 1000 ))
  g=$(( 16#${a:3:2} + (16#${b:3:2} - 16#${a:3:2}) * t / 1000 ))
  bl=$(( 16#${a:5:2} + (16#${b:5:2} - 16#${a:5:2}) * t / 1000 ))
  printf -v REPLY '#%02x%02x%02x' "$r" "$g" "$bl"
}
declare -gA __p10k_fadec 2>/dev/null
__p10k_fade() { # segment-color in|out -> REPLY (3 cells), fails if colors are unknown
  local key="$1|$2|${P10K_TERM_BG:-}|$__p10k_O"
  if [[ -n ${__p10k_fadec[$key]:-} ]]; then REPLY=${__p10k_fadec[$key]}; return 0; fi
  [[ ${P10K_TERM_BG:-} == '#'?????? ]] || return 1
  __p10k_rgb "$1"; local seg=$REPLY k out=''
  [[ -n $seg ]] || return 1
  local -a sh=()
  for k in 1 2 3 4 5 6; do __p10k_mix "$P10K_TERM_BG" "$seg" $(( k * 1000 / 7 )); sh[k]=${REPLY:1}; done
  local -a order
  [[ $2 == in ]] && order=(1 2 3 4 5 6) || order=(6 5 4 3 2 1)
  for k in 0 2 4; do
    local f=${sh[order[k]]} b=${sh[order[k+1]]}
    out+=$__p10k_O$'\e[38;2;'"$((16#${f:0:2}));$((16#${f:2:2}));$((16#${f:4:2}))"$';48;2;'"$((16#${b:0:2}));$((16#${b:2:2}));$((16#${b:4:2}))m"$__p10k_C'▌'
  done
  out+=$__p10k_O$'\e[49m'$__p10k_C
  __p10k_fadec[$key]=$out REPLY=$out
}
__p10k_isblur() { [[ $1 == '░▒▓' || $1 == '▓▒░' ]]; }

# =====================================================================================
# Layout
# =====================================================================================
__p10k_compose() { # side seg... -> REPLY_S REPLY_W
  local side=$1 s; shift
  local -a bgs=() ts=() ws=() fgs=()
  for s; do
    if [[ $s == custom_* ]]; then __p10k_custom "${s#custom_}" || continue
    else "__p10k_seg_$s" || continue; fi
    bgs+=("$S_BG") ts+=("$S_T") ws+=("$S_W") fgs+=("$S_FG")
  done
  REPLY_S='' REPLY_W=0
  local n=${#ts[@]} out='' w=0 i rst=$__p10k_O$'\e[0m'$__p10k_C
  (( n )) || return 0
  if [[ $P10K_STYLE == lean || $P10K_STYLE == pure ]]; then
    for (( i = 0; i < n; i++ )); do
      (( i )) && { out+=' '; w=$(( w + 1 )); }
      out+=${ts[i]}; w=$(( w + ws[i] ))
    done
    REPLY_S=$out$rst REPLY_W=$w
    return 0
  fi
  local sep sub start end
  if [[ $side == left ]]; then sep=$__p10k_lsep sub=$__p10k_lsub start=$__p10k_ltail end=$__p10k_lhead
  else sep=$__p10k_rsep sub=$__p10k_rsub start=$__p10k_rhead end=$__p10k_rtail; fi
  if __p10k_isblur "$start" && __p10k_fade "${bgs[0]}" in; then out+=$REPLY; w=$(( w + 3 ))
  elif [[ -n $start ]]; then __p10k_f "${bgs[0]}"; out+=$REPLY$start; w=$(( w + ${#start} )); fi
  for (( i = 0; i < n; i++ )); do
    if (( i == 0 )); then __p10k_b "${bgs[0]}"; out+=$REPLY
    elif [[ ${bgs[i]} == "${bgs[i-1]}" ]]; then
      [[ $P10K_STYLE == classic ]] && __p10k_f "$__p10k_frm" || __p10k_f "${fgs[i]}"
      out+=$REPLY$sub; w=$(( w + ${#sub} ))
    elif [[ -z $sep ]]; then __p10k_b "${bgs[i]}"; out+=$REPLY
    elif [[ $side == left ]]; then
      __p10k_f "${bgs[i-1]}"; out+=$REPLY; __p10k_b "${bgs[i]}"; out+=$REPLY$sep; w=$(( w + ${#sep} ))
    else
      __p10k_f "${bgs[i]}"; out+=$REPLY$sep; __p10k_b "${bgs[i]}"; out+=$REPLY; w=$(( w + ${#sep} ))
    fi
    out+=" ${ts[i]} "; w=$(( w + ws[i] + 2 ))
  done
  out+=$__p10k_O$'\e[49m'$__p10k_C
  if __p10k_isblur "$end" && __p10k_fade "${bgs[n-1]}" out; then out+=$REPLY; w=$(( w + 3 ))
  elif [[ -n $end ]]; then __p10k_f "${bgs[n-1]}"; out+=$REPLY$end; w=$(( w + ${#end} )); fi
  REPLY_S=$out$rst REPLY_W=$w
}

# Builds: B_top (first line of a two-line prompt), B_in/B_inw (input line), B_rin/B_rinw (right side of input line)
__p10k_build() {
  local cols=$1 L LW R RW try showpc=1 pc='' pcw=0
  local rst=$__p10k_O$'\e[0m'$__p10k_C
  [[ ($P10K_STYLE == classic || $P10K_STYLE == rainbow) && $P10K_HEIGHT == 1 ]] && showpc=0
  if (( showpc )); then
    (( __p10k_ec )) && __p10k_f "${__C[err]}" || __p10k_f "${__C[ok]}"
    pc=$REPLY$__p10k_char$rst pcw=${#__p10k_char}
  fi
  local tlw=${#__p10k_ftl} trw=${#__p10k_ftr}
  [[ -n $__p10k_ftl && ($P10K_STYLE == lean || $P10K_STYLE == pure) ]] && tlw=$(( tlw + 1 ))
  [[ -n $__p10k_ftr && ($P10K_STYLE == lean || $P10K_STYLE == pure) ]] && trw=$(( trw + 1 ))
  __p10k_short=0
  local -a rl=("${__p10k_right[@]}")
  local fit=0
  for try in 0 1; do
    __p10k_compose left "${__p10k_left[@]}"; L=$REPLY_S LW=$REPLY_W
    __p10k_compose right "${rl[@]}"; R=$REPLY_S RW=$REPLY_W
    if [[ $P10K_HEIGHT == 2 ]]; then (( tlw + LW + 2 + RW + trw < cols )) && fit=1
    else (( LW + pcw + 2 + RW + 20 < cols )) && fit=1; fi
    (( fit )) && break
    __p10k_short=1
  done
  while (( ! fit && ${#rl[@]} )); do   # too wide: drop right segments, farthest from the edge first
    rl=("${rl[@]:1}")
    __p10k_compose right "${rl[@]}"; R=$REPLY_S RW=$REPLY_W
    if [[ $P10K_HEIGHT == 2 ]]; then (( tlw + LW + 2 + RW + trw < cols )) && fit=1
    else (( LW + pcw + 2 + RW + 20 < cols )) && fit=1; fi
  done
  (( fit )) || R='' RW=0

  __p10k_f "$__p10k_frm"; local fc=$REPLY
  if [[ $P10K_HEIGHT == 2 ]]; then
    local tl='' tr='' bl=''
    if [[ -n $__p10k_ftl ]]; then tl=$fc$__p10k_ftl$rst; (( tlw > 2 )) && tl+=' '; fi
    if [[ -n $__p10k_ftr ]]; then tr=$fc$__p10k_ftr$rst; (( trw > 2 )) && tr=" $tr"; fi
    B_top=$tl$L
    if (( RW || trw )); then
      local gw=$(( cols - 1 - tlw - LW - trw - 1 )) g
      (( RW )) && gw=$(( gw - RW - 1 ))
      (( gw < 0 )) && gw=0
      printf -v g '%*s' "$gw" ''
      [[ $__p10k_gap != ' ' ]] && g=${g// /$__p10k_gap}
      B_top+=" $fc$g$rst"
      (( RW )) && B_top+=" $R"
      B_top+=$tr
    fi
    local blw=0
    [[ -n $__p10k_fbl ]] && { bl=$fc$__p10k_fbl$rst; blw=${#__p10k_fbl}; }
    B_in=$bl$pc' ' B_inw=$(( blw + pcw + 1 ))
    B_rin='' B_rinw=0
    [[ -n $__p10k_fbr ]] && { B_rin=$fc$__p10k_fbr$rst; B_rinw=${#__p10k_fbr}; }
    __p10k_above=1
  else
    B_top='' B_in=$L B_inw=$LW
    (( showpc )) && { B_in+=" $pc"; B_inw=$(( B_inw + 1 + pcw )); }
    B_in+=' ' B_inw=$(( B_inw + 1 ))
    B_rin=$R B_rinw=$RW
    __p10k_above=0
  fi
}

# =====================================================================================
# Shell integration
# =====================================================================================
__p10k_precmd() {
  local ec=$? pipe=("${PIPESTATUS[@]}")
  if (( __p10k_ran || __p10k_first )); then   # Ctrl+C or an empty Enter didn't run anything
    __p10k_ec=$ec __p10k_pipe=("${pipe[@]}")
    local p; for p in "${pipe[@]}"; do (( p )) && break; done
    (( ${#pipe[@]} > 1 && p == 0 )) && __p10k_pipe=()
  fi
  if (( __p10k_ran )); then
    local now=${EPOCHREALTIME/[.,]/}
    [[ -n ${EPOCHREALTIME:-} ]] || now=$SECONDS
    __p10k_dur=$(( (now - __p10k_t0) / __p10k_unit )) __p10k_ran=0
  else __p10k_dur=0; fi
  local j='\j'; __p10k_jobs=${j@P}
  __p10k_git_update
  local cols=${COLUMNS:-80}
  __p10k_build "$cols"
  # Only the line you type on goes into PS1. Everything above it (the info line) and the
  # right-hand part of the typing line are printed here, before bash draws PS1. Bash/readline
  # then only has to manage a simple one-line prompt, which avoids redraw glitches with
  # multi-line prompts and cursor tricks in some terminals.
  local top='' r
  if [[ -n $B_top ]]; then top=${B_top//$'\001'/}; top=${top//$'\002'/}$'\n'; fi
  __p10k_top=$top
  __p10k_pending=1   # printed by __p10k_final, after any other prompt code has run
  __p10k_ps1=$B_in
  # Right side of the typing line (e.g. the ─╯ frame corner): part of PS1 so bash redraws it
  # with the prompt. Invisible to readline: jump right, draw it, jump back by the same amount.
  if [[ -n $B_rin ]]; then
    r=${B_rin//$'\001'/}; r=${r//$'\002'/}
    local n=$(( cols - B_inw - B_rinw - 1 )) back=$(( cols - 1 - B_inw ))
    (( n > 0 )) && __p10k_ps1+=$'\001\e['"${n}C$r"$'\e['"${back}D"$'\002'
  fi
  __p10k_inw=$B_inw
  local c; (( __p10k_ec )) && c=${__C[err]} || c=${__C[ok]}
  __p10k_sgr 38 "$c"; __p10k_tchar=$REPLY$__p10k_char$'\e[0m '
  __p10k_nlines=0
  return $ec
}

__p10k_clear() { printf '\e[H\e[2J%s' "$__p10k_top"; }

__p10k_capture() { __p10k_cmd=$READLINE_LINE; (( ++__p10k_nlines )); }

__p10k_ps0() { # runs in a subshell from PS0: collapse the previous prompt (transient prompt)
  (( __p10k_nlines == 1 )) || return 0
  local cols=${COLUMNS:-80}
  local up=$(( (__p10k_inw + ${#__p10k_cmd}) / cols + 1 + __p10k_above ))
  printf '\e[%dA\r\e[J%s%s\n\r' "$up" "$__p10k_tchar" "$__p10k_cmd"  # trailing \r keeps the \n through $(...)
}

# Runs last in PROMPT_COMMAND: if another prompt (a custom PS1 function, a framework...)
# rewrote PS1 or PS0 after us, take them back.
__p10k_final() {
  local ec=$?
  if (( __p10k_pending )); then
    [[ $P10K_SPACING == sparse ]] && (( ! __p10k_first )) && printf '\n'
    __p10k_first=0 __p10k_pending=0
    printf '%s' "$__p10k_top"
  fi
  [[ $PS1 == *'${__p10k_ps1}'* ]] || PS1='${__p10k_ps1}'
  [[ $PS0 == *"$__p10k_ps0s"* ]] || PS0=$__p10k_ps0s
  return $ec
}

__p10k_hooks() {
  if [[ $(declare -p PROMPT_COMMAND 2>/dev/null) == 'declare -a'* ]]; then
    local -a pc=() e
    for e in "${PROMPT_COMMAND[@]}"; do [[ $e == __p10k_precmd || $e == __p10k_final ]] || pc+=("$e"); done
    PROMPT_COMMAND=(__p10k_precmd "${pc[@]}" __p10k_final)
  else
    local pc=${PROMPT_COMMAND:-}
    pc=${pc//__p10k_precmd; /}; pc=${pc//; __p10k_final/}; pc=${pc//__p10k_precmd/}; pc=${pc//__p10k_final/}
    PROMPT_COMMAND="__p10k_precmd${pc:+; $pc}; __p10k_final"
  fi
  PS1='${__p10k_ps1}'
  local now='SECONDS'; __p10k_unit=1
  [[ -n ${EPOCHREALTIME:-} ]] && now='${EPOCHREALTIME/[.,]/}' __p10k_unit=1000000
  local t='${__p10k_nil[__p10k_t0='"$now"',__p10k_ran=1,0]}'
  local km
  for km in emacs vi-insert; do bind -m "$km" -x '"\C-l": __p10k_clear'; done
  if [[ ${P10K_TRANSIENT_PROMPT:-0} == 1 ]]; then
    PS0='$(__p10k_ps0)'"$t"
    for km in emacs vi-insert vi-command; do
      bind -m "$km" -x '"\C-x\C-p": __p10k_capture'
      bind -m "$km" '"\C-x\C-o": accept-line'
      bind -m "$km" '"\C-m": "\C-x\C-p\C-x\C-o"'
      bind -m "$km" '"\C-j": "\C-x\C-p\C-x\C-o"'
    done
    __p10k_bound=1
  else
    PS0=$t
    if (( ${__p10k_bound:-0} )); then
      for km in emacs vi-insert vi-command; do
        bind -m "$km" '"\C-m": accept-line'; bind -m "$km" '"\C-j": accept-line'
      done
      __p10k_bound=0
    fi
  fi
  __p10k_ps0s=$PS0
}

__p10k_load() {
  local v
  for v in ${!P10K_*}; do
    case $v in P10K_CONFIG|P10K_DISABLE_CONFIGURATION_WIZARD) ;; *) unset "$v" ;; esac
  done
  [[ -r $__P10K_CONFIG ]] && source "$__P10K_CONFIG"
  __p10k_setup
}

p10k() {
  case ${1:-help} in
    configure) __P10K_FROM_SHELL=1 command bash "$__P10K_SRC" configure && { __p10k_load; __p10k_hooks; } ;;
    reload)    __p10k_load; __p10k_hooks ;;
    doctor)    __p10k_doctor ;;
    *) printf '%s\n' 'Usage: p10k <command>' '' \
         '  configure   run the interactive configuration wizard' \
         '  reload      reload ~/.p10k.bash after editing it' \
         '  doctor      show why the prompt might not be showing up' ;;
  esac
}

__p10k_doctor() {
  printf 'bash %s, locale %s\n' "$BASH_VERSION" "${LC_ALL:-${LC_CTYPE:-${LANG:-unset}}}"
  printf 'p10k: %s\nconfig: %s\n' "$__P10K_SRC" "$__P10K_CONFIG"
  if [[ $PS1 == '${__p10k_ps1}' ]]; then echo 'PS1: ok (bash-p10k)'
  elif [[ $PS1 == *'${__p10k_ps1}'* ]]; then echo 'PS1: ok (bash-p10k, wrapped by the terminal'"'"'s shell integration)'
  else printf 'PS1: NOT ours: %q\n' "$PS1"; fi
  printf 'PROMPT_COMMAND: %s\n' "$(declare -p PROMPT_COMMAND 2>/dev/null)"
  printf 'terminal background: %s\n' "${P10K_TERM_BG:-unknown (smooth blur falls back to ░▒▓)}"
  echo; echo 'Lines that set a prompt in your startup files:'
  local f
  for f in ~/.bashrc ~/.bashrc.d/* ~/.bash_profile ~/.profile; do
    [[ -f $f ]] && grep -nHiE '^[^#]*(PS1=|PROMPT_COMMAND|starship|oh-my-posh|bash-it|ble\.sh|(source|\.) .*(ps1|prompt))' "$f" 2>/dev/null
  done
  local fn
  local -a pcs=("${PROMPT_COMMAND[@]}")
  [[ ${#pcs[@]} == 1 ]] && IFS=';' read -ra pcs <<< "${pcs[0]}"
  for fn in "${pcs[@]}"; do
    fn=${fn#"${fn%%[![:space:]]*}"}; fn=${fn%%[[:space:]]*}
    case $fn in ''| __p10k_*|*_ksi_prompt_command*|__vte_prompt_command|__systemd_osc*) ;;
      *) printf '\nOther prompt code runs before every prompt: %s\n' "$fn"
         declare -F "$fn" >/dev/null && printf '  defined in: %s\n' "$(shopt -s extdebug; declare -F "$fn" | cut -d' ' -f3-)" ;;
    esac
  done
  return 0
}

__p10k_init() {
  [[ $- == *i* ]] || return 0
  __p10k_detect_os
  command -v git >/dev/null 2>&1 && __p10k_has_git=1 || __p10k_has_git=0
  __p10k_user=${USER:-$(id -un)} __p10k_host=${HOSTNAME%%.*}
  __p10k_ncpu=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
  export VIRTUAL_ENV_DISABLE_PROMPT=1
  : "${CONDA_CHANGEPS1:=false}"; export CONDA_CHANGEPS1
  shopt -s checkwinsize
  (:)   # a finished child process makes bash fill in COLUMNS before the first prompt
  if [[ ! -r $__P10K_CONFIG && -z ${P10K_DISABLE_CONFIGURATION_WIZARD:-} ]]; then
    command bash "$__P10K_SRC" configure
  fi
  __p10k_load
  __p10k_hooks
}

# =====================================================================================
# Configuration wizard (p10k configure)
# =====================================================================================
__w_center() { # text (may contain escapes) plain-width
  local pad=$(( (__w_cols - $2) / 2 )); (( pad < 0 )) && pad=0
  printf '%*s%s\n' "$pad" '' "$1"
}
__w_size() { # real terminal width (tput in $(...) can't see the tty and falls back to 80)
  local sz
  sz=$(stty size </dev/tty 2>/dev/null) && [[ ${sz#* } =~ ^[0-9]+$ ]] && { __w_cols=${sz#* }; return; }
  [[ ${COLUMNS:-} =~ ^[0-9]+$ ]] && { __w_cols=$COLUMNS; return; }
  __w_cols=$(tput cols 2>/dev/null </dev/tty || echo 80)
}
__w_header() {
  __w_size
  printf '\e[H\e[2J\e[3J'
  __w_center $'\e[1mPowerlevel10k configuration wizard\e[0m' 34
  __w_center $'\e[2mfor bash\e[0m' 8
  echo
}
__w_quit() {
  printf '\e[H\e[2J\e[3J'
  echo "Powerlevel10k configuration wizard has been aborted. Nothing was changed."
  [[ -r $__P10K_CONFIG ]] || printf '%s\n' '' \
    'It will run again next time you open bash. To stop that, put this line before' \
    'bash-p10k in your ~/.bashrc:   P10K_DISABLE_CONFIGURATION_WIZARD=1'
  exit 1
}
__w_keys() { local i s=''; for (( i = 1; i <= $1; i++ )); do s+=$i; done; REPLY=$s; }

__w_preview() { # [typed command]
  __p10k_setup
  local w=$(( __w_cols - 4 )) t=${1:-}
  (( w > 200 )) && w=200
  __p10k_build "$w"
  [[ $P10K_SPACING == sparse ]] && echo
  [[ -n $B_top ]] && printf '  %s\n' "$B_top"
  if [[ -n $B_rin ]]; then
    local pad=$(( w - 1 - B_inw - ${#t} - B_rinw )); (( pad < 1 )) && pad=1
    printf '  %s%s%*s%s\n' "$B_in" "$t" "$pad" '' "$B_rin"
  else
    printf '  %s%s\n' "$B_in" "$t"
  fi
}
__w_preview_transient() {
  __p10k_setup
  if [[ $P10K_TRANSIENT_PROMPT == 1 ]]; then
    __p10k_sgr 38 "${__C[ok]}"
    [[ $P10K_SPACING == sparse ]] && echo
    printf '  %s%s\e[0m %s\n' "$REPLY" "$__p10k_char" 'ls'
  else
    __w_preview ls
  fi
  printf '  %s\n' 'file.txt'
  __w_preview
}

__w_detect_bg() { # ask the terminal for its background color (OSC 11)
  __w_tbg='' __w_tdark=0
  [[ -t 0 && -t 1 ]] || return 0
  local old r junk
  old=$(stty -g 2>/dev/null) || return 0
  stty -echo -icanon min 1 time 0 2>/dev/null
  local i q=$'\e]11;?\e\\'
  for (( i = 0; i < 16; i++ )); do q+=$'\e]4;'"$i"$';?\e\\'; done
  printf '%s' "$q"
  IFS= read -rs -t 0.6 -d '' r
  while IFS= read -rs -t 0.05 -n 256 junk; do r+=$junk; done
  stty "$old" 2>/dev/null
  P10K_TERM_PALETTE=()
  local rest=$r
  while [[ $rest =~ \]4\;([0-9]+)\;rgb:([0-9a-fA-F]+)/([0-9a-fA-F]+)/([0-9a-fA-F]+) ]]; do
    local x=${BASH_REMATCH[2]} y=${BASH_REMATCH[3]} z=${BASH_REMATCH[4]}
    [[ ${#x} == 1 ]] && x=$x$x; [[ ${#y} == 1 ]] && y=$y$y; [[ ${#z} == 1 ]] && z=$z$z
    P10K_TERM_PALETTE[BASH_REMATCH[1]]="#${x:0:2}${y:0:2}${z:0:2}"
    P10K_TERM_PALETTE[BASH_REMATCH[1]]=${P10K_TERM_PALETTE[BASH_REMATCH[1]],,}
    rest=${rest#*"${BASH_REMATCH[0]}"}
  done
  r=${r%%$'\e]4'*}
  if [[ $r =~ rgb:([0-9a-fA-F]+)/([0-9a-fA-F]+)/([0-9a-fA-F]+) ]]; then
    local R=${BASH_REMATCH[1]} G=${BASH_REMATCH[2]} B=${BASH_REMATCH[3]}
    [[ ${#R} == 1 ]] && R=$R$R; [[ ${#G} == 1 ]] && G=$G$G; [[ ${#B} == 1 ]] && B=$B$B
    __w_tbg="#${R:0:2}${G:0:2}${B:0:2}"; __w_tbg=${__w_tbg,,}
    (( (16#${R:0:2} * 299 + 16#${G:0:2} * 587 + 16#${B:0:2} * 114) / 1000 < 128 )) && __w_tdark=1
  fi
  P10K_TERM_BG=$__w_tbg
  return 0
}
__w_shades() { # cbg|frm -> __w_s (lightest light dark darkest)
  __p10k_palette
  __w_s=()
  if [[ -n $__w_tbg ]] && (( __w_tdark )) && [[ $P10K_STYLE != pure ]]; then
    local p; local -a ps
    [[ $1 == cbg ]] && ps=(16 11 7 -22) || ps=(46 36 27 19)
    for p in "${ps[@]}"; do __p10k_blend "$__w_tbg" "$p"; __w_s+=("$REPLY"); done
  else
    __w_s=("${__C[${1}1]}" "${__C[${1}2]}" "${__C[${1}3]}" "${__C[${1}4]}")
  fi
}

# ---- wizard UI helpers ----------------------------------------------------------------
# Step return codes: 0 next, 2 back, 3 restart, 4 skipped (not applicable)
__w_note='' __w_canback=0

__w_wrap() { # dim, wrapped explanation text
  local line w=$(( __w_cols > 104 ? 100 : __w_cols - 4 ))
  (( w < 30 )) && w=30
  while IFS= read -r line; do printf '\e[2m%s\e[0m\n' "$line"; done < <(fold -s -w "$w" <<< "$1")
}

__w_footer() { # extra-keys -> prints the common footer and prompt
  printf '\n'
  (( __w_canback )) && printf '(b)  Back to the previous question.\n'
  printf '(r)  Restart from the beginning.\n(q)  Quit and do nothing.\n\n'
  local b=''; (( __w_canback )) && b=b
  printf 'Choice [%s%srq]: ' "$1" "$b"
}

__w_yesno() { # question body [note] -> 0 yes, 1 no, 3 restart
  local k
  while :; do
    __w_header
    printf '\e[1m%s\e[0m\n' "$1"
    [[ -n ${3:-} ]] && { echo; __w_wrap "$3"; }
    printf '\n%s\n\n(y)  Yes.\n\n(n)  No.\n' "$2"
    __w_footer yn
    IFS= read -rsn1 k || __w_quit
    case $k in
      y|Y) return 0 ;; n|N) return 1 ;; r|R) return 3 ;; q|Q) __w_quit ;;
    esac
  done
}

__w_ask() { # var title "value|label"...   (explanation comes from $__w_note)
  local var=$1 title=$2 k i note=$__w_note; shift 2
  __w_note=''
  local -a opts=("$@")
  local orig=${!var}
  while :; do
    __w_header
    printf '\e[1m%s\e[0m\n' "$title"
    [[ -n $note ]] && { echo; __w_wrap "$note"; }
    echo
    for i in "${!opts[@]}"; do
      printf -v "$var" '%s' "${opts[i]%%|*}"
      printf '\e[1m(%d)  %s\e[0m\n' $(( i + 1 )) "${opts[i]#*|}"
      "$__w_pv"
      echo
    done
    printf -v "$var" '%s' "$orig"
    __w_keys ${#opts[@]}
    __w_footer "$REPLY"
    IFS= read -rsn1 k || __w_quit
    case $k in
      [1-9]) if (( k <= ${#opts[@]} )); then printf -v "$var" '%s' "${opts[k-1]%%|*}"; return 0; fi ;;
      b|B) (( __w_canback )) && return 2 ;;
      r|R) return 3 ;;
      q|Q) __w_quit ;;
    esac
  done
}

__w_preview_status() {
  local e=$__p10k_ec
  printf '  \e[2mafter a command that worked:\e[0m\n'; __p10k_ec=0; __w_preview
  printf '  \e[2mafter a command that failed:\e[0m\n'; __p10k_ec=1; __w_preview
  __p10k_ec=$e
}

__w_sw() { # '#rrggbb' -> REPLY colored swatch
  local c=$1
  REPLY=$'\e[38;2;'"$((16#${c:1:2}));$((16#${c:3:2}));$((16#${c:5:2}))m"'██'$'\e[0m'
}

# ---- prompt elements -------------------------------------------------------------------
__w_ids=(os_icon context dir vcs status command_execution_time background_jobs virtualenv toolbox nix_shell
         python_version node_version go_version rust_version aws ram load disk_usage battery shell_level time)
__w_lbl=('OS logo' 'user@host' 'Current folder' 'Git status' 'Exit code' 'Command duration'
         'Background jobs' 'Python virtualenv' 'Toolbox / container' 'Nix shell' 'Python version'
         'Node.js version' 'Go version' 'Rust version' 'AWS profile' 'Free RAM' 'CPU load' 'Disk usage'
         'Battery' 'Nested shell level' 'Current time')
__w_ekeys=123456789acdefghijklm   # no b/q/r: those are Back / Quit / Restart

__w_hint() { # id -> REPLY: when does it show up?
  REPLY=''
  case $1 in
    os_icon) [[ $P10K_ICONS == many ]] || REPLY='hidden: needs "Many icons"' ;;
    context) case ${P10K_CONTEXT:-remote} in
               remote) REPLY='only over SSH or as root' ;; never) REPLY='hidden: you chose "Never"' ;; esac ;;
    status) case ${P10K_STATUS:-error} in error|cross) REPLY='only after a failed command' ;;
              never) REPLY='hidden: you chose "Never"' ;; esac ;;
    command_execution_time) REPLY="only after commands longer than ${P10K_EXEC_THRESHOLD}s"
                            (( P10K_EXEC_THRESHOLD > 99999 )) && REPLY='hidden: you chose "Never"' ;;
    background_jobs) REPLY='only while something runs in the background (&)' ;;
    virtualenv) REPLY='only inside an activated Python venv/conda' ;;
    toolbox) REPLY='only inside toolbox / distrobox / docker' ;;
    nix_shell) REPLY='only inside nix-shell' ;;
    python_version) REPLY='only in folders with pyproject.toml, requirements.txt…' ;;
    node_version) REPLY='only in folders with package.json' ;;
    go_version) REPLY='only in folders with go.mod' ;;
    rust_version) REPLY='only in folders with Cargo.toml' ;;
    aws) REPLY='only when AWS_PROFILE is set' ;;
    battery) REPLY='laptops only'; local b; for b in /sys/class/power_supply/BAT*; do [[ -e $b ]] && REPLY=''; break; done ;;
    shell_level) REPLY='only when bash runs inside bash' ;;
    time) [[ $P10K_TIME_FORMAT == none ]] && REPLY='hidden: you chose no time earlier' ;;
  esac
}

__w_default_place() {
  declare -gA __w_place=()
  local i b
  for i in "${__w_ids[@]}"; do __w_place[$i]=off; done
  if [[ $P10K_STYLE == pure ]]; then
    for i in context dir vcs command_execution_time virtualenv toolbox; do __w_place[$i]=L; done
    __w_place[time]=R
  else
    for i in os_icon dir vcs; do __w_place[$i]=L; done
    for i in status command_execution_time background_jobs virtualenv toolbox nix_shell aws context time; do
      __w_place[$i]=R
    done
    for b in /sys/class/power_supply/BAT*; do [[ -e $b ]] && __w_place[battery]=R; break; done
  fi
  __w_place_style=$P10K_STYLE
}
__w_apply_place() {
  local i
  P10K_LEFT_SEGMENTS=() P10K_RIGHT_SEGMENTS=()
  for i in "${__w_ids[@]}"; do [[ ${__w_place[$i]} == L ]] && P10K_LEFT_SEGMENTS+=("$i"); done
  # the right side reads outward like p10k: status first, user@host and time at the far edge
  for i in status command_execution_time background_jobs virtualenv toolbox nix_shell python_version \
           node_version go_version rust_version aws ram load disk_usage battery shell_level os_icon dir vcs \
           context time; do
    [[ ${__w_place[$i]} == R ]] && P10K_RIGHT_SEGMENTS+=("$i")
  done
  return 0
}

# ---- steps -----------------------------------------------------------------------------
__w_s_font() {
  __w_canback=0
  local r note='bash-p10k draws arrows and icons with special symbols that only some fonts have ("Nerd Fonts"). These three quick checks find out what your font can show. If you see an empty box, a question mark or some unrelated character, answer No. Tip: to get every symbol, install the font "MesloLGS NF" (or any Nerd Font) and pick it in your terminal settings, then run this wizard again.'
  __w_pl=1 __w_nerd=1 P10K_ICON_PADDING=0
  __w_yesno 'Font check 1/3: does this look like a diamond (a square standing on its corner)?' \
    $'          \e[38;5;31m\e[0m' "$note"; r=$?
  (( r == 3 )) && return 3
  if (( r == 1 )); then __w_pl=0 __w_nerd=0
  else
    __w_yesno 'Font check 2/3: does this look like a padlock?' $'          ' \
      'If yes, your font has icons (folders, git branch, clock…).'; r=$?
    (( r == 3 )) && return 3
    if (( r == 1 )); then __w_nerd=0
    else
      __w_yesno 'Font check 3/3: does every icon fit between the crosses?' \
        $'          ××××××××' \
        'Answer No if any icon is cut off or overlaps the × to its right. Then bash-p10k will add a little extra space after each icon.'; r=$?
      (( r == 3 )) && return 3
      (( r == 1 )) && P10K_ICON_PADDING=1
    fi
  fi
  if (( __w_nerd )); then P10K_ICONS=many; else P10K_ICONS=none; fi
  if (( __w_pl )); then P10K_CHARSET=unicode; else P10K_CHARSET=ascii; fi
  return 0
}

__w_s_style() {
  __w_note='The overall look. Lean: just colored text. Classic: text on one dark bar. Rainbow: every part gets its own colored block. Pure: minimal, two lines, like the "Pure" zsh theme. You can fine-tune everything in the next questions.'
  __w_ask P10K_STYLE 'Prompt Style' 'lean|Lean.' 'classic|Classic.' 'rainbow|Rainbow.' 'pure|Pure.' || return $?
  if [[ $P10K_STYLE == pure ]]; then [[ $P10K_PALETTE == snazzy ]] || P10K_PALETTE=pure
  elif [[ $P10K_PALETTE == pure || $P10K_PALETTE == snazzy ]]; then P10K_PALETTE=original; fi
  return 0
}

__w_s_charset() {
  (( __w_pl )) || return 4
  __w_note='Unicode uses nice symbols: arrows, ❯, ⇡ and icons. Choose ASCII only if symbols looked broken in the font check; it uses plain characters like > and | instead.'
  __w_ask P10K_CHARSET 'Character Set' 'unicode|Unicode.' 'ascii|ASCII.' || return $?
  if [[ $P10K_CHARSET == ascii ]]; then P10K_ICONS=none
  elif (( __w_nerd )) && [[ $P10K_ICONS == none ]]; then P10K_ICONS=many; fi
  return 0
}

__w_s_colors() {
  case $P10K_STYLE in
    pure)
      __w_note='Original uses the classic Pure colors. Snazzy is a brighter, more saturated variant.'
      __w_ask P10K_PALETTE 'Prompt Colors' 'pure|Original.' 'snazzy|Snazzy.' || return $? ;;
    *)
      __w_note='The color theme of the prompt. "Follows your terminal" uses the 16 colors of your terminal'"'"'s own color scheme, so it always matches it, even if you change themes later. The others are fixed themes.'
      __w_ask P10K_PALETTE 'Prompt Colors' \
        'terminal|Follows your terminal color scheme.' '256|Powerlevel10k original.' \
        'tokyonight|Tokyo Night.' 'catppuccin|Catppuccin Mocha.' || return $? ;;
  esac
  [[ $P10K_PALETTE == 256 ]] && P10K_PALETTE=original
  # Shades that sit nicely on top of this terminal's own background.
  if [[ -n $__w_tbg ]] && (( __w_tdark )); then
    __w_shades cbg; P10K_CLASSIC_BG=${__w_s[2]}
    __w_shades frm; P10K_FRAME_COLOR=${__w_s[1]}
  else
    P10K_CLASSIC_BG='' P10K_FRAME_COLOR=''
  fi
  return 0
}

__w_s_cbg() {
  [[ $P10K_STYLE == classic ]] || return 4
  __w_shades cbg
  __w_note='Color of the bar behind the text.'
  [[ -n $__w_tbg ]] && __w_note+=' These shades were made from your terminal background so they blend in.'
  __w_ask P10K_CLASSIC_BG 'Prompt Background' "${__w_s[0]}|Lightest." "${__w_s[1]}|Light." \
    "${__w_s[2]}|Dark." "${__w_s[3]}|Darkest." || return $?
}

__w_s_time() {
  __w_note='Shows a clock on the right. It is the time the prompt appeared, so you can see when the previous command finished.'
  __w_ask P10K_TIME_FORMAT 'Show current time?' 'none|No.' '24|24-hour format.' '12|12-hour format (AM/PM).' || return $?
}

__w_blocky() { [[ ($P10K_STYLE == classic || $P10K_STYLE == rainbow) && $P10K_CHARSET == unicode ]]; }
__w_s_sep() {
  __w_blocky || return 4
  __w_note='The shape of the border between two blocks that touch each other.'
  __w_ask P10K_SEPARATOR 'Prompt Separators' 'angled|Angled.' 'vertical|Vertical.' 'slanted|Slanted.' 'round|Round.' || return $?
}
__w_s_head() {
  __w_blocky || return 4
  __w_note='The shape at the inner ends: where the left side stops (pointing at what you type) and where the right side begins. "Blurred" fades smoothly into the background.'
  __w_ask P10K_HEAD 'Prompt Heads' 'sharp|Sharp.' 'blurred|Blurred.' 'slanted|Slanted.' 'round|Round.' || return $?
}
__w_s_tail() {
  __w_blocky || return 4
  __w_note='The shape at the outer ends: the very left edge of the left side and the very right edge of the right side.'
  __w_ask P10K_TAIL 'Prompt Tails' 'flat|Flat.' 'blurred|Blurred.' 'sharp|Sharp.' 'slanted|Slanted.' 'round|Round.' || return $?
}

__w_s_height() {
  __w_note='One line: info and your typing share the same line. Two lines: info on top, and you type on a fresh line below, so long commands have more room.'
  __w_ask P10K_HEIGHT 'Prompt Height' '1|One line.' '2|Two lines.' || return $?
}
__w_s_conn() {
  [[ $P10K_HEIGHT == 2 && $P10K_STYLE != pure ]] || return 4
  __w_note='What fills the empty space on the top line, between the left and the right side.'
  __w_ask P10K_CONNECTION 'Prompt Connection' 'none|Nothing (empty space).' 'dotted|Dotted line.' 'solid|Solid line.' || return $?
}
__w_s_frame() {
  [[ $P10K_HEIGHT == 2 && $P10K_STYLE != pure && $P10K_CHARSET == unicode ]] || return 4
  __w_note='Thin lines that hold the two lines of the prompt together, on the left, the right, or both sides.'
  __w_ask P10K_FRAME 'Prompt Frame' 'none|No frame.' 'left|Left.' 'right|Right.' 'full|Full (both sides).' || return $?
}
__w_s_framecolor() {
  [[ $P10K_HEIGHT == 2 && $P10K_STYLE != pure ]] || return 4
  [[ $P10K_CONNECTION != none || $P10K_FRAME != none ]] || return 4
  local title='Connection Color'; [[ $P10K_FRAME != none ]] && title='Frame Color'
  __w_shades frm
  __w_note='How bright the frame and the connecting line are. Darker is calmer, lighter stands out more.'
  __w_ask P10K_FRAME_COLOR "$title" "${__w_s[0]}|Lightest." "${__w_s[1]}|Light." \
    "${__w_s[2]}|Dark." "${__w_s[3]}|Darkest." || return $?
}

__w_s_spacing() {
  __w_note='Sparse adds an empty line before every prompt, so it is easier to see where one command'"'"'s output ends and the next begins.'
  __w_ask P10K_SPACING 'Prompt Spacing' 'compact|Compact.' 'sparse|Sparse (empty line between commands).' || return $?
}
__w_s_icons() {
  [[ $P10K_ICONS != none && $P10K_STYLE != pure && $P10K_CHARSET == unicode ]] || return 4
  __w_note='Few icons: only what is needed. Many icons: an icon in front of almost everything (your OS logo, folder, git branch, clock…).'
  __w_ask P10K_ICONS 'Icons' 'few|Few icons.' 'many|Many icons.' || return $?
}
__w_s_flow() {
  [[ $P10K_STYLE != pure ]] || return 4
  __w_note='Fluent adds small words so the prompt reads like a sentence: "on main", "took 5s", "at 16:23".'
  __w_ask P10K_FLOW 'Prompt Flow' 'concise|Concise.' 'fluent|Fluent.' || return $?
}

__w_s_context() {
  [[ ${__w_place_style:-} == "$P10K_STYLE" ]] || __w_default_place
  __w_apply_place
  __w_note="Your user name and computer name ($__p10k_user@$__p10k_host). On your own computer you already know them, so Powerlevel10k normally shows them only when you are logged into another machine over SSH, or when you are root (admin), as a warning."
  __w_ask P10K_CONTEXT 'Show user@host?' \
    'remote|Only over SSH or as root (recommended).' 'always|Always.' 'user|Always, user name only.' \
    'host|Always, computer name only.' 'never|Never.' || return $?
}
__w_s_dir() {
  __w_note='How the current folder is shown. "Shortened" keeps only the first letters of the folders in the middle (still unique, so you can tell them apart), e.g. ~/s/g/project.'
  __w_ask P10K_DIR_STYLE 'Current Folder' \
    'smart|Full path; shortened only when the line gets too long (recommended).' 'unique|Always shortened.' \
    'full|Always the full path.' 'last2|Only the last two folders.' 'last|Only the current folder.' || return $?
}
__w_s_git() {
  local sv="$__p10k_g_ahead $__p10k_g_stash $__p10k_g_staged $__p10k_g_unstaged $__p10k_g_untracked" rc=0
  __p10k_g_stash=1 __p10k_g_staged=1 __p10k_g_unstaged=2 __p10k_g_untracked=3
  __w_note='Shown when you are inside a git repository. Symbols: ⇡2 = 2 commits not pushed yet, ⇣ = commits to pull, *1 = stashes, +1 = staged files, !2 = changed files, ?3 = new (untracked) files. The color also turns yellow when there are uncommitted changes.'
  __w_ask P10K_GIT_STYLE 'Git Status' 'full|Detailed.' 'compact|Compact: just a dot when something changed.' \
    'branch|Branch name only.' || rc=$?
  read -r __p10k_g_ahead __p10k_g_stash __p10k_g_staged __p10k_g_unstaged __p10k_g_untracked <<< "$sv"
  return $rc
}
__w_s_char() {
  __w_note='The symbol just before where you type. It is green normally and turns red when the last command failed.'
  [[ ($P10K_STYLE == classic || $P10K_STYLE == rainbow) && $P10K_HEIGHT == 1 ]] &&
    __w_note+=' (With your one-line style it is used by the transient prompt only; the block arrow plays this role.)'
  if [[ $P10K_CHARSET == unicode ]]; then
    __w_ask P10K_PROMPT_CHAR 'Prompt Character' '|❯  (default)' '➜|➜' 'λ|λ' '▶|▶' '→|→' '$|$' || return $?
  else
    __w_ask P10K_PROMPT_CHAR 'Prompt Character' '|>  (default)' '$|$' '%|%' || return $?
  fi
}
__w_s_status() {
  __w_note='Every command ends with an exit code: 0 means it worked, anything else is an error. Common ones: 1 = general error, 127 = command not found (typo), 130 / SIGINT = you stopped it with Ctrl+C. The prompt character also turns red after an error.'
  __w_pv=__w_preview_status
  __w_ask P10K_STATUS 'Exit Code' 'cross|Just a ✘ when a command fails.' \
    'error|✘ plus the error code when a command fails (e.g. ✘ 127 = command not found).' \
    'always|Always: ✔ when it worked, ✘ and the code when it failed.' 'never|Never.'
  local rc=$?
  __w_pv=__w_preview
  return $rc
}
__w_s_exec() {
  __w_note='Shows how long the last command ran, but only when it took longer than this. In the preview the last command took 5 seconds, so it disappears for "10 seconds" and "Never".'
  __w_ask P10K_EXEC_THRESHOLD 'Command Duration' '1|Show when longer than 1 second.' \
    '3|Show when longer than 3 seconds (recommended).' '5|Show when longer than 5 seconds.' \
    '10|Show when longer than 10 seconds.' '999999|Never.' || return $?
}
__w_s_accent() {
  local -a ac=() names=(Blue Sky Green Mauve Pink Peach Yellow Red)
  local -a hexes=('#89b4fa' '#89dceb' '#a6e3a1' '#cba6f7' '#f5c2e7' '#fab387' '#f9e2af' '#f38ba8')
  local c
  for c in "${!hexes[@]}"; do __w_sw "${hexes[c]}"; ac+=("${hexes[c]}|$REPLY ${names[c]}."); done
  __w_note='The color of the current folder, the part of the prompt you look at most. "Theme default" keeps the color of the theme you picked.'
  __w_ask P10K_ACCENT 'Accent Color' '|Theme default.' "${ac[@]}" || return $?
}

__w_s_elements() {
  local i j k idx n=${#__w_ids[@]} half=$(( (${#__w_ids[@]} + 1) / 2 )) rc=0
  __p10k_demo=2
  while :; do
    __w_apply_place
    __w_header
    printf '\e[1mPrompt Elements\e[0m\n\n'
    __w_wrap 'Choose what your prompt shows and on which side. Press an element'"'"'s key to switch it: Left → Right → Off. Press Enter when you are done. The preview uses sample values; in real use most elements only appear when they matter (see the grey notes). You can change the order later in ~/.p10k.bash.'
    __w_preview
    echo
    local -a cell=()
    local wide=0; (( __w_cols >= 170 )) && wide=1
    for (( i = 0; i < n; i++ )); do
      local tag
      case ${__w_place[${__w_ids[i]}]} in
        L) tag=$'\e[38;5;76mLeft \e[0m' ;; R) tag=$'\e[38;5;39mRight\e[0m' ;; *) tag=$'\e[2mOff  \e[0m' ;;
      esac
      __w_hint "${__w_ids[i]}"
      printf -v 'cell[i]' '(%s) %s  %-20s \e[2m%-50s\e[0m' "${__w_ekeys:i:1}" "$tag" "${__w_lbl[i]}" "$REPLY"
    done
    if (( wide )); then
      for (( i = 0; i < half; i++ )); do
        j=$(( i + half ))
        printf '  %s' "${cell[i]}"; (( j < n )) && printf '  %s' "${cell[j]}"; echo
      done
    else
      for (( i = 0; i < n; i++ )); do printf '  %s\n' "${cell[i]}"; done
    fi
    printf '\n(Enter)  Done.\n'
    __w_footer '1-9 a c-m '
    IFS= read -rsn1 k || __w_quit
    case $k in
      '') break ;;
      b|B) rc=2; break ;;
      r|R) rc=3; break ;;
      q|Q) __w_quit ;;
      *) idx=-1
         for (( i = 0; i < n; i++ )); do [[ ${__w_ekeys:i:1} == "$k" ]] && idx=$i; done
         if (( idx >= 0 )); then
           case ${__w_place[${__w_ids[idx]}]} in
             L) __w_place[${__w_ids[idx]}]=R ;; R) __w_place[${__w_ids[idx]}]=off ;; *) __w_place[${__w_ids[idx]}]=L ;;
           esac
         fi ;;
    esac
  done
  __p10k_demo=1
  __w_apply_place
  return $rc
}

__w_s_transient() {
  __w_note='After you press Enter, the big prompt above your command shrinks to just the prompt character and the command. Your scrollback stays clean and easy to read; the full prompt is always there on the line where you type.'
  __w_pv=__w_preview_transient
  __w_ask P10K_TRANSIENT_PROMPT 'Transient Prompt' '1|Yes, shrink old prompts.' '0|No, keep them as they are.'
  local rc=$?
  __w_pv=__w_preview
  return $rc
}

__w_s_save() {
  local k cfg=${__P10K_CONFIG/#$HOME/\~}
  while :; do
    __w_header
    printf '\e[1mAll done! This is your new prompt:\e[0m\n'
    __w_preview
    echo
    __w_wrap "Your settings will be saved to $cfg (you can edit that file later, or run \"p10k configure\" to do this again)."
    [[ -e $__P10K_CONFIG ]] && __w_wrap "Your current $cfg will be kept as $cfg.bak."
    echo
    __w_wrap 'Applying to ~/.bashrc adds one line so the prompt loads in every new terminal, and turns off old prompt tools there (oh-my-posh, starship…) so they do not fight with it. A backup of ~/.bashrc is made first.'
    printf '\n(y)  Save and apply to ~/.bashrc (recommended).\n\n(n)  Save, but do not touch ~/.bashrc.\n'
    __w_footer yn
    IFS= read -rsn1 k || __w_quit
    case $k in
      y|Y) __w_apply=1; return 0 ;;
      n|N) __w_apply=0; return 0 ;;
      b|B) return 2 ;;
      r|R) return 3 ;;
      q|Q) __w_quit ;;
    esac
  done
}

__w_run() {
  P10K_STYLE=lean P10K_CHARSET=unicode P10K_PALETTE=original P10K_CLASSIC_BG='' P10K_TIME_FORMAT=none
  P10K_SEPARATOR=angled P10K_HEAD=sharp P10K_TAIL=flat P10K_HEIGHT=2 P10K_CONNECTION=none
  P10K_FRAME=none P10K_FRAME_COLOR='' P10K_SPACING=compact P10K_ICONS=many P10K_ICON_PADDING=0
  P10K_FLOW=concise P10K_TRANSIENT_PROMPT=0
  P10K_CONTEXT=remote P10K_DIR_STYLE=smart P10K_GIT_STYLE=full P10K_PROMPT_CHAR='' P10K_STATUS=cross
  P10K_EXEC_THRESHOLD=3 P10K_ACCENT=''
  unset P10K_LEFT_SEGMENTS P10K_RIGHT_SEGMENTS
  __w_place_style='' __p10k_demo=1 __w_pv=__w_preview
  local -a steps=(__w_s_font __w_s_style __w_s_charset __w_s_colors __w_s_cbg __w_s_time
                  __w_s_sep __w_s_head __w_s_tail __w_s_height __w_s_conn __w_s_frame __w_s_framecolor
                  __w_s_spacing __w_s_icons __w_s_flow __w_s_context __w_s_dir __w_s_git __w_s_char
                  __w_s_status __w_s_exec __w_s_accent __w_s_elements __w_s_transient __w_s_save)
  local i=0 dir=1 rc
  while (( i < ${#steps[@]} )); do
    __w_canback=$(( i > 0 ))
    "${steps[i]}"; rc=$?
    case $rc in
      0) i=$(( i + 1 )) dir=1 ;;
      2) i=$(( i - 1 )) dir=-1 ;;
      3) return 1 ;;
      *) i=$(( i + dir )) ;;
    esac
    (( i < 0 )) && i=0 dir=1
  done
  return 0
}

__w_write_config() {
  local f=$__P10K_CONFIG left="${P10K_LEFT_SEGMENTS[*]}" right="${P10K_RIGHT_SEGMENTS[*]}"
  [[ -f $f ]] && cp "$f" "$f.bak"
  cat > "$f" <<EOF
# Generated by \`p10k configure\` on $(date '+%Y-%m-%d %H:%M').
# Edit freely, then run \`p10k reload\`. Run \`p10k configure\` to start over.

# ---- Look ----------------------------------------------------------------------------
P10K_STYLE='$P10K_STYLE'                  # lean | classic | rainbow | pure
P10K_CHARSET='$P10K_CHARSET'              # unicode | ascii
P10K_PALETTE='$P10K_PALETTE'              # terminal | original | tokyonight | catppuccin (pure: pure | snazzy)
P10K_CLASSIC_BG='$P10K_CLASSIC_BG'            # classic segment background (0-255 or '#rrggbb')
P10K_SEPARATOR='$P10K_SEPARATOR'            # angled | vertical | slanted | round
P10K_HEAD='$P10K_HEAD'                   # sharp | blurred | slanted | round
P10K_TAIL='$P10K_TAIL'                    # flat | blurred | sharp | slanted | round
P10K_ICONS='$P10K_ICONS'                   # many | few | none
P10K_ICON_PADDING=$P10K_ICON_PADDING                  # 1 = extra space after icons
P10K_TERM_BG='${P10K_TERM_BG:-}'           # your terminal background (for the smooth blur)
P10K_TERM_PALETTE=($(printf "'%s' " "${P10K_TERM_PALETTE[@]}"))

# ---- Layout --------------------------------------------------------------------------
P10K_HEIGHT=$P10K_HEIGHT                         # 1 | 2 lines
P10K_CONNECTION='$P10K_CONNECTION'            # none | dotted | solid
P10K_FRAME='$P10K_FRAME'                  # none | left | right | full
P10K_FRAME_COLOR='$P10K_FRAME_COLOR'           # frame / connection color
P10K_SPACING='$P10K_SPACING'             # compact | sparse
P10K_FLOW='$P10K_FLOW'                # concise | fluent
P10K_TRANSIENT_PROMPT=$P10K_TRANSIENT_PROMPT              # 1 = collapse old prompts to ❯
P10K_TIME_FORMAT='$P10K_TIME_FORMAT'               # none | 24 | 12
P10K_PROMPT_CHAR='$P10K_PROMPT_CHAR'               # e.g. ❯ ➜ λ ▶ → \$ (empty = ❯)
P10K_ACCENT='$P10K_ACCENT'                    # directory accent color, '#rrggbb' (empty = theme)

# ---- What the segments show ----------------------------------------------------------
P10K_CONTEXT='$P10K_CONTEXT'               # user@host: remote (SSH/root only) | always | user | host | never
P10K_DIR_STYLE='$P10K_DIR_STYLE'              # smart | unique | full | last2 | last
P10K_GIT_STYLE='$P10K_GIT_STYLE'               # full | compact | branch
P10K_STATUS='$P10K_STATUS'                 # cross (just ✘) | error (✘ + code) | always | never

# ---- Segments ------------------------------------------------------------------------
# Order here = order on screen. Available:
#   os_icon context dir vcs status command_execution_time background_jobs virtualenv toolbox
#   nix_shell python_version node_version go_version rust_version aws ram load disk_usage
#   battery shell_level time, plus your own custom_<name> (see below)
P10K_LEFT_SEGMENTS=($left)
P10K_RIGHT_SEGMENTS=($right)
P10K_EXEC_THRESHOLD=$P10K_EXEC_THRESHOLD                   # show command duration after this many seconds

# ---- Custom segments -----------------------------------------------------------------
# Write a function that sets REPLY (text) and optionally REPLY_ICON, return 1 to hide it,
# then add custom_<name> to a segment list. Example:
#   p10k_custom_weather() { REPLY='22°C'; REPLY_ICON='☀'; }
#   P10K_RIGHT_SEGMENTS+=(custom_weather)
#   P10K_COLOR[custom_weather_bg]='#f9e2af' P10K_COLOR[custom_weather_fg]='#1e1e2e'  # rainbow
#   P10K_COLOR[custom_weather_lc]='#f9e2af'                                        # lean/classic

# ---- Color overrides -----------------------------------------------------------------
# Any palette key: <segment>_bg / <segment>_fg (rainbow), <segment>_lc (lean/classic),
# segments: os dir vcs status exec jobs venv ctx time ram load batt toolbox nix node python go rust
# aws disk shlvl; also ok, err, dir_anchor, dir_short, vcs_clean, vcs_mod, vcs_untr, vcs_conf ...
declare -gA P10K_COLOR=(
  # [dir_bg]='#7aa2f7'
)
EOF
}

__w_patch_bashrc() {
  local rc=$HOME/.bashrc l out='' inblock=0 src=$__P10K_HOME/p10k.bash
  __w_disabled=()
  if [[ -f $rc ]]; then
    __w_bak="$rc.bak.p10k-$(date +%Y%m%d-%H%M%S)"
    cp "$rc" "$__w_bak"
    while IFS= read -r l || [[ -n $l ]]; do
      if [[ $l == '# >>> bash-p10k >>>' ]]; then inblock=1; continue; fi
      if (( inblock )); then [[ $l == '# <<< bash-p10k <<<' ]] && inblock=0; continue; fi
      if [[ $l =~ ^[[:space:]]*[^#[:space:]] && $l =~ (starship\ init|oh-my-posh|powerline-shell|powerline-go|liquidprompt|synth-shell-prompt) ]]; then
        out+="# [disabled by bash-p10k] $l"$'\n'; __w_disabled+=("$l")
      else out+=$l$'\n'; fi
    done < "$rc"
  fi
  out+=$'# >>> bash-p10k >>>\n'
  out+="[[ \$- == *i* && -r \"$src\" ]] && source \"$src\""$'\n'
  out+=$'# <<< bash-p10k <<<\n'
  printf '%s' "$out" > "$rc"
}

__w_main() {
  if [[ ! -t 0 || ! -t 1 ]]; then echo "p10k configure needs an interactive terminal." >&2; exit 1; fi
  __w_size
  __p10k_O='' __p10k_C='' __p10k_demo=1
  __p10k_detect_os
  __p10k_g_ok=1 __p10k_g_branch=main __p10k_g_oid='' __p10k_g_ahead=2 __p10k_g_behind=0 __p10k_g_stash=0
  __p10k_g_staged=0 __p10k_g_unstaged=0 __p10k_g_untracked=0 __p10k_g_conflict=0 __p10k_g_action=''
  __p10k_ec=0 __p10k_dur=5 __p10k_jobs=0
  __p10k_user=${USER:-$(id -un)} __p10k_host=${HOSTNAME%%.*}
  __p10k_ncpu=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
  unset P10K_LEFT_SEGMENTS P10K_RIGHT_SEGMENTS P10K_COLOR VIRTUAL_ENV CONDA_DEFAULT_ENV
  P10K_TERM_BG='' P10K_TERM_PALETTE=()
  __w_detect_bg
  until __w_run; do :; done

  mkdir -p "$__P10K_HOME"
  [[ $__P10K_SRC -ef $__P10K_HOME/p10k.bash ]] || cp "$__P10K_SRC" "$__P10K_HOME/p10k.bash"
  __w_write_config
  (( __w_apply )) && __w_patch_bashrc

  printf '\e[H\e[2J\e[3J'
  __w_header
  printf 'New config: \e[1m%s\e[0m\n' "${__P10K_CONFIG/#$HOME/\~}"
  if (( __w_apply )); then
    printf 'Backup of ~/.bashrc: \e[1m%s\e[0m\n' "${__w_bak/#$HOME/\~}"
    if (( ${#__w_disabled[@]} )); then
      printf '\nDisabled these old prompt lines in ~/.bashrc so they no longer clash:\n'
      printf '  \e[2m%s\e[0m\n' "${__w_disabled[@]}"
    fi
  fi
  printf '\nYour prompt:\n'
  __w_preview
  if [[ -n ${__P10K_FROM_SHELL:-} ]]; then printf '\nApplied: your prompt changes as soon as this screen is gone.\n'
  else printf '\nOpen a new terminal or run \e[1mexec bash\e[0m to start using it.\n'; fi
  printf 'Change it any time with \e[1mp10k configure\e[0m, or edit the config and run \e[1mp10k reload\e[0m.\n'
}

# =====================================================================================
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  if [[ ! -f $__P10K_SRC ]]; then   # e.g. bash <(curl ...): nothing on disk we could install
    echo 'Please download the file first, then run it:' >&2
    echo '  curl -fsSLo p10k.bash https://raw.githubusercontent.com/NerixGO/p10k/main/p10k.bash && bash p10k.bash' >&2
    exit 1
  fi
  case ${1:-configure} in
    configure|install) __w_main ;;
    *) echo "Usage: bash p10k.bash [configure]" >&2; exit 2 ;;
  esac
  exit 0
fi
__p10k_init
