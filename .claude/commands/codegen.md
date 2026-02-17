# Run Code Generation

Run build_runner to generate Hive adapters and other generated code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

If there are conflicts or errors:
1. Try cleaning first: `dart run build_runner clean`
2. Then rebuild: `dart run build_runner build --delete-conflicting-outputs`
3. Analyze any remaining errors

Generated files include:
- Hive type adapters (`*.g.dart`) for models annotated with `@HiveType`
