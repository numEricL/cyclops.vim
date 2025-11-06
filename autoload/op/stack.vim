let s:stack_debug = 0
let s:stack = []

if s:stack_debug
    let s:debug_stack = []
endif

function op#stack#SID() abort
    return expand('<SID>')
endfunction

"
" Stack management functions
"
function s:GetStack() abort
    return s:stack
endfunction

function s:Init() abort
    if s:Depth() > 0 && !empty(s:op_GetException())
        let s:stack = []
    endif
    if s:Depth() == 0
        call s:op_InitScriptVars()
        if s:stack_debug && !empty(s:debug_stack)
            call remove(s:debug_stack, 0, -1)
        endif
        call s:Push('StackInit')
    endif
endfunction

function s:Depth() abort
    return len(s:stack)
endfunction

function s:Push(...) abort
    let l:tag = a:0? a:1 : ''

    call s:op_Log('↓↓↓↓ ' .. l:tag)
    let l:frame = {'stack_level': s:Depth()}
    if !empty(l:tag)
        let l:frame['tag'] = l:tag
    endif

    call add(s:stack, l:frame)
    if s:stack_debug
        call add(s:debug_stack, l:frame)
    endif
endfunction

function s:Pop(...) abort
    let l:tag = a:0? a:1 : get(s:Top(), 'tag', '')
    call s:op_Log('↑↑↑↑ ' .. l:tag)
    call remove(s:stack, -1)
endfunction

function s:Top() abort
    return s:stack[-1]
endfunction

function s:GetPrev(handle) abort
    return s:stack[a:handle['stack_level']-1]
endfunction

"
" wrappers for script-local op# functions
"
function s:op_GetException() abort
    execute 'return ' .. op#SID() .. 'GetException()'
endfunction

function s:op_InitScriptVars() abort
    execute 'call ' .. op#SID() .. 'InitScriptVars()'
endfunction

function s:op_Log(msg) abort
    execute 'call ' .. op#SID() .. 'Log(a:msg)'
endfunction
