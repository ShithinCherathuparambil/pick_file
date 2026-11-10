# Contributing to pick_file

Thank you for your interest in contributing to `pick_file`!

## Development Setup

1. Fork and clone the repository.
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Generate Pigeon platform bindings if modifying `pigeons/messages.dart`:
   ```bash
   dart run pigeon --input pigeons/messages.dart
   ```
4. Run static analysis:
   ```bash
   flutter analyze
   ```
5. Run unit tests:
   ```bash
   flutter test
   ```

## Pull Request Guidelines

- Ensure all existing and new unit tests pass.
- Format all Dart code with `dart format .`.
- Avoid adding third-party picker or storage dependencies.
- Update documentation and examples when adding new features or modifying behavior.
