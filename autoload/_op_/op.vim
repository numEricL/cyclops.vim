"
" internal op# interface
"

"TODO: use neovim virtual text instead of actual insertion during HijackInput
"TODO: enable chained operand support

let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

" must be single character
let s:hijack_probe = '×'
let s:hijack_esc = repeat("\<esc>", 3)

" n-l no-l catches f, F, t, T in lang mode (e.g. fa and dfa)
" this pattern matches also n-l-l and v-l-l, but these modes are not possible and this pattern is simpler
let s:operator_hmode_pattern = '\v^(no[vV]?|consumed|i|c|[nv]-l)(-l)?$'

let s:hijack = {'hmode': '', 'cmd': '', 'cmd_type': '', 'lmap': ''}
let s:input_stream = ''
let s:ambiguous_map_chars = ''
let s:inputs = []

let s:handles = { 'op': {}, 'dot': {}, 'pair': {} }

let s:Log    = function('_op_#log#Log')
let s:PModes = function('_op_#log#PModes')

function _op_#op#GetHandles() abort
    return s:handles
endfunction

function _op_#op#GetHandle(handle_type) abort
    return _op_#op#GetHandles()[a:handle_type]
endfunction

function s:InitScriptVars()
    let s:input_stream = ''
    let s:hijack = {'hmode': '', 'cmd': '', 'cmd_type': '', 'lmap': ''} " init early for s:Log
    let s:ambiguous_map_chars = ''
    if !empty(s:inputs)
        call remove(s:inputs, 0, -1)
    endif
endfunction

function _op_#op#InitCallback(handle_type, expr, opts) abort
    if mode(1) !~# '\v^(n|v|V||no|nov|noV|no)$'
        throw 'cyclops.vim: Entry mode '.string(mode(1)).' not yet supported.'
    endif
    call _op_#stack#Init(function('s:InitScriptVars'))
    let l:handle = _op_#stack#Top()

    call extend(l:handle, { 'opts' : a:opts } )
    call extend(l:handle, { 'init' : {
                \ 'handle_type' : a:handle_type,
                \ 'entry_mode'  : mode(1),
                \ 'op_type'     : mode(1)[:1] ==# 'no'? 'operand' : 'operator',
                \ 'op'          : mode(1)[:1] ==# 'no'? _op_#init#RegisterNoremap(v:operator .. mode(1)[2]) : '',
                \ } } )
    call extend(l:handle, { 'mods' : {
                \ 'count1'   : v:count1,
                \ 'register' : v:register,
                \ } } )
    call extend(l:handle, {
                \ 'expr_orig'           : a:expr,
                \ 'expr_reduced'        : a:expr,
                \ 'expr_reduced_so_far' : '',
                \ 'input_source'        : (a:opts['consumes_typeahead']? 'typeahead': 'user'),
                \ 'op_input_id'         : -1,
                \ })
    return l:handle
endfunction

function _op_#op#ComputeMapCallback() abort range
    let l:handle = _op_#stack#Top()
    call s:Log('ComputeMapCallback', s:PModes(2), 'expr=' .. l:handle['expr_orig'] .. ' typeahead=' .. s:TypeaheadLog())

    " reduces nested op# exprs and their inputs
    call s:ComputeMapOnStack(l:handle)

    let l:expr_with_modifiers = _op_#utils#ExprWithModifiers(l:handle)
    call s:StoreHandle(l:handle)

    if _op_#stack#Depth() == 1
        call s:Log('EXIT', s:PModes(0), 'FEED_tx!=' .. l:expr_with_modifiers .. s:ambiguous_map_chars)
        call feedkeys(l:expr_with_modifiers .. s:ambiguous_map_chars, 'tx!')
        if l:handle['opts']['silent']
            unsilent echo
        endif
        call _op_#stack#Pop(0, 'StackInit')
    endif
endfunction

