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
    let uname_s = im_select#rstrip(system('uname -s'), "\r\n")
    if uname_s ==# 'Linux' && match(system('uname -r'), 'Microsoft') >= 0
      return 'Windows'
    elseif uname_s ==# 'Linux'
      return 'Linux'
    elseif uname_s ==# 'Darwin'
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
  let s:Job = {}

  function s:Job.on_stdout(_job_id, data, _event)
    let self.stdout = self.stdout . join(a:data)
  endfunction

  function s:Job.on_stderr(_job_id, data, _event)
    let self.stderr = self.stderr . join(a:data)
  endfunction

  function s:Job.on_exit(_job_id, data, _event)
    call call(self.callback, [a:data, self.stdout, self.stderr])
  endfunction

  function s:Job.new(cmd, callback)
    let object = copy(s:Job)
    let object.cmd = a:cmd
    let object.callback = a:callback
    let object.stdout = ''
    let object.stderr = ''
    let object.id = jobstart(object.cmd, object)
    return object
  endfunction
else
  let s:Job = {}

  function s:Job.out_cb(channel, _msg)
    let self.stdout = self.stdout . ch_readraw(a:channel)
  endfunction

  function s:Job.err_cb(channel, _msg)
    let self.stderr = self.stderr . ch_readraw(a:channel)
  endfunction

  function s:Job.exit_cb(_job, status)
    call call(self.callback, [a:status, self.stdout, self.stderr])
  endfunction

  function s:Job.new(cmd, callback)
    let object = copy(im_select#job)
    let object.cmd = a:cmd
    let object.callback = a:callback
    let object.stdout = ''
    let object.stderr = ''
    let object.id = job_start(object.cmd, object)
    return object
  endfunction
endif

function! im_select#gnome_shell_get_im() abort
  silent let out_tuple = system('gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.gnome.Shell.Eval "imports.ui.status.keyboard.getInputSourceManager()._mruSources[0].index"')
  let i = stridx(out_tuple, ',') + 3
  let j = stridx(out_tuple, ')') - 1
  let result = strpart(out_tuple, i, j - i)
  return result
endfunction

function! im_select#_gnome_shell_set_im_timer_handler(timer) abort
  let s:focus_autocmd_enabled = 1
endfunction

function! im_select#gnome_shell_set_im(im) abort
  " Hack, this gdbus call steals focus
  let s:focus_autocmd_enabled = 0
  call s:Job.new([
        \   'gdbus',
        \   'call',
        \   '--session',
        \   '--dest',
        \   'org.gnome.Shell',
        \   '--object-path',
        \   '/org/gnome/Shell',
        \   '--method',
        \   'org.gnome.Shell.Eval',
        \   'imports.ui.status.keyboard.getInputSourceManager().inputSources[' . a:im . '].activate()'
        \ ],
        \ {status, stdout, stderr -> []})
  call timer_start(40, "im_select#_gnome_shell_set_im_timer_handler")
endfunction

function! im_select#ibus_get_im() abort
  return system('ibus engine')
endfunction

function! im_select#ibus_set_im(im) abort
  call s:Job.new([
        \   'ibus',
        \   'engine',
        \   a:im
        \ ],
        \ {status, stdout, stderr -> []})
endfunction

function! im_select#fcitx_get_im() abort
  return im_select#rstrip(system('fcitx-remote'))
endfunction

function! im_select#fcitx_set_im(im) abort
  silent execute '!fcitx-remote -t ' . a:im
endfunction

function! im_select#im_select_get_im() abort
  return im_select#rstrip(system(g:im_select_command), "\r\n")
endfunction

function! im_select#im_select_set_im(im) abort
  silent execute '!' . g:im_select_command . ' ' . a:im
endfunction

function! im_select#get_im() abort
  return call(g:ImSelectGetFunc, [])
endfunction

function! im_select#set_im(im) abort
  call call(g:ImSelectSetFunc, [a:im])
endfunction

function! im_select#on_insert_enter() abort
  if g:im_select_prev_im != ''
    call im_select#set_im(g:im_select_prev_im)
  else
    let g:im_select_prev_im = im_select#get_im()
  endif
endfunction

function! im_select#on_insert_leave() abort
  let g:im_select_prev_im = im_select#get_im()
  call im_select#set_im(g:im_select_default)
endfunction

function! im_select#on_focus_gained() abort
  if s:focus_autocmd_enabled
    if match(mode(), '^\(i\|R\|s\|S\|CTRL\-S\)') < 0
      let g:im_select_prev_im = im_select#get_im()
      call im_select#set_im(g:im_select_default)
    endif
  endif
endfunction

function! im_select#on_focus_lost() abort
  if s:focus_autocmd_enabled
    if match(mode(), '^\(i\|R\|s\|S\|CTRL\-S\)') < 0
      if g:im_select_prev_im != ''
        call im_select#set_im(g:im_select_prev_im)
      else
        let g:im_select_prev_im = im_select#get_im()
      endif
    endif
  endif
endfunction

function! im_select#on_vim_leave_pre() abort
  if match(mode(), '^\(i\|R\|s\|S\|CTRL\-S\)') < 0
    if g:im_select_prev_im != ''
      call im_select#set_im(g:im_select_prev_im)
    endif
  endif
endfunction
