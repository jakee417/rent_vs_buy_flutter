# Finance Calculator

A suite of financial calculators including rent vs. buy and refinance calculators, built with Dart and Flutter.

## Features

- **Rent vs. Buy Calculator**: Compare the costs of renting vs. buying a home over time
- **Refinance Calculator**: Calculate savings from refinancing your mortgage

## Getting Started

First run:

```bash
flutter run -d chrome --web-hostname 0.0.0.0 --web-port 8888
```

to serve the web server locally. You can access it from a mobile device by browsing to your computer's IP address at port `8888`.

To build for web, run:

```bash
flutter build web --base-href /pages/finance_calculator/
```

And view the files under the `build/*` directory. If you host this under a different file, make sure to change the `<base href="/">` tag in `index.html` to a relative path of the file.

## App Structure

- `lib/landing_page.dart`: Main landing page with navigation to calculators
- `lib/rent_vs_buy_page.dart`: Rent vs. Buy calculator page
- `lib/refinance_page.dart`: Refinance calculator page
- `lib/rent_vs_buy.dart`: Core rent vs. buy calculation logic
- `lib/refinance_calculations.dart`: Refinance calculation logic