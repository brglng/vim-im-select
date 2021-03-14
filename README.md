# vim-im-select
Improve Vim/Neovim experience with input methods.

Basically, this plugin does these things:

- Switch to the default IM of your choice on `InsertLeave`
- Switch back to your previous IM on `InsertEnter`
- Switch to the default IM of your choice on `FocusGained` if you are in
  normal mode, or do nothing if not
- Switch back to your previous IM on `FocusLost` if you are in normal mode, or
  do nothing if not
- If you are using a GUI (e.g., GVim), switch back to your previous IM before
  exiting Vim if you are in normal mode, or do nothing if you are in insert
  mode. If you are under a terminal, switch to the default IM of your choice
  before exiting Vim.

## Requirements

Neovim or Vim with `+job` is required.

This plugin works out of the box on Linux with iBus or Fcitx.

On macOS or Windows, [im-select](https://github.com/daipeihust/im-select) must
be installed.

## Tmux

[tmux-plugins/vim-tmux-focus-events](https://github.com/tmux-plugins/vim-tmux-focus-events)
is recommended if you are using Tmux. This plugin provides `FocusGained` and
`FocusLost` events for (Neo)Vim under Tmux. (NOTE: It is reported that this
plugin does not work well with Vim/Vim cannot recognize the terminal code from
this plugin, however it works well with Neovim.)

## Commands

### `ImSelectEnable`

Enable this plugin if not enabled.

### `ImSelectDisable`

Disable this plugin.

## Options

### `g:im_select_get_im_cmd`

This variable can be set to a list or a string of the command for getting the
current IM key.

e.g.

```vim
let g:im_select_get_im_cmd = ['im-select']
```

### `g:ImSelectSetImCmd`

This variable must be a Funcref who takes the key as argument and returns the
whole command line.

e.g.

```vim
let g:ImSelectSetImCmd = {key -> ['im-select', key]}
```

### `g:ImSelectGetImCallback`

This variable must be a Funcref, which is called after the `get_im` command is
exited, returning the current IM key.

e.g.

```vim
function! GetImCallback(exit_code, stdout, stderr) abort
    return a:stdout
endfunction
let g:ImSelectGetImCallback = function('GetImCallback')
```

### `g:im_select_default`

This variable can be set to your own default IM key.

e.g.

```vim
let g:im_select_default = 'com.apple.keylayout.ABC'   " The default value on macOS
let g:im_select_default = '1033'                      " The default value on Windows
```

You can get your current IM key by `im-select`.

```bash
$ im-select
com.apple.keylayout.ABC
```

You are likely to get `com.apple.keylayout.Dvorak` if you use Dvorak keyboard layout on macOS.

### `g:im_select_command`

This variable can be set to the `im-select` program path of your own (only
useful on macOS and Windows).

### `g:im_select_switch_timeout`

The timeout during which events are not responded, in milliseconds.

Some IM switching commands steals focus, e.g., the `gdbus` program on GNOME
desktop. This will trigger `FocusLost` and `FocusGained` events, which causes
problems. This option setups the timeout after the IM is switched. During the
timeout, events are not responded. The default value is 50.

### `g:im_select_enable_focus_events`

Whether or not to enable `FocusLost` and `FocusGained` events. If your desktop
already switches input methods among different windows/applications (e.g.,
this is the default setting on KDE), you may want to set this option to 0. The
default value is 1.

### `g:im_select_enable_for_gvim`

The plugin is disabled on GVim for Windows or MacVim, as GVim for Windows and
MacVim already supports IM auto-switching. Set this variable to 1 if you want
to enable anyway.

<!-- vim: cc=79
-->