function s:ComputeMapOnStack(handle) abort
    if _op_#stack#Depth() == 1
        let s:ambiguous_map_chars = s:StealTypeaheadTruncated()
        if s:ambiguous_map_chars =~# '\v' .. "\<esc>" .. '{' .. g:cyclops_max_trunc_esc .. '}$'
            call _op_#op#Throw('cyclops.vim: Typeahead overflow while setting ambiguous_map_chars')
        endif
        if !empty(s:ambiguous_map_chars)
            call s:Log('ComputeMapOnStack', '', 'ambiguous map chars=' .. s:ambiguous_map_chars)
        endif

        try
            " recursion typically happens at this ProbeExpr call, but can also
            " happen in HijackInput if a registered omap is triggered

            call s:ProbeExpr(a:handle['init']['op'] .. a:handle['expr_orig'], 'expr_orig')
            let l:input = s:HijackInput(a:handle)
            call s:CheckForErrors(a:handle['init']['op'] .. a:handle['expr_reduced'] .. l:input)
            let a:handle['expr_reduced'] ..= l:input
        catch /op#abort/
            echohl ErrorMsg | echomsg _op_#stack#GetException() | echohl None
            call interrupt()
        endtry
    else
        call s:ParentCallInit(a:handle)
        call inputsave()

        call s:ProbeExpr(a:handle['init']['op'] .. a:handle['expr_orig'], 'expr_orig')
        let l:input = s:HijackInput(a:handle)
        call s:CheckForErrors(a:handle['init']['op'] .. a:handle['expr_reduced'] .. l:input)
        let a:handle['expr_reduced'] ..= l:input
        call s:ParentCallUpdate(a:handle)

        call s:Log('ComputeMapOnStack', 'EXIT', 'FEED_tx!=' .. a:handle['init']['op'] .. a:handle['expr_reduced'])
        silent call feedkeys(a:handle['init']['op'] .. a:handle['expr_reduced'], 'tx!')
        call inputrestore()
    endif
endfunction

function s:HijackInput(handle) abort
    call s:Log('HijackInput ', s:PModes(2))
    if s:hijack['hmode'] !~# s:operator_hmode_pattern
        call s:Log('HijackInput EXIT', '', 'non-operator mode detected: mode=' .. s:hijack['hmode'])
        return ''
    endif

    if a:handle['input_source'] ==# 'input_cache'
        let s:input_stream = remove(a:handle['input_cache'], 0)
        return s:input_stream
    endif

    " Get input from ambig maps, user, or typeahead
    let s:input_stream = ''
    let l:op = a:handle['init']['op']
    let l:expr = a:handle['expr_reduced']

    " call s:Log(s:Pad('HijackInput GET INPUT: ', 30) .. 'expr=' .. l:op .. l:expr .. ' typeahead=' .. s:TypeaheadLog())

    while !empty(s:ambiguous_map_chars) && s:hijack['hmode'] =~# s:operator_hmode_pattern
        let l:ambig_char = strcharpart(s:ambiguous_map_chars, 0, 1)
        let s:ambiguous_map_chars = strcharpart(s:ambiguous_map_chars, 1)
        let s:input_stream ..= l:ambig_char
        call s:ProbeExpr(l:op .. l:expr .. s:input_stream, 'ambig chars')
    endwhile

    if s:hijack['hmode'] =~# s:operator_hmode_pattern
        if a:handle['input_source'] ==# 'user'
            while s:hijack['hmode'] =~# s:operator_hmode_pattern
                let l:char = s:GetCharFromUser(a:handle)
                call s:Log('', 'GOT CHAR=' .. l:char)
                let s:input_stream = s:ProcessStream(s:input_stream, l:char)
                call s:Log('', 'input_stream=' .. s:input_stream)
                if s:hijack['hmode'] =~# '\v^no[vV]?-l$'
                    call s:Log('HijackInput no-l break', '', "feedkeys('dfa×') workaround")
                    " Problem: feedkeys('dfa×') ends in (lang) operator pending mode
                    " Workaround: break out of loop early if detected
                    " let s:hijack['hmode'] = 'n'
                    break
                endif
                call s:ProbeExpr(l:op .. l:expr .. s:input_stream, 'hijack')
            endwhile
            unsilent echo
            redraw
        else
            while s:hijack['hmode'] =~# s:operator_hmode_pattern
                let s:input_stream ..= s:GetCharFromTypeahead(a:handle)
                call s:ProbeExpr(l:op .. l:expr .. s:input_stream, 'typeahead')
            endwhile
        endif
    endif
    call s:Log('HijackInput', '', 'input_stream=' .. s:input_stream)

    " TODO: this needs to be generalized to allow chained operands
    " s:input_stream is global and reset at each stack frame. Operands overwrite
    " the input stream, so let the operand store it's parent input stream (which
    " is expr_reduced of this frame) too.
    if a:handle['init']['op_type'] ==# 'operand'
        call s:Log('HijackInput', 'store', 'operand=' .. a:handle['expr_reduced'])
        call add(s:inputs, a:handle['expr_reduced'])
    endif
    if !empty(s:input_stream)
        call s:Log('HijackInput', 'store', 'input_stream=' .. s:input_stream)
        let a:handle['op_input_id'] = len(s:inputs)
        call add(s:inputs, s:input_stream)
    endif

    let l:input_stream = s:input_stream
    let s:input_stream = ''
    return l:input_stream
