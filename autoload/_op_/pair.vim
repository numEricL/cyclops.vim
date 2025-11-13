"
" internal pair# interface
"

let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

function _op_#pair#Initcallback(handle, pair, dir) abort
    call extend(a:handle, { 'pair' : {
                \ 'orig'      : a:pair,
                \ 'reduced'   : [ '', '' ],
                \ 'id'        : (a:dir ==# 'next')? 0 : 1,
                \ } } )
endfunction

function _op_#pair#ComputeMapCallback() abort
    call _op_#op#ComputeMapCallback()
    let l:handle = _op_#op#GetStoredHandle('pair')
    let l:id = l:handle['pair']['id']
    let l:handle['pair']['reduced'][l:id] = l:handle['expr']['reduced']
endfunction

function _op_#pair#PairRepeatMap(dir) abort
    call _op_#init#AssertExprMap()
    let l:stored_handle = _op_#op#GetStoredHandle('pair')

    " do nothing
    if empty(l:stored_handle) || (mode(0) =~# '\v^[vV]$' && l:stored_handle['init']['mode'] ==# 'n')
        return ''
    endif

    call _op_#pair#InitRepeatCallback(l:stored_handle, a:dir)
    let l:id = l:stored_handle['repeat']['id']

    if empty(l:stored_handle['pair']['reduced'][l:id])
        " map must be computed first
        let l:stack_handle = _op_#op#StackInit()
        call _op_#op#InitCallback(l:stack_handle, 'pair', l:stored_handle['pair']['orig'][l:id], l:stored_handle['opts'])
        let l:stack_handle['expr']['input_source'] = 'cache'
        let l:stack_handle['expr']['inputs'] = deepcopy(l:stored_handle['expr']['inputs'])
        let l:stack_handle['pair'] = l:stored_handle['pair']
        let l:stack_handle['pair']['id'] = l:id
        let l:stack_handle['repeat'] = l:stored_handle['repeat']
        return "\<cmd>call _op_#pair#ComputeMapCallback()\<cr>"
    else
        return "\<cmd>call _op_#pair#RepeatCallback()\<cr>"
    endif
endfunction

function _op_#pair#InitRepeatCallback(handle, dir) abort
    " store original direction, needed for determining ; , direction
    let l:init_id = has_key(a:handle, 'repeat')? a:handle['repeat']['init_id'] : a:handle['pair']['id']
    let l:id = (a:dir ==# 'next')? l:init_id : !l:init_id

    call extend(a:handle, { 'repeat' : {
                \ 'init_id' : l:init_id,
                \ 'id'      : l:id,
                \ 'mode'    : mode(1),
                \ } } )
    call extend(a:handle, { 'repeat_mods': {
                \ 'count1'    : v:count1,
                \ 'register' : v:register,
                \ } } )
endfunction

function _op_#pair#RepeatCallback() abort
    let l:handle = _op_#op#GetStoredHandle('pair')
    let l:id = l:handle['repeat']['id']
    let l:expr = l:handle['pair']['reduced'][l:id]
    call feedkeys(_op_#op#ExprWithModifiers(l:expr, l:handle['repeat_mods'], l:handle['opts']))
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
"             call _op_#stack#Init()
"             let l:top_handle = _op_#stack#Top()
"             call extend(l:top_handle, { 'handle_type': 'pair', 'expr': l:handle['pair'][l:id], 'pair': deepcopy(l:handle['pair']) })
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

" OLD
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
        call _op_#stack#Init()
        let l:stack_handle = _op_#stack#Top()
        " TODO: deepcopy from pair partner and modify only necessary fields
        call extend(l:stack_handle, {
                    \ 'accepts_count'    : l:stored_handle['accepts_count'],
                    \ 'accepts_register' : l:stored_handle['accepts_register'],
                    \ 'expr'             : l:stored_handle['pair'][l:id],
                    \ 'expr_so_far'      : '',
                    \ 'input_cache'      : deepcopy(l:stored_handle['inputs']),
                    \ 'input_source'     : 'input_cache',
                    \ 'handle_type'          : 'pair',
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

let &cpo = s:cpo
unlet s:cpo
