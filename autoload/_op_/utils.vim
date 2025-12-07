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
    silent execute 'buffer ' .. a:state['bufnr']
    silent execute 'undo ' .. a:state['undo_pos']
    silent execute 'buffer ' .. l:cur_bufnr

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

function _op_#utils#HasVersion(ver, ...) abort
    if has('nvim')
        return v:true
    endif
    if a:0 == 0
        return v:version >= a:ver
    else
        return v:version > a:ver || v:version == a:ver && has('patch'.string(a:1))
    endif
endfunction

function _op_#utils#RestoreVisual_COMPAT(handle) abort
    " this is a workaround for old vim versions without <cmd>
    if _op_#utils#HasVersion(802, 1978)
        return
    endif
    if a:handle['init']['mode'] =~# '\v^[vV]$' && mode() ==# 'n'
        let l:selectmode = &selectmode | set selectmode=
        normal! gv
        let &selectmode = l:selectmode
    endif
endfunction

function _op_#utils#Feedkeys(expr, mode) abort
    let [ l:timeout, l:timeoutlen ]   = [ &timeout, &timeoutlen ]   | set timeout timeoutlen=0
    let [ l:ttimeout, l:ttimeoutlen ] = [ &ttimeout, &ttimeoutlen ] | set ttimeout ttimeoutlen=0
    try
        call feedkeys(a:expr, a:mode)
    finally
        let [ &ttimeout, &ttimeoutlen ] = [ l:ttimeout, l:ttimeoutlen ]
        let [ &timeout, &timeoutlen ]   = [ l:timeout, l:timeoutlen ]
    endtry
endfunction

function _op_#utils#QueueReset(queue) abort
    let a:queue['id'] = -1
    if !empty(a:queue['list'])
        call remove(a:queue['list'], 0, -1)
    endif
endfunction

function _op_#utils#QueuePush(queue, item) abort
    call add(a:queue['list'], a:item)
endfunction

function _op_#utils#QueueNext(queue) abort
    let a:queue['id'] += 1
    return a:queue['list'][a:queue['id']]
endfunction

let &cpo = s:cpo
unlet s:cpo
