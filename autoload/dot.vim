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

function dot#SetMaps(mode, maps, ...) abort range
    if type(a:maps) == v:t_list
        for l:map in a:maps
            call s:SetMap(a:mode, l:map, a:000)
        endfor
    else
        call s:SetMap(a:mode, a:maps, a:000)
    endif
endfunction

function s:CheckOptsDict(opts) abort
    execute "return ".op#SID()."CheckOptsDict(a:opts)"
endfunction

function s:CheckLastChange(handle) abort
    return empty(a:handle) || has_key(a:handle, 'abort') || getpos("'[") != a:handle['change_start'] || getpos("']") != a:handle['change_end']
endfunction

function s:DotRepeat(count, register, mode) abort
    let l:handle = s:GetHandle('dot')
    if !s:CheckLastChange(l:handle)
        call s:InitRepeat(l:handle, a:count, a:register, a:mode)
    endif
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
