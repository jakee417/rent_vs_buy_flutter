# rent_vs_buy

A rent vs. buy calculator in dart with a flutter UI.

## `RentVsBuy`
Static class for computing the rent vs. buy computation.

## Getting Started
First run:

```bash
flutter run -d chrome --web-hostname 0.0.0.0 --web-port 8888
```

to serve the web server locally. You can access it from a mobile device by browsing to your computer's IP address at port `8888`.

To build for web, run:

```bash
flutter build web --base-href /pages/rent_vs_buy/
```

And view the files under the `build/*` directory. If you host this under a different file, make sure to change the `<base href="/">` tag in `index.html` to a relative path of the file.