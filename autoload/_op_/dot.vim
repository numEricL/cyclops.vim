"
" internal dot# interface
"

let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

function _op_#dot#ComputeMapCallback(dummy) abort
    call s:RestoreEntryMode(_op_#stack#Top())
    call _op_#op#ComputeMapCallback()
    let &operatorfunc = '_op_#dot#DotCallback'
endfunction

function _op_#dot#DotCallback(dummy) abort
    "TODO setup entry mode
    let l:handle = _op_#op#GetHandle('dot')
    let l:expr = _op_#utils#ExprWithModifiers(l:handle)
    call feedkeys(l:expr)
endfunction

function _op_#dot#Repeat(count, register, mode) abort
    let l:handle = _op_#op#GetHandle('dot')
    if !empty(l:handle) && !has_key(l:handle, 'abort')
        let l:count1 = (a:count)? a:count : l:handle['mods']['count1']
        call extend(l:handle, { 'mods' : {
                    \ 'count1': l:count1,
                    \ 'register': a:register,
                    \ } } )
        call extend(l:handle, { 'repeat_mode' : a:mode } )
    endif
    execute 'normal! .'
endfunction

function _op_#dot#RepeatOpPending() abort
    let l:handle = _op_#op#GetHandle('dot')
    if  !empty(l:handle) && !has_key(l:handle, 'abort') && has_key(l:handle, 'inputs')
        return join(l:handle['inputs'], '')
    else
        return "\<esc>"
    endif
endfunction

function s:RestoreEntryMode(handle) abort
    if a:handle['init']['entry_mode'] =~# '\v^[vV]$'
        let l:selectmode = &selectmode | set selectmode=
        normal! gv
        let &selectmode = l:selectmode
    endif
endfunction

let &cpo = s:cpo
unlet s:cpo
