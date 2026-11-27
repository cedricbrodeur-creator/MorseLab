# MorseLab

## Obtenir l'APK
**Option A – Android Studio** : `npm install`, `npx cap sync android`, `npx cap open android`, puis Build > Build APK(s).
**Option B – ligne de commande** (JDK 21 + Android SDK) : `npm install && npm run apk`.
**Option C – GitHub** : poussez ce dossier sur un dépôt GitHub, onglet Actions > « Build APK » > téléchargez l'artefact `MorseLab-debug-apk`.

Installez l'APK sur le téléphone (autoriser les sources inconnues).

## Modifier l'app
Éditez `www/index.html`, puis `npx cap sync android` et recompilez.