endfunction

function s:CheckForErrors(expr) abort
    if !g:cyclops_check_for_errors_enabled
        return
    endif
    call s:Log('CheckForErrors', s:PModes(0), 'FEED_tx!=' .. a:expr .. ' typeahead=' .. s:TypeaheadLog())
    let l:state = _op_#utils#GetState()
    try
        silent call feedkeys(a:expr, 'tx!')
        if getchar(1)
            call _op_#op#Throw('cyclops.vim: Incomplete command while processing operator')
        endif
    catch
        call _op_#op#Throw()
    finally
        call _op_#utils#RestoreState(l:state)
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

function s:ProbeExpr(expr, type) abort
    let l:msg = 'FEED_tx!=' .. a:expr .. '<PROBE>' .. ' typeahead=' .. s:TypeaheadLog()
    let l:stack_id = _op_#stack#Push(a:type, l:msg)

    let l:state = _op_#utils#GetState()

    " HijackProbMap may be consumed instead of expanded, set default case
    let s:hijack = {'hmode': 'consumed', 'cmd': '', 'cmd_type': '', 'lmap': '' }

    " vim uses these timeouts for feedkeys, neovim apparently does not
    let [ l:timeout, l:timeoutlen ] = [ &timeout, &timeoutlen ] | set timeout timeoutlen=0
    let [ l:ttimeout, l:ttimeoutlen ] = [ &ttimeout, &ttimeoutlen ] | set ttimeout ttimeoutlen=0
    let l:iminsert = &iminsert | set iminsert=1
    let l:belloff = &belloff | set belloff+=error,esc
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
        call s:Log('** Exception in ProbeExpr **', v:exception)
        call s:Log('** Exception in ProbeExpr **', v:throwpoint)
    finally
        let &belloff = l:belloff
        let &iminsert = l:iminsert
        let [ &ttimeout, &ttimeoutlen ] = [ l:ttimeout, l:ttimeoutlen ]
        let [ &timeout, &timeoutlen ] = [ l:timeout, l:timeoutlen ]
        call _op_#utils#RestoreState(l:state)
    endtry
    call _op_#stack#Pop(l:stack_id, 'typeahead=' .. s:ReadTypeaheadTruncated())
endfunction

