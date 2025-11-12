"
" internal dot# interface
"

let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

function _op_#dot#ComputeMapCallback(dummy) abort
    call s:RestoreEntry(_op_#stack#Top())
    call _op_#op#ComputeMapCallback()
    let &operatorfunc = '_op_#dot#RepeatCallback'
endfunction

function _op_#dot#RepeatCallback(dummy) abort
    "TODO setup entry mode
    let l:handle = _op_#op#GetHandle('dot')
    let l:expr = _op_#op#ExprWithModifiers(l:handle)
    call feedkeys(l:expr)
endfunction

function s:RestoreEntry(handle) abort
    if a:handle['init']['entry_mode'] ==# 'n'
        call setpos('.', a:handle['dot']['cur_start'])
    elseif a:handle['init']['entry_mode'] =~# '\v^[vV]$'
        let l:selectmode = &selectmode | set selectmode=
        normal! gv
        let &selectmode = l:selectmode
    endif
endfunction

let &cpo = s:cpo
unlet s:cpo
