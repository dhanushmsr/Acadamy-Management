#!/bin/bash
cd flutter_app
if [ -d "../flutter" ]; then
  echo "Flutter cached"
else
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 ../flutter
fi
../flutter/bin/flutter build web --release --no-tree-shake-icons --dart-define=API_BASE_URL=https://acd-man.onrender.com