" map the first char of s:hijack_probe to get hijack data
" Some commands may consume the RHS and start executing, use unusual single-byte
" character to avoid conflicts with user mappings
execute ' noremap  <expr>' .. s:hijack_probe .. ' <sid>HijackProbeMap()'
execute ' noremap! <expr>' .. s:hijack_probe .. ' <sid>HijackProbeMap()'
execute 'lnoremap  <expr>' .. s:hijack_probe .. ' <sid>HijackProbeLangMap()'
execute 'tnoremap  <expr>' .. s:hijack_probe .. ' <sid>HijackProbeMap()'

function s:HijackProbeMap() abort
    let s:hijack = { 'hmode': mode(1), 'cmd': getcmdline(), 'cmd_type': getcmdtype(), 'lmap': v:false }
    return ''
endfunction

function s:HijackProbeLangMap() abort
    let s:hijack = { 'hmode': mode(1) .. '-l', 'cmd': getcmdline(), 'cmd_type': getcmdtype(), 'lmap': v:true }
    return ''
endfunction

function s:ParentCallInit(handle) abort
    if _op_#stack#Depth() == 1
        return
    endif
    " Note: maps don't save which key triggered them, but we can deduce this
    " information with the previous stack frame.
    " Note: the parent (up to this point) is the set complement of previous expr
    " and current typeahead (less the hijack stream)

    " calling_expr = [already executed] .. [current map call] .. [omap input] .. [typeahead] .. [hijack_probe]
    let l:parent_handle = _op_#stack#GetPrev(a:handle)
    let l:calling_expr = l:parent_handle['expr_reduced']

    " remove remnants of hijack_probe .. hijack_esc placed by HijackInput
    let l:typeahead = s:ReadTypeahead()
    call s:Log('ParentCallInit', '', 'calling_expr=' .. l:calling_expr .. ' typeahead=' .. s:TypeaheadLog())
    let l:typeahead = substitute(l:typeahead, '\V' .. s:hijack_probe .. s:hijack_esc .. '\$', '', '')

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
    elseif a:handle['init']['entry_mode'] =~# '\v^no.?$'
        let l:mode = 'o'
    endif
    let l:count = 0
    while l:parent_call != '' && empty(maparg(substitute(l:parent_call, '\V' .. "\<plug>", '\<plug>', 'g'), l:mode))
        let l:count += 1
        let l:parent_call = strcharpart(l:calling_expr, l:count)
    endwhile

    " store reduced call
    call s:Log('ParentCallInit', '', 'parent_call=' .. l:parent_call .. '    parent_expr_reduced_so_far+=' .. strcharpart(l:calling_expr, 0, l:count))
    let a:handle['parent_call'] = l:parent_call
    let l:parent_handle['expr_reduced_so_far'] ..= strcharpart(l:calling_expr, 0, l:count)
endfunction

