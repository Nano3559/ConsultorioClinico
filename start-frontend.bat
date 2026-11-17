@echo off
cd /d "C:\Users\camii\Documents\ConsultorioClinico\frontend"
flutter run -d web-server --web-port 5000 --dart-define=API_BASE_URL=http://localhost:3000/api --dart-define=ECG_API_BASE_URL=http://127.0.0.1:8000