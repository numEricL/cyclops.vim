let s:cpo = &cpo
set cpo&vim

silent! call op#Load()

if !g:op#no_mappings
    nmap   ; <plug>(pair#next)
    vmap   ; <plug>(pair#visual_next)
    omap   ; <plug>(pair#op_pending_next)

    nmap   , <plug>(pair#previous)
    vmap   , <plug>(pair#visual_previous)
    omap   , <plug>(pair#op_pending_previous)
endif

nmap <silent> <plug>(pair#next) :<c-u>call <sid>PairRepeat(';', v:count, v:register, 'normal')<cr>
vmap <silent> <plug>(pair#visual_next) :<c-u>call <sid>PairRepeat(';', v:count, v:register, 'visual')<cr>
omap <silent><expr> <plug>(pair#op_pending_next) <sid>PairOpPending(';')

nmap <silent> <plug>(pair#previous) :<c-u>call <sid>PairRepeat(',', v:count, v:register, 'normal')<cr>
vmap <silent> <plug>(pair#visual_previous) :<c-u>call <sid>PairRepeat(',', v:count, v:register, 'visual')<cr>
omap <silent><expr> <plug>(pair#op_pending_previous) <sid>PairOpPending(',')

noremap <silent> <plug>(op#_noremap_;) ;
noremap <silent> <plug>(op#_noremap_,) ,

function pair#NoremapNext(pair, ...) abort range
    let l:opts = s:CheckOptsDict(a:000)
    let l:pair = s:RegisterPair(a:pair, 1, l:opts)
    call s:InitCallback('pair', 0, l:pair, l:opts)
    return "\<cmd>call ".op#SID()."Callback('', 'stack')\<cr>"
endfunction

function pair#NoremapPrevious(pair, ...) abort range
    let l:opts = s:CheckOptsDict(a:000)
    let l:pair = s:RegisterPair(a:pair, 1, l:opts)
    call s:InitCallback('pair', 1, l:pair, l:opts)
    return "\<cmd>call ".op#SID()."Callback('', 'stack')\<cr>"
endfunction

function pair#MapNext(pair, ...) abort range
    let l:opts = s:CheckOptsDict(a:000)
    let l:pair = s:RegisterPair(a:pair, 0, l:opts)
    call s:InitCallback('pair', 0, l:pair, l:opts)
    return "\<cmd>call ".op#SID()."Callback('', 'stack')\<cr>"
endfunction

function pair#MapPrevious(pair, ...) abort range
    let l:opts = s:CheckOptsDict(a:000)
    let l:pair = s:RegisterPair(a:pair, 0, l:opts)
    call s:InitCallback('pair', 1, l:pair, l:opts)
    return "\<cmd>call ".op#SID()."Callback('', 'stack')\<cr>"
endfunction

function s:RegisterPair(pair, noremap, opts) abort range
    if type(a:pair) != v:t_list || len(a:pair) != 2
        throw 'cyclops.vim: Input must be a pair of maps'
    endif
    if a:noremap && ( empty(maparg('<plug>(op#_noremap_'.a:pair[0].')')) || empty(maparg('<plug>(op#_noremap_'.a:pair[1].')')) )
        execute 'noremap <plug>(op#_noremap_'.a:pair[0].') '.a:pair[0]
        execute 'noremap <plug>(op#_noremap_'.a:pair[1].') '.a:pair[1]
    endif
    return a:noremap? [ "\<plug>(op#_noremap_".a:pair[0].')', "\<plug>(op#_noremap_".a:pair[1].')' ] : a:pair
endfunction

function pair#SetMaps(mode, pairs, ...) abort range
    let l:opts = s:CheckOptsDict(a:000)
    if type(a:pairs[0]) == v:t_list
        for l:pair in a:pairs
            call s:SetMap(a:mode, l:pair, l:opts)
        endfor
    else
        call s:SetMap(a:mode, a:pairs, l:opts)
    endif
endfunction

function s:SetMap(mode, pair, opts) abort
    let l:map_func = ['pair#MapNext', 'pair#MapPrevious']
    let l:noremap = (a:mode =~# '\v^(no|nn|vn|xn|sno|ono|no|ino|ln|cno|tno)')
    let l:modes = (a:mode =~# '\v^(no|map)')? 'nvo' : a:mode[0]
    for l:mode in split(l:modes, '\zs')
        let l:plugpair = ['', '']
        let l:create_plugmap = ['', '']
        for l:id in range(2)
            if l:noremap || empty(maparg(a:pair[l:id], l:mode))
                let l:plugpair[l:id] = '<plug>(op#_noremap_'.a:pair[l:id].')'
                if a:pair[l:id] !~# '\v^[fFtT]$'    " see workaround_f
                    let l:create_plugmap[l:id] = 'noremap <silent> '.l:plugpair[l:id].' '.a:pair[l:id]
                endif
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
            execute l:mode.'map <expr> '.a:pair[l:id].' '.l:map_func[l:id].'('.string(l:plugpair).', '.string(a:opts).')'
        endfor
    endfor
endfunction

function s:PairRepeat(direction, count, register, mode) abort
    let l:handle = s:GetHandle('pair')
    if has_key(l:handle, 'abort') || empty(l:handle)
        return
    endif
    if l:handle['expr'] =~# '\V\^'."\<plug>".'(op#_noremap_\[fFtT;,])'
        " workaround for cpo-;
        let l:handle['expr'] = (a:direction ==# ';')? "\<plug>(op#_noremap_;)" : "\<plug>(op#_noremap_,)"
        call s:InitRepeat(l:handle, a:count, a:register, a:mode)
        call s:Callback('', 'pair')
        return
    endif

    let l:old_id = l:handle['pair_id']
    let l:id = (a:direction ==# ';')? l:old_id : !l:old_id
    if l:handle['pair_state'][l:id] ==# 'valid'
        call extend(l:handle, {'pair_id': l:id, 'expr': l:handle['pair'][l:id]})
        call s:InitRepeat(l:handle, a:count, a:register, a:mode)
        call s:Callback('', 'pair')
        let l:handle['pair_id'] = l:old_id
    else
        call s:StackInit()
        let l:top_handle = s:StackTop()
        " TODO: deepcopy from pair partner and modify only necessary fields
        call extend(l:top_handle, {
                    \ 'accepts_count'    : l:handle['accepts_count'],
                    \ 'accepts_register' : l:handle['accepts_register'],
                    \ 'expr'             : l:handle['pair'][l:id],
                    \ 'expr_so_far'      : '',
                    \ 'input_cache'      : get(l:handle, 'input_cache', []),
                    \ 'input_source'     : 'input_cache',
                    \ 'op_type'          : 'pair',
                    \ 'pair'             : deepcopy(l:handle['pair']),
                    \ 'pair_id'          : l:id,
                    \ 'pair_state'       : l:handle['pair_state'],
                    \ 'register_default' : l:handle['register_default'],
                    \ 'shift_marks'      : l:handle['shift_marks'],
                    \ 'visual_motion'    : l:handle['visual_motion'],
                    \ })
        call s:InitRepeat(l:top_handle, a:count, a:register, a:mode)
        call extend(l:top_handle, { 'called_from': 'repeat initialization' })
        call s:Callback('', 'stack')
    endif
endfunction

function s:PairOpPending(direction)
    let l:handle = s:GetHandle('pair')
    if empty(l:handle) || has_key(l:handle, 'abort')
        return "\<esc>"
    else
        let l:old_id = l:handle['pair_id']
        let l:id = (a:direction ==# ';')? l:old_id : !l:old_id
        if l:handle['pair_state'][l:id] ==# 'valid'
            if mode(1) ==# 'no'
                let l:op_mode = ( l:handle['cur_start'][1] == l:handle['cur_end'][1] )? '' : 'V'
            else
                let l:op_mode = a:handle['entry_mode'][2]
            endif
            return l:op_mode.l:handle['pair'][l:id]
        else
            call s:StackInit()
            let l:top_handle = s:StackTop()
            call extend(l:top_handle, { 'op_type': 'pair', 'expr': l:handle['pair'][l:id], 'pair': deepcopy(l:handle['pair']) })
            call extend(l:top_handle, { 'accepts_count': l:handle['accepts_count'], 'accepts_register': l:handle['accepts_register'] })
            call extend(l:top_handle, { 'shift_marks': l:handle['shift_marks'], 'visual_motion': l:handle['visual_motion'] })
            call extend(l:top_handle, { 'input_cache': get(l:handle, 'input_cache', []), 'input_source': 'input_cache', 'pair_id': l:id })
            call extend(l:top_handle, { 'pair_state': l:handle['pair_state'], 'expr_so_far': '', 'register_default': l:handle['register_default'] })
            call extend(l:top_handle, { 'cur_start': getcurpos() })
            call extend(l:top_handle, { 'called_from': 'repeat initialization', 'operator': v:operator, 'entry_mode': mode(1), 'count1': 1 })
            return "\<esc>:call ".op#SID()."Callback(".string('').', '.string('stack').")\<cr>"
        endif
    endif
endfunction

function s:CheckOptsDict(opts) abort
    execute "return ".op#SID()."CheckOptsDict(a:opts)"
endfunction

function s:InitCallback(op_type, expr, pair, opts) abort
    execute "call ".op#SID()."InitCallback(a:op_type, a:expr, a:pair, a:opts)"
endfunction

function s:Callback(dummy, op_type) abort
    execute "call ".op#SID()."Callback('', a:op_type)"
endfunction

function s:GetHandle(op_type) abort
    execute "return ".op#SID()."GetHandle(a:op_type)"
endfunction

function s:InitRepeat(handle, count, register, mode) abort
    execute "call ".op#SID()."InitRepeat(a:handle, a:count, a:register, a:mode)"
endfunction

function s:StackInit() abort
    execute "call ".op#SID()."StackInit()"
endfunction

function s:StackTop() abort
    execute "return ".op#SID()."StackTop()"
endfunction

if !g:op#no_mappings
    call pair#SetMaps('noremap', [['f', 'F'], ['t', 'T']])
endif

let &cpo = s:cpo
unlet s:cpo
