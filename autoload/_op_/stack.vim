let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

let s:stack_debug = 0
let s:stack = []
let s:exception = ''
let s:throwpoint = ''
let s:stack_id = -1

if s:stack_debug
    let s:debug_stack = []
endif

"
" Internal API
"
let s:GetStack = function('_op_#stack#GetStack')
let s:Init     = function('_op_#stack#Init')
let s:Depth    = function('_op_#stack#Depth')
let s:Push     = function('_op_#stack#Push')
let s:Pop      = function('_op_#stack#Pop')
let s:Top      = function('_op_#stack#Top')
let s:GetPrev  = function('_op_#stack#GetPrev')

"
" Stack management functions
"
function _op_#stack#GetStack() abort
    return s:stack
endfunction

function _op_#stack#Init(init_func) abort
    if s:Depth() > 0 && !empty(s:exception)
        let s:stack = []
    endif
    if s:Depth() == 0
        call a:init_func()
        let s:exception = ''
        let s:stack_id = -1
        if s:stack_debug && !empty(s:debug_stack)
            call remove(s:debug_stack, 0, -1)
        endif
        call _op_#log#InitDebugLog()
        call s:Push('init', 'StackInit')
    endif
    return s:Top()
endfunction

function _op_#stack#Depth() abort
    return len(s:stack)
endfunction

function _op_#stack#Push(type, msg) abort
    let s:stack_id += 1
    let l:frame = { 'stack' : {
                \ 'level': s:Depth(),
                \ 'id': s:stack_id,
                \ } }
    call add(s:stack, l:frame)
    if s:stack_debug
        call add(s:debug_stack, l:frame)
    endif
    call _op_#log#Log('↓↓↓↓ Push ' .. s:stack_id .. ' ' .. a:type, _op_#log#PModes(0), a:msg)
    return s:stack_id
endfunction

function _op_#stack#Pop(stack_id, msg) abort
    call _op_#log#Log('↑↑↑↑ Pop  ' .. a:stack_id, _op_#log#PModes(2), a:msg)
    call remove(s:stack, -1)
endfunction

function _op_#stack#Top() abort
    return s:stack[-1]
endfunction

function _op_#stack#GetPrev(handle) abort
    return s:stack[a:handle['stack_level']-1]
endfunction

function _op_#stack#GetException() abort
    return s:exception
endfunction

function _op_#stack#GetThrowpoint() abort
    return s:throwpoint
endfunction

function _op_#stack#SetException(exception, throwpoint) abort
    let s:exception = a:exception
    let s:throwpoint = a:throwpoint
endfunction

let &cpo = s:cpo
unlet s:cpo
