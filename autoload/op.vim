let s:cpo = &cpo
set cpo&vim

let g:op#disable_expr_assert         = !exists('g:op#disable_expr_assert')         ? 0       : g:op#disable_expr_assert
let g:op#max_input_size              = !exists('g:op#max_input_size')              ? 1024    : g:op#max_input_size
let g:op#no_mappings                 = !exists('g:op#no_mappings')                 ? 0       : g:op#no_mappings
let g:op#operators_consume_typeahead = !exists('g:op#operators_consume_typeahead') ? 0       : g:op#operators_consume_typeahead
let g:op#cursor_highlight_fallback   = !exists('g:op#cursor_highlight_fallback')   ? 'Error' : g:op#cursor_highlight_fallback

let s:stack = []
let s:handles = { 'norepeat': {}, 'dot': {}, 'pair': {} }

function op#PrintScriptVars() abort range
    for l:line in execute('let g:')->split("\n")->filter('v:val =~# '.string('\v^op#'))->sort()
        echomsg 'g:'.l:line
    endfor
    if !empty(s:stack)
        echomsg ' '
        for l:handle in s:stack
            echomsg l:handle['stack_level']? ' ' : ''
            for l:key in l:handle->keys()->sort()
                echomsg 'stack '.l:handle['stack_level'].':' l:key repeat(' ', 20-strdisplaywidth(l:key)) l:handle[l:key]
            endfor
        endfor
    endif
    for [ l:op_type, l:handle ] in items(s:handles)
        if !empty(l:handle)
            echomsg ' '
            for l:key in l:handle->keys()->sort()
                let l:item = substitute(string(l:handle[l:key]), "\<plug>", '<Plug>', 'g')
                let l:item = substitute(l:item, '\v'."^'|'$", '', 'g')
                echomsg l:op_type.':' l:key repeat(' ', 20-strdisplaywidth(l:key)) l:item
            endfor
        endif
    endfor
    echomsg ' '
    for l:line in execute('let s:')->split("\n")->filter('v:val !~# '.string('\v(handles|stack)'))->sort()
        echomsg l:line
    endfor
endfunction

