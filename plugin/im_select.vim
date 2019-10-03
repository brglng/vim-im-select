if exists('g:im_select_loaded') && g:im_select_loaded
  finish
endif
let g:im_select_loaded = 1

let s:save_cpo = &cpo
set cpo&vim

if !has('nvim') && has('win32') && has('gui_running')
  " GVim already supports automatic IM switching
  finish
endif

if has('nvim')
  if !exists('*jobstart')
    finish
  endif
else
  if !has('channel') || !has('job')
    finish
  endif
endif

" OS and IM detection
if !exists('g:im_select_get_im_cmd') || !exists('g:ImSelectSetImCmd')
  let os = im_select#get_os()
  if os == 'Linux'
    if $GTK_IM_MODULE == 'fcitx' || $QT_IM_MODULE == 'fcitx'
      let g:im_select_get_im_cmd = ['fcitx-remote']
      let g:ImSelectSetImCmd = {key -> ['fcitx-remote', '-t', key]}
      if !exists('g:im_select_default')
        let g:im_select_default = '1'
      endif
    elseif match($XDG_CURRENT_DESKTOP, '\cgnome')
      if $GTK_IM_MODULE == 'ibus'
        let g:im_select_get_im_cmd = [
              \ 'gdbus', 'call', '--session',
              \ '--dest', 'org.gnome.Shell',
              \ '--object-path', '/org/gnome/Shell',
              \ '--method', 'org.gnome.Shell.Eval',
              \ 'imports.ui.status.keyboard.getInputSourceManager()._mruSources[0].index'
              \ ]
        let g:ImSelectSetImCmd = {key -> [
              \ 'gdbus', 'call', '--session',
              \ '--dest', 'org.gnome.Shell',
              \ '--object-path', '/org/gnome/Shell',
              \ '--method', 'org.gnome.Shell.Eval',
              \ 'imports.ui.status.keyboard.getInputSourceManager().inputSources[' . key . '].activate()'
              \ ]}
        let g:ImSelectGetImCallback = function('im_select#gnome_shell_get_im_callback')
        if !exists('g:im_select_default')
          let g:im_select_default = '0'
        endif
      endif
    else
      if $GTK_IM_MODULE == 'ibus' || $QT_IM_MODULE == 'ibus'
        let g:im_select_get_im_cmd = ['ibus', 'engine']
        let g:ImSelectSetImCmd = {key -> ['ibus', 'engine', key]}
        if !exists('g:im_select_default')
          let g:im_select_default = 'xkb:us::eng'
        endif
      elseif $GTK_IM_MODULE == 'fcitx' || $QT_IM_MODULE == 'fcitx'
        let g:im_select_get_im_cmd = ['fcitx-remote']
        let g:ImSelectSetImCmd = {key -> ['fcitx-remote', '-t', key]}
        if !exists('g:im_select_default')
          let g:im_select_default = '1'
        endif
      endif
    endif
  elseif os == 'macOS' || os == 'Windows'
    if !exists('g:im_select_command')
      if os == 'macOS'
        let cmd = im_select#rstrip(system('which im-select'), "\r\n")
      else
        let cmd = im_select#rstrip(system('where.exe im-select.exe'), "\r\n")
      endif

      if cmd == ''
        echohl ErrorMsg | echomsg 'im-select is not found on your system. Please refer to https://github.com/daipeihust/im-select' | echohl None
        finish
      endif

      let g:im_select_command = cmd
    endif

    if !exists('g:im_select_default')
      if os == 'Windows'
        echohl ErrorMsg | echomsg "Please set the default IM manually on Windows." | echohl None
        finish
      endif
      let g:im_select_default = 'com.apple.keylayout.ABC'
    endif

    let g:im_select_get_im_cmd = [g:im_select_command]
    let g:ImSelectSetImCmd = {key -> [g:im_select_command, key]}
  endif
endif

if !exists('g:im_select_get_im_cmd') || !exists('g:ImSelectSetImCmd')
  finish
endif

if !exists('g:ImSelectGetImCallback')
  let g:ImSelectGetImCallback = function('im_select#default_get_im_callback')
endif

let g:im_select_prev_im = ''

augroup im_select
  autocmd!
  autocmd InsertEnter * call im_select#on_insert_enter()
  autocmd InsertLeave * call im_select#on_insert_leave()
  autocmd FocusGained * call im_select#on_focus_gained()
  autocmd FocusLost * call im_select#on_focus_lost()
  autocmd VimLeavePre * call im_select#on_vim_leave_pre()
augroup END

let &cpo = s:save_cpo
unlet s:save_cpo
