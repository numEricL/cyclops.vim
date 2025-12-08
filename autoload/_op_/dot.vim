"
" internal dot# interface
"

let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

let s:macro_content = ''
let s:Log = function('_op_#log#Log')

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

function _op_#dot#ComputeMapCallback() abort
    let l:result = _op_#op#ComputeMapCallback()
    if l:result ==# 'op#insert_callback'
        return
    endif
    if exists("g:loaded_repeat")
        silent! call repeat#invalidate() " disable vim-repeat if present
    endif
    if empty(_op_#stack#GetException())
        call s:Log('dot#ComputeMapCallback', 'g@', 'initiating dot repeat')
        let l:handle = _op_#op#GetStoredHandle('dot')
        let l:handle['dot']['exit_mode'] = mode(1)
        let l:motion = (mode(0) ==# 'n')? 'l' : ''
        let &operatorfunc = '_op_#dot#InitRepeatOpFunc'
        " for reasons unknown to me, feeding with mode 'x' does not work here
        call feedkeys('g@' .. l:motion, 'in')
    endif
endfunction

function _op_#dot#InitRepeatOpFunc(dummy) abort
    let l:handle = _op_#op#GetStoredHandle('dot')

    let &operatorfunc = '_op_#dot#RepeatCallback'
    if l:handle['dot']['exit_mode'] =~# '\v^[vV]$'
        let l:selectmode = &selectmode | set selectmode=
        normal! gv
        let &selectmode = l:selectmode
    endif
endfunction

function _op_#dot#VisRepeatMap() abort
    call _op_#init#AssertExprMap()
    let l:handle = _op_#op#GetStoredHandle('dot')
    if !has_key(l:handle, 'init') || l:handle['init']['mode'] !~# '\v^[vV]$'
        return '.'
    endif
    call s:InitRepeatCallback(l:handle)
    let l:handle['repeat']['vdot_init'] = v:true
    return "\<esc>."
endfunction

function s:InitRepeatCallback(handle) abort
    if (a:handle['opts']['persistent_count'] && v:count == 0)
        let l:init_count = has_key(a:handle, 'mods')? a:handle['mods']['count'] : 0
        let l:count = has_key(a:handle, 'repeat_mods')? a:handle['repeat_mods']['count'] : l:init_count
    else 
        let l:count = v:count
    endif
    call extend(a:handle, { 'repeat' : {
                \ 'mode'     : mode(1),
                \ 'curpos'   : getcurpos(),
                \ 'reg_recording' : reg_recording(),
                \ } } )
    call extend(a:handle, { 'repeat_mods': {
                \ 'count'    : l:count,
                \ 'register' : v:register,
                \ } } )
endfunction

function _op_#dot#RepeatCallback(dummy) abort
    if !has('nvim') && !_op_#utils#HasVersion(802, 1978)
        "workaround for old vim bug where vim gets stuck in operator-pending mode
        call inputsave()
        call feedkeys("\<esc>", 'x')
        call inputrestore()
    endif
    let l:handle = _op_#op#GetStoredHandle('dot')
    call s:Log('dot#RepeatCallback', '', l:handle['expr']['reduced'] .. ' typeahead=' .. _op_#op#ReadTypeaheadTruncated())
    " normal mode dot initializes here, visdot initializes in <expr> map
    if has_key(l:handle, 'repeat') && get(l:handle['repeat'], 'vdot_init')
        " reset for next dot call
        let l:handle['repeat']['vdot_init'] = v:false
    else
        call s:InitRepeatCallback(l:handle)
    endif

    call s:MacroStop(l:handle)
    call inputsave()
    if l:handle['opts']['accepts_count']
        let l:expr_with_modifiers = _op_#op#ExprWithModifiers(l:handle['expr']['reduced'], l:handle['repeat_mods'], l:handle['opts'])
        call s:RestoreRepeatEntry(l:handle)
        call _op_#utils#Feedkeys(l:expr_with_modifiers, 'tx!')
    else
        let l:mods = extend({'count': 0}, l:handle['repeat_mods'], 'keep')
        let l:expr_with_modifiers = _op_#op#ExprWithModifiers(l:handle['expr']['reduced'], l:mods, l:handle['opts'])
        let l:count1 = max([1, l:handle['repeat_mods']['count']])
        for _ in range(l:count1)
            call s:RestoreRepeatEntry(l:handle)
            call _op_#utils#Feedkeys(l:expr_with_modifiers, 'tx!')
            call s:InitRepeatCallback(l:handle)
        endfor
    endif
    let &operatorfunc = '_op_#dot#RepeatCallback'
    if exists("g:loaded_repeat")
        silent! call repeat#invalidate() " disable vim-repeat if present
    endif
    call inputrestore()
    call s:MacroResume(l:handle)
endfunction

function s:MacroStop(handle) abort
    if a:handle['repeat']['reg_recording'] !=# ''
        execute 'normal! q'
        let s:macro_content = getreg(a:handle['repeat']['reg_recording'])
    endif
endfunction

function s:MacroResume(handle) abort
    if !empty(a:handle['repeat']['reg_recording'])
        call setreg(tolower(a:handle['repeat']['reg_recording']), s:macro_content)
        execute 'normal! q' .. toupper(a:handle['repeat']['reg_recording'])
    endif
endfunction

function s:RestoreRepeatEntry(handle) abort
    let l:imode = a:handle['dot']['mode']
    let l:rmode = a:handle['repeat']['mode']

    " if initiated in operator-pending mode then treat like normal mode
    if l:imode[0] ==# 'n' && l:rmode ==# 'n'
        " nothing needed
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
    if has('*virtcol2col')
        let l:byte_col = virtcol2col(0, a:row, a:col)
    else
        let l:byte_col = s:VirtCol2Col_COMPAT(a:row, a:col)
    return [0, a:row, l:byte_col, 0]
endfunction

function s:VirtCol2Col_COMPAT(line, virtcol) abort
    let l:line = getline(a:line)
    let l:col = 1
    let l:vcol = 1
    while l:col <= len(l:line) && l:vcol < a:virtcol
        if l:line[l:col - 1] ==# "\t"
            let l:tabstop = &tabstop
            let l:vcol += l:tabstop - ((l:vcol - 1) % l:tabstop)
        else
            let l:vcol += 1
        endif
        let l:col += 1
    endwhile
    return l:col
endfunction

let &cpo = s:cpo
unlet s:cpo
