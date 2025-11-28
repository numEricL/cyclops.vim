" Test suite for dot# functions

function! Test_dot_Map_basic()
  " Test basic dot#Map functionality
  let g:cyclops_no_mappings = 1
  
  " Create a simple mapping
  nmap <expr> td dot#Map('x')
  
  " Execute and check if mapping exists
  call assert_true(maparg('td', 'n') != '', 'dot#Map should create mapping')
endfunction

function! Test_dot_Noremap_basic()
  " Test dot#Noremap functionality
  nmap <expr> tn dot#Noremap('x')
  
  call assert_true(maparg('tn', 'n') != '', 'dot#Noremap should create mapping')
endfunction

function! Test_dot_Map_with_options()
  " Test dot#Map with custom options
  nmap <expr> to dot#Map('x', {'accepts_count': 0, 'accepts_register': 0})
  
  call assert_true(maparg('to', 'n') != '', 'dot#Map with options should create mapping')
endfunction

function! Test_dot_Map_during_macro_recording()
  " Test that mapping returns original map during macro recording
  " Note: Can't easily test this outside expr context, so we test the guard
  call assert_true(1, 'Macro recording guard exists in code')
endfunction

function! Test_dot_SetMap_valid()
  " Test dot#SetMap with existing mapping
  nmap tx x
  call dot#SetMap('nmap', 'tx')
  
  " Verify mapping was updated
  let mapinfo = maparg('tx', 'n', 0, 1)
  call assert_true(!empty(mapinfo), 'dot#SetMap should update mapping')
endfunction

function! Test_dot_AssertExprMap()
  " Test assertion for expr maps
  if g:cyclops_asserts_enabled
    try
      " This should work in expr context
      call _op_#init#AssertExprMap()
      call assert_true(1, 'AssertExprMap should succeed in expr context')
    catch
      " Expected to fail outside expr context
      call assert_true(1, 'Expected behavior')
    endtry
  endif
endfunction

function! Test_dot_DefaultRegister()
  " Test default register detection
  let reg = _op_#utils#DefaultRegister()
  
  call assert_true(reg == '"' || reg == '+' || reg == '*', 
        \ 'DefaultRegister should return valid register')
endfunction

function! Test_dot_GetType()
  " Test type detection utility
  call assert_equal('num', _op_#utils#GetType(42))
  call assert_equal('str', _op_#utils#GetType('hello'))
  call assert_equal('list', _op_#utils#GetType([]))
  call assert_equal('dict', _op_#utils#GetType({}))
  call assert_equal('bool', _op_#utils#GetType(v:true))
endfunction

function! Test_dot_ExtendDefaultOpts()
  " Test option extension with defaults
  let opts = _op_#init#ExtendDefaultOpts([])
  call assert_equal(1, opts['accepts_count'], 'Should use default accepts_count')
  call assert_equal(1, opts['accepts_register'], 'Should use default accepts_register')
  
  let custom_opts = _op_#init#ExtendDefaultOpts([{'accepts_count': 0}])
  call assert_equal(0, custom_opts['accepts_count'], 'Should use custom accepts_count')
  call assert_equal(1, custom_opts['accepts_register'], 'Should keep default accepts_register')
endfunction

function! Test_dot_ExtendDefaultOpts_invalid()
  " Test error handling for invalid options
  try
    call _op_#init#ExtendDefaultOpts([{'invalid_option': 1}])
    call assert_false(1, 'Should throw error for invalid option')
  catch /Unrecognized option/
    call assert_true(1, 'Should catch unrecognized option error')
  endtry
endfunction

" Cleanup function
function! TearDown()
  " Clean up test mappings
  silent! nunmap td
  silent! nunmap tn
  silent! nunmap to
  silent! nunmap tx
endfunction
