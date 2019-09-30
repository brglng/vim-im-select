let s:focus_event_enabled = 1

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
  let s:ImSetJob = {}

  function s:ImSetJob.new(cmd) abort
    let object = copy(s:ImSetJob)
    let object.cmd = a:cmd
    let object.id = jobstart(object.cmd, object)
    return object
  endfunction

  let s:ImGetJob = {}

  function s:ImGetJob.on_stdout(job_id, data, event) abort
    let self.stdout = self.stdout . join(a:data)
  endfunction

  function s:ImGetJob.on_stderr(job_id, data, event) abort
    let self.stderr = self.stderr . join(a:data)
  endfunction

  function s:ImGetJob.on_exit(job_id, data, event) abort
    let self.result = call(self.callback, [a:data, self.stdout, self.stderr])
    if self.set_prev_im
      let g:im_select_prev_im = self.result
    endif
  endfunction

  function s:ImGetJob.wait() abort
    call jobwait([self.id])
  endfunction

  function s:ImGetJob.new(cmd, callback, set_prev_im) abort
    let object = copy(s:ImGetJob)
    let object.cmd = a:cmd
    let object.callback = a:callback
    let object.set_prev_im = a:set_prev_im
    let object.stdout = ''
    let object.stderr = ''
    let object.id = jobstart(object.cmd, object)
    return object
  endfunction
else
  let s:ImSetJob = {}

  function s:ImSetJob.new(cmd) abort
    let object = copy(s:ImSetJob)
    let object.cmd = a:cmd
    let object.id = job_start(object.cmd)
    return object
  endfunction

  let s:ImGetJob = {}

  function s:ImGetJob.out_cb(channel, msg) abort
    while ch_status(a:channel, {'part': 'out'}) == 'buffered'
      let self.stdout = self.stdout . ch_readraw(a:channel)
    endwhile
  endfunction

  function s:ImGetJob.err_cb(channel, msg) abort
    while ch_status(a:channel, {'part': 'err'}) == 'buffered'
      let self.stderr = self.stderr . ch_readraw(a:channel)
    endwhile
  endfunction

  function s:ImGetJob.exit_cb(job, status) abort
    let self.result = call(self.callback, [a:status, self.stdout, self.stderr])
    if self.set_prev_im
      let g:im_select_prev_im = self.result
    endif
    let self.is_running = 0
  endfunction

  function s:ImGetJob.wait() abort
    while self.is_running
      sleep 10m
    endwhile
  endfunction

  function s:ImGetJob.new(cmd, callback, set_prev_im) abort
    let object = copy(s:ImGetJob)
    let object.cmd = a:cmd
    let object.callback = function(a:callback)
    let object.set_prev_im = a:set_prev_im
    let object.stdout = ''
    let object.stderr = ''
    let object.id = job_start(object.cmd, {
          \ 'out_cb': object.out_cb,
          \ 'err_cb': object.err_cb,
          \ 'exit_cb': object.exit_cb
          \ })
    let object.is_running = 1
    return object
  endfunction
endif

function! im_select#gnome_shell_get_im_callback(status, stdout, stderr) abort
  let i = stridx(a:stdout, ',') + 3
  let j = stridx(a:stdout, ')') - 1
  let result = strpart(a:stdout, i, j - i)
  return result
endfunction

function! im_select#default_get_im_callback(status, stdout, stderr) abort
  return im_select#rstrip(a:stdout)
endfunction

function! im_select#get_and_set_prev_im() abort
  return s:ImGetJob.new(g:im_select_get_im_cmd, g:ImSelectGetImCallback, 1)
endfunction

function! im_select#get_im() abort
  let j = s:ImGetJob.new(g:im_select_get_im_cmd, g:ImSelectGetImCallback, 0)
  call j.wait()
  return j.result
endfunction

function! im_select#focus_event_timer_handler(timer) abort
  let s:focus_event_enabled = 1
endfunction

function! im_select#set_im(im) abort
  " workaround for some set_im commands who steal the focus
  if im_select#get_im() != a:im
    let s:focus_event_enabled = 0
    call timer_start(50, 'im_select#focus_event_timer_handler')
    call s:ImSetJob.new(call(g:ImSelectSetImCmd, [a:im]))
  endif
endfunction

function! im_select#on_insert_enter() abort
  if g:im_select_prev_im != ''
    call im_select#set_im(g:im_select_prev_im)
  else
    call im_select#get_and_set_prev_im()
  endif
endfunction

function! im_select#on_insert_leave() abort
  let j = im_select#get_and_set_prev_im()
  call j.wait()
  call im_select#set_im(g:im_select_default)
endfunction

function! im_select#on_focus_gained() abort
  if s:focus_event_enabled
    if match(mode(), '^\(i\|R\|s\|S\|CTRL\-S\)') < 0
      let j = im_select#get_and_set_prev_im()
      call j.wait()
      call im_select#set_im(g:im_select_default)
    endif
  endif
endfunction

function! im_select#on_focus_lost() abort
  if s:focus_event_enabled
    if match(mode(), '^\(i\|R\|s\|S\|CTRL\-S\)') < 0
      if g:im_select_prev_im != ''
        call im_select#set_im(g:im_select_prev_im)
      else
        call im_select#get_and_set_prev_im()
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
