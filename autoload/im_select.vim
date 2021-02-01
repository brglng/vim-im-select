let s:focus_event_enabled = 1

if has('nvim')
    if exists('g:GuiLoaded')
        if g:GuiLoaded != 0
            let s:gui = 1
        endif
    elseif exists('*nvim_list_uis') && len(nvim_list_uis()) > 0
        let uis = nvim_list_uis()[0]
        let s:gui = get(uis, 'ext_termcolors', 0)? 0 : 1
    elseif exists("+termguicolors") && (&termguicolors) != 0
        let s:gui = 1
    endif
else
    let s:gui = has('gui_running')
endif

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

if has('nvim')
    let s:ImSetJob = {}

    function s:ImSetJob.wait() abort
        call jobwait([self.id])
    endfunction

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
        let self.result = call(self.callback, [a:data, im_select#rstrip(self.stdout, " \r\n"), im_select#rstrip(self.stderr, " \r\n")])
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

    function s:ImSetJob.exit_cb(job, status) abort
        let self.is_running = 0
    endfunction

    function s:ImSetJob.wait() abort
        while self.is_running
            sleep 10m
        endwhile
    endfunction

    function s:ImSetJob.new(cmd) abort
        let object = copy(s:ImSetJob)
        let object.cmd = a:cmd
        let object.id = job_start(object.cmd, {
          \ 'exit_cb': object.exit_cb
          \ })
        let object.is_running = 1
        return object
    endfunction

    let s:ImGetJob = {}

    function s:ImGetJob.out_cb(channel, msg) abort
        let self.stdout = self.stdout . a:msg
    endfunction

    function s:ImGetJob.err_cb(channel, msg) abort
        let self.stderr = self.stderr . a:msg
    endfunction

    function s:ImGetJob.exit_cb(job, status) abort
        let self.result = call(self.callback, [a:status, im_select#rstrip(self.stdout, " \r\n"), im_select#rstrip(self.stderr, " \r\n")])
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
    return a:stdout
endfunction

function! im_select#get_and_set_prev_im(callback) abort
    return s:ImGetJob.new(g:im_select_get_im_cmd, a:callback, 1)
endfunction

function! im_select#get_im(callback) abort
    let j = s:ImGetJob.new(g:im_select_get_im_cmd, a:callback, 0)
endfunction

function! im_select#focus_event_timer_handler(timer) abort
    let s:focus_event_enabled = 1
endfunction

function! im_select#set_im_get_im_callback(im, code, stdout, stderr) abort
    let cur_im = call(g:ImSelectGetImCallback, [a:code, a:stdout, a:stderr])
    if cur_im != a:im
        " workaround for some set_im commands who steal the focus
        let s:focus_event_enabled = 0
        call timer_start(g:im_select_switch_timeout, 'im_select#focus_event_timer_handler')
        let j = s:ImSetJob.new(call(g:ImSelectSetImCmd, [a:im]))
    endif
    return cur_im
endfunction

function! im_select#set_im(im) abort
    call im_select#get_im(function('im_select#set_im_get_im_callback', [a:im]))
endfunction

" let s:insert_enter_count = 0
function! im_select#on_insert_enter() abort
    " let s:insert_enter_count += 1
    " echomsg 'InsertEnter: ' . s:insert_enter_count . ', mode: ' . mode() . ', event: ' . string(v:event)
    if s:focus_event_enabled
        if g:im_select_prev_im != ''
            call im_select#set_im(g:im_select_prev_im)
        else
            call im_select#get_and_set_prev_im(g:ImSelectGetImCallback)
        endif
    endif
endfunction

function! im_select#on_insert_leave_get_im_callback(code, stdout, stderr) abort
    let cur_im = call(g:ImSelectGetImCallback, [a:code, a:stdout, a:stderr])
    call im_select#set_im(g:im_select_default)
    return cur_im
endfunction

" let s:insert_leave_count = 0
function! im_select#on_insert_leave() abort
    " let s:insert_leave_count += 1
    " echomsg 'InsertLeave: ' . s:insert_leave_count . ', mode: ' . mode() . ', event: ' . string(v:event)
    if s:focus_event_enabled
        let j = im_select#get_and_set_prev_im('im_select#on_insert_leave_get_im_callback')
    endif
endfunction

function! im_select#on_focus_gained_get_im_callback(code, stdout, stderr) abort
    let cur_im = call(g:ImSelectGetImCallback, [a:code, a:stdout, a:stderr])
    call im_select#set_im(g:im_select_default)
    return cur_im
endfunction

" let s:focus_gained_count = 0
function! im_select#on_focus_gained() abort
    " let s:focus_gained_count += 1
    " echomsg 'FocusGained: ' . s:focus_gained_count
    if s:focus_event_enabled
        if match(mode(), '^\(i\|R\|s\|S\|t\|CTRL\-S\)') < 0
            let j = im_select#get_and_set_prev_im('im_select#on_focus_gained_get_im_callback')
        endif
    endif
endfunction

" let s:focus_lost_count = 0
function! im_select#on_focus_lost() abort
    " let s:focus_lost_count += 1
    " echomsg 'FocusLost: ' . s:focus_lost_count
    if s:focus_event_enabled
        if match(mode(), '^\(i\|R\|s\|S\|t\|CTRL\-S\)') < 0
            if g:im_select_prev_im != ''
                call im_select#set_im(g:im_select_prev_im)
            else
                call im_select#get_and_set_prev_im(g:ImSelectGetImCallback)
            endif
        endif
    endif
endfunction

function! im_select#on_vim_leave_pre() abort
    if s:gui
        if match(mode(), '^\(i\|R\|s\|S\|t\|CTRL\-S\)') < 0
            if g:im_select_prev_im != ''
                execute 'silent! !' . join(call(g:ImSelectSetImCmd, [g:im_select_prev_im]), ' ')
            endif
        endif
    else
        execute 'silent! !' . join(call(g:ImSelectSetImCmd, [g:im_select_default]), ' ')
    endif
endfunction

" vim: ts=8 sts=4 sw=4 et
