"
" internal op# interface
"

let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

" must be single character
let s:hijack_probe = '×'
let s:hijack_esc = repeat("\<esc>", 10)
let s:operator_mode_pattern = '\v^(no[vV]=|consumed|i|c)$'

let s:hijack = {'mode': '', 'cmd': '', 'cmd_type': '' }
let s:input_stream = ''
let s:ambiguous_map_chars = ''
let s:inputs = []

let s:handles = { 'op': {}, 'dot': {}, 'pair': {} }

let s:Pad = function('_op_#log#Pad')
let s:Log = function('_op_#log#Log')

function _op_#op#GetHandles() abort
    return s:handles
endfunction

function _op_#op#GetHandle(op_type) abort
    return _op_#op#GetHandles()[a:op_type]
endfunction

function s:InitScriptVars()
    let s:hijack = {'mode': '', 'cmd': '', 'cmd_type': '' }
    let s:input_stream = ''
    let s:ambiguous_map_chars = ''
    if !empty(s:inputs)
        call remove(s:inputs, 0, -1)
    endif
endfunction

function _op_#op#InitCallback(op_type, expr, opts) abort
    if mode(1) !~# '\v^(n|v|V||no|nov|noV|no)$'
        throw 'cyclops.vim: Entry mode '.string(mode(1)).' not yet supported.'
    endif
    call _op_#stack#Init(function('s:InitScriptVars'))
    let l:handle = _op_#stack#Top()

    call extend(l:handle, { 'opts' : a:opts } )
    call extend(l:handle, { 'init' : {
                \ 'op_type': a:op_type,
                \ 'entry_mode' : mode(1),
                \   } } )
    call extend(l:handle, { 'mods' : {
                \ 'count1' : v:count1,
                \ 'register' : v:register,
                \ } } )
    call extend(l:handle, {
                \ 'expr_orig': a:expr,
                \ 'expr_reduced': a:expr,
                \ 'expr_reduced_so_far': '',
                \ 'input_source': (a:opts['consumes_typeahead']? 'typeahead': 'user'),
                \ })
    return l:handle
endfunction

