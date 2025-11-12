let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

" internal utils

let s:Pad    = function('_op_#log#Pad')
let s:Log    = function('_op_#log#Log')
let s:PModes = function('_op_#log#PModes')

function _op_#utils#ExprWithModifiers(handle) abort
    let l:opts = a:handle['opts']
    let l:mods = a:handle['mods']

    let l:register = (l:opts['accepts_register'])? '"' .. l:mods['register'] : ''
    let l:expr_with_modifiers = l:register .. a:handle['init']['op'] .. a:handle['expr_reduced']

    if l:opts['accepts_count'] && l:mods['count1'] != 1
        let l:expr_with_modifiers = l:mods['count1'].l:expr_with_modifiers
    elseif !l:opts['accepts_count']
        let l:expr_with_modifiers = repeat(l:expr_with_modifiers, l:mods['count1'])
    endif

    " expr_with_modifiers stored for debugging
    let a:handle['expr_with_modifiers'] = l:expr_with_modifiers
    return l:expr_with_modifiers
endfunction

function _op_#utils#GetState() abort
    let [ l:winid, l:win, l:last_undo ] = [ win_getid(), winsaveview(), undotree()['seq_cur'] ]
    let l:v_state = _op_#utils#GetVisualState()
    call winrestview(l:win)
    return { 'winid': l:winid, 'win': l:win, 'last_undo': l:last_undo, 'v_state': l:v_state }
endfunction

function _op_#utils#RestoreState(state) abort
    call win_gotoid(a:state['winid'])
    while a:state['last_undo'] < undotree()['seq_cur']
        silent undo
    endwhile
    call _op_#utils#RestoreVisualState(a:state['v_state'])
    call winrestview(a:state['win'])
endfunction

function _op_#utils#GetVisualState() abort
    if mode(0) !~# '\v^[nvV]$'
        call _op_#op#Throw('cyclops.vim: unsupported mode for restoring visual state: ' .. mode(1))
    endif
    return [ mode(), getpos("'<"), getpos("'>"), visualmode(), getpos('v'), getpos('.') ]
endfunction

function _op_#utils#RestoreVisualState(v_state) abort
    let [ l:mode, l:vmark_start, l:vmark_end, l:visual_mode, l:v_start, l:v_end ] = a:v_state

    if mode(0) !~# '\v^[nvV]$'
        call _op_#op#Throw('cyclops.vim: unsupported mode for restoring visual state: ' .. mode(1))
    endif

    " reset the previous visualmode (e.g. for gv)
    execute "normal! \<esc>" .. l:visual_mode .. "\<esc>"
    call setpos("'<", l:vmark_start)
    call setpos("'>", l:vmark_end)

    if l:mode =~# '\v^[vV]$'
        let l:selectmode = &selectmode | set selectmode=
        call setpos('.', l:v_start)
        execute "normal! " .. l:mode
        call setpos('.', l:v_end)
        let &selectmode = l:selectmode
    endif
endfunction

let &cpo = s:cpo
unlet s:cpo
