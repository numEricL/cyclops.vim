let s:cpo = &cpo
set cpo&vim

silent! call op#Load()

if !g:op#no_mappings
    nmap   . <plug>(dot#dot)
    nmap "". <plug>(dot#dot_default_register)
    vmap   . <plug>(dot#visual_dot)
    vmap "". <plug>(dot#visual_dot_default_register)
    omap   . <plug>(dot#op_pending_dot)
endif

nmap <silent> <plug>(dot#dot) :<c-u>call <sid>DotRepeat(v:count, v:register, 'normal')<cr>
nmap <silent> <plug>(dot#dot_default_register) :<c-u>call <sid>DotRepeat(v:count, 'use_default', 'normal')<cr>
vmap <silent> <plug>(dot#visual_dot) :<c-u>call <sid>DotRepeat(v:count, v:register, 'visual')<cr>
vmap <silent> <plug>(dot#visual_dot_default_register) :<c-u>call <sid>DotRepeat(v:count, 'use_default', 'visual')<cr>
omap <silent><expr> <plug>(dot#op_pending_dot) <sid>DotOpPending()

function s:DotOpPending()
    let l:handle = s:GetHandle('dot')
    if  !empty(l:handle) && !has_key(l:handle, 'abort') && has_key(l:handle, 'input_cache')
        return l:handle['input_cache'][0]
    else
        return "\<esc>"
    endif
endfunction

function dot#Map(map, ...) abort range
    return s:InitCallback('dot', a:map, 0, (a:0>=1? !empty(a:1) : 0), (a:0>=2? !empty(a:2) : 1), (a:0>=3? !empty(a:3) : 0), (a:0>=4? !empty(a:4) : 0), (a:0>=5? !empty(a:5) : !empty(g:op#operators_consume_typeahead)))
endfunction

function dot#Noremap(map, ...) abort range
    if empty(maparg('<plug>(op#_noremap_'.a:map.')'))
        execute 'noremap <plug>(op#_noremap_'.a:map.') '.a:map
    endif
    return s:InitCallback('dot', "\<plug>(op#_noremap_".a:map.")", 0, (a:0>=1? !empty(a:1) : 0), (a:0>=2? !empty(a:2) : 1), (a:0>=3? !empty(a:3) : 0), (a:0>=4? !empty(a:4) : 0), (a:0>=5? !empty(a:5) : !empty(g:op#operators_consume_typeahead)))
endfunction

function dot#SetMaps(mode, maps, ...) abort range
    if type(a:maps) == v:t_list
        for l:map in a:maps
            call s:SetMap(a:mode, l:map, a:000)
        endfor
    else
        call s:SetMap(a:mode, a:maps, a:000)
    endif
endfunction

function s:DotRepeat(count, register, mode) abort
    let l:handle = s:GetHandle('dot')
    if  !empty(l:handle) && !has_key(l:handle, 'abort')
        call s:InitRepeat(l:handle, a:count, a:register, a:mode)
    endif
    execute "normal! ."
endfunction

function s:SetMap(mode, map, args) abort
    let l:args = ''
    for l:arg in a:args
        let l:args .= ', '.(type(l:arg) =~# '\v^[06]$'? l:arg : string(l:arg))
    endfor
    let l:map_func = 'dot#Map'
    let l:noremap = (a:mode =~# '\v^(no|nn|vn|xn|sno|ono|no|ino|ln|cno|tno)')
    let l:modes = (a:mode =~# '\v^(no|map)')? 'nvo' : a:mode[0]
    for l:mode in split(l:modes, '\zs')
        let l:plugmap = ''
        let l:create_plugmap = ''
        if l:noremap || empty(maparg(a:map, l:mode))
            let l:plugmap = '<plug>(op#_noremap_'.a:map.')'
            if a:map !~# '\v^[fFtT]$'   " see workaround_f
                let l:create_plugmap = 'noremap <silent> '.l:plugmap.' '.a:map
            endif
        else
            let l:plugmap = '<plug>(op#_'.l:mode.'map_'.a:map.')'
            let l:mapinfo = maparg(a:map, l:mode, 0, 1)
            let l:rhs = substitute(l:mapinfo['rhs'], '\V<sid>', '<snr>'.l:mapinfo['sid'].'_', '')
            let l:rhs = substitute(l:rhs, '\v(\|)@<!\|(\|)@!', '<bar>', 'g')
            let l:create_plugmap .= (l:mapinfo['noremap'])? 'noremap ' : 'map '
            let l:create_plugmap .= (l:mapinfo['buffer'])? '<buffer>' : ''
            let l:create_plugmap .= (l:mapinfo['nowait'])? '<nowait>' : ''
            let l:create_plugmap .= (l:mapinfo['silent'])? '<silent>' : ''
            let l:create_plugmap .= (l:mapinfo['expr'])? '<expr>' : ''
            let l:create_plugmap .= l:plugmap.' '
            let l:create_plugmap .= l:rhs
        endif
        execute l:create_plugmap
        execute l:mode.'map <expr> '.a:map.' '.l:map_func.'('.string(l:plugmap).l:args.')'
    endfor
endfunction

function s:InitCallback(name, expr, id, accepts_count, accepts_register, shift_marks, visual_motion, input_source) abort
    execute "return ".op#SID()."InitCallback(a:name, a:expr, a:id, a:accepts_count, a:accepts_register, a:shift_marks, a:visual_motion, a:input_source)"
endfunction

function s:GetHandle(name) abort
    execute "return ".op#SID()."GetHandle(a:name)"
endfunction

function s:InitRepeat(handle, count, register, mode) abort
    execute "return ".op#SID()."InitRepeat(a:handle, a:count, a:register, a:mode)"
endfunction

let &cpo = s:cpo
unlet s:cpo
