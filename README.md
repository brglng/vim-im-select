# vim-im-select
Improve Vim/Neovim experience with input methods.

## Usage

This plugin works out of the box on Linux with iBus or Fcitx.

On macOS or Windows, [im-select](https://github.com/daipeihust/im-select) must be installed.

## Options

### `g:im_select_get_im_cmd`

This variable can be set to a list or a string of the command for getting the current IM key.

e.g.

```vim
let g:im_select_get_im_cmd = ['im-select']
```

### `g:ImSelectSetImCmd`

This variable must be a Funcref who takes the key as argument and returns the whole
command line.

e.g.

```vim
let g:ImSelectSetImCmd = {key -> ['im-select', key]}
```

### `g:ImSelectGetImCallback`

This variable must be a Funcref, which is called after the `get_im` command is exited,
returning the current IM key.

e.g.

```vim
function! GetImCallback(exit_code, stdout, stderr)
  return a:stdout
endfunction
let g:ImSelectGetImCallback = function('GetImCallback')
```

### `g:im_select_default`

This variable can be set to your own default IM key.

### `g:im_select_command`

This variable can be set to the `im-select` program path of your own (only useful on macOS and Windows).
