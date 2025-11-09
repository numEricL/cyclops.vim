let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

" internal utils

function _op_#utils#ExprWithModifiers(handle) abort
    let l:opts = a:handle['opts']
    let l:mods = a:handle['mods']

    let l:register = (l:opts['accepts_register'])? '"' .. l:mods['register'] : ''
    let l:expr_with_modifiers = l:register .. a:handle['expr_reduced']

    if l:opts['accepts_count'] && l:mods['count1'] != 1
        let l:expr_with_modifiers = l:mods['count1'].l:expr_with_modifiers
    elseif !l:opts['accepts_count']
        let l:expr_with_modifiers = repeat(l:expr_with_modifiers, l:mods['count1'])
    endif
    return l:expr_with_modifiers
endfunction

function _op_#utils#GetVisualState() abort
    let l:mode = mode()
    if l:mode =~# '\v^[vV]$'
        let l:v_state = [ l:mode, getpos('v'), getpos('.') ]
    else
        " TODO: fix to work with reverse orientation
        let l:v_state = [ visualmode(), getpos("'<"), getpos("'>") ]
    endif
    return l:v_state
endfunction

function _op_#utils#RestoreVisualState(v_state) abort
    let [ l:v_mode, l:v_start, l:v_end ] = a:v_state
    let l:enter_mode = mode()

    " temp solution that works most of the time
    if l:enter_mode =~# '\v^[vV]$'
        execute "normal! \<esc>"
    endif
    call setpos("'<", l:v_start)
    call setpos("'>", l:v_end)
    if l:enter_mode =~# '\v^[vV]$'
        let l:selectmode = &selectmode | set selectmode=
        normal! gv
        let &selectmode = l:selectmode
    endif
endfunction

" TODO: update to work with operator pending mode
" function _op#utils#SetVisualState(v_state) abort
"     let [ l:v_mode, l:v_start, l:v_end ] = a:v_state
"     silent! execute "normal! \<esc>"
"     call setpos('.', l:v_start)
"     let l:selectmode = &selectmode | set selectmode=
"     silent! execute "normal! ".l:v_mode
"     let &selectmode = l:selectmode
"     call setpos('.', l:v_end)
" endfunction

let &cpo = s:cpo
unlet s:cpo
