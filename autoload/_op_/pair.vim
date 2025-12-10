"
" internal pair# interface
"

let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

let s:Log = function('_op_#log#Log')

function _op_#pair#Initcallback(handle, pair, dir) abort
    call extend(a:handle, { 'pair' : {
                \ 'orig'      : a:pair,
                \ 'reduced'   : [ '', '' ],
                \ 'id'        : (a:dir ==# 'next')? 0 : 1,
                \ } } )
endfunction

function _op_#pair#ComputeMapCallback() abort
    let l:result = _op_#op#ComputeMapCallback()
    if l:result ==# 'op#insert_callback'
        return
    endif
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

    let l:cmd_COMPAT = _op_#utils#HasVersion(802, 1978)? "\<cmd>" : ":\<c-u>"
    if empty(l:stored_handle['pair']['reduced'][l:id])
        " map must be computed first
        let l:stack_handle = _op_#op#StackInit()
        call _op_#op#InitCallback(l:stack_handle, 'pair', l:stored_handle['pair']['orig'][l:id], l:stored_handle['opts'])
        let l:stack_handle['init']['input_source'] = 'cache'
        let l:stack_handle['macro']['append_input'] = v:false
        let l:stack_handle['expr']['inputs'] = l:stored_handle['expr']['inputs']
        let l:stack_handle['pair'] = l:stored_handle['pair']
        let l:stack_handle['pair']['id'] = l:id
        let l:stack_handle['repeat'] = l:stored_handle['repeat']
        let l:stack_handle['mods'] = l:stored_handle['repeat_mods']
        return l:cmd_COMPAT .. "call _op_#pair#ComputeMapCallback()\<cr>"
    else
        return l:cmd_COMPAT .. "call _op_#pair#RepeatCallback()\<cr>"
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
                \ 'reg_recording' : reg_recording(),
                \ } } )
    call extend(a:handle, { 'repeat_mods': {
                \ 'count'    : l:count,
                \ 'register' : v:register,
                \ } } )
endfunction

function _op_#pair#RepeatCallback() abort
    let l:handle = _op_#op#GetStoredHandle('pair')
    call _op_#utils#RestoreVisual_COMPAT(l:handle)
    call inputsave()
    let l:macro_content = _op_#utils#MacroStop('')
    let l:id = l:handle['repeat']['id']
    let l:expr_with_modifiers = _op_#op#ExprWithModifiers(l:handle['pair']['reduced'][l:id], l:handle['repeat_mods'], l:handle['opts'])
    call s:Log('pair#RepeatCallback', '', 'FEED_tx=' .. l:expr_with_modifiers)
    call _op_#utils#Feedkeys(l:expr_with_modifiers, 'tx')
    call _op_#utils#MacroResume(l:handle['repeat']['reg_recording'], l:macro_content)
    call inputrestore()
endfunction

let &cpo = s:cpo
unlet s:cpo
