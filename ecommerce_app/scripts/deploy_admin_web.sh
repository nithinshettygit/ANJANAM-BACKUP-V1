#!/usr/bin/env bash
cd "$(dirname "$0")/.."
flutter build web --release
firebase deploy --only hosting
