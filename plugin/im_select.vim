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

if !exists('g:im_select_enable_for_win32_gvim')
    let g:im_select_enable_for_win32_gvim = 0
endif

if !has('nvim') && has('win32') && has('gui_running') && !g:im_select_enable_for_win32_gvim
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
                echohl ErrorMsg | echomsg "Please set the default IM manually on Windows." | echohl None
                finish
            endif
            let g:im_select_default = 'com.apple.keylayout.ABC'
        endif

        let g:im_select_get_im_cmd = [g:im_select_command]
        let g:ImSelectSetImCmd = {key -> [g:im_select_command, key]}
    elseif has('unix')
        if $GTK_IM_MODULE == 'fcitx' || $QT_IM_MODULE == 'fcitx'
            let g:im_select_get_im_cmd = ['fcitx-remote']
            let g:ImSelectSetImCmd = {key -> ['fcitx-remote', '-t', key]}
            if !exists('g:im_select_default')
                let g:im_select_default = '1'
            endif
        elseif match($XDG_CURRENT_DESKTOP, '\cgnome') >= 0
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

" vim: ts=8 sts=4 sw=4 et
