" TODO: create dot specific callback that sets visual mode and then calls op callback

let s:cpo = &cpo
set cpo&vim

nmap <silent> <plug>(dot#dot) <cmd>call <sid>DotRepeat(v:count, v:register, 'normal')<cr>
vmap <silent> <plug>(dot#visual_dot) <cmd>call <sid>DotRepeat(v:count, v:register, 'visual')<cr>
omap <silent><expr> <plug>(dot#op_pending_dot) <sid>DotOpPending()

function dot#Map(map, ...) abort range
    call s:InitCallback(a:map, s:op_CheckOptsDict(a:000))
    let &operatorfunc = dot#SID() .. 'ComputeMapCallback'
    return 'g@' .. (mode(1) ==# 'n'? '_' : '')
endfunction

function dot#Noremap(map, ...) abort range
    let l:map = s:op_RegisterNoremap(a:map)
    call s:InitCallback(l:map, s:op_CheckOptsDict(a:000))
    let &operatorfunc = dot#SID() .. 'ComputeMapCallback'
    return 'g@' .. (mode(1) ==# 'n'? '_' : '')
endfunction

function dot#SetMaps(mapping_type, maps, ...) abort range
    let l:opts = s:op_CheckOptsDict(a:000)
    if type(a:maps) == v:t_list
        for l:map in a:maps
            call s:SetMap(a:mapping_type, l:map, l:opts)
        endfor
    else
        call s:SetMap(a:mapping_type, a:maps, l:opts)
    endif
endfunction

function s:ComputeMapCallback(dummy) abort
    call s:RestoreEntryMode(s:op_StackTop())
    call s:op_ComputeMapCallback()
    let &operatorfunc = dot#SID() .. 'repeatCallback'
endfunction

function s:DotRepeat(count, register, mode) abort
    let l:handle = s:op_GetHandle('dot')
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

function s:repeatCallback(dummy) abort
    "TODO setup entry mode
    let l:handle = s:op_GetHandle('dot')
    let l:expr = s:op_ExprWithModifiers(l:handle)
    call feedkeys(l:expr)
endfunction

function s:RestoreEntryMode(handle) abort
    let l:init = a:handle['init']
    let l:marks = a:handle['marks']
    let l:dot = a:handle['dot']
    if l:init['entry_mode'] ==# 'n'
        call setpos('.', l:dot['cur_start'])
    elseif l:init['entry_mode'] =~# '\v^[vV]$'
        let l:v_state = [l:init['entry_mode'], l:marks['v'], l:marks['.']]
        call s:op_SetVisualState(l:v_state)
    endif
endfunction

function s:DotOpPending()
    let l:handle = s:op_GetHandle('dot')
    if  !empty(l:handle) && !has_key(l:handle, 'abort') && has_key(l:handle, 'inputs')
        return join(l:handle['inputs'], '')
    else
        return "\<esc>"
    endif
endfunction

function s:SetMap(mapping_type, map, opts) abort
    let l:noremap = (a:mapping_type =~# '\v^(no|nn|vn|xn|sno|ono|no|ino|ln|cno|tno)')
    let l:modes = (a:mapping_type =~# '\v^(no|map)')? 'nvo' : a:mapping_type[0]

    let l:plugmap = ''
    if l:noremap || empty(maparg(a:map, l:modes[0]))
        let l:plugmap = s:op_RegisterNoremap(a:map)
    else
        call s:AssertSameRHS(split(l:modes, '\zs'), a:map)
        let l:create_plugmap = ''
        let l:plugmap = '<plug>(op#_'.a:mapping_type.'_'.a:map.')'
        let l:mapinfo = maparg(a:map, l:mode, 0, 1)
        let l:rhs = substitute(l:mapinfo['rhs'], '\V<sid>', '<snr>'.l:mapinfo['sid'].'_', '')
        let l:rhs = substitute(l:rhs, '\v(\|)@<!\|(\|)@!', '<bar>', 'g')
        let l:create_plugmap .= (l:mapinfo['noremap'])? 'noremap ' : 'map '
        let l:create_plugmap .= (l:mapinfo['buffer'])? '<buffer>' : ''
        let l:create_plugmap .= (l:mapinfo['nowait'])? '<nowait>' : ''
        let l:create_plugmap .= (l:mapinfo['silent'])? '<silent>' : ''
        let l:create_plugmap .= (l:mapinfo['expr'])? '<expr>' : ''
        let l:create_plugmap .= l:plugmap.' '
        execute l:create_plugmap
    endif
    execute a:mapping_type.' <expr> '.a:map.' dot#Map('.string(l:plugmap).', '.string(l:opts).')'
endfunction

function s:InitCallback(expr, opts) abort
    let l:handle = s:op_InitCallback('dot', a:expr, a:opts)
    call extend(l:handle, { 'marks': {
                \ '.' : getpos('.'),
                \ 'v' : getpos('v'),
                \ "'<" : getpos("'<"),
                \ "'>" : getpos("'>"),
                \ "'[" : getpos("'["),
                \ "']" : getpos("']"),
                \ } } )
    call extend(l:handle, { 'dot' : {
                \ 'v_mode' : visualmode(),
                \ 'cur_start' : getcurpos(),
                \ } } )
endfunction

function s:op_RegisterNoremap(map) abort
    execute 'return ' .. op#SID() .. 'RegisterNoremap(a:map)'
endfunction

function s:op_InitCallback(op_type, expr, opts) abort
    execute 'return ' .. op#SID() .. 'InitCallback(a:op_type, a:expr, a:opts)'
endfunction

function s:op_ComputeMapCallback() abort
    execute 'call ' .. op#SID() .. 'ComputeMapCallback()'
endfunction

function s:op_StackTop() abort
    execute 'return ' .. op#SID() .. 'StackTop()'
endfunction

function s:op_GetHandle(op_type) abort
    execute 'return ' .. op#SID() .. 'GetHandle(a:op_type)'
endfunction

function s:op_SetVisualState(v_state) abort
    execute 'call ' .. op#SID() .. 'SetVisualState(a:v_state)'
endfunction

function s:op_CheckOptsDict(vargs) abort
    execute 'return '.. op#SID() .. 'CheckOptsDict(a:vargs)'
endfunction

function s:op_ExprWithModifiers(handle) abort
    execute 'return ' .. op#SID() .. 'ExprWithModifiers(a:handle)'
endfunction

function dot#SID() abort
    return expand('<SID>')
endfunction

let &cpo = s:cpo
unlet s:cpo
