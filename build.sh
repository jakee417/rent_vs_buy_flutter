#!/bin/bash
flutter build web --base-href "/apps/rent_vs_buy/"
echo "Removing current web build"
rm -rf ~/jakee417.github.io/apps/rent_vs_buy/
echo "Copying new web build"
cp -r build/web/ ~/jakee417.github.io/apps/rent_vs_buy/