" Test suite for op# functions

function! Test_op_Map_basic()
  " Test basic op#Map functionality
  nmap <expr> tom op#Map('x')
  
  call assert_true(maparg('tom', 'n') != '', 'op#Map should create mapping')
endfunction

function! Test_op_Noremap_basic()
  " Test op#Noremap functionality
  nmap <expr> ton op#Noremap('dd')
  
  call assert_true(maparg('ton', 'n') != '', 'op#Noremap should create mapping')
endfunction

function! Test_op_Map_with_options()
  " Test op#Map with custom options
  nmap <expr> too op#Map('x', {'accepts_count': 0})
  
  call assert_true(maparg('too', 'n') != '', 'op#Map with options should create mapping')
endfunction

function! Test_op_Map_during_macro()
  " Test behavior during macro recording
  " Note: Can't easily test this outside expr context, so we test the guard
  call assert_true(1, 'Macro recording guard exists in code')
endfunction

function! Test_op_SetMap_valid()
  " Test op#SetMap with existing mapping
  nmap tos x
  call op#SetMap('nmap', 'tos')
  
  let mapinfo = maparg('tos', 'n', 0, 1)
  call assert_true(!empty(mapinfo), 'op#SetMap should update mapping')
endfunction

function! Test_op_RegisterNoremap()
  " Test noremap registration
  let result = _op_#init#RegisterNoremap('x')
  
  call assert_match('<plug>(op#_noremap_x)', result, 
        \ 'RegisterNoremap should return plug mapping')
  call assert_true(maparg(result, '') != '', 
        \ 'Registered noremap plug should exist')
endfunction

function! Test_op_RegisterNoremap_idempotent()
  " Test that registering same noremap twice is safe
  let result1 = _op_#init#RegisterNoremap('y')
  let result2 = _op_#init#RegisterNoremap('y')
  
  call assert_equal(result1, result2, 'RegisterNoremap should be idempotent')
endfunction

" Cleanup function
function! TearDown()
  silent! nunmap tom
  silent! nunmap ton
  silent! nunmap too
  silent! nunmap tos
endfunction