function s:ParentCallUpdate(handle) abort
    let l:expr = a:handle['init']['op'] .. a:handle['expr_reduced']
    let l:parent_handle = _op_#stack#GetPrev(a:handle)
    let l:update_pattern = '\V' .. escape(l:parent_handle['expr_reduced_so_far'], '\') .. '\zs' .. escape(a:handle['parent_call'], '\')
    let l:update = substitute(l:parent_handle['expr_reduced'], l:update_pattern, escape(l:expr, '\'), '')
    if l:update ==# l:parent_handle['expr_reduced']
        call _op_#op#Throw('cyclops.vim: "unexpected error while updating parent call"')
    endif
    call s:Log('ParentCallUpdate', '', l:parent_handle['expr_reduced'] .. ' -> ' .. l:update)
    let l:parent_handle['expr_reduced'] = l:update
    let l:parent_handle['expr_reduced_so_far'] ..= l:expr
endfunction

function s:GetCharFromUser(handle) abort
    " extra typeahead may be available if user typed fast
    if s:hijack['hmode'] =~# '\v^(i|i-l)$'
        let l:char = s:GetCharFromUser_i(a:handle)
    elseif s:hijack['hmode'] =~# '\v^(no[vV]?|consumed|[nv]-l)(-l)?$'
        let l:char = s:GetCharFromUser_no(a:handle)
    elseif s:hijack['hmode'] =~# '\v^(c|c-l)$'
        let l:char = s:GetCharFromUser_c(a:handle)
    else
        call _op_#op#Throw('cyclops.vim: unsupported hijack mode '.string(s:hijack['hmode']))
    endif

    if l:char ==# "\<esc>"
        call _op_#op#Throw('cyclops.vim: interrupt (<esc>)')
    elseif empty(l:char)
        call _op_#op#Throw('cyclops.vim: empty char received from user')
    endif

    call s:Log('GetCharFromUser', s:PModes(2), 'GOT char=' .. l:char)
    return l:char
endfunction

function s:GetCharFromUser_i(handle) abort
    let l:match_ids = []
    let l:state = _op_#utils#GetState()
    try
        " update buffer if waiting for user input
        if !getchar(1)
            call s:Log('GetCharFromUser_i', s:PModes(0), 'FEED_tx=' .. a:handle['expr_reduced'] .. s:input_stream)
            silent call feedkeys(a:handle['expr_reduced'] .. s:input_stream, 'tx')
            let l:cursor_hl = hlexists('Cursor')? 'Cursor' : g:cyclops_cursor_highlight_fallback
            call add(l:match_ids, matchadd(l:cursor_hl, '\%'.line('.').'l\%'.(col('.')+1).'c'))
            redraw
        endif
        let l:char = s:GetCharStr('i')
    finally
        call s:ClearHighlights(l:match_ids)
        call _op_#utils#RestoreState(l:state)
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
            call _op_#op#Throw('cyclops.vim: interrupt (<c-c>)')
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
        call s:Log('GetCharFromTypeahead', '', 'PROBE CHAR DETECTED, reinserting probe')
        call feedkeys(s:hijack_probe, 'i')
    endif
    call inputsave()

    " traverse stack to find available typeahead (if any)
    let [ l:handle, l:parent_handle ] = [ a:handle, _op_#stack#GetPrev(a:handle) ]
    let l:parent_typeahead = matchstr(l:parent_handle['expr_reduced'], '\V'.l:handle['parent_call'].'\zs\.\*')
    while l:handle['stack_level'] > 0 && empty(l:parent_typeahead)
        let [ l:handle, l:parent_handle ] = [ _op_#stack#GetPrev(l:handle), _op_#stack#GetPrev(l:parent_handle) ]
        let l:parent_typeahead = matchstr(l:parent_handle['expr_reduced'], '\V'.l:handle['parent_call'].'\zs\.\*')
    endwhile

    " consume from parent typeahead if available
    if !empty(l:parent_typeahead)
        let l:parent_handle['expr_reduced'] = matchstr(l:parent_handle['expr_reduced'], '\V\^\.\{-}'.l:handle['parent_call']).strcharpart(l:parent_typeahead, 1)
        if  !empty(l:nr) && ( l:char !=# strcharpart(l:parent_typeahead, 0, 1) )
            call _op_#op#Throw('cyclops.vim: Typeahead mismatch while processing operator')
        endif
        let l:char = strcharpart(l:parent_typeahead, 0, 1)
    endif

    if empty(l:char)
        call _op_#op#Throw('cyclops.vim: empty typeahead char received from typeahead stack')
    endif

    return l:char
endfunction

function s:ReadTypeahead() abort
    let l:typeahead = s:StealTypeahead()
    call feedkeys(l:typeahead, 'i')
    return l:typeahead
endfunction

function s:ReadTypeaheadTruncated() abort
    let l:typeahead = s:StealTypeaheadTruncated()
    call feedkeys(l:typeahead, 'i')
    return l:typeahead
endfunction

function s:TypeaheadLog() abort
    let l:typeahead = s:ReadTypeaheadTruncated()
    let l:typeahead = substitute(l:typeahead, '\v' .. s:hijack_probe .. s:hijack_esc, '<PROBE>', '')
    let l:typeahead = substitute(l:typeahead, '\v' .. "\<esc>" .. '{' .. g:cyclops_max_trunc_esc .. '}$', '<esc>...', '')
    return l:typeahead
endfunction

function s:StealTypeahead() abort
    let l:typeahead = ''
    while getchar(1)
        let l:char = getcharstr(0)
        if empty(l:char)
            call _op_#op#Throw('cyclops.vim: empty typeahead char received while stealing typeahead')
        endif
        let l:typeahead ..= l:char
        if strchars(l:typeahead) > g:cyclops_max_input_size
            call s:Log('STEALTYPEAHEAD', '', 'TYPEAHEAD OVERFLOW')
            call s:Log('', '', l:typeahead[0:30].'...')
            call _op_#op#Throw('cyclops.vim: Typeahead overflow while reading typeahead (incomplete command called in normal mode?)')
        endif
    endwhile
    return l:typeahead
endfunction

function s:StealTypeaheadTruncated() abort
    let l:typeahead = ''
    let l:count = 0

    while !empty(getcharstr(1)) && l:count < g:cyclops_max_trunc_esc
        let l:char = getcharstr(0)
        if empty(l:char)
            call _op_#op#Throw('cyclops.vim: empty typeahead char received while stealing typeahead')
        endif
        let l:count = (l:char ==# "\<esc>")? l:count+1 : 0
        let l:typeahead ..= l:char
    endwhile
    return l:typeahead
endfunction

function s:StoreHandle(handle) abort
    call s:Log('StoreHandle ' .. a:handle['init']['handle_type'], '', 'expr=' .. a:handle['expr_reduced'])
    let l:handle_to_store = deepcopy(a:handle)

    if a:handle['init']['op_type'] ==# 'operand'
        " TODO: chained operand support
        let l:input = s:inputs[a:handle['op_input_id']]
        call extend(l:handle_to_store, { 'inputs': [ l:input ] })
    else
        call extend(l:handle_to_store, { 'inputs': deepcopy(s:inputs) })
    endif

    call remove(l:handle_to_store, 'stack_level')
    call remove(l:handle_to_store, 'stack_id')

    let l:name = a:handle['init']['handle_type']
    let s:handles[l:name] = l:handle_to_store
endfunction

function s:ShiftToCursor(cur_start, cur_end) abort
    let l:cur_pos = getcurpos()
    let l:shifted_lnr = l:cur_pos[1] + ( a:cur_end[1] - a:cur_start[1] )
    let l:shifted_col = s:GetScreenCol(l:cur_pos) + ( s:GetScreenCol(a:cur_end) - s:GetScreenCol(a:cur_start) )
    let l:shifted_pos = s:GetScreenPos(l:shifted_lnr, l:shifted_col)
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

function _op_#op#Throw(...)
    let l:msg = a:0? a:1 : v:exception
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

" use for logging only
function _op_#op#GetLastHijackMode() abort
    return s:hijack['hmode']
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

" noremap <plug>(op#_noremap_f) f
" noremap <plug>(op#_noremap_F) F
" noremap <plug>(op#_noremap_t) t
" noremap <plug>(op#_noremap_T) T
"    omap <plug>(op#_noremap_f) <plug>(op#_workaround_f)
"    omap <plug>(op#_noremap_F) <plug>(op#_workaround_F)
"    omap <plug>(op#_noremap_t) <plug>(op#_workaround_t)
"    omap <plug>(op#_noremap_T) <plug>(op#_workaround_T)
" onoremap <expr> <plug>(op#_workaround_f) <sid>Workaround_f('f')
" onoremap <expr> <plug>(op#_workaround_F) <sid>Workaround_f('F')
" onoremap <expr> <plug>(op#_workaround_t) <sid>Workaround_f('t')
" onoremap <expr> <plug>(op#_workaround_T) <sid>Workaround_f('T')
"
" let s:workaround_f = 0
" function s:Workaround_f(char)
"     let s:workaround_f = 1
"     return a:char
" endfunction

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
