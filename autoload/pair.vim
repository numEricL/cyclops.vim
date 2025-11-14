noremap <silent> <plug>(op#_noremap_;) ;
noremap <silent> <plug>(op#_noremap_,) ,
"
" external pair# interface
"

let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

let s:AssertExprMap     = function('_op_#init#AssertExprMap')
let s:AssertSameRHS     = function('_op_#init#AssertSameRHS')
let s:ExtendDefaultOpts = function('_op_#init#ExtendDefaultOpts')
let s:RegisterNoremap   = function('_op_#init#RegisterNoremap')

function pair#MapNext(pair, ...) abort range
    call s:AssertExprMap()
    let l:handle = _op_#op#StackInit()
    call _op_#op#InitCallback(l:handle, 'pair', a:pair[0], s:ExtendDefaultOpts(a:000))
    call _op_#pair#Initcallback(l:handle, a:pair, 'next')
    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    return l:omap_esc .. "\<cmd>call _op_#pair#ComputeMapCallback()\<cr>"
endfunction

function pair#MapPrev(pair, ...) abort range
    call s:AssertExprMap()
    let l:handle = _op_#op#StackInit()
    call _op_#op#InitCallback(l:handle, 'pair', a:pair[1], s:ExtendDefaultOpts(a:000))
    call _op_#pair#Initcallback(l:handle, a:pair, 'prev')
    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    return l:omap_esc .. "\<cmd>call _op_#pair#ComputeMapCallback()\<cr>"
endfunction

function pair#NoremapNext(pair, ...) abort range
    call s:AssertExprMap()
    let l:pair = s:RegisterNoremapPair(a:pair)
    let l:handle = _op_#op#StackInit()
    call _op_#op#InitCallback(l:handle, 'pair', l:pair[0], s:ExtendDefaultOpts(a:000))
    call _op_#pair#Initcallback(l:handle, l:pair, 'next')
    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    return l:omap_esc .. "\<cmd>call _op_#pair#ComputeMapCallback()\<cr>"
endfunction

function pair#NoremapPrev(pair, ...) abort range
    call s:AssertExprMap()
    let l:pair = s:RegisterNoremapPair(a:pair)
    let l:handle = _op_#op#StackInit()
    call _op_#op#InitCallback(l:handle, 'pair', l:pair[1], s:ExtendDefaultOpts(a:000))
    call _op_#pair#Initcallback(l:handle, l:pair, 'prev')
    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    return l:omap_esc .. "\<cmd>call _op_#pair#ComputeMapCallback()\<cr>"
endfunction

function pair#SetMaps(mapping_type, pairs, ...) abort range
    let l:opts_dict = a:0 ? a:1 : {}
    if type(a:pairs[0]) == v:t_list
        for l:pair in a:pairs
            call s:SetMap(a:mapping_type, l:pair, l:opts_dict)
        endfor
    else
        call s:SetMap(a:mapping_type, a:pairs, l:opts_dict)
    endif
endfunction

function s:SetMap(mapping_type, pair, opts) abort
    let l:noremap = (a:mapping_type =~# '\v^(no|nn|vn|xn|sno|ono|no|ino|ln|cno|tno)')


    if l:noremap
        execute a:mapping_type .. ' <expr> ' .. a:pair[0] .. ' pair#NoremapNext(' .. string(a:pair[0]) .. ', ' .. string(a:opts_dict) .. ')'
        execute a:mapping_type .. ' <expr> ' .. a:pair[1] .. ' pair#NoremapPrev(' .. string(a:pair[1]) .. ', ' .. string(a:opts_dict) .. ')'
    else
        let l:modes = (a:mapping_type =~# '\v^(no|map)')? 'nvo' : a:mapping_type[0]
        let l:plugpair = ['', '']
        for l:id in range(2)
            call s:AssertSameRHS(a:pair[l:id], l:modes)
            let l:create_plugmap = ''
            let l:plugpair[l:id] = '<plug>(op#_'.a:mapping_type.'_'.a:pair[l:id].')'
            let l:mapinfo = maparg(a:pair[l:id], l:modes[0], 0, 1)
            let l:rhs = substitute(l:mapinfo['rhs'], '\V<sid>', '<snr>'.l:mapinfo['sid'].'_', '')
            let l:rhs = substitute(l:rhs, '\v(\|)@<!\|(\|)@!', '<bar>', 'g')
            let l:create_plugmap .= (l:mapinfo['noremap'])? 'noremap ' : 'map '
            let l:create_plugmap .= (l:mapinfo['buffer'])? '<buffer>' : ''
            let l:create_plugmap .= (l:mapinfo['nowait'])? '<nowait>' : ''
            let l:create_plugmap .= (l:mapinfo['silent'])? '<silent>' : ''
            let l:create_plugmap .= (l:mapinfo['expr'])? '<expr>' : ''
            let l:create_plugmap .= l:plugpair[l:id] .. ' ' .. l:rhs
            execute l:create_plugmap
        endfor
        execute a:mapping_type.' <expr> '.a:pair[0].' pair#MapNext('.string(l:plugpair).', '.string(a:opts).')'
        execute a:mapping_type.' <expr> '.a:pair[1].' pair#MapPrev('.string(l:plugpair).', '.string(a:opts).')'
    endif
endfunction

function s:RegisterNoremapPair(pair) abort range
    if type(a:pair) != v:t_list || len(a:pair) != 2
        throw 'cyclops.vim: Input must be a pair of maps'
    endif
    let l:map0 = s:RegisterNoremap(a:pair[0])
    let l:map1 = s:RegisterNoremap(a:pair[1])
    return [ l:map0, l:map1 ]
endfunction

let &cpo = s:cpo
unlet s:cpo
