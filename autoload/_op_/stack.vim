let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

let s:stack_debug = 0
let s:stack = []
let s:exception = ''

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
        if s:stack_debug && !empty(s:debug_stack)
            call remove(s:debug_stack, 0, -1)
        endif
        call _op_#log#ClearDebugLog()
        call s:Push('StackInit')
    endif
endfunction

function _op_#stack#Depth() abort
    return len(s:stack)
endfunction

function _op_#stack#Push(...) abort
    let l:tag = a:0? a:1 : ''

    call _op_#log#Log('↓↓↓↓ ' .. l:tag)
    let l:frame = {'stack_level': s:Depth()}
    if !empty(l:tag)
        let l:frame['tag'] = l:tag
    endif

    call add(s:stack, l:frame)
    if s:stack_debug
        call add(s:debug_stack, l:frame)
    endif
endfunction

function _op_#stack#Pop(...) abort
    let l:tag = a:0? a:1 : get(s:Top(), 'tag', '')
    call _op_#log#Log('↑↑↑↑ ' .. l:tag)
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

function _op_#stack#SetException(msg) abort
    let s:exception = a:msg
endfunction

let &cpo = s:cpo
unlet s:cpo
