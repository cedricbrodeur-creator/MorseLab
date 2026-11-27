# MorseLab

App Android d'apprentissage du code Morse (inspirée de Morse Code Complete). Capacitor 8 + une seule page web.

- Tout le code de l'app est dans `www/index.html` (HTML + CSS + JS, sans bundler).
- Aucun emoji dans l'UI : icônes SVG inline (objet `ICONS`, helper `ic()`), codes Morse dessinés avec `glyph()`.
- Vibration : plugin natif local `MorseVibe` (`android/app/src/main/java/com/morselab/app/MorseVibePlugin.java`, enregistré dans `MainActivity`) — amplitude max + usage ALARM pour ne pas être coupé sur Android 13+, et `cancel()` pour la clé. Repli : Haptics puis `navigator.vibrate`.
- Bouton retour Android géré via `@capacitor/app` (quitte l'exercice → onglet Apprendre → ferme l'app).
- Icône / splash : `android/app/src/main/res/drawable/ic_launcher_mark.xml` (point + trait ambre sur #0E0D0B).
- Sorties : son (WebAudio), vibration (`@capacitor/haptics`, repli `navigator.vibrate`), flash d'écran, lampe torche (`@capawesome/capacitor-torch`). Voir la section « SORTIES » du script.
- Onglets : Apprendre (méthode Koch, table), Pratique (réception, Q-codes/abréviations/prosignes, QSO), Manip (clé droite, mono-levier, iambique), Traduire, Réglages.
- Après toute modification de `www/`, lancer `npx cap sync android`.
- Compiler l'APK : `npm run apk` (JDK 21 + Android SDK requis) → `android/app/build/outputs/apk/debug/app-debug.apk`. Ou pousser sur GitHub : le workflow `.github/workflows/android.yml` produit l'APK.
- iOS : projet `ios/` (Swift Package Manager, pas de CocoaPods). Ne se compile que sur Mac : le workflow `.github/workflows/ios.yml` produit un `.ipa` non signé (à signer via Sideloadly/AltStore). `MorseVibe` est Android uniquement ; sur iOS la vibration passe par Haptics.
- Aperçu rapide dans un navigateur : ouvrir `www/index.html` (la lampe torche ne marche que sur Android).
