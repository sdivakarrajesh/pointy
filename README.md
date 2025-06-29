# Pointy

Pointy is a macOS annotation app designed to enhance your presentations and workflows. It allows you to draw, annotate, and highlight directly on your screen, making it perfect for educators, presenters, and professionals.

## Features
- **Annotation Tools**: Select from various tools like pencil, arrow, rectangle, rounded rectangle, and circle.
- **Keyboard Shortcuts**: Use number keys to quickly switch tools and the Escape key to exit.
- **Color Picker**: Choose colors using a color picker with hue sliders and preset options.
- **Status Bar Integration**: Includes a status bar icon with a right-click Quit button and left-click annotation panel.
- **Dockless App**: Pointy does not appear in the Dock, ensuring a clean user experience.

## Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/theblueorb/Pointy.git
   ```
2. Navigate to the project directory:
   ```bash
   cd Pointy
   ```
3. Build and deploy the app using the provided script:
   ```bash
   bash build.sh
   ```

## Usage
- Launch the app from the `/Applications` folder.
- Use the annotation tools to draw directly on your screen.
- Access the status bar menu for quick actions.

## Development
### Prerequisites
- macOS
- Xcode
- Swift 5+


## Permissions
Pointy requires the following permissions:
- **Accessibility**: To stay on top and receive keyboard events.
- **Microphone**: For annotation purposes.
- **Camera**: For annotation purposes.

Ensure these permissions are granted in System Preferences > Security & Privacy.

## License
This project is licensed under the MIT License. See the LICENSE file for details.

## Contributing
Contributions are welcome! Feel free to open issues or submit pull requests.

