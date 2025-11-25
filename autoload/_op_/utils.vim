let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

" internal utils

let s:Pad    = function('_op_#log#Pad')
let s:Log    = function('_op_#log#Log')
let s:PModes = function('_op_#log#PModes')

function _op_#utils#GetState() abort
    let l:state = {
                \ 'winid'    : win_getid(),
                \ 'win'      : winsaveview(),
                \ 'bufnr'    : bufnr(),
                \ 'undo_pos' : undotree()['seq_cur'],
                \ 'v_state'  : _op_#utils#GetVisualState(),
                \ }
    return l:state
endfunction

function _op_#utils#RestoreState(state) abort
    call s:Log('RestoreState', '', _op_#stack#Top()['expr']['orig'])
    call win_gotoid(a:state['winid'])

    let l:cur_bufnr = bufnr()
    execute 'buffer ' .. a:state['bufnr']
    silent execute 'undo ' .. a:state['undo_pos']
    execute 'buffer ' .. l:cur_bufnr

    call _op_#utils#RestoreVisualState(a:state['v_state'])
    call winrestview(a:state['win'])
endfunction

function _op_#utils#GetVisualState() abort
    if mode(0) !~# '\v^[nvV]$'
        call _op_#op#Throw('unsupported mode for restoring visual state: ' .. mode(1))
    endif
    return [ mode(), getpos("'<"), getpos("'>"), visualmode(), getpos('v'), getpos('.') ]
endfunction

function _op_#utils#RestoreVisualState(v_state) abort
    let [ l:mode, l:vmark_start, l:vmark_end, l:visual_mode, l:v_start, l:v_end ] = a:v_state

    if mode(0) !~# '\v^[nvV]$'
        call _op_#op#Throw('unsupported mode for restoring visual state: ' .. mode(1))
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

function _op_#utils#DefaultRegister() abort
    if stridx(&clipboard, 'unnamedplus') != -1
        return '+'
    elseif stridx(&clipboard, 'unnamed') != -1
        return '*'
    else
        return '"'
    endif
endfunction

function _op_#utils#GetType(val) abort
    let l:type = type(a:val)
    if     l:type == v:t_number
        return 'num'
    elseif l:type == v:t_string
        return 'str'
    elseif l:type == v:t_func
        return 'func'
    elseif l:type == v:t_list
        return 'list'
    elseif l:type == v:t_dict
        return 'dict'
    elseif l:type == v:t_float
        return 'float'
    elseif l:type == v:t_bool
        return 'bool'
    elseif l:type == 7
        return 'null'
    elseif l:type == v:t_blob
        return 'blob'
    else
        return 'unknown'
    endif
endfunction

let &cpo = s:cpo
unlet s:cpo
