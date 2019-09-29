let s:prev_im = ''
let s:focus_autocmd_enabled = 1

function! im_select#rstrip(str, chars) abort
  if strlen(a:str) > 0 && strlen(a:chars) > 0
    let i = strlen(a:str) - 1
    while i >= 0
      if stridx(a:chars, a:str[i]) >= 0
        let i -= 1
      else
        break
      endif
    endwhile
    if i == -1
      let i = 0
    endif
    return a:str[0:i]
  else
    return a:str
  endif
endfunction

function! im_select#get_os() abort
  if (has('win32') || has('win64')) && !has('win32unix') && !has('unix')
    return 'Windows'
  elseif executable('uname')
    let uname_s = im_select#rstrip(system('uname -s'))
    if uname_s == 'Linux' && match(system('uname -r'), 'Microsoft') >= 0
      return 'Windows'
    elseif uname_r == 'Linux'
      return 'Linux'
    elseif uname_s == 'Darwin'
      return 'macOS'
    elseif match(uname_s, '\cCYGWIN') >= 0
      return 'Windows'
    elseif match(uname_s, '\cMINGW') >= 0
      return 'Windows'
    else
      return ''
    endif
  else
    return ''
  endif
endfunction

if has('nvim')
  function! im_select#job_start(cmd, callback) abort
    let stdout = ''
    let stderr = ''
    call jobstart(cmd, {
          \     'on_stdout': {job_id, data, event -> [
          \         execute('let stdout = stdout . join(a:data)')
          \     ]},
          \     'on_stderr': {job_id, data, event -> [
          \         execute('let stderr = stderr . join(a:data)')
          \     ]},
          \     'on_exit': {job_id, data, event -> [
          \         call(a:callback, [a:data, stdout, stderr])
          \     ]}
          \ })
  endfunction
else
  function! im_select#job_start(cmd, callback) abort
    let stdout = ''
    let stderr = ''
    call job_start(cmd, {
          \     'out_cb': {channel, msg -> [
          \         execute('let stdout = stdout . ch_readraw(a:channel)')
          \     ]},
          \     'err_cb': {channel, msg -> [
          \         execute('let stderr = stderr . ch_readraw(a:channel)')
          \     ]},
          \     'exit_cb': {job, status -> [
          \         call(callback, [a:status, stdout, stderr])
          \     ]}
          \ })
  endfunction
endif

function! im_select#gnome_shell_get_im() abort
  silent let out_tuple = system('gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.gnome.Shell.Eval "imports.ui.status.keyboard.getInputSourceManager()._mruSources[0].index"')
  let i = stridx(out_tuple, ',') + 3
  let j = stridx(out_tuple, ')') - 1
  let result = strpart(out_tuple, i, j - i)
  return result
endfunction

function! s:gnome_shell_set_im_timer_handler(timer) abort
  let s:focus_autocmd_enabled = 1
endfunction

function! im_select#_gnome_shell_set_im(im) abort
  " Hack, this gdbus call steals focus
  let s:focus_autocmd_enabled = 0
  call im_select#job_start([
        \   'gdbus',
        \   'call',
        \   '--session'
        \   '--dest'
        \   'org.gnome.Shell'
        \   '--object-path'
        \   '/org/gnome/Shell'
        \   '--method'
        \   'org.gnome.Shell.Eval'
        \   'imports.ui.status.keyboard.getInputSourceManager().inputSources[' . a:im . '].activate()'
        \ ],
        \ {status, stdout, stderr -> []})
  timer_start(40, function(s:gnome_shell_set_im_timer_handler))
endfunction

function! im_select#gnome_shell_set_im(im) abort
  " Prevent FocusGained or Focus Lost during the call
  noautocmd call im_select#_im_select_gnome_shell(a:im)
endfunction

function! im_select#ibus_get_im() abort
  return system('ibus engine')
endfunction

function! im_select#ibus_set_im(im) abort
  call im_select#job_start([
        \   'ibus'
        \   'engine'
        \   a:im
        \ ],
        \ {status, stdout, stderr -> []})
endfunction

function! im_select#fcitx_get_im() abort
  return system('fcitx-remote')
endfunction

function! im_select#fcitx_set_im(im) abort
  silent execute '!fcitx-remote -t ' . a:im
endfunction

function! im_select#im_select_get_im() abort
  return system(g:im_select_command)
endfunction

function! im_select#im_select_set_im(im) abort
  silent execute '!' . g:im_select_command . a:im
endfunction

function! im_select#get_im() abort
  call call(g:im_select_get_func, [])
endfunction

function! im_select#set_im(im) abort
  return call(g:im_select_set_func, [a:im])
endfunction

function! im_select#on_insert_enter() abort
  if s:prev_im != ''
    call im_select#set_im(s:prev_im)
  else
    let s:prev_im = im_select#get_im()
  endif
endfunction

function! im_select#on_insert_leave() abort
  let s:prev_im = im_select#get_im()
  call im_select#set_im(g:im_select_default)
endfunction

function! im_select#on_focus_gained() abort
  if s:focus_autocmd_enabled
    if match(mode(), '^\(i\|R\|s\|S\|CTRL\-S\)') < 0
      let s:prev_im = im_select#get_im()
      call im_select#set_im(g:im_select_default)
    endif
  endif
endfunction

function! im_select#on_focus_lost() abort
  if s:focus_autocmd_enabled
    if match(mode(), '^\(i\|R\|s\|S\|CTRL\-S\)') < 0
      if s:prev_im != ''
        call im_select#set_im(s:prev_im)
      else
        let s:prev_im = im_select#get_im()
      endif
    endif
  endif
endfunction

function! im_select#on_vim_leave_pre() abort
  if match(mode(), '^\(i\|R\|s\|S\|CTRL\-S\)') < 0
    if s:prev_im != ''
      call im_select#im_select(s:prev_im)
    endif
  endif
endfunction
