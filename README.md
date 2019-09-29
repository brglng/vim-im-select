# vim-im-select
Improve Vim/Neovim experience with input methods.

## Usage

This plugin works out of the box on Linux with iBus or Fcitx.

On macOS or Windows, [im-select](https://github.com/daipeihust/im-select) must be installed.

## Options

`g:ImSelectGetFunc` can be set to a function name or Funcref with the following prototype:

```vim
function! ImGet()
  ...
endfunction
```

`g:ImSelectGetFunc` can be set to a function name or Funcref with the following prototype:

```vim
function! ImSet(key)
  ...
endfunction
```

`g:im_select_default` can be set to your own default IM key.

`g:im_select_command` can be set to the `im-select` program path of your own.
