"
" external dot# interface
"

let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

let s:AssertExprMap     = function('_op_#init#AssertExprMap')
let s:AssertSameRHS     = function('_op_#init#AssertSameRHS')
let s:ExtendDefaultOpts = function('_op_#init#ExtendDefaultOpts')
let s:RegisterNoremap   = function('_op_#init#RegisterNoremap')

function dot#Map(map, ...) abort range
    call s:AssertExprMap()
    let l:handle = _op_#op#StackInit()
    call _op_#op#InitCallback(l:handle, 'dot', a:map, s:ExtendDefaultOpts(a:000))
    call _op_#dot#InitCallback(l:handle)
    let &operatorfunc = '_op_#dot#ComputeMapCallback'
    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    return l:omap_esc .. 'g@' .. (mode(0) ==# 'n'? '_' : '')
endfunction

function dot#Noremap(map, ...) abort range
    call s:AssertExprMap()
    let l:map = s:RegisterNoremap(a:map)
    let l:handle = _op_#op#StackInit()
    call _op_#op#InitCallback(l:handle, 'dot', l:map, s:ExtendDefaultOpts(a:000))
    call _op_#dot#InitCallback(l:handle)
    let &operatorfunc = '_op_#dot#ComputeMapCallback'
    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    return l:omap_esc .. 'g@' .. (mode(0) ==# 'n'? '_' : '')
endfunction

function dot#RepeatMap() abort
    call s:AssertExprMap()
    let l:handle = _op_#op#GetStoredHandle('dot')

    " do nothing
    if mode(0) =~# '\v^[vV]$' && l:handle['init']['mode'] ==# 'n'
        return ''
    endif

    call _op_#dot#InitRepeatCallback(l:handle)
    if mode(1) ==# 'n'
        return '.'
    elseif mode(0) =~# '\v^[vV]$'
        return "\<esc>."
    else
        throw 'unimplemented mode: ' . mode(1)
    endif
endfunction

" function _op_#dot#RepeatOpPending() abort
"     let l:handle = _op_#op#GetStoredHandle('dot')
"     if  !empty(l:handle) && !has_key(l:handle, 'abort') && has_key(l:handle, 'inputs')
"         return join(l:handle['inputs'], '')
"     else
"         return "\<esc>"
"     endif
" endfunction

function dot#SetMaps(mapping_type, maps, ...) abort range
    let l:opts_dict = a:0 ? a:1 : {}
    if type(a:maps) == v:t_list
        for l:map in a:maps
            call s:SetMap(a:mapping_type, l:map, l:opts_dict)
        endfor
    else
        call s:SetMap(a:mapping_type, a:maps, l:opts_dict)
    endif
endfunction

function s:SetMap(mapping_type, map, opts_dict) abort
    let l:noremap = (a:mapping_type =~# '\v^(no|nn|vn|xn|sno|ono|no|ino|ln|cno|tno)')
    let l:modes = (a:mapping_type =~# '\v^(no|map)')? 'nvo' : a:mapping_type[0]

    if l:noremap || empty(maparg(a:map, l:modes[0]))
        call s:RegisterNoremap(a:map)
    else
        call s:AssertSameRHS(split(l:modes, '\zs'), a:map)
    endif
    execute a:mapping_type .. ' <expr> ' .. a:map .. ' dot#Map(' .. string(maparg(a:map, l:modes[0])) .. ', ' .. string(a:opts_dict) .. ')'
endfunction

let &cpo = s:cpo
unlet s:cpo
