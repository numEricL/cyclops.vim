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

    if empty(l:stored_handle)
        return ''
    endif

    call _op_#pair#InitRepeatCallback(l:stored_handle, a:dir)
    let l:id = l:stored_handle['repeat']['id']

    if empty(l:stored_handle['pair']['reduced'][l:id])
        " map must be computed first
        let l:stack_handle = _op_#op#StackInit()
        call _op_#op#InitCallback(l:stack_handle, 'pair', l:stored_handle['pair']['orig'][l:id], l:stored_handle['opts'])
        let l:stack_handle['init']['input_source'] = 'cache'
        let l:stack_handle['expr']['inputs'] = deepcopy(l:stored_handle['expr']['inputs'])
        let l:stack_handle['pair'] = l:stored_handle['pair']
        let l:stack_handle['pair']['id'] = l:id
        let l:stack_handle['repeat'] = l:stored_handle['repeat']
        let l:stack_handle['mods'] = l:stored_handle['repeat_mods']
        return "\<cmd>call _op_#pair#ComputeMapCallback()\<cr>"
    else
        return "\<cmd>call _op_#pair#RepeatCallback()\<cr>"
    endif
endfunction

function _op_#pair#InitRepeatCallback(handle, dir) abort
    " store original direction, needed for determining ; , direction
    let l:init_id = has_key(a:handle, 'repeat')? a:handle['repeat']['init_id'] : a:handle['pair']['id']
    if a:handle['opts']['absolute_direction']
        let l:id = (a:dir !=# 'next')
    else
        let l:id = (a:dir ==# 'next')? l:init_id : !l:init_id
    endif
    if (a:handle['opts']['persistent_count'] && v:count == 0)
        let l:init_count = has_key(a:handle, 'mods')? a:handle['mods']['count'] : 0
        let l:count = has_key(a:handle, 'repeat_mods')? a:handle['repeat_mods']['count'] : l:init_count
    else 
        let l:count = v:count
    endif

    call extend(a:handle, { 'repeat' : {
                \ 'init_id' : l:init_id,
                \ 'id'      : l:id,
                \ 'mode'    : mode(1),
                \ } } )
    call extend(a:handle, { 'repeat_mods': {
                \ 'count'    : l:count,
                \ 'register' : v:register,
                \ } } )
endfunction

function _op_#pair#RepeatCallback() abort
    let l:handle = _op_#op#GetStoredHandle('pair')
    let l:id = l:handle['repeat']['id']
    let l:expr = l:handle['pair']['reduced'][l:id]
    call inputsave()
    if l:handle['opts']['silent']
        silent call feedkeys(_op_#op#ExprWithModifiers(l:expr, l:handle['repeat_mods'], l:handle['opts']), 'x!')
    else
        call feedkeys(_op_#op#ExprWithModifiers(l:expr, l:handle['repeat_mods'], l:handle['opts']), 'x!')
    endif
    call inputrestore()
endfunction

let &cpo = s:cpo
unlet s:cpo