function s:CheckOptsDict(opts)
    if len(a:opts) > 1 || ( len(a:opts) == 1 && type(a:opts[0]) != v:t_dict )
        throw 'cyclops.vim: Incorrect parameter, only a dictionary of options is accepted.'
    endif
    let l:opts = {
                \ 'accepts_count': 0, 
                \ 'accepts_register': 1,
                \ 'shift_marks': 0,
                \ 'visual_motion': 0,
                \ 'consumes_typeahead': !empty(g:op#operators_consume_typeahead)
                \ }
    if len(a:opts)
        for [l:key, l:value] in items(a:opts[0])
            if l:key !~# '\v^(accepts_count|accepts_register|shift_marks|visual_motion|consumes_typeahead)$'
                throw 'cyclops.vim: Unrecognized option '.string(l:key).'.'
            endif
            if l:value != v:true && l:value != v:false
                throw 'cyclops.vim: Unrecognied option value '.string(l:key).': '.string(l:value).'. Values must be 0 or 1.'
            endif
            let l:opts[l:key] = l:value
        endfor
    endif
    return l:opts
endfunction

function op#Map(map, ...) abort range
    call s:AssertExprMap()
    call s:InitCallback('norepeat', a:map, 0, s:CheckOptsDict(a:000))
    return "\<cmd>call ".op#SID()."Callback('', 'stack')\<cr>"
endfunction

function op#Noremap(map, ...) abort range
    call s:AssertExprMap()
    if empty(maparg('<plug>(op#_noremap_'.a:map.')'))
        execute 'noremap <plug>(op#_noremap_'.a:map.') '.a:map
    endif
    call s:InitCallback('norepeat', "\<plug>(op#_noremap_".a:map.")", 0, s:CheckOptsDict(a:000))
endfunction

function op#ExprNoremap(map, ...) abort range
    if empty(maparg('<plug>(op#_noremap_'.a:map.')'))
        execute 'noremap <plug>(op#_noremap_'.a:map.') '.a:map
    endif
    call s:InitCallback('norepeat', "\<plug>(op#_noremap_".a:map.")", 0, s:CheckOptsDict(a:000))
    return "\<cmd>call ".op#SID()."Callback('', 'stack')\<cr>"
endfunction

function s:InitCallback(op_type, expr, pair, opts) abort
    if mode(1) !~# '\v^(n|v|V||s|S||no|nov|noV|no)$'
        throw 'cyclops.vim: Entry mode '.string(mode(1)).' not yet supported.'
    endif

    let l:handle = s:StartStack()
    call extend(l:handle, a:opts)
    call extend(l:handle, {
                \ 'input_source': (a:opts['consumes_typeahead']? 'typeahead': 'user'),
                \ 'op_type': a:op_type,
                \ 'expr': a:expr,
                \ 'expr_so_far': '',
                \ 'called_from': 'initialization',
                \ 'entry_mode': mode(1),
                \ 'cur_start': getcurpos(),
                \ 'count1': v:count1,
                \ 'register': v:register,
                \ })
    if a:op_type ==# 'pair'
        call extend(l:handle, { 'expr': a:pair[a:expr], 'pair': a:pair, 'pair_id': a:expr, 'pair_state': ['invalid', 'invalid'] })
    endif
endfunction

function s:Callback(dummy, ...) abort range
    let l:handle = a:0? s:GetHandle(a:1) : s:GetHandle('dot_or_stack')
    call setpos('.', l:handle['cur_start'])
    call extend(l:handle, { 'register_default': s:GetDefaultRegister() })
    if l:handle['entry_mode'] ==# 'n'
        silent! execute "normal! \<esc>"
    elseif l:handle['entry_mode'] =~# '\v^[vV]$' && !l:handle['visual_motion']
        let l:selectmode = &selectmode | set selectmode=
        silent! execute "normal! \<esc>gv"
        let &selectmode = l:selectmode
    elseif l:handle['entry_mode'] =~# '\v^[sS]$' && mode(1) !=# l:handle['entry_mode']
        let l:char = l:mode ==# 's'? 'h' : (l:mode ==# 'S'? 'H' : '')
        silent! execute "normal! \<esc>g".l:char
    elseif l:handle['entry_mode'] =~# '\v^(no|nov|noV|no)$'
        let l:handle['operator'] = v:operator
    endif

    if l:handle['called_from'] =~# 'initialization'
        call s:ExecuteAndRestoreOnFail(l:handle)
    elseif l:handle['called_from'] =~# 'repeat'
        call s:ExecuteMap(l:handle, s:ExprWithModifiers(l:handle))
    endif

    call extend(l:handle, {'cur_end': getcurpos()})
    if l:handle['entry_mode'] =~# '\v^[vV]$' && l:handle['visual_motion'] && mode(1) ==# 'n'
        silent! execute "normal! \<esc>gv"
        call setpos('.', l:handle['cur_end'])
    endif
    call s:StoreHandle(l:handle)
    let &operatorfunc = a:0? &operatorfunc : op#SID().'Callback'
    unsilent echo
endfunction

function s:ExecuteAndRestoreOnFail(handle) abort
    if a:handle['stack_start']
        let l:state = s:SaveState(a:handle)
        try
            call s:ExecuteMapOnStack(a:handle)
        catch /^op#abort$/
            call s:RestoreState(a:handle, l:state)
        endtry
        if has_key(a:handle, 'error_log')
            echohl ErrorMsg | echomsg a:handle['error_log'][0] | echohl None
            echohl ErrorMsg | echomsg a:handle['error_log'][1] | echohl None
            call remove(a:handle, 'error_log')
            echoerr 'cyclops.vim: Error detected, see messages'
        endif
    else
        call s:ExecuteMapOnStack(a:handle)
    endif
endfunction

function s:ExecuteMapOnStack(handle) abort
    try
        if a:handle['stack_start']
            let l:state = s:SaveState(a:handle)
            call s:ResolveAmbiguousMap(a:handle, s:StealTypeahead())
        else
            call s:SetParentCall(a:handle)
        endif
        call inputsave()
        call s:HijackInput(a:handle)
        call s:ExecuteMap(a:handle, a:handle['expr'])
        call s:SetOpMode(a:handle)
        let l:expr = (a:handle['entry_mode'] =~# '\v^no[vV]=$')? get(a:handle, 'operator', '').get(a:handle, 'op_mode', '') : ''
        let l:expr .= s:ExprWithModifiers(a:handle)
        if a:handle['stack_start'] && a:handle['expr'] !=# l:expr
            call s:RestoreState(a:handle, l:state)
            call s:ExecuteMap(a:handle, l:expr)
        elseif !a:handle['stack_start']
            call s:UpdateParentExpr(a:handle)
        endif
        call inputrestore()
    catch /^op#abort$/
        if !a:handle['stack_start']
            if has_key(a:handle, 'error_log')
                let l:root = s:GetRootHandle()
                let l:root['error_log'] = a:handle['error_log']
            endif
            let l:parent = s:GetParentHandle(a:handle)
            let l:parent['abort'] = a:handle['abort']
        endif
        throw 'op#abort'
    endtry
endfunction

function s:HijackInput(handle) abort
    call extend(a:handle, { 'hijack_mode': 'no', 'hijack_stream': '' })
    for l:char in split(get(a:handle, 'ambiguous_map', ''), '\zs')
        call s:UpdateHijackStream(a:handle, char2nr(l:char))
    endfor
    let [ l:expr, l:state ] = [ a:handle['expr'], s:SaveState(a:handle) ]
    let a:handle['expr'] = l:expr.a:handle['hijack_stream']
    call s:ExecuteHijack(a:handle)
    if a:handle['input_source'] ==# 'input_cache' && a:handle['hijack_mode'] =~# '\v^(no.=|i|c)$'
        let a:handle['expr'] = l:expr .. remove(a:handle['input_cache'], 0)
        return
    endif

    while a:handle['hijack_mode'] =~# '\v^(no[vV]=|i|c)$'
        if a:handle['hijack_mode'] =~# '\m^no'
            while a:handle['hijack_mode'] =~# '\m^no'
                call s:UpdateHijackStream(a:handle, s:GetChar(a:handle))
                let a:handle['expr'] = l:expr.a:handle['hijack_stream']
                if s:workaround_f
                    " Problem: feedkeys('dfa×') ends in operator pending mode
                    " Workaround: break out of loop early if any of [fFtT] is used
                    let a:handle['hijack_mode'] = 'n'
                    let s:workaround_f = 0
                    break
                endif
                call s:RestoreState(a:handle, l:state)
                call s:ExecuteHijack(a:handle)
            endwhile
        elseif a:handle['hijack_mode'] ==# 'i'
            let l:char = s:UpdateHijackStream(a:handle, s:GetChar(a:handle))
            execute "normal! a".l:char
            while l:char != "\<esc>"
                let l:char = s:UpdateHijackStream(a:handle, s:GetChar(a:handle))
                execute "normal! a".l:char
            endwhile
            let a:handle['expr'] = l:expr.a:handle['hijack_stream']
            call s:ExecuteHijack(a:handle)
        elseif a:handle['hijack_mode'] ==# 'c' || a:handle['hijack_cmd_type'] =~# '\v^[:/?]$'
            call s:RestoreState(a:handle, l:state)
            call extend(a:handle, { 'hijack_cmd': s:hijack_cmd, 'hijack_cmd_type': s:hijack_cmd_type })
            let l:char = s:UpdateHijackStream(a:handle, s:GetChar(a:handle))
            while l:char != "\<cr>"
                let l:char = s:UpdateHijackStream(a:handle, s:GetChar(a:handle))
            endwhile
            call setpos('.', a:handle['cur_start'])
            let a:handle['expr'] = l:expr.a:handle['hijack_stream']
            call s:ExecuteHijack(a:handle)
        endif
        let s:workaround_f = 0

        if !empty(a:handle['hijack_stream'])
            let l:root = s:GetRootHandle()
            if !has_key(l:root, 'input_cache')
                call extend(l:root, {'input_cache': []})
            endif
            call add(l:root['input_cache'], a:handle['hijack_stream'])
        endif
    endwhile

    call s:RestoreState(a:handle, l:state)
endfunction

function s:UpdateHijackStream(handle, nr) abort
    let l:char = nr2char(a:nr)
    if a:nr == "\<bs>"
        let a:handle['hijack_stream'] = strcharpart(a:handle['hijack_stream'], 0, strchars(a:handle['hijack_stream'])-1)
        let l:char = "\<bs>"
    elseif l:char == "\<c-v>"
        let l:literal = nr2char(s:GetChar(a:handle))
        let l:char = (a:handle['hijack_mode'] ==# 'i')? l:char.l:literal : l:literal
        let a:handle['hijack_stream'] .= l:char
    elseif l:char == "\<esc>"
        if a:handle['hijack_mode'] !=# 'i'
            let a:handle['abort'] = '<esc>'
            throw 'op#abort'
        else
            let a:handle['hijack_stream'] .= l:char
        endif
    elseif l:char == "\<c-c>"
        let a:handle['abort'] = 'interrupt (<c-c>)'
        throw 'op#abort'
    elseif l:char == '.'
        if a:handle['hijack_mode'] =~# '\v^no[vV]=$'
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

function s:ExecuteHijack(handle) abort
    " feedkeys with 'x' fills typeahead with endless <esc> in order to exit
    " insert mode, whereas 'x!' does not fill the typeahead. In Hijack mode we
    " still want to to return to normal mode, but in a controlled manner. Hijack
    " mode adds g:op#max_input_size many <esc> to typeahead.
    let [ s:hijack_mode, s:hijack_cmd, s:hijack_cmd_type ] = [ 'NULL', 'NULL', 'NULL' ]
    let [ l:belloff, l:timeout, l:timeoutlen ] = [ &belloff, &timeout, &timeoutlen ]
    set belloff+=error,esc timeout timeoutlen=0
    call s:PushStack()
    try
        silent! call feedkeys(a:handle['expr'].'×'.repeat("\<esc>", g:op#max_input_size), 'x!')
    catch
    endtry
    call s:PopStack()
    let [ &belloff, &timeout, &timeoutlen ] = [ l:belloff, l:timeout, l:timeoutlen ]
    let a:handle['hijack_mode'] = (s:hijack_mode !=# 'NULL')? s:hijack_mode : a:handle['hijack_mode']
    let a:handle['hijack_cmd_type'] = (s:hijack_cmd_type !=# 'NULL')? s:hijack_cmd_type : ''
    let a:handle['hijack_cmd'] = (s:hijack_cmd !=# 'NULL')? s:hijack_cmd : ''
    if has_key(a:handle, 'abort')
        throw 'op#abort'
    endif
endfunction

" Some commands may consume the RHS and start executing, use something unusual
noremap  <expr>× <sid>SetHijackModeVar()
noremap! <expr>× <sid>SetHijackModeVar()
function s:SetHijackModeVar() abort
    let s:hijack_mode = mode(1)
    let [ s:hijack_cmd, s:hijack_cmd_type ] = [ getcmdline(), getcmdtype() ]
    return ''
endfunction

function s:ResolveAmbiguousMap(handle, typeahead) abort
    let a:handle['ambiguous_map'] = a:typeahead
endfunction

function s:SetOpMode(handle) abort
    if has_key(a:handle, 'operator')
        if a:handle['entry_mode'] ==# 'no'
            let a:handle['op_mode'] = ( a:handle['cur_start'][1] == getcurpos()[1] )? '' : 'V'
        else
            let a:handle['op_mode'] = a:handle['entry_mode'][2]
        endif
    endif
endfunction

function s:SetParentCall(handle) abort
    " Note: maps don't save which key triggered them, but we can deduce this
    " information when the stack frame is not the root.
    " Note: the parent (up to this point) is the set complement of previous expr
    " and current typeahead (less the hijack junk)
    let l:parent_handle = s:GetParentHandle(a:handle)
    let a:handle['parent_expr'] = l:parent_handle['expr']
    let l:typeahead = substitute(s:ReadTypeahead(), '\v×'."\<esc>".'*$', '', '')
    let l:parent = matchstr(a:handle['parent_expr'], '\V\.\*\ze\('."\<plug>".'\)\='.escape(l:typeahead, '\'))

    " remove parts already executed
    let l:parent = substitute(l:parent, '\V\^'.escape(l:parent_handle['expr_so_far'], '\'), '', '')

    " remove keys that are not managed by this plugin
    let l:parent_call = l:parent
    if a:handle['entry_mode'] ==# 'n'
        let l:mode = 'n'
    elseif a:handle['entry_mode'] =~# '\v^[vV]$'
        let l:mode = 'x'
    elseif a:handle['entry_mode'] =~# '\v^[sS]$'
        let l:mode = 's'
    elseif a:handle['entry_mode'] =~# '\v^no.=$'
        let l:mode = 'o'
    endif
    let l:count = 0
    while l:parent_call != '' && empty(maparg(substitute(l:parent_call, '\V'."\<plug>", '\<plug>', 'g'), l:mode))
        let l:count += 1
        let l:parent_call = strcharpart(l:parent, l:count)
    endwhile
    let l:parent_handle['expr_so_far'] .= strcharpart(l:parent, 0, l:count)
    let a:handle['parent_call'] = l:parent_call
endfunction

function s:UpdateParentExpr(handle) abort
    let l:expr = get(a:handle, 'op_mode', '').a:handle['expr']
    let l:parent_handle = s:GetParentHandle(a:handle)
    let l:update_pattern = '\V'.escape(l:parent_handle['expr_so_far'], '\').'\zs'.escape(a:handle['parent_call'], '\')
    let l:update = substitute(l:parent_handle['expr'], l:update_pattern, escape(l:expr, '\'), '')
    if l:update ==# l:parent_handle['expr']
        throw 'cyclops.vim: Unexpected error while updating parent call'
    endif
    let l:parent_handle['expr'] = l:update
    let l:parent_handle['expr_so_far'] .= l:expr
endfunction

function s:SaveState(handle) abort
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

function s:RestoreState(handle, state) abort
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
        if l:char ==# '×'
            call feedkeys('×', 'i')
        endif
        call inputsave()

        if a:handle['stack_level'] > 0
            let [ l:handle, l:parent_handle ] = [ a:handle, s:GetParentHandle(a:handle) ]
            let l:parent_typeahead = matchstr(l:parent_handle['expr'], '\V'.l:handle['parent_call'].'\zs\.\*')
            while l:handle['stack_level'] > 1 && empty(l:parent_typeahead)
                let [ l:handle, l:parent_handle ] = [ s:GetParentHandle(l:handle), s:GetParentHandle(l:parent_handle) ]
                let l:parent_typeahead = matchstr(l:parent_handle['expr'], '\V'.l:handle['parent_call'].'\zs\.\*')
            endwhile
            if !empty(l:parent_typeahead)
                let l:parent_handle['expr'] = matchstr(l:parent_handle['expr'], '\V\^\.\{-}'.l:handle['parent_call']).strcharpart(l:parent_typeahead, 1)
                if  !empty(l:nr) && ( l:char !=# strcharpart(l:parent_typeahead, 0, 1) )
                    throw 'cyclops.vim: Unexpected error while processing operator'
                endif
                let l:char = strcharpart(l:parent_typeahead, 0, 1)
                let l:nr = char2nr(l:char)
            endif
        endif

        if empty(l:nr) || l:char ==# '×'
            let l:nr = s:GetCharShowCursor(a:handle)
        endif
    endif
    return l:nr
endfunction

function s:GetCharShowCursor(handle) abort
    let [ l:match_ids, l:cursor_hl ] = [ [], hlexists('Cursor')? 'Cursor' : g:op#cursor_highlight_fallback ]
    let l:cursorline = &cursorline
    if a:handle['hijack_mode'] =~# '\m^no'
        unsilent echo 'Operator Input:' a:handle['hijack_stream']
        if a:handle['entry_mode'] =~# '\v^[vV]$'
            set nocursorline
            if a:handle['entry_mode'] =~# '\v^[vV]$'
                call add(l:match_ids, matchadd('Visual', '\m\%>'."'".'<\&\%<'."'".'>\&[^$]'))
                call add(l:match_ids, matchadd('Visual', '\m\%'."'".'<\|\%'."'".'>'))
            else
                " TODO  mode
            endif
        endif
        call add(l:match_ids, matchadd(l:cursor_hl, '\%'.line('.').'l\%'.col('.').'c'))
    elseif a:handle['hijack_mode'] ==# 'i'
        call add(l:match_ids, matchadd(l:cursor_hl, '\%'.line('.').'l\%'.(col('.')+1).'c'))
    elseif a:handle['hijack_mode'] ==# 'c' || a:handle['hijack_cmd_type'] =~# '\v^[:/?]$'
        let l:input = (a:handle['hijack_cmd_type'] == a:handle['hijack_stream'][0])? a:handle['hijack_stream'][1:] : a:handle['hijack_stream']
        if a:handle['hijack_cmd_type'] =~# '\v[/?]' && &incsearch
            nohlsearch
            call add(l:match_ids, matchadd(l:cursor_hl, '\%'.line('.').'l\%'.col('.').'c'))
            silent! call add(l:match_ids, matchadd('IncSearch', l:input))
            redraw
        endif
        unsilent echo a:handle['hijack_cmd_type'].a:handle['hijack_cmd'].l:input
    endif
    redraw
    try
        let l:nr = getchar()
    catch /^Vim:Interrupt$/
        let l:nr = char2nr("\<c-c>")
    endtry
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
    try
        call feedkeys(a:cmd, 'x')
        call s:PopStack()
    catch /^op#abort$/
        let a:handle['abort'] = get(a:handle, 'abort', 'graceful')
    catch
        let a:handle['abort'] = 'error'
        call s:LogError(a:handle, a:cmd)
    endtry
    let [ &timeout, &timeoutlen ] = [ l:timeout, l:timeoutlen ]
    if has_key(a:handle, 'abort')
        throw 'op#abort'
    endif
endfunction

function s:ReadTypeahead() abort
    let l:typeahead = s:StealTypeahead()
    call feedkeys(l:typeahead)
    return l:typeahead
endfunction

function s:StealTypeahead() abort
    let l:typeahead = ''
    while getchar(1)
        let l:char = getchar(0)
        let l:typeahead .= (l:char ==# "\<plug>")? "\<plug>" : nr2char(l:char)
        if strchars(l:typeahead) > 2*g:op#max_input_size
            throw 'cyclops.vim: Unexpected error while reading typeahead'
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

function s:LogError(handle, expr) abort
    let a:handle['error_log'] = [ 'Error detected while processing '.a:expr.' at '.v:throwpoint, v:exception ]
endfunction

function s:ExprWithModifiers(handle) abort
    let a:handle['expr_with_modifiers'] = a:handle['expr']
    if a:handle['accepts_register'] && get(a:handle, 'register', a:handle['register_default']) != a:handle['register_default']
        let a:handle['expr_with_modifiers'] = a:handle['expr_with_modifiers'] a:handle['register']
    endif
    if a:handle['accepts_count'] && a:handle['count1'] != 1
        let a:handle['expr_with_modifiers'] = a:handle['count1'].a:handle['expr_with_modifiers']
    elseif !a:handle['accepts_count']
        let a:handle['expr_with_modifiers'] = repeat(a:handle['expr_with_modifiers'], a:handle['count1'])
    endif
    return a:handle['expr_with_modifiers']
endfunction

function s:StoreHandle(handle) abort
    if has_key(a:handle, 'abort')
        unlet! s:hijack_cmd s:hijack_cmd_type s:hijack_mode
        return
    endif

    call extend(a:handle, {'change_start': getpos("'["), 'change_end': getpos("']")})

    if a:handle['op_type'] ==# 'pair'
        let l:pair_id = a:handle['pair_id']
        let a:handle['pair'][l:pair_id] = a:handle['expr']
        let a:handle['pair_state'][l:pair_id] = 'valid'
        let a:handle['pair_id'] = (a:handle['called_from'] =~# 'repeat')? !l:pair_id : l:pair_id
    endif

    if a:handle['op_type'] =~# '\v^(dot|pair)$'
        let [ l:win, l:mode ] = [ winsaveview(), mode(1) ]
        let l:selectmode = &selectmode | set selectmode=
        silent! execute "normal! \<esc>gv"
        let &selectmode = l:selectmode
        call extend(a:handle, {'v_mode': visualmode(), 'v_start': getpos('v'), 'v_end': getpos('.')} )
        if l:mode ==# 'n'
            silent! execute "normal! \<esc>"
            call winrestview(l:win)
        elseif l:mode !~# '\v^[vV]$'
            throw 'cyclops.vim: Unexpected exit mode'
        endif

        if a:handle['called_from'] =~# 'initialization'
            let s:handles[a:handle['op_type']] = deepcopy(a:handle)
        endif
    endif

    if a:handle['stack_start']
        unlet! s:hijack_cmd s:hijack_cmd_type s:hijack_mode
        call s:PopStack()
    endif
endfunction

function s:GetHandle(op_type) abort
    if a:op_type ==# 'dot_or_stack' && !empty(s:stack) && !has_key(s:stack[-1], 'abort')
        return s:stack[-1]
    else
        let l:op_type = substitute(a:op_type, '\v_or_stack$', '', '')
        return (l:op_type ==# 'stack')? s:stack[-1] : s:handles[l:op_type]
    endif
endfunction

function s:GetRootHandle() abort
    return s:stack[0]
endfunction

function s:GetParentHandle(handle) abort
    return s:stack[a:handle['stack_level']-1]
endfunction

function s:StartStack() abort
    if len(s:stack) > 0 && has_key(s:stack[0], 'abort')
        call remove(s:stack, 0, -1)
    endif
    if len(s:stack) == 0
        call s:PushStack()
        let s:stack[0]['stack_start'] = 1
    endif
    return s:stack[-1]
endfunction

function s:PushStack() abort
    call add(s:stack, {'stack_start': 0, 'stack_level': len(s:stack)})
endfunction

function s:PopStack() abort
    if len(s:stack) > 0
        call remove(s:stack, -1)
    endif
endfunction

function s:InitRepeat(handle, count, register, mode) abort
    if a:mode ==# 'normal'
        call extend(a:handle, { 'called_from': 'repeat', 'entry_mode': 'n', 'cur_start': getcurpos()})
    elseif a:mode ==# 'visual'
        let l:selectmode = &selectmode | set selectmode=
        silent! execute "normal! \<esc>gv"
        let &selectmode = l:selectmode
        call extend(a:handle, { 'called_from': 'visual repeat', 'entry_mode': mode(1), 'cur_start': getcurpos()})
    endif
    let a:handle['count1'] = (a:count || !has_key(a:handle, 'count1'))? max([1,a:count]) : a:handle['count1']
    if a:register ==# 'use_default'
        let a:handle['register'] = a:handle['register_default']
    elseif a:register !~# a:handle['register_default']
        let a:handle['register'] = a:register
    endif
    if get(a:handle, 'shift_marks')
        if a:mode ==# 'normal'
            let [ a:handle['v_start'], a:handle['v_end'] ] = s:ShiftToCursor(a:handle['v_start'], a:handle['v_end'])
            call setpos('.', a:handle['v_start'])
            let l:selectmode = &selectmode | set selectmode=
            silent! execute "normal! ".a:handle['v_mode']
            let &selectmode = l:selectmode
            call setpos('.', a:handle['v_end'])
            silent! execute "normal! \<esc>"
        endif
        let [ l:shifted_start, l:shifted_end ] = s:ShiftToCursor(getpos("'["), getpos("']"))
        call setpos("'[", l:shifted_start) | call setpos("']", l:shifted_end)
    endif
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

function s:GetDefaultRegister() abort
    silent! execute "normal! \<esc>"
    return v:register
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
