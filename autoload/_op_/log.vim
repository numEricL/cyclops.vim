let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

let s:debug_log = []

" internal api
let s:Pad = function('_op_#log#Pad')

function _op_#log#PrintScriptVars() abort range
    for l:line in execute('let g:')->split("\n")->filter('v:val =~# '.string('\v^op#'))->sort()
        echomsg 'g:'.l:line
    endfor
    for l:handle in _op_#stack#GetStack()
        if len(l:handle) == 1 && has_key(l:handle, 'stack_level')
            continue
        endif
        echomsg ' '
        call s:PrintDict(l:handle, '')
    endfor
    for [ l:op_type, l:handle ] in items(_op_#op#GetHandles())
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

function _op_#log#PrintDebugLog() abort
    for l:line in s:debug_log
        echomsg s:ToPrintable(l:line)
    endfor
endfunction

function _op_#log#Log(msg) abort
    call add(s:debug_log, strftime("%S ") .. s:Pad(string(_op_#stack#Depth()), 3) . a:msg)
endfunction

function _op_#log#Pad(value, length) abort
    let l:pad_len = a:length - strdisplaywidth(a:value)
    let l:pad = (l:pad_len > 0)? repeat(' ', l:pad_len) : ''
    return a:value . l:pad
endfunction

function _op_#log#ClearDebugLog() abort
    if !empty(s:debug_log)
        call remove(s:debug_log, 0, len(s:debug_log)-1)
    endif
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

let &cpo = s:cpo
unlet s:cpo
