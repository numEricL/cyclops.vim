" Test suite for utility functions

function! Test_utils_GetVisualState()
  " Test visual state capture in normal mode
  normal! v
  let state = _op_#utils#GetVisualState()
  execute "normal! \<esc>"
  
  call assert_equal(6, len(state), 'Visual state should have 6 elements')
endfunction

function! Test_utils_GetState()
  " Test state capture
  let state = _op_#utils#GetState()
  
  call assert_true(has_key(state, 'winid'), 'State should have winid')
  call assert_true(has_key(state, 'win'), 'State should have win')
  call assert_true(has_key(state, 'bufnr'), 'State should have bufnr')
  call assert_true(has_key(state, 'undo_pos'), 'State should have undo_pos')
  call assert_true(has_key(state, 'v_state'), 'State should have v_state')
endfunction

function! Test_utils_DefaultRegister_unnamed()
  " Test default register with different clipboard settings
  let old_cb = &clipboard
  set clipboard=
  
  let reg = _op_#utils#DefaultRegister()
  call assert_equal('"', reg, 'Default register should be " when clipboard is empty')
  
  let &clipboard = old_cb
endfunction

function! Test_utils_DefaultRegister_unnamedplus()
  " Test default register with unnamedplus clipboard
  if has('clipboard')
    let old_cb = &clipboard
    set clipboard=unnamedplus
    
    let reg = _op_#utils#DefaultRegister()
    call assert_equal('+', reg, 'Default register should be + with unnamedplus')
    
    let &clipboard = old_cb
  endif
endfunction

function! Test_utils_GetType_all_types()
  " Test type detection for all types
  call assert_equal('num', _op_#utils#GetType(0))
  call assert_equal('num', _op_#utils#GetType(-42))
  call assert_equal('str', _op_#utils#GetType(''))
  call assert_equal('str', _op_#utils#GetType('test'))
  call assert_equal('list', _op_#utils#GetType([]))
  call assert_equal('list', _op_#utils#GetType([1, 2, 3]))
  call assert_equal('dict', _op_#utils#GetType({}))
  call assert_equal('dict', _op_#utils#GetType({'a': 1}))
  call assert_equal('float', _op_#utils#GetType(1.5))
  call assert_equal('bool', _op_#utils#GetType(v:true))
  call assert_equal('bool', _op_#utils#GetType(v:false))
  call assert_equal('null', _op_#utils#GetType(v:null))
endfunction
