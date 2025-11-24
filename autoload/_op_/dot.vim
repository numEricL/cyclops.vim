"
" internal dot# interface
"

let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

function _op_#dot#InitCallback(handle) abort
    call extend(a:handle, { 'dot' : {
                \ 'mode'     : mode(1),
                \ 'curpos'   : getcurpos(),
                \ } } )
    call extend(a:handle, { 'marks': {
                \ '.'  : getpos('.'),
                \ 'v'  : getpos('v'),
                \ } } )
endfunction

function _op_#dot#ComputeMapCallback(dummy) abort
    let l:handle = _op_#stack#Top()
    call s:RestoreEntry(l:handle, 'dot')
    call _op_#op#ComputeMapCallback()
    if empty(_op_#stack#GetException())
        let &operatorfunc = '_op_#dot#RepeatCallback'
    else
        " last change is clobbered, even on fail
        let &operatorfunc = '_op_#dot#ExceptionCallback'
    endif
endfunction

function s:RestoreEntry(handle, key) abort
    if a:handle[a:key]['mode'] ==# 'n'
        call setpos('.', a:handle[a:key]['curpos'])
    elseif a:handle[a:key]['mode'] =~# '\v^[vV]$'
        let l:selectmode = &selectmode | set selectmode=
        normal! gv
        let &selectmode = l:selectmode
    endif
endfunction

function _op_#dot#ExceptionCallback(dummy) abort
    let l:handle = _op_#op#GetStoredHandle('dot')
    call s:RestoreEntry(l:handle, 'repeat')
    echohl ErrorMsg | echomsg 'last dot operation failed' | echohl None
endfunction

function _op_#dot#VisRepeatMap() abort
    call _op_#init#AssertExprMap()
    let l:handle = _op_#op#GetStoredHandle('dot')
    if !has_key(l:handle, 'init') || l:handle['init']['mode'] ==# 'n'
        return '.'
    endif
    call s:InitRepeatCallback(l:handle)
    let l:handle['repeat']['vdot'] = v:true
    return "\<esc>."
endfunction

" function _op_#dot#RepeatOpPending() abort
"     let l:handle = _op_#op#GetStoredHandle('dot')
"     if  !empty(l:handle) && !has_key(l:handle, 'abort') && has_key(l:handle, 'inputs')
"         return join(l:handle['inputs'], '')
"     else
"         return "\<esc>"
"     endif
" endfunction

function s:InitRepeatCallback(handle) abort
    if (g:cyclops_persistent_count && v:count == 0)
        let l:init_count = has_key(a:handle, 'mods')? a:handle['mods']['count'] : 0
        let l:count = has_key(a:handle, 'repeat_mods')? a:handle['repeat_mods']['count'] : l:init_count
    else 
        let l:count = v:count
    endif
    call extend(a:handle, { 'repeat' : {
                \ 'mode'     : mode(1),
                \ 'curpos'   : getcurpos(),
                \ 'vdot'     : mode(0) =~# '\v^[vV]$'
                \ } } )
    call extend(a:handle, { 'repeat_mods': {
                \ 'count'    : l:count,
                \ 'register' : v:register,
                \ } } )
endfunction

function _op_#dot#RepeatCallback(dummy) abort
    let l:handle = _op_#op#GetStoredHandle('dot')
    " normal mode dot initializes here, visdot initializes in <expr> map
    if has_key(l:handle, 'repeat') && l:handle['repeat']['vdot'] == v:true
        " reset for next dot call
        let l:handle['repeat']['vdot'] = v:false
    else
        call s:InitRepeatCallback(l:handle)
    endif
    call s:RestoreRepeatEntry(l:handle)
    " ensure that 3<dot> is the same as <dot><dot><dot>
    let l:opts = extend({'accepts_count': v:false}, l:handle['opts'], 'keep')
    let l:expr_with_modifiers = _op_#op#ExprWithModifiers(l:handle['expr']['reduced'], l:handle['repeat_mods'], l:opts)
    if l:opts['silent']
        silent call feedkeys(l:expr_with_modifiers, 'x!')
    else
        call feedkeys(l:expr_with_modifiers, 'x!')
    endif
    let &operatorfunc = '_op_#dot#RepeatCallback'
endfunction

function s:RestoreRepeatEntry(handle) abort
    let l:imode = a:handle['dot']['mode']
    let l:rmode = a:handle['repeat']['mode']

    " if initiated in operator-pending mode then treat like normal mode
    if l:imode[0] ==# 'n' && l:rmode ==# 'n'
        " call setpos('.', a:handle['repeat']['curpos'])
    elseif l:imode =~# '\v^[vV]$' && l:rmode ==# 'n'
        " shift visual marks to cursor
        let l:v_beg = s:ShiftPos(a:handle['repeat']['curpos'], a:handle['marks']['v'], a:handle['marks']['.'])
        let l:v_end = s:ShiftPos(a:handle['repeat']['curpos'], a:handle['marks']['.'], a:handle['marks']['.'])
        call setpos('.', l:v_beg)
        execute "normal! " .. a:handle['dot']['mode']
        call setpos('.', l:v_end)
    elseif l:imode =~# '\v^[vV]$' && l:rmode =~# '\v^[vV]$'
        let l:selectmode = &selectmode | set selectmode=
        normal! gv
        let &selectmode = l:selectmode
    else
        throw 'unsupported mode combination: init=' .. l:imode .. ' repeat=' .. l:rmode
    endif
endfunction

" point, v_beg, v_end are position as returned by getpos(). If inputs are
" thought of as vectors, this function returns the vector 
" point + (v_end - v_beg)
function s:ShiftPos(point, v_beg, v_end) abort
    let l:shifted_row = a:point[1] + ( a:v_end[1] - a:v_beg[1] )
    let l:shifted_col = s:VirtCol(a:point) + ( s:VirtCol(a:v_end) - s:VirtCol(a:v_beg) )
    return s:GetPos(l:shifted_row, l:shifted_col)
endfunction

function s:VirtCol(pos) abort
    return virtcol(a:pos[1:3])
endfunction

function s:GetPos(row, col) abort
    " TODO: handle virtual edit case (i.e. offset in getpos())
    let l:byte_col = virtcol2col(0, a:row, a:col)
    return [0, a:row, l:byte_col, 0]
endfunction

let &cpo = s:cpo
unlet s:cpo
