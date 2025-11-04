let s:cpo = &cpo
set cpo&vim

call op#Load()

nmap <silent> <plug>(pair#next) :<c-u>call <sid>PairRepeat(';', v:count, v:register, 'normal')<cr>
vmap <silent> <plug>(pair#visual_next) :<c-u>call <sid>PairRepeat(';', v:count, v:register, 'visual')<cr>
" omap <silent><expr> <plug>(pair#op_pending_next) <sid>PairOpPending(';')

nmap <silent> <plug>(pair#previous) :<c-u>call <sid>PairRepeat(',', v:count, v:register, 'normal')<cr>
vmap <silent> <plug>(pair#visual_previous) :<c-u>call <sid>PairRepeat(',', v:count, v:register, 'visual')<cr>
" omap <silent><expr> <plug>(pair#op_pending_previous) <sid>PairOpPending(',')

noremap <silent> <plug>(op#_noremap_;) ;
noremap <silent> <plug>(op#_noremap_,) ,

function pair#NoremapNext(pair, ...) abort range
    let l:pair = s:RegisterNoremapPair(a:pair)
    call s:InitPairCallback(l:pair, 'next', s:CheckOptsDict(a:000))
    return "\<cmd>call ".pair#SID()."PairComputeMapCallback('init')\<cr>"
endfunction

function pair#NoremapPrevious(pair, ...) abort range
    let l:pair = s:RegisterNoremapPair(a:pair)
    call s:InitPairCallback(l:pair, 'previous', s:CheckOptsDict(a:000))
    return "\<cmd>call ".pair#SID()."PairComputeMapCallback('init')\<cr>"
endfunction

function pair#MapNext(pair, ...) abort range
    call s:InitPairCallback(a:pair, 'next', s:CheckOptsDict(a:000))
    return "\<cmd>call ".pair#SID()."PairComputeMapCallback('init')\<cr>"
endfunction

function pair#MapPrevious(pair, ...) abort range
    call s:InitPairCallback(a:pair, 'previous', s:CheckOptsDict(a:000))
    return "\<cmd>call ".pair#SID()."PairComputeMapCallback('init')\<cr>"
endfunction

function s:RegisterNoremapPair(pair) abort range
    if type(a:pair) != v:t_list || len(a:pair) != 2
        throw 'cyclops.vim: Input must be a pair of maps'
    endif
    let l:map0 = s:RegisterNoremap(a:pair[0])
    let l:map1 = s:RegisterNoremap(a:pair[1])
    return [ l:map0, l:map1 ]
endfunction

function pair#SetMaps(mapping_type, pairs, ...) abort range
    let l:opts = s:CheckOptsDict(a:000)
    if type(a:pairs[0]) == v:t_list
        for l:pair in a:pairs
            call s:SetMap(a:mapping_type, l:pair, l:opts)
        endfor
    else
        call s:SetMap(a:mapping_type, a:pairs, l:opts)
    endif
endfunction

function s:AssertSameRHS(modes, map) abort
    if len(a:modes) < 2
        return
    endif

    let l:first_rhs = maparg(a:map, a:modes[0])
    for l:next_mode in a:modes[1:]
        if l:first_rhs !=# maparg(a:map, l:next_mode)
            throw 'cyclops.vim: Mapped keys in different modes must have the same RHS: '.a:map
        endif
    endfor
endfunction

function s:SetMap(mapping_type, pair, opts) abort
    let l:noremap = (a:mapping_type =~# '\v^(no|nn|vn|xn|sno|ono|no|ino|ln|cno|tno)')
    let l:modes = (a:mapping_type =~# '\v^(no|map)')? 'nvo' : a:mapping_type[0]

    let l:plugpair = ['', '']
    for l:id in range(2)
        " echom l:noremap
        " echom maparg(a:pair[l:id], l:modes[0])
        if l:noremap || empty(maparg(a:pair[l:id], l:modes[0]))
            let l:plugpair[l:id] = s:RegisterNoremap(a:pair[l:id])
        else
            call s:AssertSameRHS(split(l:modes, '\zs'), a:pair[l:id])
            let l:create_plugmap = ''
            let l:plugpair[l:id] = '<plug>(op#_'.a:mapping_type.'_'.a:pair[l:id].')'
            let l:mapinfo = maparg(a:pair[l:id], l:modes[0], 0, 1)
            let l:rhs = substitute(l:mapinfo['rhs'], '\V<sid>', '<snr>'.l:mapinfo['sid'].'_', '')
            let l:rhs = substitute(l:rhs, '\v(\|)@<!\|(\|)@!', '<bar>', 'g')
            let l:create_plugmap .= (l:mapinfo['noremap'])? 'noremap ' : 'map '
            let l:create_plugmap .= (l:mapinfo['buffer'])? '<buffer>' : ''
            let l:create_plugmap .= (l:mapinfo['nowait'])? '<nowait>' : ''
            let l:create_plugmap .= (l:mapinfo['silent'])? '<silent>' : ''
            let l:create_plugmap .= (l:mapinfo['expr'])? '<expr>' : ''
            let l:create_plugmap .= l:plugpair[l:id].' '
            let l:create_plugmap .= l:rhs
            " echom l:create_plugmap
            execute l:create_plugmap
        endif
    endfor
    " echom a:mapping_type.' <expr> '.a:pair[0].' pair#MapNext('.string(l:plugpair).', '.string(a:opts).')'
    " echom a:mapping_type.' <expr> '.a:pair[1].' pair#MapPrevious('.string(l:plugpair).', '.string(a:opts).')'
    execute a:mapping_type.' <expr> '.a:pair[0].' pair#MapNext('.string(l:plugpair).', '.string(a:opts).')'
    execute a:mapping_type.' <expr> '.a:pair[1].' pair#MapPrevious('.string(l:plugpair).', '.string(a:opts).')'
endfunction

function s:PairRepeat(direction, count, register, mode) abort
    let l:stored_handle = s:GetHandle('pair')
    " if has_key(l:stored_handle, 'abort') || empty(l:stored_handle)
    "     return
    " endif
    " if l:stored_handle['expr'] =~# '\V\^'."\<plug>".'(op#_noremap_\[fFtT;,])'
    "     " workaround for cpo-;
    "     let l:stored_handle['expr'] = (a:direction ==# ';')? "\<plug>(op#_noremap_;)" : "\<plug>(op#_noremap_,)"
    "     call s:InitRepeat(l:stored_handle, a:count, a:register, a:mode)
    "     call s:Callback('', 'pair')
    "     return
    " endif

    let l:old_id = l:stored_handle['pair_id']
    let l:id = (a:direction ==# ';')? l:old_id : !l:old_id
    if l:stored_handle['pair_state'][l:id] ==# 'valid'
        call extend(l:stored_handle, {'pair_id': l:id, 'expr': l:stored_handle['pair'][l:id]})
        call s:InitRepeat(l:stored_handle, a:count, a:register, a:mode)
        call s:Callback('', 'pair')
        let l:stored_handle['pair_id'] = l:old_id
    else
        call s:StackInit()
        let l:stack_handle = s:StackTop()
        " TODO: deepcopy from pair partner and modify only necessary fields
        call extend(l:stack_handle, {
                    \ 'accepts_count'    : l:stored_handle['accepts_count'],
                    \ 'accepts_register' : l:stored_handle['accepts_register'],
                    \ 'expr'             : l:stored_handle['pair'][l:id],
                    \ 'expr_so_far'      : '',
                    \ 'input_cache'      : deepcopy(l:stored_handle['inputs']),
                    \ 'input_source'     : 'input_cache',
                    \ 'op_type'          : 'pair',
                    \ 'pair'             : deepcopy(l:stored_handle['pair']),
                    \ 'pair_id'          : l:id,
                    \ 'pair_state'       : l:stored_handle['pair_state'],
                    \ 'shift_marks'      : l:stored_handle['shift_marks'],
                    \ 'visual_motion'    : l:stored_handle['visual_motion'],
                    \ })
        call s:InitRepeat(l:stack_handle, a:count, a:register, a:mode)
        call s:Callback('', 'init')
    endif
endfunction

" function s:PairOpPending(direction)
"     let l:handle = s:GetHandle('pair')
"     if empty(l:handle) || has_key(l:handle, 'abort')
"         return "\<esc>"
"     else
"         let l:old_id = l:handle['pair_id']
"         let l:id = (a:direction ==# ';')? l:old_id : !l:old_id
"         if l:handle['pair_state'][l:id] ==# 'valid'
"             if mode(1) ==# 'no'
"                 let l:op_mode = ( l:handle['cur_start'][1] == l:handle['cur_end'][1] )? '' : 'V'
"             else
"                 let l:op_mode = a:handle['entry_mode'][2]
"             endif
"             return l:op_mode.l:handle['pair'][l:id]
"         else
"             call s:StackInit()
"             let l:top_handle = s:StackTop()
"             call extend(l:top_handle, { 'op_type': 'pair', 'expr': l:handle['pair'][l:id], 'pair': deepcopy(l:handle['pair']) })
"             call extend(l:top_handle, { 'accepts_count': l:handle['accepts_count'], 'accepts_register': l:handle['accepts_register'] })
"             call extend(l:top_handle, { 'shift_marks': l:handle['shift_marks'], 'visual_motion': l:handle['visual_motion'] })
"             call extend(l:top_handle, { 'input_cache': get(l:handle, 'input_cache', []), 'input_source': 'input_cache', 'pair_id': l:id })
"             call extend(l:top_handle, { 'pair_state': l:handle['pair_state'], 'expr_so_far': ''})
"             call extend(l:top_handle, { 'cur_start': getcurpos() })
"             call extend(l:top_handle, { 'operator': v:operator, 'entry_mode': mode(1), 'count1': 1 })
"             return "\<esc>:call ".op#SID()."Callback(".string('').', '.string('init').")\<cr>"
"         endif
"     endif
" endfunction

function s:CheckOptsDict(vargs) abort
    execute "return ".op#SID()."CheckOptsDict(a:vargs)"
endfunction

function s:RegisterNoremap(map) abort
    execute "return ".op#SID()."RegisterNoremap(a:map)"
endfunction

function s:InitCallback(op_type, expr, opts) abort
    execute "return ".op#SID()."InitCallback(a:op_type, a:expr, a:opts)"
endfunction

function s:InitPairCallback(pair, dir, opts) abort
    let l:id = (a:dir ==# 'next')? 0 : 1
    let l:handle = s:InitCallback('pair', a:pair[id], a:opts)
    call extend(l:handle, { 'pair' : {
                \ 'pair_orig'    : a:pair,
                \ 'id'           : l:id,
                \ 'direction'    : a:dir,
                \ } } )
endfunction

function s:PairComputeMapCallback(op_type) abort
    execute "call ".op#SID()."ComputeMapCallback()"

    if a:op_type ==# 'init'
        let l:handle = s:GetHandle('pair')
        let l:id = l:handle['pair']['id']
    endif

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

function s:SID() abort
    return '<SNR>'.matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$').'_'
endfunction

function pair#SID() abort
    return s:SID()
endfunction

if !g:op#no_mappings
    call pair#SetMaps('noremap', [['f', 'F'], ['t', 'T']])
endif

let &cpo = s:cpo
unlet s:cpo
