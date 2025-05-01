# Contributing to SimpleDialogue

Thank you for your interest in contributing to SimpleDialogue! This guide will help you get started with the development process.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/your-username/SimpleDialogue.git`
3. Set up the development environment:
   - Install [Rojo](https://rojo.space/)
   - Install [Wally](https://wally.run/)
   - Install dependencies: `wally install`

## Development Workflow

### Code Structure

SimpleDialogue is structured into several main components:

- **System**: Core dialogue system functionality
- **UI**: User interface components
- **Handlers**: Interaction handlers

### Coding Standards

Please follow these guidelines when contributing:

- Use Luau's strict type checking
- Add type annotations to functions and variables
- Document public-facing functions with comments
- Keep code modular and follow OOP principles
- Follow naming conventions:
  - PascalCase for classes/modules
  - camelCase for variables/functions
  - UPPER_CASE for constants

### Testing Changes

1. Make your changes
2. Test in a Roblox place using the testing project:
   - `rojo serve testing.project.json`
   - Open Roblox Studio and connect to the Rojo server

## Submitting Changes

1. Commit your changes: `git commit -m "Description of changes"`
2. Push to your fork: `git push origin your-branch-name`
3. Open a pull request

## Pull Request Guidelines

When submitting a pull request:

1. Describe what was changed and why
2. Include screenshots or videos if UI changes were made
3. Ensure your code passes the existing tests
4. Add tests if you've added new functionality
5. Update documentation if necessary

## Bug Reports and Feature Requests

Use the GitHub Issues tracker to:

- Report bugs
- Request new features
- Discuss potential changes

Provide as much information as possible, including:

- Steps to reproduce (for bugs)
- Expected vs. actual behavior
- Screenshots or videos if applicable
- Suggestions for implementation (for features)

## Documentation

SimpleDialogue uses MkDocs for documentation. To preview documentation changes:

1. Install MkDocs: `pip install mkdocs mkdocs-material`
2. Start the documentation server: `mkdocs serve`
3. Open your browser to `http://localhost:8000`

## License

By contributing to SimpleDialogue, you agree that your contributions will be licensed under the project's MIT License.