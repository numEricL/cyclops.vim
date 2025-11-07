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
    let l:mode = mode(1)
    if l:mode !~# '\v^[nvV]$'
        call s:Throw('cyclops.vim: GetVisualState called in unsupported mode '.string(l:mode))
    endif

    let l:selectmode = &selectmode | set selectmode=
    " exit/re-enter visual mode to get visualmode()
    silent! execute "normal! \<esc>gv"
    let &selectmode = l:selectmode
    let l:v_state = [ visualmode(), getpos('v'), getpos('.') ]

    if l:mode ==# 'n'
        silent! execute "normal! \<esc>"
    endif
    return l:v_state
endfunction

function _op_#utils#SetVisualState(v_state) abort
    let [ l:v_mode, l:v_start, l:v_end ] = a:v_state
    silent! execute "normal! \<esc>"
    call setpos('.', l:v_start)
    let l:selectmode = &selectmode | set selectmode=
    silent! execute "normal! ".l:v_mode
    let &selectmode = l:selectmode
    call setpos('.', l:v_end)
endfunction

let &cpo = s:cpo
unlet s:cpo
