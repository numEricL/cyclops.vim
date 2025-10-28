let s:cpo = &cpo
set cpo&vim

silent! call op#Load()

if !g:op#no_mappings
    nmap   . <plug>(dot#dot)
    vmap   . <plug>(dot#visual_dot)
    omap   . <plug>(dot#op_pending_dot)
endif

nmap <silent> <plug>(dot#dot) <cmd>call <sid>DotRepeat(v:count, v:register, 'normal')<cr>
vmap <silent> <plug>(dot#visual_dot) <cmd>call <sid>DotRepeat(v:count, v:register, 'visual')<cr>
omap <silent><expr> <plug>(dot#op_pending_dot) <sid>DotOpPending()

function dot#Map(map, ...) abort range
    call s:InitCallback('dot', a:map, 0, s:CheckOptsDict(a:000))
    let &operatorfunc = op#SID().'Callback'
    return 'g@'.(mode(1) ==# 'n'? '_' : '')
endfunction

function dot#Noremap(map, ...) abort range
    let l:map = s:RegisterNoremap(a:map)
    call s:InitCallback('dot', l:map, 0, s:CheckOptsDict(a:000))
    return 'g@'.(mode(1) ==# 'n'? '_' : '')
endfunction

function dot#SetMaps(mapping_type, maps, ...) abort range
    let l:opts = s:CheckOptsDict(a:000)
    if type(a:maps) == v:t_list
        for l:map in a:maps
            call s:SetMap(a:mapping_type, l:map, l:opts)
        endfor
    else
        call s:SetMap(a:mapping_type, a:maps, l:opts)
    endif
endfunction

function s:CheckOptsDict(vargs) abort
    execute "return ".op#SID()."CheckOptsDict(a:vargs)"
endfunction

function s:DotRepeat(count, register, mode) abort
    let l:handle = s:GetHandle('dot')
    call s:InitRepeat(l:handle, a:count, a:register, a:mode)
    execute "normal! ."
endfunction

function s:DotOpPending()
    let l:handle = s:GetHandle('dot')
    if  !empty(l:handle) && !has_key(l:handle, 'abort') && has_key(l:handle, 'input_cache')
        return l:handle['input_cache'][0]
    else
        return "\<esc>"
    endif
endfunction

function s:SetMap(mapping_type, map, opts) abort
    let l:noremap = (a:mapping_type =~# '\v^(no|nn|vn|xn|sno|ono|no|ino|ln|cno|tno)')
    let l:modes = (a:mapping_type =~# '\v^(no|map)')? 'nvo' : a:mapping_type[0]

    let l:plugmap = ''
    if l:noremap || empty(maparg(a:map, l:modes[0]))
        let l:plugmap = s:RegisterNoremap(a:map)
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

function s:RegisterNoremap(map) abort
    execute "return ".op#SID()."RegisterNoremap(a:map)"
endfunction

function s:InitCallback(op_type, expr, pair, opts) abort
    execute "call ".op#SID()."InitCallback(a:op_type, a:expr, a:pair, a:opts)"
endfunction

function s:GetHandle(op_type) abort
    execute "return ".op#SID()."GetHandle(a:op_type)"
endfunction

function s:InitRepeat(handle, count, register, mode) abort
    execute "call ".op#SID()."InitRepeat(a:handle, a:count, a:register, a:mode)"
endfunction

let &cpo = s:cpo
unlet s:cpo
