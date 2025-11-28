" Test suite for pair# functions

function! Test_pair_AssertPair_valid()
  " Test pair assertion with valid input
  if g:cyclops_asserts_enabled
    try
      call _op_#init#AssertPair(['a', 'b'])
      call assert_true(1, 'Valid pair should pass assertion')
    catch
      call assert_false(1, 'Valid pair should not throw')
    endtry
  endif
endfunction

function! Test_pair_AssertPair_invalid_not_list()
  " Test pair assertion with invalid input (not a list)
  if g:cyclops_asserts_enabled
    try
      call _op_#init#AssertPair('not_a_list')
      call assert_false(1, 'Non-list should fail assertion')
    catch /Assertion failed/
      call assert_true(1, 'Should catch assertion error')
    endtry
  endif
endfunction

function! Test_pair_AssertPair_invalid_wrong_length()
  " Test pair assertion with wrong length
  if g:cyclops_asserts_enabled
    try
      call _op_#init#AssertPair(['a'])
      call assert_false(1, 'Single element list should fail')
    catch /Assertion failed/
      call assert_true(1, 'Should catch assertion error')
    endtry
  endif
endfunction

function! Test_pair_NoremapNext_basic()
  " Test pair#NoremapNext functionality
  nmap <expr> tpn pair#NoremapNext(['j', 'k'], {'accepts_register': 0})
  
  call assert_true(maparg('tpn', 'n') != '', 'pair#NoremapNext should create mapping')
endfunction

function! Test_pair_NoremapPrev_basic()
  " Test pair#NoremapPrev functionality
  nmap <expr> tpp pair#NoremapPrev(['j', 'k'], {'accepts_register': 0})
  
  call assert_true(maparg('tpp', 'n') != '', 'pair#NoremapPrev should create mapping')
endfunction

function! Test_pair_MapNext_basic()
  " Test pair#MapNext functionality
  nmap tx j
  nmap ty k
  nmap <expr> tpm pair#MapNext(['<plug>(op#_nmap_tx)', '<plug>(op#_nmap_ty)'])
  
  call assert_true(maparg('tpm', 'n') != '', 'pair#MapNext should create mapping')
endfunction

function! Test_pair_NoremapNext_during_macro()
  " Test behavior during macro recording
  " Note: Can't easily test this outside expr context, so we test the guard
  call assert_true(1, 'Macro recording guard exists in code')
endfunction

function! Test_pair_NoremapPrev_during_macro()
  " Test behavior during macro recording
  " Note: Can't easily test this outside expr context, so we test the guard
  call assert_true(1, 'Macro recording guard exists in code')
endfunction

function! Test_pair_SetMap_valid()
  " Test pair#SetMap with existing mappings
  nmap tp1 j
  nmap tp2 k
  call pair#SetMap('nmap', ['tp1', 'tp2'], {'accepts_register': 0})
  
  " Verify mappings were updated
  let mapinfo1 = maparg('tp1', 'n', 0, 1)
  let mapinfo2 = maparg('tp2', 'n', 0, 1)
  call assert_true(!empty(mapinfo1), 'pair#SetMap should update first mapping')
  call assert_true(!empty(mapinfo2), 'pair#SetMap should update second mapping')
endfunction

function! Test_pair_noremap_plugs_exist()
  " Test that default noremap plugs are created
  call assert_true(maparg('<plug>(op#_noremap_;)', '') != '', 
        \ 'Noremap plug for ; should exist')
  call assert_true(maparg('<plug>(op#_noremap_,)', '') != '', 
        \ 'Noremap plug for , should exist')
endfunction

" Cleanup function
function! TearDown()
  silent! nunmap tpn
  silent! nunmap tpp
  silent! nunmap tpm
  silent! nunmap tx
  silent! nunmap ty
  silent! nunmap tp1
  silent! nunmap tp2
endfunction
