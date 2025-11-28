# cyclops.vim Tests

This directory contains unit tests for cyclops.vim.

## Running Tests

There are several ways to run the tests:

### Using the shell script (recommended)

```bash
./test/run.sh
```

### Using Make

```bash
make test
```

### Using Vim directly

```bash
vim -Nu test/run_tests.vim
```

### Running a specific test file

```bash
vim -Nu test/run_tests.vim -c "source test/test_dot.vim"
```

## Test Structure

The test suite is organized into the following files:

- **test_dot.vim** - Tests for `dot#` functions (dot repeat functionality)
- **test_pair.vim** - Tests for `pair#` functions (pair repeat with `;` and `,`)
- **test_op.vim** - Tests for `op#` functions (operator functionality)
- **test_utils.vim** - Tests for utility functions
- **test_settings.vim** - Tests for settings and initialization
- **test_integration.vim** - Integration tests combining multiple features
- **run_tests.vim** - Test runner that executes all tests

## Writing Tests

Test functions should:

1. Start with `Test_` prefix (e.g., `Test_dot_Map_basic`)
2. Use `call assert_*()` functions for assertions
3. Clean up any resources in a `TearDown()` function if needed
4. Be independent and not rely on other test execution order

### Example Test

```vim
function! Test_my_feature()
  " Setup
  let expected = 'result'
  
  " Execute
  let actual = MyFunction()
  
  " Assert
  call assert_equal(expected, actual, 'MyFunction should return expected value')
endfunction

function! TearDown()
  " Clean up resources
  silent! nunmap my_mapping
endfunction
```

## Available Assertions

Vim provides these assertion functions:

- `assert_true(actual, msg)` - Assert value is true
- `assert_false(actual, msg)` - Assert value is false
- `assert_equal(expected, actual, msg)` - Assert values are equal
- `assert_notequal(expected, actual, msg)` - Assert values are not equal
- `assert_match(pattern, actual, msg)` - Assert pattern matches
- `assert_notmatch(pattern, actual, msg)` - Assert pattern doesn't match
- `assert_fails(command, error, msg)` - Assert command fails with error

## Test Coverage

The test suite covers:

- ✓ Basic mapping creation (dot, pair, op)
- ✓ Noremap variants
- ✓ Custom options handling
- ✓ Macro recording detection
- ✓ SetMap functions
- ✓ Assertions and error handling
- ✓ Utility functions
- ✓ Settings and initialization
- ✓ Integration scenarios
- ✓ Visual mode support

## Continuous Integration

To run tests in a CI environment:

```bash
# Exit with non-zero code on test failure
vim -Nu test/run_tests.vim || exit 1
```
