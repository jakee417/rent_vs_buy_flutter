#!/bin/bash
flutter build web --base-href "/pages/rent_vs_buy/"
echo "Removing current web build"
rm -rf ~/dev/jakee417.github.io/pages/rent_vs_buy/
echo "Copying new web build"
cp -r build/web/ ~/dev/jakee417.github.io/pages/rent_vs_buy/