function _op_#op#ComputeMapCallback() abort range
    let l:handle = _op_#stack#Top()
    call s:Log(s:Pad('Callback ' .. _op_#stack#Depth() .. ' ' .. s:PModes() .. ': ', 30) .. 'expr=' .. l:handle['expr_orig'] .. ' typeahead=' .. substitute(s:ReadTypeahead(), '\m' .. "\<esc>" .. '\+$', "\<esc>", ''))

    " reduces nested op# exprs and concatenates with their inputs
    call s:ComputeMapOnStack(l:handle)

    " execute computed map and store handle in case of repeat
    if _op_#stack#Depth() == 1
        " expr_with_modifiers stored for debugging
        let l:handle['expr_with_modifiers'] = _op_#utils#ExprWithModifiers(l:handle)
        call feedkeys(l:handle['expr_with_modifiers'] .. s:ambiguous_map_chars, 'tx!')
        if l:handle['opts']['silent']
            unsilent echo
        endif
        call s:StoreHandle(l:handle)
    endif
endfunction

function s:ComputeMapOnStack(handle) abort
    if _op_#stack#Depth() == 1
        let s:ambiguous_map_chars = s:StealTypeahead()
        if !empty(s:ambiguous_map_chars)
            call s:Log(s:Pad('ComputeMapOnStack: ', 30) .. 'ambiguous map chars=' .. s:ambiguous_map_chars)
        endif

        try
            " stack recursion starts here
            call s:ComputeMapRecursive(a:handle)
            let l:input = s:HijackInput(a:handle)
            call s:CheckForErrors(a:handle['expr_reduced'] .. s:input_stream)
            let a:handle['expr_reduced'] ..= s:input_stream
        catch /op#abort/
            echohl ErrorMsg | echomsg _op_#stack#GetException() | echohl None
            call interrupt()
        endtry
    else
        call s:ParentReduceExpr(a:handle)
        call inputsave()

        " stack recursion continues here
        call s:ComputeMapRecursive(a:handle)
        let l:input = s:HijackInput(a:handle)
        call s:CheckForErrors(a:handle['expr_reduced'] .. s:input_stream)
        let a:handle['expr_reduced'] ..= s:input_stream
        call s:ParentReduceExprInput(a:handle)

        call feedkeys(a:handle['expr_reduced'], 'tx')
        call inputrestore()
    endif
endfunction

function s:ComputeMapRecursive(handle) abort
    call _op_#stack#Push(s:Pad('Push  ' .. s:PModes() .. ': ', 25) .. 'expr=' .. a:handle['expr_orig'] .. s:hijack_probe .. '<esc>' .. ' typeahead=' .. s:ReadTypeahead())
    call s:ProbeExpr(a:handle['expr_orig'])
    call _op_#stack#Pop(s:Pad('Pop   ' .. s:PModes() .. ': ', 25) .. 'mode=' .. s:hijack['mode'] .. ' cmd=' .. s:hijack['cmd'] .. ' cmd_type=' .. s:hijack['cmd_type'] .. ' typeahead=' .. s:ReadTypeahead())
endfunction

function s:HijackInput(handle) abort
    if s:hijack['mode'] !~# s:operator_mode_pattern
        return ''
    endif

    if a:handle['input_source'] ==# 'input_cache'
        let s:input_stream = remove(a:handle['input_cache'], 0)
        return s:input_stream
    endif

    call s:Log(s:Pad('HijackInput ' .. s:PModes() .. ': ', 30))
    call s:Log(s:Pad('HijackInput GET INPUT: ', 30) .. 'expr=' .. a:handle['expr_reduced'] .. ' typeahead=' .. substitute(s:ReadTypeahead(), '\m' .. "\<esc>" .. '\+$', "\<esc>", ''))

    " Get input from ambig maps, user, or typeahead
    let s:input_stream = ''
    let l:expr = a:handle['expr_reduced']
    while !empty(s:ambiguous_map_chars) && s:hijack['mode'] =~# s:operator_mode_pattern
        let l:ambig_char = strcharpart(s:ambiguous_map_chars, 0, 1)
        let s:ambiguous_map_chars = strcharpart(s:ambiguous_map_chars, 1)
        let s:input_stream ..= l:ambig_char
        call s:ProbeExpr(l:expr .. s:input_stream)
    endwhile

    if s:hijack['mode'] =~# s:operator_mode_pattern
        if a:handle['input_source'] ==# 'user'
            while s:hijack['mode'] =~# s:operator_mode_pattern
                let l:char = s:GetCharFromUser(a:handle)
                let s:input_stream = s:ProcessStream(s:input_stream, l:char)
                call s:ProbeExpr(l:expr .. s:input_stream)
            endwhile
            unsilent echo
            redraw
        else
            while s:hijack['mode'] =~# s:operator_mode_pattern
                let s:input_stream ..= s:GetCharFromTypeahead(a:handle)
                call s:ProbeExpr(l:expr .. s:input_stream)
            endwhile
        endif
    endif
    call s:Log(s:Pad('HijackInput GOT: ', 30) .. 'input_stream=' .. s:input_stream)

    " store
    if !empty(s:input_stream)
        call add(s:inputs, s:input_stream)
    endif

    return s:input_stream
endfunction

function s:CheckForErrors(expr) abort
    let l:state = s:GetState()
    try
        silent call feedkeys(a:expr, 'tx!')
        if getchar(1)
            call s:Throw('cyclops.vim: Incomplete command while processing operator')
        endif
    catch
        call s:Throw('')
    finally
        call s:RestoreState(l:state)
    endtry
endfunction

function s:ProcessStream(stream, char) abort
    let l:stream = a:stream
    if a:char == "\<bs>"
        let l:stream = strcharpart(l:stream, 0, strchars(l:stream)-1)
    else
        let l:stream ..= a:char
    endif
    return l:stream
endfunction

function s:ProbeExpr(expr) abort
    let l:state = s:GetState()

    " HijackProbMap may be consumed instead of expanded, set default case
    let s:hijack = {'mode': 'consumed', 'cmd': '', 'cmd_type': '' }
    let l:belloff = &belloff
    set belloff+=error,esc
    try
        " feedkeys(... s:hijack_probe, 'x') is not working as expected, only
        " last map in stack is processed, execution order is seemingly broken
        " (logging at callback entry doesn't show beginning/intermediate maps)

        " 't' flag fixes an issue when cursor is at end of buffer and '<c-d>' is
        " fed, which prevented the probe from executing.
        silent call feedkeys(a:expr .. s:hijack_probe .. s:hijack_esc, 'tx!')
    catch /op#abort/
        throw 'op#abort'
    catch
    finally
        let &belloff = l:belloff
        call s:RestoreState(l:state)
    endtry
endfunction

" map the first char of s:hijack_probe to get hijack data
" Some commands may consume the RHS and start executing, use something unusual
execute ' noremap <expr>' .. s:hijack_probe .. ' <sid>HijackProbeMap()'
execute 'lnoremap <expr>' .. s:hijack_probe .. ' <sid>HijackProbeMap()'
execute 'tnoremap <expr>' .. s:hijack_probe .. ' <sid>HijackProbeMap()'
function s:HijackProbeMap() abort
    let s:hijack = {'mode': mode(1), 'cmd': getcmdline(), 'cmd_type': getcmdtype() }
    return ''
endfunction

" function s:SetOpMode(handle) abort
"     if has_key(a:handle, 'operator')
"         if a:handle['entry_mode'] ==# 'no'
"             let a:handle['op_mode'] = ( a:handle['cur_start'][1] == getcurpos()[1] )? '' : 'V'
"         else
"             let a:handle['op_mode'] = a:handle['entry_mode'][2]
"         endif
"     endif
" endfunction

function s:ParentReduceExpr(handle) abort
    if _op_#stack#Depth() == 1
        return
    endif
    " Note: maps don't save which key triggered them, but we can deduce this
    " information with the previous stack frame.
    " Note: the parent (up to this point) is the set complement of previous expr
    " and current typeahead (less the hijack stream)

    " calling_expr = [already executed] . [current map call] . [typeahead] . [hijack_probe]
    let l:parent_handle = _op_#stack#GetPrev(a:handle)
    let l:calling_expr = l:parent_handle['expr_reduced']

    " remove remnants of hijack_probe .. hijack_esc placed by HijackInput
    let l:typeahead = s:ReadTypeahead()
    let l:typeahead = substitute(l:typeahead, '\V' .. "\<esc>" .. '\+\$', '', '')
    let l:typeahead = substitute(l:typeahead, '\V' .. s:hijack_probe .. '\$', '', '')

    " [already executed] .. [current map call] .. [typeahead] -> [current map call]
    let l:calling_expr = substitute(l:calling_expr, '\V' .. escape(l:typeahead, '\') .. '\$', '', '')
    let l:calling_expr = substitute(l:calling_expr, '\V\^' .. escape(l:parent_handle['expr_reduced_so_far'], '\'), '', '')

    " in case [current map call] == xxxOP1, remove xxx
    let l:parent_call = l:calling_expr
    if a:handle['init']['entry_mode'] ==# 'n'
        let l:mode = 'n'
    elseif a:handle['init']['entry_mode'] =~# '\v^[vV]$'
        let l:mode = 'x'
    elseif a:handle['init']['entry_mode'] =~# '\v^[sS]$'
        let l:mode = 's'
    elseif a:handle['init']['entry_mode'] =~# '\v^no.=$'
        let l:mode = 'o'
    endif
    let l:count = 0
    while l:parent_call != '' && empty(maparg(substitute(l:parent_call, '\V' .. "\<plug>", '\<plug>', 'g'), l:mode))
        let l:count += 1
        let l:parent_call = strcharpart(l:calling_expr, l:count)
    endwhile

    " store reduced call
    call s:Log(s:Pad('ParentReduceExpr: ', 30) .. 'parent_call=' .. l:parent_call .. '    parent_expr_reduced_so_far+=' .. strcharpart(l:calling_expr, 0, l:count))
    let a:handle['parent_call'] = l:parent_call
    let l:parent_handle['expr_reduced_so_far'] ..= strcharpart(l:calling_expr, 0, l:count)
endfunction

function s:ParentReduceExprInput(handle) abort
    " operator pending case
    " let l:op = get(a:handle, 'op_mode', '')
    let l:op = ''

    let l:expr = l:op . a:handle['expr_reduced']
    let l:parent_handle = _op_#stack#GetPrev(a:handle)
    let l:update_pattern = '\V'.escape(l:parent_handle['expr_reduced_so_far'], '\').'\zs'.escape(a:handle['parent_call'], '\')
    let l:update = substitute(l:parent_handle['expr_reduced'], l:update_pattern, escape(l:expr, '\'), '')
    if l:update ==# l:parent_handle['expr_reduced']
        call s:Throw('cyclops.vim: "Unexpected error while updating parent call"')
    endif
    call s:Log(s:Pad('ParentReduceExprInput:', 30) . 'parent expr='.l:update . '    parent expr_reduced_so_far+='.l:expr)
    let l:parent_handle['expr_reduced'] = l:update
    let l:parent_handle['expr_reduced_so_far'] .= l:expr
endfunction

function s:GetState() abort
    let [ l:mode, l:winid, l:win, l:last_undo ] = [ mode(1), win_getid(), winsaveview(), undotree()['seq_cur'] ]
    if l:mode ==# 'n'
        let l:v_state = _op_#utils#GetVisualState()
    elseif l:mode =~# '\v^[vV]$'
        let l:v_state = _op_#utils#GetVisualState()
    elseif l:mode =~# '\v^no.=$'
        " let [ l:v_mode, l:v_start, l:v_end ] = [ visualmode(), getpos("'<"), getpos("'>") ]
    else
        call s:Throw('cyclops.vim: unsupported mode '.string(l:mode).' in GetState')
    endif
    call winrestview(l:win)
    return { 'mode': l:mode, 'winid': l:winid, 'win': l:win, 'last_undo': l:last_undo, 'v_state': l:v_state }
endfunction

function s:RestoreState(state) abort
    let l:mode = a:state['mode']
    call win_gotoid(a:state['winid'])
    while a:state['last_undo'] < undotree()['seq_cur']
        silent undo
    endwhile
    if l:mode =~# '\v^[nvVsS]$'
        call _op_#utils#SetVisualState(a:state['v_state'])
    elseif l:mode =~# '\v^no.=$'
        " silent! execute "normal! \<esc>"
        " call setpos("'<", a:state['v_start'])
        " call setpos("'>", a:state['v_end'])
    endif
    if l:mode ==# 'n'
        silent! execute "normal! \<esc>"
        " elseif l:mode =~# '\v^[sS]$'
        "     let l:char = l:mode ==# 's'? 'h' : (l:mode ==# 'S'? 'H' : '')
        "     silent! execute "normal! \<esc>g".l:char
    endif
    call winrestview(a:state['win'])
endfunction

function s:GetCharFromUser(handle) abort
    " extra typeahead may be available if user typed fast
    if s:hijack['mode'] ==# 'i'
        let l:char = s:GetCharFromUser_i(a:handle)
    elseif s:hijack['mode'] =~# '\v^(no[vV]=|consumed)$'
        let l:char = s:GetCharFromUser_no(a:handle)
    elseif s:hijack['mode'] ==# 'c'
        let l:char = s:GetCharFromUser_c(a:handle)
    else
        call s:Throw('cyclops.vim: Unsupported hijack mode '.string(s:hijack['mode']))
    endif

    if empty(l:char)
        call s:Throw('cyclops.vim: empty char received from user')
    endif

    " call s:Log(s:Pad('GetCharFromUser: ', 30) .. 'GOT' .. ' char=' .. l:char)
    return l:char
endfunction

function s:GetCharFromUser_i(handle) abort
    let l:match_ids = []
    let l:state = s:GetState()
    try
        " update buffer if waiting for user input
        if !getchar(1)
            call feedkeys(a:handle['expr_reduced'] .. s:input_stream, 'tx')
            let l:cursor_hl = hlexists('Cursor')? 'Cursor' : g:cyclops_cursor_highlight_fallback
            call add(l:match_ids, matchadd(l:cursor_hl, '\%'.line('.').'l\%'.(col('.')+1).'c'))
            redraw
        endif
        let l:char = s:GetCharStr('i')
    finally
        call s:ClearHighlights(l:match_ids)
        call s:RestoreState(l:state)
    endtry

    return l:char
endfunction

function s:GetCharFromUser_no(handle) abort
    let l:match_ids = []

    if !getchar(1)
        unsilent echo 'Operator Input:' .. s:input_stream

        " set highlights
        let l:cursor_hl = hlexists('Cursor')? 'Cursor' : g:cyclops_cursor_highlight_fallback
        if a:handle['init']['entry_mode'] =~# '\v^[vV]$'
            if a:handle['init']['entry_mode'] =~# '\v^[vV]$'
                call add(l:match_ids, matchadd('Visual', '\m\%>'."'".'<\&\%<'."'".'>\&[^$]'))
                call add(l:match_ids, matchadd('Visual', '\m\%'."'".'<\|\%'."'".'>'))
            else
                " TODO  mode
            endif
        endif
        call add(l:match_ids, matchadd(l:cursor_hl, '\%'.line('.').'l\%'.col('.').'c'))
        redraw
    endif

    try
        let l:char = s:GetCharStr('o')
    finally
        call s:ClearHighlights(l:match_ids)
    endtry

    return l:char
endfunction

function s:GetCharFromUser_c(handle) abort
    let l:match_ids = []

    if !getchar(1)
        unsilent echo s:hijack['cmd_type'] .. s:hijack['cmd']

        " set highlights
        let l:cursor_hl = hlexists('Cursor')? 'Cursor' : g:cyclops_cursor_highlight_fallback

        let l:input = (s:hijack['cmd_type'] == s:input_stream[0])? s:input_stream[1:] : s:input_stream
        if s:hijack['cmd_type'] =~# '\v[/?]' && &incsearch
            nohlsearch
            call add(l:match_ids, matchadd(l:cursor_hl, '\%'.line('.').'l\%'.col('.').'c'))
            silent! call add(l:match_ids, matchadd('IncSearch', l:input))
        endif
        redraw
    endif

    try
        let l:char = s:GetCharStr('c')
    finally
        call s:ClearHighlights(l:match_ids)
    endtry

    return l:char
endfunction

function s:GetCharStr(mode) abort
    try
        let l:char = getcharstr()
    catch /^Vim:Interrupt$/
        if !empty(a:mode) && !empty(maparg('<c-c>', a:mode))
            let l:char = "\<c-c>"
        else
            call s:Throw('cyclops.vim: interrupt (<c-c>)')
        endif
    endtry
    return l:char
endfunction

function s:ClearHighlights(match_ids) abort
    for l:id in a:match_ids
        if l:id > 0
            call matchdelete(l:id)
        endif
    endfor
endfunction

function s:GetCharFromTypeahead(handle) abort
    call inputrestore()
    let l:nr = getchar(0)
    let l:char = nr2char(l:nr)
    if l:char ==# s:hijack_probe
        call feedkeys(s:hijack_probe, 'i')
    endif
    call inputsave()

    " traverse stack to find available typeahead (if any)
    let [ l:handle, l:parent_handle ] = [ a:handle, _op_#stack#GetPrev(a:handle) ]
    let l:parent_typeahead = matchstr(l:parent_handle['expr_reduced'], '\V'.l:handle['parent_call'].'\zs\.\*')
    while l:handle['stack_level'] > 1 && empty(l:parent_typeahead)
        let [ l:handle, l:parent_handle ] = [ _op_#stack#GetPrev(l:handle), _op_#stack#GetPrev(l:parent_handle) ]
        let l:parent_typeahead = matchstr(l:parent_handle['expr_reduced'], '\V'.l:handle['parent_call'].'\zs\.\*')
    endwhile

    " consume from parent typeahead if available
    if !empty(l:parent_typeahead)
        let l:parent_handle['expr_reduced'] = matchstr(l:parent_handle['expr_reduced'], '\V\^\.\{-}'.l:handle['parent_call']).strcharpart(l:parent_typeahead, 1)
        if  !empty(l:nr) && ( l:char !=# strcharpart(l:parent_typeahead, 0, 1) )
            call s:Throw('cyclops.vim: Typeahead mismatch while processing operator')
        endif
        let l:char = strcharpart(l:parent_typeahead, 0, 1)
    endif

    if empty(l:char)
        call s:Throw('cyclops.vim: empty typeahead char received from typeahead stack')
    endif

    return l:char
endfunction

function s:ReadTypeahead() abort
    let l:typeahead = s:StealTypeahead()
    call feedkeys(l:typeahead, 'i')
    return l:typeahead
endfunction

function s:StealTypeahead() abort
    let l:typeahead = ''
    while getchar(1)
        let l:typeahead ..= getcharstr(0)
        if empty(l:typeahead)
            call s:Throw('cyclops.vim: empty typeahead char received while stealing typeahead')
        endif
        if strchars(l:typeahead) > g:cyclops_max_input_size
            call s:Log(s:Pad('STEALTYPEAHEAD: ', 30) . 'TYPEAHEAD OVERFLOW')
            call s:Log(s:Pad('', 20) . l:typeahead[0:30].'...')
            call s:Throw('cyclops.vim: Typeahead overflow while reading typeahead (incomplete command called in normal mode?)')
        endif
    endwhile
    return l:typeahead
endfunction

function s:StoreHandle(handle) abort
    let l:handle_to_store = deepcopy(a:handle)
    call extend(l:handle_to_store, { 'inputs': s:inputs })
    call remove(l:handle_to_store, 'stack_level')

    let l:name = a:handle['init']['op_type']
    let s:handles[l:name] = l:handle_to_store
    call _op_#stack#Pop()
endfunction

function s:ShiftToCursor(cur_start, cur_end) abort
    let l:cur_pos = getcurpos()
    let l:shifted_lnr = l:cur_pos[1]+(a:cur_end[1]-a:cur_start[1])
    let l:shifted_pos = s:GetScreenPos(l:shifted_lnr, s:GetScreenCol(l:cur_pos)+s:GetScreenCol(a:cur_end)-s:GetScreenCol(a:cur_start))
    call setpos('.', l:cur_pos)
    return [ l:cur_pos, l:shifted_pos ]
endfunction

function s:GetScreenPos(linenr, col) abort
    let l:col = max([1, a:col])
    silent! execute 'normal! '.a:linenr.'G'.l:col.'|'
    return getpos('.')
endfunction

function s:GetScreenCol(pos) abort
    return virtcol(a:pos[1:3]) ? virtcol(a:pos[1:3]) : a:pos[2]
endfunction

function s:Throw(msg) 
    let l:msg = empty(a:msg)? v:exception : a:msg
    try
        throw 'op#abort'
    catch /op#abort/
        call _op_#stack#SetException(l:msg)

        call s:Log('')
        call s:Log('EXCEPTION: ' .. l:msg)
        call s:Log(v:throwpoint)
        throw 'op#abort'
    endtry
endfunction

function s:PModes() abort
    if empty(s:hijack['mode'])
        let l:hmode = '-'
    elseif s:hijack['mode'] ==# 'consumed'
        let l:hmode = 'cns'
    else
        let l:hmode = s:hijack['mode']
    endif
    return '(' . mode(1) . '|' . l:hmode . ')'
endfunction

" function s:SetDefaultRegister() abort
"     silent! execute "normal! \<esc>"
"     let s:default_register = v:register
" endfunction

function op#SID() abort
    return expand('<SID>')
endfunction

noremap <plug>(op#_noremap_f) f
noremap <plug>(op#_noremap_F) F
noremap <plug>(op#_noremap_t) t
noremap <plug>(op#_noremap_T) T
omap <plug>(op#_noremap_f) <plug>(op#_workaround_f)
omap <plug>(op#_noremap_F) <plug>(op#_workaround_F)
omap <plug>(op#_noremap_t) <plug>(op#_workaround_t)
omap <plug>(op#_noremap_T) <plug>(op#_workaround_T)
onoremap <expr> <plug>(op#_workaround_f) <sid>Workaround_f('f')
onoremap <expr> <plug>(op#_workaround_F) <sid>Workaround_f('F')
onoremap <expr> <plug>(op#_workaround_t) <sid>Workaround_f('t')
onoremap <expr> <plug>(op#_workaround_T) <sid>Workaround_f('T')

let s:workaround_f = 0
function s:Workaround_f(char)
    let s:workaround_f = 1
    return a:char
endfunction

let &cpo = s:cpo
unlet s:cpo

" function s:PrepareRepeat(handle) abort
"     let l:count = a:handle['repeat_count']
"     let l:register = a:handle['repeat_register']
"     let l:mode = a:handle['repeat_mode']
"
"     if l:mode ==# 'normal'
"         call extend(a:handle, { 'entry_mode': 'n', 'cur_start': getcurpos()})
"     elseif l:mode ==# 'visual'
"         let l:selectmode = &selectmode | set selectmode=
"         silent! execute "normal! \<esc>gv"
"         let &selectmode = l:selectmode
"         call extend(a:handle, { 'entry_mode': mode(1), 'cur_start': getcurpos()})
"     endif
"     let a:handle['count1'] = (l:count || !has_key(a:handle, 'count1'))? max([1,l:count]) : a:handle['count1']
"     let a:handle['register'] = l:register
"     if get(a:handle['opts'], 'shift_marks')
"         if l:mode ==# 'normal'
"             let [ a:handle['v_start'], a:handle['v_end'] ] = s:ShiftToCursor(a:handle['v_start'], a:handle['v_end'])
"             call setpos('.', a:handle['v_start'])
"             let l:selectmode = &selectmode | set selectmode=
"             silent! execute "normal! ".a:handle['v_mode']
"             let &selectmode = l:selectmode
"             call setpos('.', a:handle['v_end'])
"             silent! execute "normal! \<esc>"
"         endif
"         let [ l:shifted_start, l:shifted_end ] = s:ShiftToCursor(getpos("'["), getpos("']"))
"         call setpos("'[", l:shifted_start)
"         call setpos("']", l:shifted_end)
"     endif
" endfunction
