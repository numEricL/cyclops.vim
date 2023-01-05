let s:cpo = &cpo
set cpo&vim

silent! call op#Load()

if !g:op#no_mappings
    nmap   ; <plug>(pair#next)
    nmap ""; <plug>(pair#next_default_register)
    vmap   ; <plug>(pair#visual_next)
    vmap ""; <plug>(pair#visual_next_default_register)
    nmap   , <plug>(pair#previous)
    nmap "", <plug>(pair#previous_default_register)
    vmap   , <plug>(pair#visual_previous)
    vmap "", <plug>(pair#visual_previous_default_register)
endif

nmap <silent> <plug>(pair#next) :<c-u>call <sid>PairRepeat(';', v:count, v:register, 'normal')<cr>
nmap <silent> <plug>(pair#next_default_register) :<c-u>call <sid>PairRepeat(';', v:count, 'use_default', 'normal')<cr>
vmap <silent> <plug>(pair#visual_next) :<c-u>call <sid>PairRepeat(';', v:count, v:register, 'visual')<cr>
vmap <silent> <plug>(pair#visual_next_default_register) :<c-u>call <sid>PairRepeat(';', v:count, 'use_default', 'visual')<cr>
nmap <silent> <plug>(pair#previous) :<c-u>call <sid>PairRepeat(',', v:count, v:register, 'normal')<cr>
nmap <silent> <plug>(pair#previous_default_register) :<c-u>call <sid>PairRepeat(',', v:count, 'use_default', 'normal')<cr>
vmap <silent> <plug>(pair#visual_previous) :<c-u>call <sid>PairRepeat(',', v:count, v:register, 'visual')<cr>
vmap <silent> <plug>(pair#visual_previous_default_register) :<c-u>call <sid>PairRepeat(',', v:count, 'use_default', 'visual')<cr>

function pair#NoremapNext(pair, ...) abort range
    return s:Pair(a:pair, 1, 0, a:000)
endfunction

function pair#NoremapPrevious(pair, ...) abort range
    return s:Pair(a:pair, 1, 1, a:000)
endfunction

function pair#MapNext(pair, ...) abort range
    return s:Pair(a:pair, 0, 0, a:000)
endfunction

function pair#MapPrevious(pair, ...) abort range
    return s:Pair(a:pair, 0, 1, a:000)
endfunction

function pair#SetMaps(mode, pairs, ...) abort range
    if type(a:pairs[0]) == v:t_list
        for l:pair in a:pairs
            call s:SetMap(a:mode, l:pair, a:000)
        endfor
    else
        call s:SetMap(a:mode, a:pairs, a:000)
    endif
endfunction

function s:SetMap(mode, pair, args) abort
    let l:args = ''
    for l:arg in a:000
        let l:args .= ', '.(type(l:arg) =~# '\v^[06]$'? l:arg : string(l:arg))
    endfor
    let l:map_func = ['pair#MapNext', 'pair#MapPrevious']
    let l:noremap = (a:mode =~# '\v^(no|nn|vn|xn|sno|ono|no|ino|ln|cno|tno)')
    let l:modes = (a:mode =~# '\v^(no|map)')? 'nvo' : a:mode[0]
    for l:mode in split(l:modes, '\zs')
        let l:plugpair = ['', '']
        let l:create_plugmap = ['', '']
        for l:id in range(2)
            if l:noremap || empty(maparg(a:pair[l:id], l:mode))
                let l:plugpair[l:id] = '<plug>(op#_noremap_'.a:pair[l:id].')'
                let l:create_plugmap[l:id] = 'noremap '.l:plugpair[l:id].' '.a:pair[l:id]
            else
                let l:plugpair[l:id] = '<plug>(op#_'.l:mode.'map_'.a:pair[l:id].')'
                let l:mapinfo = maparg(a:pair[l:id], l:mode, 0, 1)
                let l:rhs = substitute(l:mapinfo['rhs'], '\V<sid>', '<snr>'.l:mapinfo['sid'].'_', '')
                let l:rhs = substitute(l:rhs, '\v(\|)@<!\|(\|)@!', '<bar>', 'g')
                let l:create_plugmap[l:id] .= (l:mapinfo['noremap'])? 'noremap ' : 'map '
                let l:create_plugmap[l:id] .= (l:mapinfo['buffer'])? '<buffer>' : ''
                let l:create_plugmap[l:id] .= (l:mapinfo['nowait'])? '<nowait>' : ''
                let l:create_plugmap[l:id] .= (l:mapinfo['silent'])? '<silent>' : ''
                let l:create_plugmap[l:id] .= (l:mapinfo['expr'])? '<expr>' : ''
                let l:create_plugmap[l:id] .= l:plugpair[l:id].' '
                let l:create_plugmap[l:id] .= l:rhs
            endif
        endfor
        for l:id in range(2)
            execute l:create_plugmap[l:id]
            execute l:mode.'map <expr> '.a:pair[l:id].' '.l:map_func[l:id].'('.string(l:plugpair).l:args.')'
        endfor
    endfor
endfunction

function s:Pair(pair, noremap, id, args) abort range
    if type(a:pair) != v:t_list || len(a:pair) != 2
        throw 'cyclops.vim: Input must be a pair of maps'
    endif
    if a:noremap && ( empty(maparg('<plug>(op#_noremap_'.a:pair[0].')')) || empty(maparg('<plug>(op#_noremap_'.a:pair[1].')')) )
        execute 'noremap <plug>(op#_noremap_'.a:pair[0].') '.a:pair[0]
        execute 'noremap <plug>(op#_noremap_'.a:pair[1].') '.a:pair[1]
    endif
    let l:pair = a:noremap? [ "\<plug>(op#_noremap_".a:pair[0].')', "\<plug>(op#_noremap_".a:pair[1].')' ] : a:pair
    return s:InitCallback('pair', 'map', l:pair, a:id, (len(a:args)>=1? !empty(a:args[0]) : 0), (len(a:args)>=2? !empty(a:args[1]) : 1), (len(a:args)>=3? !empty(a:args[2]) : 0), (len(a:args)>=4? !empty(a:args[3]) : 0), (len(a:args)>=5? !empty(a:args[4]) : !empty(g:op#operators_consume_typeahead)))
endfunction

function s:PairRepeat(direction, count, register, mode) abort
    let l:handle = s:GetHandle('pair')
    if has_key(l:handle, 'abort') || empty(l:handle)
        return
    endif

    let l:init_id = l:handle['pair_init_id']
    let l:other_id = !l:init_id
    if l:handle['pair_state'][l:init_id] ==# 'invalid'
        let l:handle['pair'][l:init_id] = l:handle['expr']
        let l:handle['pair_state'][l:init_id] = 'valid'
    endif

    call inputsave()
    if a:direction ==# ';'
        let l:handle['expr'] = l:handle['pair'][l:init_id]
        call s:InitRepeat(l:handle, a:count, a:register, a:mode)
        call s:Callback('', 'pair')
    elseif a:direction ==# ',' && l:handle['pair_state'][l:other_id] ==# 'valid'
        let l:handle['expr'] = l:handle['pair'][l:other_id]
        call s:InitRepeat(l:handle, a:count, a:register, a:mode)
        call s:Callback('', 'pair')
    elseif a:direction ==# ',' && l:handle['pair_state'][l:other_id] ==# 'invalid'
        execute "let l:stack = ".op#SID()."StartStack()"
        for l:key in keys(l:handle)
            let l:stack[l:key] = deepcopy(l:handle[l:key])
        endfor
        call extend(l:stack, { 'expr': l:handle['pair'][l:other_id], 'expr_so_far': '', 'input_source': 'input_cache' })
        call s:InitRepeat(l:stack, a:count, a:register, a:mode)
        call extend(l:stack, { 'called_from': 'pair initialization' })
        call s:Callback('', 'stack')
        let l:new = s:GetHandle('pair')
        let l:new['pair_state'] = ['valid', 'valid']
        let l:new['pair'][l:other_id] = l:new['expr']
        let l:new['pair'][!l:other_id] = l:handle['expr']
    endif
    call inputrestore()
endfunction

function s:InitCallback(name, type, expr, id, accepts_count, accepts_register, shift_marks, stay_in_visual, input_source) abort
    execute "return ".op#SID()."InitCallback(a:name, a:type, a:expr, a:id, a:accepts_count, a:accepts_register, a:shift_marks, a:stay_in_visual, a:input_source)"
endfunction

function s:Callback(dummy, name) abort
    execute "return ".op#SID()."Callback('', a:name)"
endfunction

function s:GetHandle(name) abort
    execute "return ".op#SID()."GetHandle(a:name)"
endfunction

function s:InitRepeat(handle, count, register, mode) abort
    execute "return ".op#SID()."InitRepeat(a:handle, a:count, a:register, a:mode)"
endfunction

if !g:op#no_mappings
    call pair#SetMaps('noremap', [['f', 'F'], ['t', 'T']])
endif

let &cpo = s:cpo
unlet s:cpo
