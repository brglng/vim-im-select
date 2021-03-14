if (exists('g:im_select_loaded') && g:im_select_loaded) || &compatible
    finish
endif
let g:im_select_loaded = 1

let s:save_cpo = &cpo
set cpo&vim

if has('nvim')
    if !exists('*jobstart')
        finish
    endif
else
    if !has('channel') || !has('job')
        finish
    endif
endif

let g:im_select_enable_for_gvim = get(g:, 'im_select_enable_for_gvim', 0)

if !has('nvim') && has('gui_running') && (has('win32') || has('win64') || has('gui_mavim'))  && !g:im_select_enable_for_gvim
    finish
endif

" OS and IM detection
if !exists('g:im_select_get_im_cmd') || !exists('g:ImSelectSetImCmd')
    let is_windows = has('win32') || has('win64') || has('win32unix') || has('wsl') || $PATH =~ '/mnt/c/WINDOWS'
    let is_mac = has('mac') || has('macunix') || has('osx') || has('osxdarwin')
    if is_windows || is_mac
        if !exists('g:im_select_command')
            let cmd = exepath('im-select')
            if cmd == ''
                echohl ErrorMsg | echomsg 'im-select is not found on your system. Please refer to https://github.com/daipeihust/im-select' | echohl None
                finish
            endif

            let g:im_select_command = cmd
        endif

        if !exists('g:im_select_default')
            if is_windows
                let g:im_select_default = '1033'
            else
                let g:im_select_default = 'com.apple.keylayout.ABC'
            endif
        endif

        let g:im_select_get_im_cmd = [g:im_select_command]
        let g:ImSelectSetImCmd = {key -> [g:im_select_command, key]}
    elseif has('unix')
        if $GTK_IM_MODULE == 'fcitx' || $QT_IM_MODULE == 'fcitx'
            let g:im_select_get_im_cmd = ['fcitx-remote']
            let g:ImSelectSetImCmd = {
              \ key ->
              \ key == 1 ? ['fcitx-remote', '-c'] :
              \ key == 2 ? ['fcitx-remote', '-o'] :
              \ execute("throw 'invalid im key'")
              \ }
            if !exists('g:im_select_default')
                let g:im_select_default = '1'
            endif
        elseif $GTK_IM_MODULE == 'fcitx5' || $QT_IM_MODULE == 'fcitx5'
            let g:im_select_get_im_cmd = ['fcitx5-remote']
            let g:ImSelectSetImCmd = {
              \ key ->
              \ key == 1 ? ['fcitx5-remote', '-c'] :
              \ key == 2 ? ['fcitx5-remote', '-o'] :
              \ execute("throw 'invalid im key'")
              \ }
            if !exists('g:im_select_default')
                let g:im_select_default = '1'
            endif
        elseif match($XDG_CURRENT_DESKTOP, '\cgnome') >= 0
            if $GTK_IM_MODULE == 'ibus' || $QT_IM_MODULE == 'ibus'
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
                let g:ImSelectSetImCmd = {
                \ key ->
                \ key == 1 ? ['fcitx-remote', '-c'] :
                \ key == 2 ? ['fcitx-remote', '-o'] :
                \ execute("throw 'invalid im key'")
                \ }
                if !exists('g:im_select_default')
                    let g:im_select_default = '1'
                endif
            elseif $GTK_IM_MODULE == 'fcitx5' || $QT_IM_MODULE == 'fcitx5'
                let g:im_select_get_im_cmd = ['fcitx5-remote']
                let g:ImSelectSetImCmd = {
                            \ key ->
                            \ key == 1 ? ['fcitx5-remote', '-c'] :
                            \ key == 2 ? ['fcitx5-remote', '-o'] :
                            \ execute("throw 'invalid im key'")
                            \ }
                if !exists('g:im_select_default')
                    let g:im_select_default = '1'
                endif
            endif
        endif
    endif
endif

if !exists('g:im_select_get_im_cmd') || !exists('g:ImSelectSetImCmd')
    finish
endif

let g:ImSelectGetImCallback = get(g:, 'ImSelectGetImCallback', function('im_select#default_get_im_callback'))
let g:im_select_switch_timeout = get(g:, 'im_select_switch_timeout', 50)
let g:im_select_enable_focus_events = get(g:, 'im_select_enable_focus_events', 1)

let g:im_select_prev_im = ''

function! im_select#enable() abort
    augroup im_select
        autocmd!
        autocmd InsertEnter * call im_select#on_insert_enter()
        if exists('##TermEnter')
            autocmd TermEnter * call im_select#on_insert_enter()
        endif
        autocmd InsertLeave * call im_select#on_insert_leave()
        if exists('##TermLeave')
            autocmd TermLeave * call im_select#on_insert_leave()
        endif
        if g:im_select_enable_focus_events
            autocmd FocusGained * call im_select#on_focus_gained()
            autocmd FocusLost * call im_select#on_focus_lost()
        endif
        autocmd VimLeavePre * call im_select#on_vim_leave_pre()
    augroup END
endfunction

function! im_select#disable() abort
    autocmd! im_select
endfunction

command! -nargs=0 ImSelectEnable call im_select#enable()
command! -nargs=0 ImSelectDisable call im_select#disable()

call im_select#enable()

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: ts=8 sts=4 sw=4 et
