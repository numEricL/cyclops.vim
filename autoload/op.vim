let s:cpo = &cpo
set cpo&vim

let g:op#disable_expr_assert         = !exists('g:op#disable_expr_assert')         ? 0       : g:op#disable_expr_assert
let g:op#max_input_size              = !exists('g:op#max_input_size')              ? 1024    : g:op#max_input_size
let g:op#no_mappings                 = !exists('g:op#no_mappings')                 ? 0       : g:op#no_mappings
let g:op#cursor_highlight_fallback   = !exists('g:op#cursor_highlight_fallback')   ? 'Error' : g:op#cursor_highlight_fallback


let g:op#map_defaults = {
            \ 'accepts_count': 0,
            \ 'accepts_register': 1,
            \ 'shift_marks': 0,
            \ 'visual_motion': 0,
            \ 'consumes_typeahead': 0
            \ }

" must be single character
let s:hijack_probe = '×'
let s:hijack = {'mode': '_NULL_', 'cmd': '_NULL_', 'cmd_type': '_NULL_' }

let s:stack = []
let s:stack_copy = []
let s:handles = { 'op': {}, 'dot': {}, 'pair': {} }
let s:error_log = []

let g:handles = s:handles
let g:stack = s:stack

let g:log = []
function s:Log(msg) abort
    call add(g:log, s:Pad(string(len(s:stack)), 3) . a:msg)
endfunction

function PrintLog() abort
    for l:line in g:log
        echomsg s:ToPrintable(l:line)
    endfor
endfunction

command P call PrintLog()

function op#PrintScriptVars() abort range
    for l:line in execute('let g:')->split("\n")->filter('v:val =~# '.string('\v^op#'))->sort()
        echomsg 'g:'.l:line
    endfor
    " if s:StackDepth() > 0
    if len(s:stack_copy) > 0
        for l:handle in s:GetStack()
            echomsg ' '
            call s:PrintDict(l:handle, '')
        endfor
    endif
    for [ l:op_type, l:handle ] in items(s:handles)
        if !empty(l:handle)
            echomsg ' '
            call s:PrintDict(l:handle, '['.l:op_type.']')
        endif
    endfor
    echomsg ' '
    for l:line in execute('let s:')->split("\n")->filter('v:val !~# '.string('\v(handles|stack)'))->sort()
        echomsg s:ToPrintable(l:line)
    endfor
endfunction

function s:PrintDict(dict, prefix) abort
    let l:stack_prefix = has_key(a:dict, 'stack_level') ? '[stack' . a:dict['stack_level'] . ']' : ''
    let l:prefix = l:stack_prefix .. a:prefix
    for l:key in a:dict->keys()->sort()
        if type(a:dict[l:key]) == v:t_dict
            " call s:PrintDict(a:dict[l:key], l:prefix.'['.l:key.']')
            continue
        endif
        let l:value = s:FormatValue( l:key, a:dict[l:key] )
        echomsg l:prefix s:Pad(l:key, 20) l:value
    endfor
endfunction


function s:FormatValue(key, value) abort
    let l:value = deepcopy(a:value)
    if type(a:value) == v:t_string
        let l:value = s:ToPrintable(a:value)
    elseif type(a:value) == v:t_list && type(a:value[0]) == v:t_string
        call map(l:value, 's:ToPrintable(v:val)')
    endif

    if a:key ==# 'input_cache'
        let l:value = '[' . join(l:value, ', ') . ']'
    endif
    return l:value
endfunction

function s:ToPrintable(value) abort
    let l:ctrl_names = [
                \ '<nul>', '<soh>', '<stx>', '<etx>', '<eot>', '<enq>', '<ack>', '<bel>',
                \ '<bs>',  '<tab>', '<lf>',  '<vt>',  '<ff>',  '<cr>',  '<so>',  '<si>',
                \ '<dle>', '<dc1>', '<dc2>', '<dc3>', '<dc4>', '<nak>', '<syn>', '<etb>',
                \ '<can>', '<em>',  '<sub>', '<esc>', '<fs>',  '<gs>',  '<rs>',  '<us>'
                \ ]
    let l:value = substitute(a:value, "\<plug>", '<plug>', 'g')
    let l:output = ''
    for l:char in split(l:value, '\zs')
        let l:nr = char2nr(l:char)
        let l:output .= (l:nr < 32)? l:ctrl_names[l:nr] : l:char
    endfor
    return l:output
endfunction

function ToPrintable(value) abort
    return s:ToPrintable(a:value)
endfunction

function s:Pad(value, length) abort
    let l:pad_len = a:length - strdisplaywidth(a:value)
    let l:pad = (l:pad_len > 0)? repeat(' ', l:pad_len) : ''
    return a:value . l:pad
endfunction

