# Stock Market App with Upstox API

A modern Flutter-based stock market application that displays real-time NSE (National Stock Exchange) data using the Upstox API.

## Features

- Real-time market indices (Nifty 50, Bank Nifty, etc.)
- Live stock prices and market data
- Detailed stock information with historical data
- Search functionality for stocks
- Clean UI with support for light and dark themes

## API Integration

This app uses the Upstox API (v2) to fetch real-time market data. The API integration is handled by the following components:

- `MarketDataService`: Handles all API calls related to market data
- `AuthService`: Manages authentication with the Upstox API

## Project Structure

This application follows Clean Architecture principles, separating the codebase into distinct layers:

```
lib/
├── core/            # Core utilities, constants, and common functionality
├── data/            # Data sources, repositories, and services
├── domain/          # Business logic, entities, and use cases
├── presentation/    # UI components, screens, and widgets
└── main.dart        # Application entry point
```

## Getting Started

### Prerequisites

- Flutter SDK (3.6.0 or higher)
- Dart SDK (3.0.0 or higher)
- An Upstox API key

### Setup

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Add your Upstox API key in `lib/core/constants/app_constants.dart`
4. Run the app with `flutter run`

## Customization

You can customize the app by:

- Changing the theme in `lib/core/theme/app_theme.dart`
- Adding more stock symbols in `lib/core/constants/app_constants.dart`
- Customizing widgets in the presentation layer

## API Documentation

For more information about the Upstox API, visit the [official documentation](https://upstox.com/developer/api-documentation/).

## License

This project is licensed under the MIT License - see the LICENSE file for details.
