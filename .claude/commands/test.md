# Run Flutter Tests

Run the project tests:

```bash
flutter test $ARGUMENTS
```

If no arguments provided, run all tests. Arguments can be a specific test file path like `test/core/network/token_storage_test.dart`.

If tests fail:
1. Read the failing test file
2. Read the source file being tested
3. Analyze the failure and suggest a fix