" function s:GetType(val) abort
"     let l:type = type(a:val)
"     if     l:type == v:t_number
"         return 'num'
"     elseif l:type == v:t_string
"         return 'str'
"     elseif l:type == v:t_func
"         return 'func'
"     elseif l:type == v:t_list
"         return 'list'
"     elseif l:type == v:t_dict
"         return 'dict'
"     elseif l:type == v:t_float
"         return 'float'
"     elseif l:type == v:t_bool
"         return 'bool'
"     elseif l:type == 7
"         return 'null'
"     elseif l:type == v:t_blob
"         return 'blob'
"     else
"         return 'unknown'
"     endif
" endfunction

function s:CheckOptsDict(vargs)
    if len(a:vargs) > 1 || ( len(a:vargs) == 1 && type(a:vargs[0]) != v:t_dict )
        throw 'cyclops.vim: Incorrect parameter, only a dictionary of options is accepted.'
    endif
    let l:opts = len(a:vargs) == 1 ? a:vargs[0] : {}
    for [l:key, l:value] in items(l:opts)
        if l:key !~# '\v^(accepts_count|accepts_register|shift_marks|visual_motion|consumes_typeahead)$'
            throw 'cyclops.vim: Unrecognized option '.string(l:key).'.'
        endif
        if l:value != v:true && l:value != v:false
            throw 'cyclops.vim: Unrecognied option value '.string(l:key).': '.string(l:value).'. Values must be 0 or 1.'
        endif
    endfor
    return extend(l:opts, g:op#map_defaults, 'keep')
endfunction

function op#Map(map, ...) abort range
    call s:AssertExprMap()
    call s:InitCallback('op', a:map, 0, s:CheckOptsDict(a:000))
    return "\<cmd>call ".op#SID()."Callback('', 'init')\<cr>"
endfunction

function op#Noremap(map, ...) abort range
    call s:AssertExprMap()
    let l:map = s:RegisterNoremap(a:map)
    call s:InitCallback('op', l:map, 0, s:CheckOptsDict(a:000))
    return "\<cmd>call ".op#SID()."Callback('', 'init')\<cr>"
endfunction

function s:AssertMode() abort
    if mode(1) !~# '\v^(n|v|V||no|nov|noV|no)$'
        throw 'cyclops.vim: Entry mode '.string(mode(1)).' not yet supported.'
    endif
endfunction

function s:RegisterNoremap(map) abort
    call s:AssertMode()
    let l:mode = mode(1)
    if l:mode ==# 'n'
        let l:noremap = 'nnoremap'
    elseif l:mode =~# '\v^[vV]$'
        let l:noremap = 'xnoremap'
    elseif l:mode =~# '\v^no.=$'
        let l:noremap = 'onoremap'
    else
        throw 'cyclops.vim: impossible state in s:RegisterNoremap reached'
    endif
    let l:map_string = '<plug>(op#_noremap_'.a:map.')'
    if empty(maparg(l:map_string))
        execute l:noremap.' <silent> '.l:map_string.' '.a:map
    endif
    return "\<plug>(op#_noremap_".a:map.')'
endfunction

function s:InitCallback(op_type, expr, pair, opts) abort
    call s:AssertMode()
    call s:StackInit()
    let l:handle = s:StackTop()
    call extend(l:handle, { 'opts' : a:opts } )
    call extend(l:handle, { 'init' : {
                \ 'count1': v:count1,
                \ 'register': v:register,
                \ 'op_type': a:op_type,
                \ 'entry_mode': mode(1),
                \ 'cur_start': getcurpos(),
                \ 'v_mode': visualmode(),
                \ 'v_start': getpos("'<"),
                \ 'v_end': getpos("'>"),
                \ 'c_start': getpos("'["),
                \ 'c_end': getpos("']"),
                \   } } )
    call extend(l:handle, {
                \ 'expr_orig': a:expr,
                \ 'expr_reduced': a:expr,
                \ 'expr_reduced_so_far': '',
                \ 'input_source': (a:opts['consumes_typeahead']? 'typeahead': 'user'),
                \ })
    if a:op_type ==# 'pair'
        call extend(l:handle, {
                    \ 'expr_reduced': a:pair[a:expr],
                    \ 'pair': a:pair,
                    \ 'pair_id': a:expr,
                    \ 'pair_state': ['invalid', 'invalid']
                    \ })
    endif
endfunction

function s:Callback(dummy, ...) abort range
    call s:StackClearIfAborted()
    let l:type = s:GetSource(a:000)
    let l:handle = s:GetHandle(l:type)
    call s:Log(s:Pad('Callback '.s:StackDepth().': ', 16) .'type='.l:type . ' expr='.l:handle['expr_reduced']. '    '.s:ToPrintable(s:ReadTypeahead()))

    " " Prepare repeat state
    " if l:type !=# 'init'
    "     let l:handle['count1'] = ( l:handle['repeat_count'] )? l:handle['repeat_count'] : l:handle['count1']
    "     let l:handle['register'] = l:handle['repeat_register']
    "     let l:repeat_mode = l:handle['repeat_mode']
    "
    "     if get(l:handle['opts'], 'shift_marks')
    "         let [ l:handle['v_start'], l:handle['v_end'] ] = s:ShiftToCursor(l:handle['v_start'], l:handle['v_end'])
    "         let [ l:handle['c_start'], l:handle['c_end'] ] = s:ShiftToCursor(l:handle['c_start'], l:handle['c_end'])
    "         call setpos("'<", l:handle['v_start'])
    "         call setpos("'>", l:handle['v_end'])
    "         call setpos("'[", l:handle['c_start'])
    "         call setpos("']", l:handle['c_end'])
    "     endif
    " endif

    " NOTE: needed for all ops or just dot because of g@?
    " set initial state of cursor and vim mode as specified by InitCallback

    " elseif l:handle['entry_mode'] =~# '\v^(no|nov|noV|no)$'
    "     let l:handle['operator'] = v:operator


    " first call in nested maps
    if s:StackDepth() == 1 || l:type !=# 'init'
        call s:SetVimMode(l:handle)
    endif

    if l:type ==# 'init'
        call s:ComputeMapStack(l:handle)
    else
        call s:ExecuteMap(l:handle, s:ExprWithModifiers(l:handle))
    endif

    " " visual motion (stay in visual mode if we started there)
    " call extend(l:handle, {'cur_end': getcurpos()})
    " if l:handle['opts']['visual_motion'] && l:handle['entry_mode'] =~# '\v^[vV]$' && mode(1) ==# 'n'
    "     let l:selectmode = &selectmode | set selectmode=
    "     silent! execute "normal! gv"
    "     let &selectmode = l:selectmode
    "     call setpos('.', l:handle['cur_end'])
    " endif
    "
    " if l:handle['op_type'] =~# '\v^(dot|pair)$'
    "     let l:mode = mode(1)
    "     if l:mode !~# '\v^[nvV]$'
    "         throw 'cyclops.vim: Unexpected exit mode'
    "     endif
    "
    "     " let l:win = winsaveview()
    "     " let l:selectmode = &selectmode | set selectmode=
    "     " silent! execute "normal! \<esc>gv"
    "     " let &selectmode = l:selectmode
    "     " call extend(l:handle, {'v_mode': visualmode(), 'v_start': getpos('v'), 'v_end': getpos('.')} )
    "     " if l:mode ==# 'n'
    "     "     silent! execute "normal! \<esc>"
    "     "     call winrestview(l:win)
    "     " endif
    " endif

    " STORE HANDLE
    if s:StackDepth() == 1
        let l:name = l:handle['init']['op_type']
        let l:stored_handle = deepcopy(l:handle)
        call remove(l:stored_handle, 'stack_level')
        let s:handles[l:name] = l:stored_handle
        call s:PopStack()
    endif

    " pair handling
    if l:handle['init']['op_type'] ==# 'pair'
        let l:stored_handle = s:GetHandle('pair')
        let l:pair_id = l:handle['pair_id']

        let l:stored_handle['pair'][l:pair_id] = l:handle['expr_reduced']
        let l:stored_handle['pair_state'][l:pair_id] = 'valid'
        let l:stored_handle['pair_id'] = (l:type !=# 'init')? !l:pair_id : l:pair_id
    endif

    let &operatorfunc = a:0? &operatorfunc : op#SID().'Callback'
    unsilent echo
endfunction

function s:ComputeMapStack(handle) abort
    if s:StackDepth() == 1
        call s:ComputeMapRoot(a:handle)
    else
        call s:ComputeMapRecur(a:handle)
    endif

    " if s:StackDepth() == 1 && !empty(s:error_log)
    "     echohl ErrorMsg | echomsg s:error_log[0] | echohl None
    "     echohl ErrorMsg | echomsg s:error_log[1] | echohl None
    "     let s:error_log = []
    "     echoerr 'cyclops.vim: Error detected, see messages'
    " endif
endfunction

function s:ComputeMapRoot(handle) abort
    " try
        let l:state = s:SaveState()
        " let l:ambiguous_map_chars = s:StealTypeahead()
        let l:ambiguous_map_chars = ''

        "only stored for debugging
        let a:handle['ambiguous_map'] = l:ambiguous_map_chars

        call s:HijackInput(a:handle, l:ambiguous_map_chars)
        call s:ExecuteMap(a:handle, a:handle['expr_reduced'])

        " operator pending case
        " call s:SetOpMode(a:handle)
        " let l:op = (a:handle['entry_mode'] =~# '\v^no[vV]=$')? get(a:handle, 'operator', '').get(a:handle, 'op_mode', '') : ''
        let l:op = ''

        let l:expr = l:op . s:ExprWithModifiers(a:handle)
        " if a:handle['expr_reduced'] !=# l:expr
            " call s:RestoreState(l:state)
            call s:ExecuteMap(a:handle, l:expr)
        " endif
    " catch /^op#abort$/
    "     call s:RestoreState(l:state)
    " endtry
endfunction

function s:ComputeMapRecur(handle) abort
    let l:this_expr = a:handle['expr_reduced']
    " try
        call s:SetParentCall(a:handle)
        call s:Log(s:Pad('inputsave: ', 16) . s:ReadTypeahead())
        call inputsave()
        call s:HijackInput(a:handle, '')
        call s:ExecuteMap(a:handle, a:handle['expr_reduced'])

        call s:UpdateParentExpr(a:handle)
        call inputrestore()
    " catch /^op#abort$/
    "     let l:parent = s:GetStackPrev(a:handle)
    "     let l:parent['abort'] = a:handle['abort']
    "     throw 'op#abort'
    " endtry
endfunction

function s:HijackInput(handle, ambiguous_map_chars) abort
    let s:hijack['mode'] = 'no'
    call extend(a:handle, { 'hijack_stream': '' })
    for l:char in split(a:ambiguous_map_chars, '\zs')
        call s:Log('HANDLE AMBIGUOUS MAP CHARS')
        call s:UpdateHijackStream(a:handle, s:hijack['mode'], char2nr(l:char))
    endfor
    let l:expr = a:handle['expr_reduced']
    let l:state = s:SaveState()
    call s:Log(s:Pad('HijackInput :', 16) . 'l:expr = '.l:expr)
    let a:handle['expr_reduced'] = l:expr.a:handle['hijack_stream']
    call s:HijackProbe(a:handle)
    if a:handle['input_source'] ==# 'input_cache' && s:hijack['mode'] =~# '\v^(no.=|i|c)$'
        call s:Log(s:Pad('HijackInput: ', 16) . 'early return')
        let a:handle['expr_reduced'] = l:expr .. remove(a:handle['input_cache'], 0)
        call s:RestoreState(l:state)
        return
    endif

    while s:hijack['mode'] =~# '\v^(no[vV]=|i|c)$'
        if s:hijack['mode'] =~# '\v^no'
            while s:hijack['mode'] =~# '\v^no'
                call s:UpdateHijackStream(a:handle, s:hijack['mode'], s:GetChar(a:handle))
                let a:handle['expr_reduced'] = l:expr.a:handle['hijack_stream']
                if s:workaround_f
                    " Problem: feedkeys('dfa'.s:hijack_probe) ends in operator pending mode
                    " Workaround: break out of loop early if any of [fFtT] is used
                    let s:hijack['mode'] = 'n'
                    let s:workaround_f = 0
                    break
                endif
                call s:RestoreState(l:state)
                call s:HijackProbe(a:handle)
            endwhile
        elseif s:hijack['mode'] ==# 'i'
            let l:char = s:UpdateHijackStream(a:handle, s:hijack['mode'], s:GetChar(a:handle))
            execute "normal! a".l:char
            while l:char != "\<esc>"
                let l:char = s:UpdateHijackStream(a:handle, s:hijack['mode'], s:GetChar(a:handle))
                execute "normal! a".l:char
            endwhile
            let a:handle['expr_reduced'] = l:expr.a:handle['hijack_stream']
            call s:HijackProbe(a:handle)
        elseif s:hijack['mode'] ==# 'c' || s:hijack['cmd'] =~# '\v^[:/?]$'
            if !s:hijack['mode'] ==# 'c' || !s:hijack['cmd'] =~# '\v^[:/?]$'
                call s:Log(s:Pad('HijackInput: ', 16) . 'WARNING: Mismatch in command mode hijack state')
            endif
            call s:RestoreState(l:state)
            " call extend(a:handle, { 'hijack_cmd': s:hijack_cmd, 'hijack_cmd_type': s:hijack_cmd_type })
            let l:char = s:UpdateHijackStream(a:handle, s:hijack['mode'], s:GetChar(a:handle))
            while l:char != "\<cr>"
                let l:char = s:UpdateHijackStream(a:handle, s:hijack['mode'], s:GetChar(a:handle))
            endwhile
            call setpos('.', a:handle['cur_start'])
            let a:handle['expr_reduced'] = l:expr.a:handle['hijack_stream']
            call s:HijackProbe(a:handle)
        endif
        let s:workaround_f = 0

        if !empty(a:handle['hijack_stream'])
            let l:root = s:StackBottom()
            call extend(l:root, {'input_cache': []}, 'keep')
            call add(l:root['input_cache'], a:handle['hijack_stream'])
        endif
    endwhile

    call s:RestoreState(l:state)
    call s:Log(s:Pad('INPUT: ', 16) . a:handle['hijack_stream'])
endfunction

function s:UpdateHijackStream(handle, input_mode, nr) abort
    let l:char = nr2char(a:nr)
    if a:nr == "\<bs>"
        let a:handle['hijack_stream'] = strcharpart(a:handle['hijack_stream'], 0, strchars(a:handle['hijack_stream'])-1)
        let l:char = "\<bs>"
    elseif l:char == "\<c-v>"
        let l:literal = nr2char(s:GetChar(a:handle))
        let l:char = (a:input_mode ==# 'i')? l:char.l:literal : l:literal
        let a:handle['hijack_stream'] .= l:char
    elseif l:char == "\<esc>"
        if a:input_mode !=# 'i'
            let a:handle['abort'] = '<esc>'
            throw 'op#abort'
        else
            let a:handle['hijack_stream'] .= l:char
        endif
    elseif l:char == "\<c-c>"
        let a:handle['abort'] = 'interrupt (<c-c>)'
        throw 'op#abort'
    elseif l:char == '.'
        if a:input_mode =~# '\v^no[vV]=$'
            let l:dot_handle = s:GetHandle('dot')
            if  !empty(l:dot_handle) && !has_key(l:dot_handle, 'abort') && has_key(l:dot_handle, 'input_cache')
                let l:char = l:dot_handle['input_cache'][0]
            else
                let l:char = "\<esc>"
            endif
        endif
        let a:handle['hijack_stream'] .= l:char
    else
        let a:handle['hijack_stream'] .= l:char
    endif
    return l:char
endfunction

function s:HijackProbe(handle) abort
    let l:mode_at_start = s:hijack['mode']

    let s:hijack = {'mode': '_NULL_', 'cmd': '_NULL_', 'cmd_type': '_NULL_' }
    let [ l:belloff, l:timeout, l:timeoutlen ] = [ &belloff, &timeout, &timeoutlen ]
    set belloff+=error,esc timeout timeoutlen=0
    call s:PushStack()
    try
        call s:Log(s:Pad('HijackProbe: ', 16) . ' FEEDKEYS: '.a:handle['expr_reduced'].s:hijack_probe)
        silent! call feedkeys(a:handle['expr_reduced'] . s:hijack_probe, 'x!')
    catch
    endtry
    call s:PopStack()
    let [ &belloff, &timeout, &timeoutlen ] = [ l:belloff, l:timeout, l:timeoutlen ]
    let s:hijack['mode'] = (s:hijack['mode'] ==# '_NULL_')? l:mode_at_start : s:hijack['mode']
    let s:hijack['cmd_type'] = (s:hijack['cmd_type'] ==# '_NULL_')? '' : s:hijack['cmd_type']
    let s:hijack['cmd'] = (s:hijack['cmd'] ==# '_NULL_')? '' : s:hijack['cmd']
    " if has_key(a:handle, 'abort')
    "     throw 'op#abort'
    " endif
endfunction

" map the first char of s:hijack_probe to get hijack data
" Some commands may consume the RHS and start executing, use something unusual
execute 'noremap  <expr>'.s:hijack_probe.' <sid>HijackProbeMap()'
execute 'noremap! <expr>'.s:hijack_probe.' <sid>HijackProbeMap()'
function s:HijackProbeMap() abort
    call s:Log(s:Pad('HijackProbeMap: ', 16) . 'mode='.mode(1).' cmd='.s:ToPrintable(getcmdline()).' type='.getcmdtype())
    let s:hijack = {'mode': mode(1), 'cmd': getcmdline(), 'cmd_type': getcmdtype() }
    return "\<esc>"
endfunction

function s:ResolveAmbiguousMap(handle, typeahead) abort
    let a:handle['ambiguous_map'] = a:typeahead
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

function s:SetParentCall(handle) abort
    if s:StackDepth() == 1
        return
    endif
    " Note: maps don't save which key triggered them, but we can deduce this
    " information with the previous stack frame.
    " Note: the parent (up to this point) is the set complement of previous expr
    " and current typeahead (less the hijack stream)

    " calling_expr = [already executed] . [current map call] . [typeahead] . [hijack_probe]
    let l:parent_handle = s:GetStackPrev(a:handle)
    let l:calling_expr = l:parent_handle['expr_reduced']


    " call s:Log(s:Pad('SetParentCall: ', 16) .'parent expr='.l:calling_expr)
    " call s:Log(s:Pad('SetParentCall: ', 16) .'  typeahead='.s:ReadTypeahead())

    " remove hijack_probe placed by HijackInput
    let l:typeahead = substitute(s:ReadTypeahead(), '\V'.s:hijack_probe.'\$', '', '')
    " call s:Log(s:Pad('SetParentCall: ', 16) .'  typeahead='.l:typeahead)

    " remove matching typeahead from calling_expr
    " call s:Log(s:Pad('SetParentCall: ', 16) . 'l:calling_expr='.l:calling_expr)
    " let l:calling_expr = matchstr(l:calling_expr, '\V\.\*\ze\('."\<plug>".'\)\='.escape(l:typeahead, '\'))


    " calling_expr = [already executed] . [current map call]
    let l:calling_expr = substitute(l:calling_expr, '\V'.escape(l:typeahead, '\').'\$', '', '')

    " call s:Log(s:Pad('SetParentCall: ', 16) . 'l:calling_expr='.l:calling_expr)
    " call s:Log(s:Pad('SetParentCall: ', 16) ."parent expr_reduced_so_far=".l:parent_handle['expr_reduced_so_far'])





    " calling_expr = [current map call]
    let l:calling_expr = substitute(l:calling_expr, '\V\^'.escape(l:parent_handle['expr_reduced_so_far'], '\'), '', '')
    " call s:Log(s:Pad('SetParentCall: ', 16) . 'l:calling_expr='.l:calling_expr)

    " remove keys that are not managed by this plugin
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
    while l:parent_call != '' && empty(maparg(substitute(l:parent_call, '\V'."\<plug>", '\<plug>', 'g'), l:mode))
        let l:count += 1
        let l:parent_call = strcharpart(l:calling_expr, l:count)
    endwhile
    call s:Log(s:Pad('SetParentCall: ', 16) . ' parent_call='.l:parent_call . '    parent_expr_reduced_so_far+='.strcharpart(l:calling_expr, 0, l:count))
    let a:handle['parent_call'] = l:parent_call
    let l:parent_handle['expr_reduced_so_far'] .= strcharpart(l:calling_expr, 0, l:count)
endfunction

function s:UpdateParentExpr(handle) abort
    " operator pending case
    " let l:op = get(a:handle, 'op_mode', '')
    let l:op = ''

    let l:expr = l:op . a:handle['expr_reduced']
    let l:parent_handle = s:GetStackPrev(a:handle)
    let l:update_pattern = '\V'.escape(l:parent_handle['expr_reduced_so_far'], '\').'\zs'.escape(a:handle['parent_call'], '\')
    let l:update = substitute(l:parent_handle['expr_reduced'], l:update_pattern, escape(l:expr, '\'), '')
    if l:update ==# l:parent_handle['expr_reduced']
        throw 'cyclops.vim: Unexpected error while updating parent call'
    endif
    call s:Log(s:Pad('UpdateParentExpr:', 16) . ' parent expr='.l:update . '    parent expr_reduced_so_far+='.l:expr)
    let l:parent_handle['expr_reduced'] = l:update
    let l:parent_handle['expr_reduced_so_far'] .= l:expr
endfunction

function s:SaveState() abort
    let [ l:mode, l:winid, l:win, l:last_undo ] = [ mode(1), win_getid(), winsaveview(), undotree()['seq_cur'] ]
    if l:mode ==# 'n'
        let l:selectmode = &selectmode | set selectmode=
        silent! execute "normal! gv"
        let &selectmode = l:selectmode
        let [ l:v_mode, l:v_start, l:v_end ] = [ visualmode(), getpos('v'), getpos('.') ]
        silent! execute "normal! \<esc>"
    elseif l:mode =~# '\v^[vVsS]$'
        let [ l:v_mode, l:v_start, l:v_end ] = [ visualmode(), getpos('v'), getpos('.') ]
    elseif l:mode =~# '\v^no.=$'
        let [ l:v_mode, l:v_start, l:v_end ] = [ visualmode(), getpos("'<"), getpos("'>") ]
    endif
    call winrestview(l:win)
    return { 'mode': l:mode, 'winid': l:winid, 'win': l:win, 'last_undo': l:last_undo, 'v_mode': l:v_mode, 'v_start': l:v_start, 'v_end': l:v_end }
endfunction

function s:RestoreState(state) abort
    let l:mode = a:state['mode']
    call win_gotoid(a:state['winid'])
    while a:state['last_undo'] < undotree()['seq_cur']
        silent undo
    endwhile
    silent! execute "normal! \<esc>"
    if l:mode =~# '\v^[nvVsS]$'
        call setpos('.', a:state['v_start'])
        let l:selectmode = &selectmode | set selectmode=
        silent! execute "normal! ".a:state['v_mode']
        let &selectmode = l:selectmode
        call setpos('.', a:state['v_end'])
    elseif l:mode =~# '\v^no.=$'
        call setpos("'<", a:state['v_start'])
        call setpos("'>", a:state['v_end'])
    endif
    if l:mode ==# 'n'
        silent! execute "normal! \<esc>"
    elseif l:mode =~# '\v^[sS]$'
        let l:char = l:mode ==# 's'? 'h' : (l:mode ==# 'S'? 'H' : '')
        silent! execute "normal! \<esc>g".l:char
    endif
    call winrestview(a:state['win'])
endfunction

function s:GetChar(handle) abort
    if a:handle['input_source'] ==# 'user'
        let l:nr = s:GetCharShowCursor(a:handle)
    elseif a:handle['input_source'] ==# 'typeahead'
        call inputrestore()
        let l:nr = getchar(0)
        let l:char = nr2char(l:nr)
        if l:char ==# s:hijack_probe
            call feedkeys(s:hijack_probe, 'i')
        endif
        call inputsave()

        " if a:handle['stack_level'] > 0
            let [ l:handle, l:parent_handle ] = [ a:handle, s:GetStackPrev(a:handle) ]
            let l:parent_typeahead = matchstr(l:parent_handle['expr_reduced'], '\V'.l:handle['parent_call'].'\zs\.\*')
            " TODO: remove 'stack_level' usage
            while l:handle['stack_level'] > 1 && empty(l:parent_typeahead)
                let [ l:handle, l:parent_handle ] = [ s:GetStackPrev(l:handle), s:GetStackPrev(l:parent_handle) ]
                let l:parent_typeahead = matchstr(l:parent_handle['expr_reduced'], '\V'.l:handle['parent_call'].'\zs\.\*')
            endwhile
            if !empty(l:parent_typeahead)
                let l:parent_handle['expr_reduced'] = matchstr(l:parent_handle['expr_reduced'], '\V\^\.\{-}'.l:handle['parent_call']).strcharpart(l:parent_typeahead, 1)
                if  !empty(l:nr) && ( l:char !=# strcharpart(l:parent_typeahead, 0, 1) )
                    throw 'cyclops.vim: Unexpected error while processing operator'
                endif
                let l:char = strcharpart(l:parent_typeahead, 0, 1)
                let l:nr = char2nr(l:char)
            endif
        " endif

        if empty(l:nr) || l:char ==# s:hijack_probe
            let l:nr = s:GetCharShowCursor(a:handle)
        endif
    endif
    return l:nr
endfunction

function s:GetCharShowCursor(handle) abort
    let [ l:match_ids, l:cursor_hl ] = [ [], hlexists('Cursor')? 'Cursor' : g:op#cursor_highlight_fallback ]
    let l:cursorline = &cursorline
    if s:hijack['mode'] =~# '\m^no'
        unsilent echo 'Operator Input:' a:handle['hijack_stream']
        if a:handle['init']['entry_mode'] =~# '\v^[vV]$'
            set nocursorline
            if a:handle['init']['entry_mode'] =~# '\v^[vV]$'
                call add(l:match_ids, matchadd('Visual', '\m\%>'."'".'<\&\%<'."'".'>\&[^$]'))
                call add(l:match_ids, matchadd('Visual', '\m\%'."'".'<\|\%'."'".'>'))
            else
                " TODO  mode
            endif
        endif
        call add(l:match_ids, matchadd(l:cursor_hl, '\%'.line('.').'l\%'.col('.').'c'))
    elseif s:hijack['mode'] ==# 'i'
        call add(l:match_ids, matchadd(l:cursor_hl, '\%'.line('.').'l\%'.(col('.')+1).'c'))
    elseif s:hijack['mode'] ==# 'c' || s:hijack['cmd_type'] =~# '\v^[:/?]$'
        let l:input = (s:hijack['cmd_type'] == a:handle['hijack_stream'][0])? a:handle['hijack_stream'][1:] : a:handle['hijack_stream']
        if s:hijack['cmd_type'] =~# '\v[/?]' && &incsearch
            nohlsearch
            call add(l:match_ids, matchadd(l:cursor_hl, '\%'.line('.').'l\%'.col('.').'c'))
            silent! call add(l:match_ids, matchadd('IncSearch', l:input))
            redraw
        endif
        unsilent echo s:hijack['cmd_type'].s:hijack['cmd'].l:input
    endif
    redraw
    " try
        let l:nr = getchar()
    " catch /^Vim:Interrupt$/
    "     let l:nr = char2nr("\<c-c>")
    " endtry
    let &cursorline = l:cursorline
    for l:id in l:match_ids
        if l:id > 0
            call matchdelete(l:id)
        endif
    endfor
    return l:nr
endfunction

function s:ExecuteMap(handle, cmd) abort
    call s:PushStack()
    let [ l:timeout, l:timeoutlen ] = [ &timeout, &timeoutlen ]
    set timeout timeoutlen=0
    " try
        call s:Log(s:Pad('ExecuteMap: ', 16) . 'cmd='.a:cmd)
        call feedkeys(a:cmd, 'x')
    " catch /^op#abort$/
    "     let a:handle['abort'] = get(a:handle, 'abort', 'graceful')
    " catch
    "     call s:Log(s:Pad('ExecuteMap ERROR: ', 16) . 'cmd='.a:cmd)
    "
    "     let a:handle['abort'] = 'error'
    "     call s:LogError(a:cmd)
    " endtry
    let [ &timeout, &timeoutlen ] = [ l:timeout, l:timeoutlen ]
    call s:PopStack()
    if has_key(a:handle, 'abort')
        throw 'op#abort'
    endif
endfunction

function s:ReadTypeahead() abort
    let l:typeahead = s:StealTypeahead()
    call feedkeys(l:typeahead)
    return l:typeahead
endfunction

" TEMP: consume typeahead and return empty string
function s:StealTypeahead() abort
    let l:typeahead = ''
    while getchar(1)
        let l:char = getchar(0)
        " let l:typeahead .= (l:char ==# "\<plug>")? "\<plug>" : nr2char(l:char)
        let l:typeahead .= nr2char(l:char)
        if strchars(l:typeahead) > g:op#max_input_size
            " call s:Log(s:Pad('STEALTYPEAHEAD: ', 16) . 'TYPEAHEAD OVERFLOW')
            " call s:Log(s:Pad('', 16) . l:typeahead[0:20].'...')
            " return l:typeahead[0:20]
            throw 'cyclops.vim: Unexpected error while reading typeahead (incomplete command called in normal mode?)'
        endif
    endwhile
    return l:typeahead
endfunction

function s:AssertExprMap() abort
    if g:op#disable_expr_assert
        return
    endif
    try " throws if in <expr> map
        execute "normal! 1"
        let l:expr_map = 0
    catch /^Vim\%((\a\+)\)\=:E523:/
        let l:expr_map = 1
    endtry
    if !l:expr_map
        throw 'cyclops.vim: Error while processing map. <expr> map must be used for this plugin. To disable this check (and likely break dot repeating) set g:op#disable_expr_assert'
    endif
endfunction

function s:LogError(expr) abort
    let s:error_log = [ 'Error detected while processing '.a:expr.' at '.v:throwpoint, v:exception ]
endfunction

function s:ExprWithModifiers(handle) abort
    let l:opts = a:handle['opts']
    let l:init = a:handle['init']

    let l:expr_with_modifiers = a:handle['expr_reduced']
    if l:opts['accepts_register'] && l:init['register'] != s:GetDefaultRegister()
        let l:expr_with_modifiers = l:expr_with_modifiers.l:init['register']
    endif
    if l:opts['accepts_count'] && l:init['count1'] != 1
        let l:expr_with_modifiers = l:init['count1'].l:expr_with_modifiers
    elseif !l:opts['accepts_count']
        let l:expr_with_modifiers = repeat(l:expr_with_modifiers, l:init['count1'])
    endif
    return l:expr_with_modifiers
endfunction

function s:GetSource(vargs) abort
    if len(a:vargs)
        return a:vargs[0]
    else
        " a:0 == 0 if called from operatorfunc (via g@) from the dop map. In
        " this case we must determine if it's the first call (initialization) or
        " a repeat call.
        return (s:StackDepth() == 0)? 'dot' : 'init'
    endif
endfunction

function s:GetHandle(op_type) abort
    return (a:op_type ==# 'init')? s:StackTop() : s:handles[a:op_type]
endfunction

function s:StackDepth() abort
    return len(s:stack)
endfunction

function s:PushStack() abort
    call s:Log('↓↓↓↓')
    call add(s:stack, {'stack_level': s:StackDepth()})
    call add(s:stack_copy, s:stack[-1])
endfunction

function s:PopStack() abort
    call s:Log('↑↑↑↑')
    call remove(s:stack, -1)
endfunction

function s:StackInit() abort
    if s:StackDepth() > 0 && has_key(s:stack[0], 'abort')
        let s:stack = []
    endif
    if s:StackDepth() == 0
        let g:log = []
        let s:stack_copy = []
        call s:PushStack()
    endif
endfunction

function s:StackClearIfAborted() abort
    if s:StackDepth() > 0 && has_key(s:stack[0], 'abort')
        let s:stack = []
        let s:stack_copy = []
    endif
endfunction

function s:StackTop() abort
    return s:stack[-1]
endfunction

function s:StackBottom() abort
    return s:stack[0]
endfunction

function s:GetStackPrev(handle) abort
    return s:stack[a:handle['stack_level']-1]
endfunction

function s:GetStack() abort
    return s:stack_copy
endfunction

function s:InitRepeat(handle, count, register, mode) abort
    call extend(a:handle, {'repeat_count': a:count, 'repeat_register': a:register, 'repeat_mode': a:mode })
endfunction

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

function s:GetDefaultRegister() abort
    silent! execute "normal! \<esc>"
    return v:register
endfunction

function s:SetVimMode(handle) abort
    let l:opts = a:handle['opts']
    let l:init = a:handle['init']
    silent! execute "normal! \<esc>"
    if l:init['entry_mode'] ==# 'n'
        call setpos('.', l:init['cur_start'])
    elseif l:init['entry_mode'] =~# '\v^[vV]$' && !l:opts['visual_motion']
        call s:SetVisualMode(l:init['v_mode'], l:init['v_start'], l:init['v_end'])
    endif
endfunction

function s:SetVisualMode(v_mode, v_start, v_end) abort
    call setpos('.', a:v_start)
    let l:selectmode = &selectmode | set selectmode=
    silent! execute "normal! ".a:v_mode
    let &selectmode = l:selectmode
    call setpos('.', a:v_end)
endfunction

function s:SID() abort
    return '<SNR>'.matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$').'_'
endfunction

function op#SID() abort
    return s:SID()
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
