∏#!/bin/bash

echo "🚀 Instalando extensiones de VS Code para Flutter..."

# Definir la ruta de VS Code
CODE_PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"

# Verificar si VS Code está instalado
if [ ! -f "$CODE_PATH" ]; then
    echo "❌ Error: No se encontró VS Code en la ubicación esperada."
    echo "Por favor, instala las extensiones manualmente desde VS Code."
    exit 1
fi

echo "✅ VS Code encontrado. Instalando extensiones..."

# Extensiones esenciales
"$CODE_PATH" --install-extension Dart-Code.flutter
"$CODE_PATH" --install-extension Dart-Code.dart-code

# Extensiones muy recomendadas
"$CODE_PATH" --install-extension Nash.awesome-flutter-snippets
"$CODE_PATH" --install-extension jeroen-meijer.pubspec-assist
"$CODE_PATH" --install-extension alexisvt.flutter-snippets
"$CODE_PATH" --install-extension usernamehw.errorlens

# Extensiones adicionales útiles
"$CODE_PATH" --install-extension aaron-bond.better-comments
"$CODE_PATH" --install-extension CoenraadS.bracket-pair-colorizer-2
"$CODE_PATH" --install-extension eamodio.gitlens
"$CODE_PATH" --install-extension PKief.material-icon-theme
"$CODE_PATH" --install-extension localizely.flutter-intl
"$CODE_PATH" --install-extension kisstkondoros.vscode-gutter-preview
"$CODE_PATH" --install-extension jock.svg

echo ""
echo "✅ ¡Instalación completada!"
echo "📝 Reinicia VS Code para que los cambios surtan efecto."
