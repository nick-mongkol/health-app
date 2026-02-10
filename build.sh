#!/bin/bash

# 1. Create .env from Vercel Environment Variables
if [ -z "$API_URL" ]; then
  echo "WARNING: API_URL environment variable is not set!"
else
  echo "API_URL=$API_URL" > .env
  echo "Created .env file"
fi

# 2. Install Flutter
if [ -d "flutter" ]; then
  echo "Flutter already installed."
else
  echo "Installing Flutter..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

# 3. Add to PATH
export PATH="$PATH:`pwd`/flutter/bin"

# 4. Verify Install
flutter doctor -v

# 5. Enable Web
flutter config --enable-web

# 6. Build
echo "Building Flutter Web App..."
flutter build web --release

echo "Build Complete!"
