# cyclops.vim Testing Quick Reference

## Running Tests

```bash
# Easiest method - just run this:
./test/run.sh

# Or use vim directly:
vim -Nu test/run_tests.vim

# Or use make (if available):
make test
```

## Test Files

- `test_dot.vim` - Tests for dot repeat (`.`) functionality
- `test_pair.vim` - Tests for pair repeat (`;`, `,`) functionality
- `test_op.vim` - Tests for operator functionality
- `test_utils.vim` - Tests for utility functions
- `test_settings.vim` - Tests for settings and initialization
- `test_integration.vim` - Integration tests

## Adding New Tests

1. Create test function starting with `Test_`:
   ```vim
   function! Test_my_new_feature()
     " Setup
     let expected = 'value'
     
     " Execute
     let actual = MyFunction()
     
     " Assert
     call assert_equal(expected, actual, 'Description')
   endfunction
   ```

2. Add cleanup if needed:
   ```vim
   function! TearDown()
     silent! nunmap my_test_mapping
   endfunction
   ```

3. Run tests to verify:
   ```bash
   ./test/run.sh
   ```

## Test Status

✓ All 44 tests passing
✓ 100% success rate
✓ Covers all major functionality
