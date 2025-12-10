"
" internal op# interface
"

" TODO: operators should store input from different modes separately, then .
"   used in operator pending mode can insert a motion from the last operator. E.g.
"   if 'c' is a dot operator then 'ciwfoo' should store ['iw', 'foo'] and then
"   'c.' should be equivalent to 'ciw'.
" TODO: enable chained operand support (refactor s:inputs, operand expr reduction)
" TODO: operator pending mode for dot/pair repeat
" TODO: pair repeat with different modes?

let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

let s:hijack_probe = g:cyclops_probe_char
let s:hijack_esc = repeat("\<esc>", 3)

" n-l no-l catches f, F, t, T in lang mode (e.g. fa and dfa)
" this pattern matches also n-l-l and v-l-l, but these modes are not possible and this pattern is simpler
let s:operator_hmode_pattern = '\v^(no[vV]?|consumed|i|c|[nv]-l)(-l)?$'
let s:operator_end_pattern = '\v^(n|[vV])$'

" Problem: feedkeys('dfa×') ends in (lang) operator pending mode
" Workaround: break out of hijack loop early if detected
let s:fFtT_op_pending_pattern = '\v^(no[vV]?-l)$'

let s:hijack = {'hmode': '', 'cmd': '', 'cmd_type': ''}
let s:initial_typeahead = ''
let s:inputs = { 'list': [], 'id': 0 }
let s:operand = { 'expr': '', 'input': '' }
let s:probe_exception = { 'status': v:false, 'expr': '', 'exception': '' }
let s:insert_mode_callback = { 'status': v:false, 'char': '', 'input_stream': '', 'last_insert': '', 'typeahead': '', }

let s:handles = { 'op': {}, 'dot': {}, 'pair': {} }

let s:Log    = function('_op_#log#Log')
let s:PModes = function('_op_#log#PModes')

function _op_#op#GetHandles() abort
    return s:handles
endfunction

function _op_#op#GetStoredHandle(handle_type) abort
    return _op_#op#GetHandles()[a:handle_type]
endfunction

function s:InitScriptVars()
    let s:initial_typeahead = ''
    call extend(s:operand, { 'expr': '', 'input': '' } )
    call extend(s:hijack, { 'hmode': '', 'cmd': '', 'cmd_type': '' } ) " init early for s:Log
    call extend(s:probe_exception, { 'status': v:false, 'expr': '', 'exception': '' } )
    call extend(s:insert_mode_callback, { 'status': v:false, 'char': '', 'input_stream': '', 'last_insert': '', 'typeahead': '', } )
    call _op_#utils#QueueReset(s:inputs)
endfunction

function _op_#op#StackInit() abort
    return _op_#stack#Init(function('s:InitScriptVars'))
endfunction

function _op_#op#InitCallback(handle, handle_type, expr, opts) abort
    if mode(1) !~# '\v^(n|v|V||no|nov|noV|no)$'
        throw 'cyclops.vim: Entry mode ' .. string(mode(1)) .. ' not yet supported.'
    endif

    call extend(a:handle, { 'init' : {
                \ 'handle_type'   : a:handle_type,
                \ 'mode'          : mode(1),
                \ 'op_type'       : mode(1)[:1] ==# 'no'? 'operand' : 'operator',
                \ 'input_source'  : 'user',
                \ } } )
    call extend(a:handle, {'macro' : {
                \ 'reg_recording' : reg_recording(),
                \ 'content'       : '',
                \ 'append_input'  : v:true,
                \ } } )
    call extend(a:handle, { 'mods' : {
                \ 'count'    : v:count,
                \ 'register' : v:register,
                \ } } )
    call extend(a:handle, { 'opts' : a:opts } )
    call extend(a:handle, { 'expr' : {
                \ 'orig'           : a:expr,
                \ 'reduced'        : a:expr,
                \ 'reduced_so_far' : '',
                \ 'op'             : mode(1)[:1] ==# 'no'? _op_#init#RegisterNoremap(v:operator .. mode(1)[2]) : '',
                \ } } )
    " ['init']['input_source'] may be set to 'cache' by pair repeat handling
endfunction

