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
    for [ l:name, l:handle ] in items(s:handles)
        if !empty(l:handle)
            echomsg ' '
            for l:key in l:handle->keys()->sort()
                let l:level = (get(l:handle, 'stack_level') > 0)? l:handle['stack_level'] : ''
                echomsg l:name.l:level.':' l:key repeat(' ', 20-strdisplaywidth(l:key)) l:handle[l:key]
            endfor
        endif
    endfor
    echomsg ' '
    echomsg 'has map to <plug>(op#dot)        ' hasmapto('<plug>(op#dot)')
    echomsg 'has map to <plug>(op#visual_dot) ' hasmapto('<plug>(op#visual_dot)')
    nmap .
    vmap .
    echomsg ' '
    for l:line in execute('let s:')->split("\n")->filter('v:val !~# '.string('\v(handles|stack)'))->sort()
        echomsg l:line
    endfor
endfunction

function op#Command(command, ...) abort range
    return s:InitCallback('norepeat', 'command', a:command, 0, (a:0>=1? !empty(a:1) : 0), (a:0>=2? !empty(a:2) : 0), (a:0>=3? !empty(a:3) : 0), (a:0>=4? !empty(a:4) : 0), 0)
endfunction

function op#Map(map, ...) abort range
    return s:InitCallback('norepeat', 'map', a:map, 0, (a:0>=1? !empty(a:1) : 0), (a:0>=2? !empty(a:2) : 1), (a:0>=3? !empty(a:3) : 0), (a:0>=4? !empty(a:4) : 0), (a:0>=5? !empty(a:5) : !empty(g:op#operators_consume_typeahead)))
endfunction

function op#Noremap(map, ...) abort range
    execute 'noremap' s:MapName('noremap', a:map, 0) a:map
    return s:InitCallback('norepeat', 'map', s:MapName('noremap', a:map, 1), 0, (a:0>=1? !empty(a:1) : 1), (a:0>=2? !empty(a:2) : 0), (a:0>=3? !empty(a:3) : 0), (a:0>=4? !empty(a:4) : 0), (a:0>=5? !empty(a:5) : !empty(g:op#operators_consume_typeahead)))
endfunction

" let s:map_name_count = 0
function s:MapName(mode, map, expanded) abort
    " if a:map =~# '\W'
    "     let s:map_name_count = exists('s:map_name_count')? s:map_name_count+1 : 1
    "     let l:map = '#'.s:map_name_count.'_'.substitute(a:map, '\W', '?', 'g')
    " else
    "     let l:map = a:map
    " endif
    return (a:expanded? "\<plug>" : '<plug>').'(Op#_'.a:mode.'_'.a:map.')'
endfunction

function s:InitCallback(name, type, expr, id, accepts_count, accepts_register, shift_marks, stay_in_visual, input_source) abort
    let l:handle = s:StartStack()
    call extend(l:handle, { 'name': a:name, 'type': a:type, 'expr': a:expr, 'expr_so_far': '', 'input_source': (a:input_source? 'typeahead': 'user') })
    call extend(l:handle, { 'shift_marks': a:shift_marks, 'accepts_count': a:accepts_count, 'accepts_register' : a:accepts_register })
    call extend(l:handle, { 'entry_mode': mode(1), 'cur_pos': getcurpos(), 'count1': v:count1, 'register': v:register })
    call extend(l:handle, { 'stay_in_visual': a:stay_in_visual })

    if l:handle['name'] ==# 'pair'
        call extend(l:handle, { 'pair': a:expr, 'expr': a:expr[a:id], 'pair_init_id': a:id, 'pair_state': ['invalid', 'invalid'] })
    endif
    if l:handle['entry_mode'] !~# '\v^(n|v|V||s|S||no|nov|noV|no)$'
        throw 'cyclops.vim: Entry mode '.string(mode(1)).' not yet supported. Please make a request at https://github.com/numericl/cyclops.vim/issues'
    endif
    if l:handle['entry_mode'] =~# '\v^(n|v|V||s|S|)$'
        let l:handle['called_from'] = 'initialization'
        call s:AssertExprMap(l:handle)
        if a:name ==# 'dot'
            let &operatorfunc = s:SID().'Callback'
            return s:ExprMapReturn('g@'.(l:handle['entry_mode'] ==# 'n'? '_' : ''))
        else
            return s:ExprMapReturn(":\<c-u>call ".s:SID()."Callback(".string('').', '.string('stack').")\<cr>")
        endif
    elseif l:handle['entry_mode'] =~# '\v^no.=$'
        let l:handle['called_from'] = 'operator pending'
        if l:handle['expr'] =~# '\V'."\<plug>".'(op#_noremap_'
            return l:handle['expr']
        else
            return s:ExprMapReturn(":call ".s:SID()."OpPending()\<cr>")
        endif
    endif
endfunction

function s:Callback(dummy, ...) abort
    let l:handle = a:0? s:GetHandle(a:1) : s:GetHandle('dot')
    call extend(l:handle, { 'register_default': s:GetDefaultRegister() })
    if l:handle['entry_mode'] =~# '\v^[vV]$' && mode(1) !=# l:handle['entry_mode']
        let l:selectmode = &selectmode | set selectmode=
        silent! execute "normal! \<esc>gv"
        let &selectmode = l:selectmode
    elseif l:handle['entry_mode'] =~# '\v^[sS]$' && mode(1) !=# l:handle['entry_mode']
        call setpos('.', l:handle['cur_pos'])
        let l:char = l:mode ==# 's'? 'h' : (l:mode ==# 'S'? 'H' : '')
        silent! execute "normal! \<esc>g".l:char
    elseif l:handle['entry_mode'] ==# 'n' && mode(1) !=# l:handle['entry_mode']
        call setpos('.', l:handle['cur_pos'])
        silent! execute "normal! \<esc>"
    endif

    if l:handle['stack_start']
        call s:ExecuteAndRestoreOnFail(l:handle)
    else
        call s:ExecuteExpr(l:handle)
    endif
    if l:handle['stay_in_visual'] && mode(1) ==# 'n' && l:handle['entry_mode'] =~# '\v^[vV]$'
        let l:cur_pos = getcurpos()
        silent! execute "normal! \<esc>gv"
        call setpos('.', l:cur_pos)
    endif
    call s:FinishStack(l:handle)
    let &operatorfunc = a:0? &operatorfunc : s:SID().'Callback'
    echo
endfunction

function s:OpPending() abort
    let l:start_pos = getcurpos()
    let l:handle = s:GetHandle('op_pending')
    call s:ExecuteAndRestoreOnFail(l:handle)
    call s:FinishStack(l:handle)
    let l:end_pos = getcurpos()

    if l:handle['entry_mode'] ==# 'no'
        let l:op_mode = ( l:start_pos[1] == l:end_pos[1] )? 'v' : 'V'
    elseif l:handle['entry_mode'] =~# '\v^no.$'
        let l:op_mode = l:handle['entry_mode'][2]
    endif
    call setpos('.', l:start_pos)
    silent execute "normal! \<esc>".l:op_mode
    call setpos('.', l:end_pos)
endfunction

function s:ExecuteAndRestoreOnFail(handle) abort
    let l:state = s:SaveState(a:handle)
    try
        call s:ExecuteExpr(a:handle)
    catch /^op#abort$/
        call s:RestoreState(a:handle, l:state)
    endtry
    if has_key(a:handle, 'error_log')
        echohl ErrorMsg | echomsg a:handle['error_log'][0] | echohl None
        echohl ErrorMsg | echomsg a:handle['error_log'][1] | echohl None
        call remove(a:handle, 'error_log')
        echoerr 'cyclops.vim: Error detected, see messages'
    endif
endfunction

function s:ExecuteExpr(handle) abort
    if a:handle['called_from'] =~# '\v^(initialization|pair initialization)$'
        if a:handle['type'] ==# 'command'
            call s:ExecuteCommand(a:handle)
        elseif a:handle['type'] ==# 'map'
            call s:ExecuteMapOnStack(a:handle)
        endif
    elseif a:handle['called_from'] ==# 'operator pending'
        if a:handle['type'] ==# 'command'
            call s:ExecuteCommand(a:handle)
        elseif a:handle['type'] ==# 'map'
            call s:ExecuteMap(a:handle, s:AddModifiers(a:handle, a:handle['expr']), 'x')
        endif
    elseif a:handle['called_from'] =~# '\v^(repeat|visual repeat)$'
        call s:ExecuteMap(a:handle, s:AddModifiers(a:handle, a:handle['expr']), 'x')
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
        call s:ExecuteMap(a:handle, a:handle['expr'], 'x')
        if a:handle['stack_start']
            call s:RestoreState(a:handle, l:state)
            call s:ExecuteMap(a:handle, s:AddModifiers(a:handle, a:handle['expr']), 'x')
        else
            call s:UpdateParentCall(a:handle)
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
    if a:handle['called_from'] ==# 'operator pending'
        return
    endif
    call extend(a:handle, { 'hijack_mode': 'no', 'hijack_stream': get(a:handle, 'ambiguous_map', '') })
    let [ l:expr, l:state ] = [ a:handle['expr'], s:SaveState(a:handle) ]
    let a:handle['expr'] = l:expr.a:handle['hijack_stream']
    call s:ExecuteHijack(a:handle, a:handle['expr'])
    if a:handle['input_source'] ==# 'input_cache' && a:handle['hijack_mode'] =~# '\v^(no.=|i|c)$'
        let a:handle['expr'] = l:expr .. remove(a:handle['input_cache'], 0)
        return
    elseif a:handle['hijack_mode'] =~# '\m^no'
        while a:handle['hijack_mode'] =~# '\m^no'
            call s:UpdateHijackStream(a:handle, s:GetChar(a:handle))
            let a:handle['expr'] = l:expr.a:handle['hijack_stream']
            call s:ExecuteHijack(a:handle, a:handle['expr'])
        endwhile
    elseif a:handle['hijack_mode'] ==# 'i'
        let l:char = s:UpdateHijackStream(a:handle, s:GetChar(a:handle))
        execute "normal! a".l:char
        while l:char != "\<esc>"
            let l:char = s:UpdateHijackStream(a:handle, s:GetChar(a:handle))
            execute "normal! a".l:char
        endwhile
        let a:handle['expr'] = l:expr.a:handle['hijack_stream']
        call s:ExecuteHijack(a:handle, a:handle['expr'])
    elseif a:handle['hijack_mode'] ==# 'c' || a:handle['hijack_cmd_type'] =~# '\v^[:/?]$'
        call extend(a:handle, { 'hijack_cmd': s:hijack_cmd, 'hijack_cmd_type': s:hijack_cmd_type })
        let l:char = s:UpdateHijackStream(a:handle, s:GetChar(a:handle))
        while l:char != "\<cr>"
            let l:char = s:UpdateHijackStream(a:handle, s:GetChar(a:handle))
        endwhile
        call setpos('.', a:handle['cur_pos'])
        let a:handle['expr'] = l:expr.a:handle['hijack_stream']
        call s:ExecuteHijack(a:handle, a:handle['expr'])
    endif
    if !empty(a:handle['hijack_stream'])
        let l:root = s:GetRootHandle()
        if !has_key(l:root, 'input_cache')
            call extend(l:root, {'input_cache': []})
        endif
        call add(l:root['input_cache'], a:handle['hijack_stream'])
    endif
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
    else
        let a:handle['hijack_stream'] .= l:char
    endif
    return l:char
endfunction

function s:ExecuteHijack(handle, cmd) abort
    " hijack mode: feedkeys with 'x' fills typeahead with endless <esc> in order
    " to exit insert mode, whereas 'x!' does not fill the typeahead. In Hijack
    " mode we still want to to return to normal mode, but in a controlled
    " manner. Hijack mode adds g:op#max_input_size many <esc> to typeahead.
    let [ s:hijack_mode, s:hijack_cmd, s:hijack_cmd_type ] = [ 'NULL', 'NULL', 'NULL' ]
    let l:belloff = &belloff
    set belloff+=error,esc
    try
        call s:ExecuteMap(a:handle, a:cmd.'×'.repeat("\<esc>", g:op#max_input_size), 'x!')
    catch /^op#abort$/
        if a:handle['abort'] ==# 'error'
            unlet a:handle['abort'] a:handle['error_log']
        endif
    endtry
    let &belloff = l:belloff
    let a:handle['hijack_mode'] = (s:hijack_mode !=# 'NULL')? s:hijack_mode : a:handle['hijack_mode']
    let a:handle['hijack_cmd'] = (s:hijack_cmd !=# 'NULL')? s:hijack_cmd : ''
    let a:handle['hijack_cmd_type'] = (s:hijack_cmd_type !=# 'NULL')? s:hijack_cmd_type : ''
    if has_key(a:handle, 'abort')
        throw 'op#abort'
    endif
endfunction

" Some plugins may consume the RHS and start executing, use something unusual
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

function s:SetParentCall(handle) abort
    " parent (up to this point) is the set complement of previous expr and current typeahead (less the hijack junk)
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

function s:UpdateParentCall(handle) abort
    let l:parent_handle = s:GetParentHandle(a:handle)
    let l:update_pattern = '\V'.escape(l:parent_handle['expr_so_far'], '\').'\zs'.escape(a:handle['parent_call'], '\')
    let l:update = substitute(l:parent_handle['expr'], l:update_pattern, escape(a:handle['expr'], '\'), '')
    if l:update ==# l:parent_handle['expr']
        throw 'cyclops.vim: Unexpected error while updating parent call'
    endif
    let l:parent_handle['expr'] = l:update
    let l:parent_handle['expr_so_far'] .= a:handle['expr']
endfunction

function s:ExecuteCommand(handle) abort
    call s:PushStack()
    call s:ResetVCount(a:handle)
    try
        execute s:AddModifiers(a:handle, a:handle['expr'])
        call s:PopStack()
    catch /^op#abort$/
        let a:handle['abort'] = get(a:handle, 'abort', 'graceful')
    catch
        let a:handle['abort'] = 'error'
        call s:LogError(a:handle, a:handle['expr_with_modifiers'])
    endtry
    if has_key(a:handle, 'abort')
        throw 'op#abort'
    endif
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
        echo 'Operator Input:' a:handle['hijack_stream']
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
        if a:handle['hijack_cmd_type'] =~# '\v[/?]' && &incsearch
            nohlsearch
            call setpos('.', a:handle['cur_pos'])
            if !empty(a:handle['hijack_stream'])
                silent! call add(l:match_ids, matchadd('Search', a:handle['hijack_stream']))
                silent! call search(a:handle['hijack_stream'], a:handle['hijack_cmd_type'] == '/'? '' : 'b')
                redraw
            endif
        endif
        echo a:handle['hijack_cmd_type'].a:handle['hijack_cmd'].a:handle['hijack_stream']
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

function s:ExecuteMap(handle, cmd, mode) abort
    call s:PushStack()
    let [ l:timeout, l:timeoutlen ] = [ &timeout, &timeoutlen ]
    set timeout timeoutlen=0
    try
        call feedkeys(a:cmd, a:mode)
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
            throw 'cyclops.vim: Unexpected error while reading typeahead:'
        endif
    endwhile
    return l:typeahead
endfunction

function s:AssertExprMap(handle) abort
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
        throw 'cyclops.vim: Error while processing '.string(a:handle['expr']).'. <expr> map
                    \ must be used for this plugin. To disable this check
                    \ (and likely break dot repeating) set g:op#disable_expr_assert'
    endif
endfunction

function s:ExprMapReturn(cmd) abort
    try " throws if in <expr> map
        execute "normal! ".a:cmd
        return ''
    catch /^Vim\%((\a\+)\)\=:E523:/
        return a:cmd
    endtry
endfunction

function s:LogError(handle, expr) abort
    let a:handle['error_log'] = [ 'Error detected while processing '.a:expr.' at '.v:throwpoint, v:exception ]
endfunction

function s:AddModifiers(handle, expr) abort
    let a:handle['expr_with_modifiers'] = a:expr
    if a:handle['accepts_register'] && a:handle['register'] != a:handle['register_default']
        if a:handle['type'] ==# 'command'
            let a:handle['expr_with_modifiers'] = a:handle['expr_with_modifiers'] a:handle['register']
        else
            let a:handle['expr_with_modifiers'] = '"'.a:handle['register'].a:handle['expr_with_modifiers']
        endif
    endif
    if a:handle['accepts_count'] && a:handle['count1'] != 1
        let a:handle['expr_with_modifiers'] = a:handle['count1'].a:handle['expr_with_modifiers']
    elseif !a:handle['accepts_count'] && a:handle['type'] =~# '\v^(map|noremap)$'
        let a:handle['expr_with_modifiers'] = repeat(a:handle['expr_with_modifiers'], a:handle['count1'])
    endif
    return a:handle['expr_with_modifiers']
endfunction

function s:ResetVCount(handle) abort
    let l:cur_pos = getcurpos()
    silent! execute ":normal! \<esc>".a:handle['count1']."|"
    call setpos('.', l:cur_pos)
endfunction

function s:GetHandle(name) abort
    if a:name =~# '\v^(dot|op_pending)$' && !empty(s:stack) && !has_key(s:stack[-1], 'abort')
        return s:stack[-1]
    else
        return (a:name ==# 'stack')? s:stack[-1] : s:handles[a:name]
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

function s:FinishStack(handle) abort
    if !a:handle['stack_start']
        return
    endif

    let [ l:win, l:mode ] = [ winsaveview(), mode(1) ]
    let l:selectmode = &selectmode | set selectmode=
    silent! execute "normal! \<esc>gv"
    let &selectmode = l:selectmode
    let [ l:v_mode, l:v_start, l:v_end ] = [ visualmode(), getpos('v'), getpos('.') ]
    call extend(a:handle, {'v_mode': visualmode(), 'v_start': getpos('v'), 'v_end': getpos('.')} )
    if l:mode ==# 'n'
        silent! execute "normal! \<esc>"
        call winrestview(l:win)
    elseif l:mode !~# '\v^[vV]$'
        throw 'cyclops.vim: Exit mode '.string(l:mode).' not yet supported. Please make a request at https://github.com/numericl/cyclops.vim/issues'
    endif

    unlet! s:hijack_cmd s:hijack_cmd_type s:hijack_mode
    if a:handle['called_from'] =~# '\v^(initialization|pair initialization)$'
        let s:handles[a:handle['name']] = deepcopy(a:handle)
    elseif a:handle['called_from'] ==# 'operator pending'
        let s:handles['op_pending'] = deepcopy(a:handle)
    endif
    call s:PopStack()
endfunction

function s:PushStack() abort
    call add(s:stack, {'stack_start': 0, 'stack_level': len(s:stack)})
    return
endfunction

function s:PopStack() abort
    if len(s:stack) > 0
        call remove(s:stack, -1)
    endif
endfunction

function s:InitRepeat(handle, count, register, mode) abort
    if a:mode ==# 'normal'
        call extend(a:handle, { 'called_from': 'repeat', 'cur_pos': getcurpos() })
    elseif a:mode ==# 'visual'
        let l:selectmode = &selectmode | set selectmode=
        silent! execute "normal! \<esc>gv"
        let &selectmode = l:selectmode
        call extend(a:handle, { 'called_from': 'visual repeat', 'cur_pos': getcurpos() })
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

function s:ShiftToCursor(start_pos, end_pos) abort
    let l:cur_pos = getcurpos()
    let l:shifted_lnr = l:cur_pos[1]+(a:end_pos[1]-a:start_pos[1])
    let l:shifted_pos = s:GetScreenPos(l:shifted_lnr, s:GetScreenCol(l:cur_pos)+s:GetScreenCol(a:end_pos)-s:GetScreenCol(a:start_pos))
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

let &cpo = s:cpo
unlet s:cpo
