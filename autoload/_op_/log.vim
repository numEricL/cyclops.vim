let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

let s:time_start = 0
let s:debug_log = []

" internal api
let s:Pad = function('_op_#log#Pad')

function _op_#log#PrintOpMaps() abort
    redir => l:output
    silent map <plug>(op#
    redir END
    let l:maps = split(l:output, "\n")
    for l:map in l:maps
        echom s:ToPrintable(l:map)
    endfor
endfunction

function _op_#log#PrintScriptVars() abort range
    for l:line in execute('let g:')->split("\n")->filter('v:val =~# ' .. string('\v^op#'))->sort()
        echomsg 'g:' .. l:line
    endfor
    for l:handle in _op_#stack#GetStack()
        if len(l:handle) == 1 && has_key(l:handle, 'stack')
            continue
        endif
        echomsg ' '
        call s:PrintDict(l:handle, '')
    endfor
    for [ l:handle_type, l:handle ] in items(_op_#op#GetHandles())
        if !empty(l:handle)
            echomsg ' '
            call s:PrintDict(l:handle, '[' .. l:handle_type .. ']')
        endif
    endfor
    if !empty(_op_#stack#GetException())
        echomsg ' '
        echomsg 'stack exception: ' .. _op_#stack#GetException()
        echomsg _op_#stack#GetThrowpoint()
    endif
    echomsg ' '
endfunction

function _op_#log#PrintDebugLog() abort
    for l:line in s:debug_log
        echomsg s:ToPrintable(l:line)
    endfor
endfunction

function _op_#log#Log(...) abort
    if g:cyclops_debug_log_enabled
        let l:stack_level = (_op_#stack#Depth())? string(_op_#stack#Depth()-1) : '-'
        let l:prefix = s:Pad(l:stack_level, 3)
        if has('float') " perf info
            let l:elapsed_ms = reltimefloat(reltime(s:time_start)) * 1000
            let l:elapsed = printf('%.0f', l:elapsed_ms)
            let l:prefix = s:Pad(l:elapsed, 6) .. l:prefix
        endif
        let l:pads = [24, 10]
        let l:msg = ''
        for l:i in range(a:0)
            let l:msg ..= s:Pad(a:000[l:i], get(l:pads, l:i, 0))
        endfor
        call add(s:debug_log, l:prefix .. l:msg)
    endif
endfunction

function _op_#log#Pad(value, length) abort
    let l:pad_len = a:length - strdisplaywidth(a:value)
    let l:pad = (l:pad_len > 0)? repeat(' ', l:pad_len) : ''
    return a:value .. l:pad
endfunction

function _op_#log#PModes(kind) abort
    let l:hijack = _op_#op#GetLastHijack()

    let l:hmode = empty(l:hijack['hmode'])? '-'   : l:hijack['hmode']
    let l:hmode = (l:hmode ==# 'consumed')? 'cns' : l:hmode
    let l:hmode ..= empty(l:hijack['cmd_type'])? '' : '|' .. l:hijack['cmd_type']

    if a:kind == 0
        return '(' .. mode(1) .. '|)'
    elseif a:kind == 1
        return '(|' .. l:hmode .. ')'
    elseif a:kind == 2
        return '(' .. mode(1) .. '|' .. l:hmode .. ')'
    else
        call _op_#op#Throw('Invalid PModes kind ' .. string(a:kind))
    endif
endfunction

function _op_#log#InitDebugLog() abort
    let s:time_start = reltime()
    if !empty(s:debug_log)
        call remove(s:debug_log, 0, len(s:debug_log)-1)
    endif
endfunction

function s:PrintDict(dict, prefix) abort
    let l:stack_prefix = has_key(a:dict, 'stack') ? '[stack' .. a:dict['stack']['level'] .. ']' : ''
    let l:prefix = l:stack_prefix .. a:prefix
    for l:key in a:dict->keys()->sort()
        if type(a:dict[l:key]) == v:t_dict
            call s:PrintDict(a:dict[l:key], l:prefix .. '[' .. l:key .. ']')
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
    elseif type(a:value) == v:t_list
        call map(l:value, 's:ToPrintable(v:val)')
    endif

    if a:key ==# 'inputs'
        let l:value = '[' .. join(l:value, ', ') .. ']'
    endif
    return l:value
endfunction

function s:ToPrintable(value) abort
    if type(a:value) != v:t_string
        return a:value
    endif
    let l:ctrl_names = [
                \ '<NUL>', '<C-A>', '<C-B>', '<C-C>', '<C-D>', '<C-E>', '<C-F>', '<C-G>',
                \ '<BS>' , '<TAB>', '<NL>' , '<C-K>', '<C-L>', '<CR>' , '<C-N>', '<C-O>',
                \ '<C-P>', '<C-Q>', '<C-R>', '<C-S>', '<C-T>', '<C-U>', '<C-V>', '<C-W>',
                \ '<C-X>', '<C-Y>', '<C-Z>', '<ESC>', '<FS>' , '<GS>' , '<RS>' , '<US>' ,
                \ ]
    let l:value = a:value
    let l:value = substitute(l:value, "\<plug>", '<plug>', 'g')
    let l:value = substitute(l:value, "\<cmd>" , '<cmd>' , 'g')
    let l:value = substitute(l:value, "\<bs>"  , '<bs>'  , 'g')
    let l:value = substitute(l:value, _op_#op#GetProbe(), '<PROBE>', 'g')
    " <PROBE> adds 3 <esc>
    let l:value = substitute(l:value, '\v' .. "\<esc>" .. '{' .. (g:cyclops_max_trunc_esc - 3) .. ',}$', '<esc>...', '')
    let l:output = ''
    for l:char in split(l:value, '\zs')
        let l:nr = char2nr(l:char)
        let l:output ..= (l:nr < 32)? l:ctrl_names[l:nr] : l:char
    endfor
    return l:output
endfunction

let &cpo = s:cpo
unlet s:cpo
