#!/bin/bash
flutter build web --base-href "/apps/finance_calculator/"
echo "Removing current web build"
rm -rf ~/Documents/jakee417.github.io/apps/finance_calculator/
echo "Copying new web build"
cp -r build/web/ ~/Documents/jakee417.github.io/apps/finance_calculator/