# betelsas

A new Flutter project.

## Design Compliance

All screen design images are located in the `src/mobile/guidelines/0-screens-designs` directory. The project must strictly adhere to these designs regarding colors, components, and layout. While text labels may be subject to change, the visual structure and style are definitive.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Git Hooks

This project uses Husky to enforce code quality.

- **Pre-commit**: Runs unit and widget tests (`flutter test`).
- **Pre-push**: Runs integration tests (`flutter test integration_test`).
