let s:cpo = &cpo
set cpo&vim

function op#Load() abort
    " dummy functions to autoload modules
    silent! call dot#load()
    silent! call pair#load()

    if !g:op#no_mappings
        nmap . <plug>(dot#dot)
        vmap . <plug>(dot#visual_dot)
        omap . <plug>(dot#op_pending_dot)

        nmap ; <plug>(pair#next)
        vmap ; <plug>(pair#visual_next)
        omap ; <plug>(pair#op_pending_next)

        nmap , <plug>(pair#previous)
        vmap , <plug>(pair#visual_previous)
        omap , <plug>(pair#op_pending_previous)
    endif
endfunction

let g:op#max_input_size              = !exists('g:op#max_input_size')              ? 1024    : g:op#max_input_size
let g:op#no_mappings                 = !exists('g:op#no_mappings')                 ? 0       : g:op#no_mappings
let g:op#cursor_highlight_fallback   = !exists('g:op#cursor_highlight_fallback')   ? 'Error' : g:op#cursor_highlight_fallback

let g:op#map_defaults = {
            \ 'accepts_count': 1,
            \ 'accepts_register': 1,
            \ 'shift_marks': 0,
            \ 'visual_motion': 0,
            \ 'consumes_typeahead': 0,
            \ 'silent': 1,
            \ }

" must be single character
let s:hijack_probe = '×'
let s:hijack_esc = repeat("\<esc>", 10)
let s:operator_mode_pattern = '\v^(no[vV]=|consumed|i|c)$'

let s:hijack = {'mode': '', 'cmd': '', 'cmd_type': '' }
let s:input_stream = ''
let s:ambiguous_map_chars = ''
let s:inputs = []
let s:exception = ''
let s:debug_throwpoint = ''

let s:stack = []
let s:handles = { 'op': {}, 'dot': {}, 'pair': {} }

let s:debug_log = []
let s:debug_stack = []

function s:Log(msg) abort
    call add(s:debug_log, strftime("%S ") .. s:Pad(string(len(s:stack)), 3) . a:msg)
endfunction

function op#PrintLog() abort
    for l:line in s:debug_log
        echomsg s:ToPrintable(l:line)
    endfor
endfunction

command PL call op#PrintLog()
command PS call op#PrintScriptVars()

function op#PrintScriptVars() abort range
    for l:line in execute('let g:')->split("\n")->filter('v:val =~# '.string('\v^op#'))->sort()
        echomsg 'g:'.l:line
    endfor
    for l:handle in s:GetStack()
        if len(l:handle) == 1 && has_key(l:handle, 'stack_level')
            continue
        endif
        echomsg ' '
        call s:PrintDict(l:handle, '')
    endfor
    for [ l:op_type, l:handle ] in items(s:handles)
        if !empty(l:handle)
            echomsg ' '
            call s:PrintDict(l:handle, '['.l:op_type.']')
        endif
    endfor
    echomsg ' '
    for l:line in execute('let s:')->split("\n")->filter('v:val !~# '.string('\v(handles|stack|debug)'))->sort()
        echomsg s:ToPrintable(l:line)
    endfor
endfunction

function s:PrintDict(dict, prefix) abort
    let l:stack_prefix = has_key(a:dict, 'stack_level') ? '[stack' . a:dict['stack_level'] . ']' : ''
    let l:prefix = l:stack_prefix .. a:prefix
    for l:key in a:dict->keys()->sort()
        if type(a:dict[l:key]) == v:t_dict
            call s:PrintDict(a:dict[l:key], l:prefix.'['.l:key.']')
            continue
        endif
        let l:value = s:FormatValue( l:key, a:dict[l:key] )
        echomsg l:prefix s:Pad(l:key, 20) l:value
    endfor
endfunction

function PrintDict(dict) abort
    call s:PrintDict(a:dict, '')
endfunction

function s:FormatValue(key, value) abort
    let l:value = deepcopy(a:value)
    if type(a:value) == v:t_string
        let l:value = s:ToPrintable(a:value)
    elseif type(a:value) == v:t_list && !empty(a:value) && type(a:value[0]) == v:t_string
        call map(l:value, 's:ToPrintable(v:val)')
    endif

    if a:key ==# 'inputs'
        let l:value = '[' . join(l:value, ', ') . ']'
    endif
    return l:value
endfunction

function s:ToPrintable(value) abort
    let l:ctrl_names = [
                \ '<nul>', '<c-a>', '<c-b>', '<c-c>', '<c-d>', '<c-e>', '<c-f>', '<c-g>',
                \ '<bs>',  '<tab>', '<nl>',  '<c-k>', '<c-l>', '<cr>',  '<c-n>', '<c-o>',
                \ '<c-p>', '<c-q>', '<c-r>', '<c-s>', '<c-t>', '<c-u>', '<c-v>', '<c-w>',
                \ '<c-x>', '<c-y>', '<c-z>', '<esc>', '<fs>',  '<gs>',  '<rs>',  '<us>'
                \ ]
    let l:value = substitute(a:value, "\<plug>", '<plug>', 'g')
    let l:output = ''
    for l:char in split(l:value, '\zs')
        let l:nr = char2nr(l:char)
        let l:output .= (l:nr < 32)? l:ctrl_names[l:nr] : l:char
    endfor
    return l:output
endfunction

function s:Pad(value, length) abort
    let l:pad_len = a:length - strdisplaywidth(a:value)
    let l:pad = (l:pad_len > 0)? repeat(' ', l:pad_len) : ''
    return a:value . l:pad
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

function s:CheckOptsDict(vargs)
    if len(a:vargs) > 1 || ( len(a:vargs) == 1 && type(a:vargs[0]) != v:t_dict )
        throw 'cyclops.vim: Incorrect parameter, only a dictionary of options is accepted.'
    endif
    let l:opts = len(a:vargs) == 1 ? a:vargs[0] : {}
    for [l:key, l:value] in items(l:opts)
        if !has_key(g:op#map_defaults, l:key)
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
    call s:InitCallback('op', a:map, s:CheckOptsDict(a:000))
    return "\<cmd>call ".op#SID()."ComputeMapCallback()\<cr>"
endfunction

function op#Noremap(map, ...) abort range
    call s:AssertExprMap()
    let l:map = s:RegisterNoremap(a:map)
    call s:InitCallback('op', l:map, s:CheckOptsDict(a:000))
    return "\<cmd>call ".op#SID()."ComputeMapCallback()\<cr>"
endfunction

function s:AssertExprMap() abort
    try " throws if in <expr> map
        execute "normal! 1"
        let l:expr_map = 0
    catch /^Vim\%((\a\+)\)\=:E523:/
        let l:expr_map = 1
    endtry
    if !l:expr_map
        throw 'cyclops.vim: Error while processing map, <expr> map must be used for this plugin'
    endif
endfunction

function s:RegisterNoremap(map) abort
    let l:map_string = '<plug>(op#_noremap_'.a:map.')'
    if empty(maparg(l:map_string))
        execute 'noremap <silent> ' .. l:map_string .. ' ' .. a:map
    endif
    return "\<plug>(op#_noremap_".a:map.')'
endfunction

function s:InitCallback(op_type, expr, opts) abort
    if mode(1) !~# '\v^(n|v|V||no|nov|noV|no)$'
        throw 'cyclops.vim: Entry mode '.string(mode(1)).' not yet supported.'
    endif
    call s:StackInit()
    let l:handle = s:StackTop()

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

function s:ComputeMapCallback() abort range
    let l:handle = s:StackTop()
    call s:Log(s:Pad('Callback ' .. s:StackDepth() .. ' ' .. s:PModes() .. ': ', 30) .. 'expr=' .. l:handle['expr_orig'] .. ' typeahead=' .. substitute(s:ReadTypeahead(), '\m' .. "\<esc>" .. '\+$', "\<esc>", ''))

    " reduces nested op# exprs and concatenates with their inputs
    call s:ComputeMapOnStack(l:handle)

    " execute computed map and store handle in case of repeat
    if s:StackDepth() == 1
        " expr_with_modifiers stored for debugging
        let l:handle['expr_with_modifiers'] = s:ExprWithModifiers(l:handle)
        call feedkeys(l:handle['expr_with_modifiers'] .. s:ambiguous_map_chars, 'x!')
        if l:handle['opts']['silent']
            unsilent echo
        endif
        call s:StoreHandle(l:handle)
    endif
endfunction

function s:ComputeMapOnStack(handle) abort
    if s:StackDepth() == 1
        let s:ambiguous_map_chars = s:StealTypeahead()

        try
            " stack recursion starts here
            call s:ComputeMapRecursive(a:handle)
        catch /op#abort/
            let s:debug_throwpoint = empty(s:debug_throwpoint)? v:throwpoint : s:debug_throwpoint
            call s:Log('')
            call s:Log('EXCEPTION: ' .. s:exception)
            call s:Log(s:debug_throwpoint)
            echohl ErrorMsg | echomsg s:exception | echohl None
            call interrupt()
        endtry
        call s:HijackInput(a:handle)
    else
        call s:ParentReduceExpr(a:handle)
        call inputsave()

        " stack recursion continues here
        call s:ComputeMapRecursive(a:handle)
        call s:HijackInput(a:handle)
        call s:ParentReduceExprInput(a:handle)

        call feedkeys(a:handle['expr_reduced'], 'x')
        call inputrestore()
    endif
endfunction

function s:ComputeMapRecursive(handle) abort
    call s:PushStack(s:Pad('Push  ' .. s:PModes() .. ': ', 25) .. 'expr=' .. a:handle['expr_orig'] .. s:hijack_probe .. '<esc>' .. ' typeahead=' .. s:ReadTypeahead())
    call s:ProbeExpr(a:handle['expr_orig'])
    call s:PopStack(s:Pad('Pop   ' .. s:PModes() .. ': ', 25) .. 'mode=' .. s:hijack['mode'] .. ' cmd=' .. s:hijack['cmd'] .. ' cmd_type=' .. s:hijack['cmd_type'] .. ' typeahead=' .. s:ReadTypeahead())
endfunction

function s:HijackInput(handle) abort
    let l:expr = a:handle['expr_reduced']

    let l:debug_log = s:hijack['mode'] =~# s:operator_mode_pattern
    if l:debug_log
        call s:Log(s:Pad('HijackInput ' .. s:PModes() .. ': ', 30))
    endif

    let s:input_stream = ''
    if a:handle['input_source'] ==# 'input_cache'
        if s:hijack['mode'] =~# s:operator_mode_pattern
            let s:input_stream = remove(a:handle['input_cache'], 0)
        endif
    else
        " get input from ambiguous maps
        while !empty(s:ambiguous_map_chars) && s:hijack['mode'] =~# s:operator_mode_pattern
            let l:ambig_char = strcharpart(s:ambiguous_map_chars, 0, 1)
            let s:ambiguous_map_chars = strcharpart(s:ambiguous_map_chars, 1)
            let s:input_stream ..= l:ambig_char
            call s:ProbeExpr(l:expr .. s:input_stream)
        endwhile

        if l:debug_log
            call s:Log(s:Pad('HijackInput GET INPUT: ', 30) .. 'expr=' .. a:handle['expr_reduced'] .. ' typeahead=' .. substitute(s:ReadTypeahead(), '\m' .. "\<esc>" .. '\+$', "\<esc>", ''))
        endif

        if a:handle['input_source'] ==# 'user'
            while s:hijack['mode'] =~# s:operator_mode_pattern
                let l:char = s:GetCharFromUser(a:handle)
                let s:input_stream = s:ProcessStream(s:input_stream, l:char)
                call s:ProbeExpr(l:expr .. s:input_stream)
            endwhile
        else
            while s:hijack['mode'] =~# s:operator_mode_pattern
                let s:input_stream ..= s:GetCharFromTypeahead(a:handle)
                call s:ProbeExpr(l:expr .. s:input_stream)
            endwhile
        endif

        if l:debug_log
            call s:Log(s:Pad('HijackInput GOT: ', 30) .. 'input_stream=' .. s:input_stream)
        endif

        " store
        if !empty(s:input_stream)
            call add(s:inputs, s:input_stream)
        endif
    endif

    call s:CheckForErrors(l:expr .. s:input_stream)
    let a:handle['expr_reduced'] = l:expr .. s:input_stream
endfunction

function s:CheckForErrors(expr) abort
    let l:state = s:GetState()
    try
        silent call feedkeys(a:expr, 'x!')
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
        " feedkeys(..., 'x') is not working as expected, only last map in
        " stack is processed, execution order is seemingly broken (logging at
        " callback entry doesn't show beginning/intermediate maps)
        " silent call feedkeys(a:expr .. s:hijack_probe, 'x')

        silent call feedkeys(a:expr .. s:hijack_probe .. s:hijack_esc, 'x!')
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
execute 'noremap  <expr>' .. s:hijack_probe .. ' <sid>HijackProbeMap()'
execute 'noremap! <expr>' .. s:hijack_probe .. ' <sid>HijackProbeMap()'
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
    let l:parent_handle = s:GetStackPrev(a:handle)
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
        let l:v_state = s:GetVisualState()
    elseif l:mode =~# '\v^[vV]$'
        let l:v_state = s:GetVisualState()
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
        call s:SetVisualState(a:state['v_state'])
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

function s:GetVisualState() abort
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

function s:SetVisualState(v_state) abort
    let [ l:v_mode, l:v_start, l:v_end ] = a:v_state
    silent! execute "normal! \<esc>"
    call setpos('.', l:v_start)
    let l:selectmode = &selectmode | set selectmode=
    silent! execute "normal! ".l:v_mode
    let &selectmode = l:selectmode
    call setpos('.', l:v_end)
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
    if !getchar(1)
        unsilent echo
        redraw
    endif
    return l:char
endfunction

function s:GetCharFromUser_i(handle) abort
    let l:match_ids = []
    try
        if !getchar(1)
            " show changes
            call feedkeys(a:handle['expr_reduced'] .. s:input_stream, 'x')

            " set highlights
            let l:cursor_hl = hlexists('Cursor')? 'Cursor' : g:op#cursor_highlight_fallback
            call add(l:match_ids, matchadd(l:cursor_hl, '\%'.line('.').'l\%'.(col('.')+1).'c'))
            redraw
        endif
        let l:char = s:GetCharStr('i')
    finally
        call s:ClearHighlights(l:match_ids)
    endtry

    return l:char
endfunction

function s:GetCharFromUser_no(handle) abort
    let l:match_ids = []

    if !getchar(1)
        unsilent echo 'Operator Input:' .. s:input_stream

        " set highlights
        let l:cursor_hl = hlexists('Cursor')? 'Cursor' : g:op#cursor_highlight_fallback
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
        let l:cursor_hl = hlexists('Cursor')? 'Cursor' : g:op#cursor_highlight_fallback

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

function s:SetPrompts() abort
    if s:hijack['mode'] =~# '\v^(no|consumed)$'
        unsilent echo 'Operator Input:' .. s:input_stream
    elseif s:hijack['mode'] ==# 'c' || s:hijack['cmd_type'] =~# '\v^[:/?]$'
        unsilent echo s:hijack['cmd_type'] .. s:hijack['cmd']
    endif
    redraw
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
    let [ l:handle, l:parent_handle ] = [ a:handle, s:GetStackPrev(a:handle) ]
    let l:parent_typeahead = matchstr(l:parent_handle['expr_reduced'], '\V'.l:handle['parent_call'].'\zs\.\*')
    while l:handle['stack_level'] > 1 && empty(l:parent_typeahead)
        let [ l:handle, l:parent_handle ] = [ s:GetStackPrev(l:handle), s:GetStackPrev(l:parent_handle) ]
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
        if strchars(l:typeahead) > g:op#max_input_size
            call s:Log(s:Pad('STEALTYPEAHEAD: ', 30) . 'TYPEAHEAD OVERFLOW')
            call s:Log(s:Pad('', 20) . l:typeahead[0:30].'...')
            call s:Throw('cyclops.vim: Typeahead overflow while reading typeahead (incomplete command called in normal mode?)')
        endif
    endwhile
    return l:typeahead
endfunction

function s:ExprWithModifiers(handle) abort
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

function s:GetHandle(op_type) abort
    return s:handles[a:op_type]
endfunction

function s:StoreHandle(handle) abort
        let l:handle_to_store = deepcopy(a:handle)
        call extend(l:handle_to_store, { 'inputs': s:inputs })
        call remove(l:handle_to_store, 'stack_level')

        let l:name = a:handle['init']['op_type']
        let s:handles[l:name] = l:handle_to_store
        call s:PopStack()
endfunction

function s:StackDepth() abort
    return len(s:stack)
endfunction

function s:PushStack(...) abort
    let l:tag = a:0? a:1 : ''

    call s:Log('↓↓↓↓ ' .. l:tag)
    let l:frame = {'stack_level': s:StackDepth()}
    if !empty(l:tag)
        let l:frame['tag'] = l:tag
    endif

    call add(s:stack, l:frame)
    call add(s:debug_stack, l:frame)
endfunction

function s:PopStack(...) abort
    let l:tag = a:0? a:1 : get(s:StackTop(), 'tag', '')
    call s:Log('↑↑↑↑ ' .. l:tag)
    call remove(s:stack, -1)
endfunction

function s:StackInit() abort
    if s:StackDepth() > 0 && !empty(s:exception)
        let s:stack = []
    endif
    if s:StackDepth() == 0
        let s:exception = ''
        let s:debug_throwpoint = ''
        let s:debug_log = []
        let s:ambiguous_map_chars = ''
        let s:hijack = {'mode': '', 'cmd': '', 'cmd_type': '' }
        if !empty(s:inputs)
            call remove(s:inputs, 0, -1)
        endif
        if !empty(s:debug_stack)
            call remove(s:debug_stack, 0, -1)
        endif
        call s:PushStack('StackInit')
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
    " return s:debug_stack
    return s:stack
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
        let s:exception = l:msg
        let s:debug_throwpoint = v:throwpoint
        throw 'op#abort'
    endtry
endfunction

" function s:SetDefaultRegister() abort
"     silent! execute "normal! \<esc>"
"     let s:default_register = v:register
" endfunction

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
