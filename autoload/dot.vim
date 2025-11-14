"
" external dot# interface
"

let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

let s:AssertExprMap     = function('_op_#init#AssertExprMap')
let s:AssertSameRHS     = function('_op_#init#AssertSameRHS')
let s:ExtendDefaultOpts = function('_op_#init#ExtendDefaultOpts')
let s:RegisterNoremap   = function('_op_#init#RegisterNoremap')

function dot#Map(map, ...) abort range
    call s:AssertExprMap()
    let l:handle = _op_#op#StackInit()
    call _op_#op#InitCallback(l:handle, 'dot', a:map, s:ExtendDefaultOpts(a:000))
    call _op_#dot#InitCallback(l:handle)
    let &operatorfunc = '_op_#dot#ComputeMapCallback'
    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    return l:omap_esc .. 'g@' .. (mode(0) ==# 'n'? '_' : '')
endfunction

function dot#Noremap(map, ...) abort range
    call s:AssertExprMap()
    let l:map = s:RegisterNoremap(a:map)
    let l:handle = _op_#op#StackInit()
    call _op_#op#InitCallback(l:handle, 'dot', l:map, s:ExtendDefaultOpts(a:000))
    call _op_#dot#InitCallback(l:handle)
    let &operatorfunc = '_op_#dot#ComputeMapCallback'
    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    return l:omap_esc .. 'g@' .. (mode(0) ==# 'n'? '_' : '')
endfunction

function dot#SetMaps(mapping_type, maps, ...) abort range
    let l:opts_dict = a:0 ? a:1 : {}
    if type(a:maps) == v:t_list
        for l:map in a:maps
            call s:SetMap(a:mapping_type, l:map, l:opts_dict)
        endfor
    else
        call s:SetMap(a:mapping_type, a:maps, l:opts_dict)
    endif
endfunction

function s:SetMap(mapping_type, map, opts_dict) abort
    let l:noremap = (a:mapping_type =~# '\v^(no|nn|vn|xn|sno|ono|no|ino|ln|cno|tno)')

    if l:noremap
        execute a:mapping_type .. ' <expr> ' .. a:map .. ' dot#Noremap(' .. string(a:map) .. ', ' .. string(a:opts_dict) .. ')'
    else
        let l:modes = (a:mapping_type =~# '\v^(no|map)')? 'nvo' : a:mapping_type[0]
        call s:AssertSameRHS(a:map, l:modes)
        let l:create_plugmap = ''
        let l:plugmap = '<plug>(op#_'.a:mapping_type.'_'.a:map.')'
        let l:mapinfo = maparg(a:map, l:modes[0], 0, 1)
        let l:rhs = substitute(l:mapinfo['rhs'], '\V<sid>', '<snr>'.l:mapinfo['sid'].'_', '')
        let l:rhs = substitute(l:rhs, '\v(\|)@<!\|(\|)@!', '<bar>', 'g')
        let l:create_plugmap .= (l:mapinfo['noremap'])? 'noremap ' : 'map '
        let l:create_plugmap .= (l:mapinfo['buffer'])? '<buffer>' : ''
        let l:create_plugmap .= (l:mapinfo['nowait'])? '<nowait>' : ''
        let l:create_plugmap .= (l:mapinfo['silent'])? '<silent>' : ''
        let l:create_plugmap .= (l:mapinfo['expr'])? '<expr>' : ''
        let l:create_plugmap .= l:plugmap .. ' ' .. l:rhs
        execute l:create_plugmap
        execute a:mapping_type .. ' <expr> ' .. a:map .. ' dot#Map(' .. string(l:plugmap) .. ', ' .. string(a:opts_dict) .. ')'
    endif
endfunction

let &cpo = s:cpo
unlet s:cpo