function _op_#op#ComputeMapCallback() abort range
    let l:handle = _op_#stack#Top()
    call _op_#utils#RestoreVisual_COMPAT(l:handle)
    call s:Log('ComputeMapCallback', s:PModes(2), 'expr=' .. l:handle['expr']['orig'] .. ' typeahead=' .. _op_#op#ReadTypeaheadTruncated())

    " if insert mode is reached during input hijacking, cyclops.vim unwinds the
    " stack and sets up a callback on InsertLeave to rebuild the stack and resume
    " processing with last change register content and any remaining typeahead.

    " The insert mode callback keeps the base stack handle, so we don't update
    " state in that case
    if !has_key(l:handle, 'state')
        let l:handle['state'] = _op_#utils#GetState()
    endif

    if _op_#stack#Depth() == 1
        try
            if !s:insert_mode_callback['status']
                call s:SaveInitialTypeahead()
                let l:macro_typeahead = substitute(s:initial_typeahead, '\v' .. "\<esc>" .. '{' .. g:cyclops_max_trunc_esc ..'}$', '', '')
                let l:handle['macro']['content'] = _op_#utils#MacroStop(l:macro_typeahead)
            else
                call _op_#utils#RestoreState(l:handle['state'])
                let s:insert_mode_callback['typeahead'] = _op_#op#StealTypeaheadTruncated()
            endif
            call s:ComputeMapOnStack(l:handle)
        catch /op#abort/
            echohl ErrorMsg | echomsg _op_#stack#GetException() | echohl None
            call _op_#utils#RestoreState(l:handle['state'])
            call _op_#utils#MacroResume(l:handle['macro']['reg_recording'], l:handle['macro']['content'])
            return 'op#abort'
        catch /op#insert_callback/
            call _op_#utils#Feedkeys(s:insert_mode_callback['char'], 'n')
            return 'op#insert_callback'
        endtry
    else
        call s:ComputeMapOnStack(l:handle)
    endif

    call s:StoreHandle(l:handle)

    if _op_#stack#Depth() == 1
        let l:typeahead = substitute(s:initial_typeahead, '\v' .. "\<esc>" .. '{' .. g:cyclops_max_trunc_esc ..'}$', '', '')
        call s:Log('ComputeMapCallback EXIT', '', 'typeahead=' .. l:typeahead)
        if s:ModifiersNeeded(l:handle)
            call _op_#utils#RestoreState(l:handle['state'])
            let l:expr_with_modifiers = _op_#op#ExprWithModifiers(l:handle['expr']['reduced'], l:handle['mods'], l:handle['opts'], l:handle['expr']['op'])
            call s:Log('EXIT', s:PModes(0), 'FEED_tx=' .. l:expr_with_modifiers .. l:typeahead)
            call _op_#utils#Feedkeys(l:expr_with_modifiers, 'tx')
        endif
        if l:handle['macro']['append_input']
            let l:handle['macro']['content'] ..= join(s:inputs['list'], '')
        endif
        call _op_#utils#MacroResume(l:handle['macro']['reg_recording'], l:handle['macro']['content'])
        call _op_#utils#Feedkeys(l:typeahead, 't')
        call _op_#stack#Pop(0, 'StackInit')
    endif
    return 'op#success'
endfunction

function s:ComputeMapOnStack(handle) abort
    if _op_#stack#Depth() == 1
        " Nested op#map calls results in recursion and is managed by a stack.
        " Recursion typically happens at this ProbeExpr call, but can also
        " happen in HijackInput if a registered omap is triggered. When
        " recursion happens, callee's update the caller's reduced expr, removing
        " the recursion in subsequent calls.
        call s:ProbeExpr(a:handle['expr']['op'] .. a:handle['expr']['orig'], 'expr_orig')
        let l:input = s:HijackInput(a:handle)
        call s:CheckForProbeErrors()
        call s:StoreInput(a:handle, l:input)
    else
        call s:ParentCallInit(a:handle)
        call inputsave()

        call _op_#utils#RestoreState(a:handle['state'])
        call s:ProbeExpr(a:handle['expr']['op'] .. a:handle['expr']['orig'], 'expr_orig')
        let l:input = s:HijackInput(a:handle)
        call s:CheckForProbeErrors()
        call s:StoreInput(a:handle, l:input)
        call s:ParentCallUpdate(a:handle)

        call _op_#utils#RestoreState(a:handle['state'])
        call s:Log('ComputeMapOnStack', 'EXIT', 'FEED_tx=' .. a:handle['expr']['op'] .. a:handle['expr']['reduced'] .. ' typeahead=' .. _op_#op#ReadTypeaheadTruncated())
        call _op_#utils#Feedkeys(a:handle['expr']['op'] .. a:handle['expr']['reduced'], 'tx')
        call inputrestore()
    endif
endfunction

function s:SaveInitialTypeahead() abort
    " prevent duplication on insert mode callback
    if !empty(s:initial_typeahead)
        return
    endif
    let s:initial_typeahead = _op_#op#StealTypeaheadTruncated()
    if !empty(s:initial_typeahead)
        call s:Log('SaveInitialTypeahead', '', 'initial_typeahead=' .. s:initial_typeahead)
    endif
endfunction

function s:HijackInput(handle) abort
    call s:Log('HijackInput ', s:PModes(2), 'initial_typeahead=' .. s:initial_typeahead)
    if s:hijack['hmode'] =~# s:operator_end_pattern
        call s:Log('HijackInput EXIT', '', 'non-operator mode detected: mode=' .. s:hijack['hmode'])
        return ''
    elseif s:hijack['hmode'] !~# s:operator_hmode_pattern
        call _op_#op#Throw('Unsupported hijack mode: ' .. string(s:hijack['hmode']) .. '. Please make a feature request.')
    endif

    let l:input_stream = ''
    let l:op = a:handle['expr']['op']
    let l:expr = a:handle['expr']['reduced']

    if s:insert_mode_callback['status'] && empty(s:initial_typeahead)
        if !_op_#utils#QueueFinished(s:inputs)
            let l:input_stream = _op_#utils#QueueNext(s:inputs)
            call s:Log('HijackInput', 'queue', 'stack cached input=' .. l:input_stream)
            call _op_#utils#RestoreState(a:handle['state'])
            call s:ProbeExpr(l:op .. l:expr .. l:input_stream, 'stack cache')
            return l:input_stream
        else
            call s:Log('HijackInput', 'q done', 'insert_input_stream=' .. s:insert_mode_callback['input_stream'])
            let s:insert_mode_callback['status'] = v:false
            let l:input_stream = s:insert_mode_callback['input_stream'] .. s:insert_mode_callback['last_insert']
            let s:initial_typeahead ..= s:insert_mode_callback['typeahead']
            call _op_#utils#RestoreState(a:handle['state'])
            call s:ProbeExpr(l:op .. l:expr .. l:input_stream, 'q done')
            return l:input_stream
        endif
    elseif a:handle['init']['input_source'] ==# 'cache'
        let l:input_stream = _op_#utils#QueueNext(a:handle['expr']['inputs'])
        call s:Log('HijackInput', '', 'cached input=' .. l:input_stream)
        call _op_#utils#RestoreState(a:handle['state'])
        call s:ProbeExpr(l:op .. l:expr .. l:input_stream, 'cache')
        return l:input_stream
    endif

    let l:input_stream = s:HijackUserInput(a:handle, l:input_stream)

    " if s:hijack['hmode'] =~# s:operator_hmode_pattern
    "     if a:handle['init']['input_source'] ==# 'user'
    "         let l:input_stream = s:HijackUserInput(a:handle, l:input_stream)
    "     else
    "         while s:hijack['hmode'] =~# s:operator_hmode_pattern
    "             let l:input_stream ..= s:GetCharFromTypeahead(a:handle)
    "             call _op_#utils#RestoreState(a:handle['state'])
    "             call s:ProbeExpr(l:op .. l:expr .. l:input_stream, 'typeahead')
    "         endwhile
    "     endif
    " endif

    return l:input_stream
endfunction

function s:StoreInput(handle, input) abort
    if !s:insert_mode_callback['status']
        " TODO: this needs to be generalized to allow chained operands

        " The operator must wait for the operand to finish before storing its input,
        " to ensure the correct order of inputs we delay storing the operand's
        " input. First store the operand's input in s:operand, then let the operator
        " store both inputs in the correct order.
        if a:handle['init']['op_type'] ==# 'operand'
            call s:Log('HijackInput', 'store', 'operand=' .. a:handle['expr']['reduced'] .. a:input)
            let s:operand = { 'expr': a:handle['expr']['reduced'], 'input': a:input }
        else
            if !empty(s:operand['expr'])
                call _op_#utils#QueuePush(s:inputs, s:operand['expr'])
                call _op_#utils#QueuePush(s:inputs, s:operand['input'])
            else
                call _op_#utils#QueuePush(s:inputs, a:input)
            endif
        endif
    endif

    if a:handle['init']['op_type'] ==# 'operator' && !empty(s:operand['expr'])
        " the ParentCallUpdate has already updated with the reduced operand
        let l:input = ''
    else
        let l:input = a:input
    endif
    let a:handle['expr']['reduced'] ..= l:input
endfunction

function s:HijackUserInput(handle, input_stream) abort
    let l:op = a:handle['expr']['op']
    let l:expr = a:handle['expr']['reduced']
    let l:input_stream = a:input_stream
    while s:hijack['hmode'] !~# s:operator_end_pattern
        if s:hijack['hmode'] !~# s:operator_hmode_pattern
            call _op_#op#Throw('Unsupported hijack mode: ' .. string(s:hijack['hmode']) .. '. Please make a feature request.')
        endif
        if s:hijack['cmd_type'] ==# '@'
            call s:Log('HijackUserInput (cmd)', s:PModes(2), 'FEED_x!: ' .. l:op .. l:expr .. l:input_stream)
            let l:reg = getreginfo('i')
            call _op_#utils#RestoreState(a:handle['state'])
            call _op_#utils#Feedkeys('qi', 'n')
            call _op_#utils#Feedkeys(l:op .. l:expr .. l:input_stream, 'x!')
            call _op_#utils#Feedkeys('q', 'nx')
            let l:input_stream ..= getreg('i')
            call setreg('i', l:reg)
            call s:ProbeExpr('', 'hijack input()')
        elseif s:hijack['hmode'] =~# '\v^(i|i-l)$'
            if !empty(s:initial_typeahead)
                let l:char = s:GetCharStr('i')
                let l:input_stream ..= l:char
                while !empty(s:initial_typeahead) && l:char !=# "\<esc>"
                    let l:char = s:GetCharStr('i')
                    let l:input_stream ..= l:char
                endwhile
                call _op_#utils#RestoreState(a:handle['state'])
                call s:ProbeExpr(l:op .. l:expr .. l:input_stream, 'hijack')
            else
                let s:insert_mode_callback['status'] = v:true
                let s:insert_mode_callback['char'] = (getpos("']'")[2] == 1)? 'i' : 'a'
                let s:insert_mode_callback['input_stream'] = l:input_stream
                call s:Log('HijackUserInput', 'insert', 'begin insert mode callback')
                augroup _op_#op#InsertMode
                    autocmd!
                    autocmd InsertLeave * call s:RestartFromInsertMode()
                augroup END
                throw 'op#insert_callback'
            endif
        else
            let l:mode = s:HModeToMapMode(s:hijack['hmode'])
            let l:char = s:HijackUserChar(a:handle, l:mode, l:input_stream)
            let l:input_stream = s:ProcessStream(l:input_stream, l:char)
            if s:hijack['hmode'] =~# s:fFtT_op_pending_pattern
                call s:Log('HijackUserInput (no-l break)', '', "feedkeys('dfa×') workaround")
                break
            endif
            call _op_#utils#RestoreState(a:handle['state'])
            call s:ProbeExpr(l:op .. l:expr .. l:input_stream, 'hijack')
        endif
    endwhile
    unsilent echo
    redraw
    return l:input_stream
endfunction

function s:RestartFromInsertMode() abort
    autocmd! _op_#op#InsertMode
    if s:insert_mode_callback['status']
        let s:insert_mode_callback['last_insert'] = getreg('.') .. "\<esc>"
        call s:Log('RestartFromInsertMode', '', 'last_insert=' .. s:insert_mode_callback['last_insert'])

        let l:stack = _op_#stack#GetStack()
        if len(l:stack) > 1
            call remove(l:stack, 1, -1) " clear all but base of stack
        endif
        let l:handle = l:stack[0]
        let l:handle['expr']['reduced'] = l:handle['expr']['orig']
        let l:handle['expr']['reduced_so_far'] = ''

        if l:handle['init']['handle_type'] ==# 'op'
            call _op_#op#ComputeMapCallback()
        elseif l:handle['init']['handle_type'] ==# 'dot'
            call _op_#dot#ComputeMapCallback()
        elseif l:handle['init']['handle_type'] ==# 'pair'
            call _op_#pair#ComputeMapCallback()
        else
            call _op_#op#Throw('Unsupported handle type in RestartFromInsertMode: ' .. string(l:handle['init']['handle_type']))
        endif
    endif
endfunction

function s:CheckForProbeErrors() abort
    if s:probe_exception['status']
        call _op_#op#Throw('Exception detected while processing ' .. s:probe_exception['expr'] .. ': ' .. s:probe_exception['exception'])
    endif
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
    let l:msg = 'FEED_tx!=' .. a:expr .. '<PROBE>' .. ' typeahead=' .. _op_#op#ReadTypeaheadTruncated()
    let l:stack_id = _op_#stack#Push(a:type, l:msg)

    " HijackProbMap may be consumed instead of expanded, set default case
    let s:hijack = { 'hmode': 'consumed', 'cmd': '', 'cmd_type': '' }

    " vim uses these timeouts for feedkeys, neovim apparently does not
    let l:iminsert = &iminsert | set iminsert=1
    let l:belloff = &belloff | set belloff+=error,esc
    try
        " feedkeys(... s:hijack_probe, 'x') is not working as expected, only
        " last map in stack is processed, execution order is seemingly broken
        " (logging at callback entry doesn't show beginning/intermediate maps)

        " 't' flag fixes an issue when cursor is at end of buffer and '<c-d>' is
        " fed, which prevented the probe from executing.
        call _op_#utils#Feedkeys(a:expr .. s:hijack_probe .. s:hijack_esc, 'itx!')
    catch /op#abort/
        throw 'op#abort'
    catch /op#insert_callback/
        throw v:exception
    catch
        call extend(s:probe_exception, {
                    \ 'status': v:true,
                    \ 'expr': a:expr,
                    \ 'exception': v:exception,
                    \ } )
        call s:Log('** Probe Exception **', a:expr)
        call s:Log('** Probe Exception **', v:exception)
        call s:Log('** Probe Exception **', v:throwpoint)
    finally
        let &belloff = l:belloff
        let &iminsert = l:iminsert
    endtry
    call _op_#stack#Pop(l:stack_id, 'typeahead=' .. _op_#op#ReadTypeaheadTruncated())
endfunction

" map the first char of s:hijack_probe to get hijack data
" Some commands may consume the RHS and start executing, use unusual single-byte
" character to avoid conflicts with user mappings
execute ' noremap  <expr>' .. s:hijack_probe .. ' <sid>HijackProbeMap()'
execute ' noremap! <expr>' .. s:hijack_probe .. ' <sid>HijackProbeMap()'
execute 'lnoremap  <expr>' .. s:hijack_probe .. ' <sid>HijackProbeLangMap()'
execute 'tnoremap  <expr>' .. s:hijack_probe .. ' <sid>HijackProbeMap()'

function s:HijackProbeMap() abort
    let s:hijack = { 'hmode': mode(1), 'cmd': getcmdline(), 'cmd_type': getcmdtype() }
    return ''
endfunction

function s:HijackProbeLangMap() abort
    let s:hijack = { 'hmode': mode(1) .. '-l', 'cmd': getcmdline(), 'cmd_type': getcmdtype() }
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
    let l:calling_expr = l:parent_handle['expr']['reduced']

    " remove remnants of hijack_probe .. hijack_esc placed by HijackInput
    let l:typeahead = _op_#op#ReadTypeaheadTruncated()
    call s:Log('ParentCallInit', '', 'calling_expr=' .. l:calling_expr .. ' typeahead=' .. l:typeahead)
    let l:typeahead = substitute(l:typeahead, '\V' .. s:hijack_probe .. "\<esc>" .. '\+\$', '', '')

    " [already executed] .. [current map call] .. [typeahead] -> [current map call]
    let l:calling_expr = substitute(l:calling_expr, '\V' .. escape(l:typeahead, '\') .. '\$', '', '')
    let l:calling_expr = substitute(l:calling_expr, '\V\^' .. escape(l:parent_handle['expr']['reduced_so_far'], '\'), '', '')

    " in case [current map call] == xxxOP1, remove xxx
    let l:parent_call = l:calling_expr
    let l:map_mode = s:ModeToMapMode(a:handle['init']['mode'])
    let l:count = 0
    while l:parent_call != '' && empty(maparg(substitute(l:parent_call, '\V' .. "\<plug>", '\<plug>', 'g'), l:map_mode))
        let l:count += 1
        let l:parent_call = strcharpart(l:calling_expr, l:count)
    endwhile

    " store the calling expression and the parent call substring
    call s:Log('ParentCallInit', '', 'parent_call=' .. l:parent_call .. ' calling_expr=' .. l:calling_expr)
    let a:handle['expr']['parent_call'] = l:parent_call
    let a:handle['expr']['calling_expr'] = strcharpart(l:calling_expr, 0, l:count)
endfunction

function s:ParentCallUpdate(handle) abort
    let l:expr = a:handle['expr']['op'] .. a:handle['expr']['reduced']
    let l:parent_handle = _op_#stack#GetPrev(a:handle)
    let l:parent_handle['expr']['reduced_so_far'] ..= a:handle['expr']['calling_expr']
    let l:update_pattern = '\V' .. escape(l:parent_handle['expr']['reduced_so_far'], '\') .. '\zs' .. escape(a:handle['expr']['parent_call'], '\')
    let l:update = substitute(l:parent_handle['expr']['reduced'], l:update_pattern, escape(l:expr, '\'), '')
    if l:update ==# l:parent_handle['expr']['reduced']
        call _op_#op#Throw('Unexpected error while updating parent call')
    endif
    call s:Log('ParentCallUpdate', '', l:parent_handle['expr']['reduced'] .. ' -> ' .. l:update)
    let l:parent_handle['expr']['reduced'] = l:update
    let l:parent_handle['expr']['reduced_so_far'] ..= l:expr
endfunction

function s:HijackUserChar(handle, mode, display_stream) abort
    let l:empty_init_typeahead = empty(s:initial_typeahead)
    let l:match_ids = []
    " extra typeahead may be available if user typed fast
    if !getchar(1) && l:empty_init_typeahead
        let l:match_ids = s:SetDisplayElements(a:handle, a:mode, a:display_stream)
    endif

    try
        let l:char = s:GetCharStr(a:mode)
    finally
        call s:ClearHighlights(l:match_ids)
    endtry

    if empty(l:char)
        call _op_#op#Throw('Empty char received from user')
    endif

    call s:Log('HijackUserChar', s:PModes(2), (l:empty_init_typeahead? 'user' : 'init_typeahead') .. ' char=' .. l:char)
    return l:char
endfunction

function s:SetDisplayElements(handle, mode, display_stream) abort
    let l:match_ids = []
    " if a:mode ==# 'i'
    "     let l:cursor_hl = hlexists('Cursor')? 'Cursor' : g:cyclops_cursor_highlight_fallback
    "     " workaround for col('.') not updating correctly when inserting at beginning of line
    "     let l:cur_offset = (getpos("']'")[2] == 1)? 0 : 1
    "     call add(l:match_ids, matchadd(l:cursor_hl, '\%' .. line('.') .. 'l\%' .. (col('.') + l:cur_offset) .. 'c'))
    "     redraw
    "     unsilent echo '--INSERT-- (cyclops.vim)'
    if a:mode ==# 'o'
        call _op_#utils#RestoreState(a:handle['state'])
        let l:cursor_hl = hlexists('Cursor')? 'Cursor' : g:cyclops_cursor_highlight_fallback
        if a:handle['init']['mode'] =~# '\v^[vV]$'
            if a:handle['init']['mode'] =~# '\v^[vV]$'
                call add(l:match_ids, matchadd('Visual', '\m\%>' .. "'" .. '<\&\%<' .. "'" .. '>\&[^$]'))
                call add(l:match_ids, matchadd('Visual', '\m\%' .. "'" .. '<\|\%' .. "'" .. '>'))
            else
                " TODO  mode
            endif
        endif
        call add(l:match_ids, matchadd(l:cursor_hl, '\%' .. line('.') .. 'l\%' .. col('.') .. 'c'))
        redraw
        unsilent echo 'Operator Input:' .. a:display_stream
    elseif a:mode ==# 'c'
        unsilent echo s:hijack['cmd_type'] .. s:hijack['cmd']
        if s:hijack['cmd_type'] =~# '\v[/?]' && &incsearch
            let l:cursor_hl = hlexists('Cursor')? 'Cursor' : g:cyclops_cursor_highlight_fallback
            let l:input = (s:hijack['cmd_type'] == a:display_stream[0])? a:display_stream[1:] : a:display_stream
            nohlsearch
            silent! call add(l:match_ids, matchadd('IncSearch', l:input))
        endif
        redraw
    endif

    return l:match_ids
endfunction

function s:ModeToMapMode(mode) abort
    if a:mode ==# 'n'
        return 'n'
    elseif a:mode =~# '\v^[vV]$'
        return 'x'
    elseif a:mode =~# '\v^[sS]$'
        return 's'
    elseif a:mode =~# '\v^no.?$'
        return 'o'
    endif
    call _op_#op#Throw('Unsupported mode: ' .. string(a:mode))
endfunction

function s:HModeToMapMode(hmode) abort
    if a:hmode =~# '\v^(i|i-l)$'
        return 'i'
    elseif a:hmode =~# '\v^(no[vV]?|consumed|[nv]-l)(-l)?$'
        return 'o'
    elseif a:hmode =~# '\v^(c|c-l)$'
        return 'c'
    else
        call _op_#op#Throw('Unsupported hijack mode: ' .. string(a:hmode) .. '. Please make a feature request.')
    endif
endfunction

function s:ClearHighlights(match_ids) abort
    for l:id in a:match_ids
        if l:id > 0
            call matchdelete(l:id)
        endif
    endfor
endfunction

function s:GetCharStr(mode) abort
    try
        if !empty(s:initial_typeahead)
            if s:initial_typeahead =~# '\v^' .. "\<plug>"
                let l:idx = stridx(s:initial_typeahead, ')')
                if l:idx == -1
                    " only <plug>(op#...) is expected here
                    call _op_#op#Throw('Malformed <plug> mapping in initial_typeahead')
                endif
                let l:char = strpart(s:initial_typeahead, 0, l:idx+1)
                let s:initial_typeahead = strpart(s:initial_typeahead, l:idx+1)
            elseif char2nr(s:initial_typeahead[0]) == 0x80
                " vim uses 3-byte encoding for special keys
                let l:char = strpart(s:initial_typeahead, 0, 3)
                let s:initial_typeahead = strpart(s:initial_typeahead, 3)
            else
                let l:char = strcharpart(s:initial_typeahead, 0, 1)
                let s:initial_typeahead = strcharpart(s:initial_typeahead, 1)
            endif
        else
            let l:char = s:GetCharStr_COMPAT()
        endif
    catch /^Vim:Interrupt$/
        if !empty(a:mode) && !empty(maparg('<c-c>', a:mode))
            let l:char = "\<c-c>"
        else
            call _op_#op#Throw('interrupt (<c-c>)')
        endif
    endtry

    if a:mode[0] !=# 'i' && l:char ==# "\<esc>"
        call _op_#op#Throw('interrupt (<esc>)')
    endif

    return l:char
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
    let l:parent_typeahead = matchstr(l:parent_handle['expr']['reduced'], '\V' .. l:handle['expr']['parent_call'] .. '\zs\.\*')
    while l:handle['stack']['level'] > 0 && empty(l:parent_typeahead)
        let [ l:handle, l:parent_handle ] = [ _op_#stack#GetPrev(l:handle), _op_#stack#GetPrev(l:parent_handle) ]
        let l:parent_typeahead = matchstr(l:parent_handle['expr']['reduced'], '\V' .. l:handle['expr']['parent_call'] .. '\zs\.\*')
    endwhile

    " consume from parent typeahead if available
    if !empty(l:parent_typeahead)
        let l:parent_handle['expr']['reduced'] = matchstr(l:parent_handle['expr']['reduced'], '\V\^\.\{-}' .. l:handle['expr']['parent_call']) .. strcharpart(l:parent_typeahead, 1)
        if  !empty(l:nr) && ( l:char !=# strcharpart(l:parent_typeahead, 0, 1) )
            call _op_#op#Throw('Typeahead mismatch while processing operator')
        endif
        let l:char = strcharpart(l:parent_typeahead, 0, 1)
    endif

    if empty(l:char)
        call _op_#op#Throw('Empty typeahead char received from typeahead stack')
    endif

    return l:char
endfunction

function _op_#op#ReadTypeaheadTruncated() abort
    let l:typeahead = _op_#op#StealTypeaheadTruncated()
    call feedkeys(l:typeahead, 'i')
    return l:typeahead
endfunction

function _op_#op#StealTypeaheadTruncated() abort
    let l:typeahead = ''
    let l:count = 0

    while getchar(1) && l:count < g:cyclops_max_trunc_esc
        let l:char = s:GetCharStr_COMPAT(0)
        if empty(l:char)
            call _op_#op#Throw('Empty typeahead char received while stealing typeahead')
        endif
        let l:count = (l:char ==# "\<esc>")? l:count+1 : 0
        let l:typeahead ..= l:char
    endwhile
    return l:typeahead
endfunction

function s:StoreHandle(handle) abort
    call s:Log('StoreHandle ' .. a:handle['init']['handle_type'], '', 'expr=' .. a:handle['expr']['reduced'])
    let l:handle_to_store = deepcopy(a:handle)

    if a:handle['init']['input_source'] ==# 'user'
        if a:handle['init']['op_type'] ==# 'operand'
            call extend(l:handle_to_store['expr'], { 'inputs': { 'list': [s:operand['input']], 'id': 0} })
        else
            call extend(l:handle_to_store['expr'], { 'inputs': deepcopy(s:inputs) })
        endif
    endif
    call remove(l:handle_to_store, 'stack')

    let l:name = a:handle['init']['handle_type']
    let s:handles[l:name] = l:handle_to_store
endfunction

function s:ModifiersNeeded(handle) abort
    " HijackInput always ends with the probe that returns to normal mode, so we
    " must correct it here.
    " This is not necessary if we know the probe will not be consumed, so
    " further optimization is possible.
    if s:hijack['hmode']  !=# 'n'
        return v:true
    endif
    if a:handle['opts']['accepts_count'] && a:handle['mods']['count'] != 0
        return v:true
    endif
    if a:handle['opts']['accepts_register'] && a:handle['mods']['register'] !=# _op_#utils#DefaultRegister()
        return v:true
    endif
    call s:Log('ModifiersNeeded FALSE', 'EXIT', 'no modifiers needed')
    return v:false
endfunction

function _op_#op#ExprWithModifiers(expr, mods, opts, ...) abort
    let l:op = a:0? a:1 : ''

    let l:register = ''
    if a:opts['accepts_register'] && a:mods['register'] !=# _op_#utils#DefaultRegister()
        let l:register = '"' .. a:mods['register']
    endif
    let l:expr_with_modifiers = l:register .. l:op .. a:expr

    if a:mods['count'] != 0
        if a:opts['accepts_count']
            let l:expr_with_modifiers = a:mods['count'] .. l:expr_with_modifiers
        elseif !a:opts['accepts_count']
            let l:count1 = max([1, a:mods['count']])
            let l:expr_with_modifiers = repeat(l:expr_with_modifiers, l:count1)
        endif
    endif
    call s:Log('ExprWithModifiers', s:PModes(0), 'expr_with_modifiers=' .. l:expr_with_modifiers)

    return l:expr_with_modifiers
endfunction

function _op_#op#Throw(...)
    let l:exception = a:0? 'cyclops.vim: ' .. a:1 : v:exception
    try
        throw 'op#abort'
    catch /op#abort/
        call _op_#stack#SetException(l:exception, v:throwpoint)

        call s:Log('')
        call s:Log('EXCEPTION: ' .. l:exception)
        call s:Log(v:throwpoint)
        throw 'op#abort'
    endtry
endfunction

" only used for logging
function _op_#op#GetLastHijack() abort
    return s:hijack
endfunction

function _op_#op#GetProbe() abort
    return s:hijack_probe .. s:hijack_esc
endfunction

function _op_#op#GetScriptVars() abort
    if exists('*getscriptinfo')
        let l:sid = s:SID()
        return getscriptinfo({'sid': l:sid})[0]['variables']
    else
        return {'insert_mode_callback': s:insert_mode_callback}
    endif
endfunction

function s:GetCharStr_COMPAT(...) abort
    if exists('*getcharstr')
        return a:0? getcharstr(a:1) : getcharstr()
    else
        let l:char = a:0? getchar(a:1) : getchar()
        if l:char =~# '\v^\d+$'
            let l:char = nr2char(l:char)
        endif
        return l:char
    endif
endfunction

let &cpo = s:cpo
unlet s:cpo
