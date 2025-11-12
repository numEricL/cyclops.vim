"
" external dot# interface
"

" TODO: create dot specific callback that sets visual mode and then calls op callback

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
    call s:InitCallback(l:handle, a:map, s:ExtendDefaultOpts(a:000))
    let &operatorfunc = '_op_#dot#ComputeMapCallback'
    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    return l:omap_esc .. 'g@' .. (mode(0) ==# 'n'? '_' : '')
endfunction

function dot#Noremap(map, ...) abort range
    call s:AssertExprMap()
    let l:handle = _op_#op#StackInit()
    let l:map = s:RegisterNoremap(a:map)
    call s:InitCallback(l:handle, l:map, s:ExtendDefaultOpts(a:000))
    let &operatorfunc = '_op_#dot#ComputeMapCallback'
    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    return l:omap_esc .. 'g@' .. (mode(0) ==# 'n'? '_' : '')
endfunction

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

function dot#RepeatMap() abort
    let l:handle = _op_#op#GetHandle('dot')
    if !empty(l:handle) && !has_key(l:handle, 'abort')
        let l:count1 = (v:count)? v:count : l:handle['mods']['count1']
        call extend(l:handle, { 'mods' : {
                    \ 'count1': l:count1,
                    \ 'register': v:register,
                    \ } } )
        call extend(l:handle, { 'repeat_mode' : mode(1) } )
    endif
    return '.'
endfunction

function s:InitCallback(handle, expr, opts) abort
    call _op_#op#InitCallback(a:handle, 'dot', a:expr, a:opts)
    " call extend(l:handle, { 'marks': {
    "             \ '.' : getpos('.'),
    "             \ 'v' : getpos('v'),
    "             \ "'<" : getpos("'<"),
    "             \ "'>" : getpos("'>"),
    "             \ "'[" : getpos("'["),
    "             \ "']" : getpos("']"),
    "             \ } } )
    call extend(a:handle, { 'dot' : {
                \ 'cur_start' : getcurpos(),
                \ } } )
                " \ 'v_mode' : visualmode(),
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

" function _op_#dot#RepeatOpPending() abort
"     let l:handle = _op_#op#GetHandle('dot')
"     if  !empty(l:handle) && !has_key(l:handle, 'abort') && has_key(l:handle, 'inputs')
"         return join(l:handle['inputs'], '')
"     else
"         return "\<esc>"
"     endif
" endfunction


let &cpo = s:cpo
unlet s:cpo
