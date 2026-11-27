# MorseLab

App Android d'apprentissage du code Morse (inspirée de Morse Code Complete). Capacitor 8 + une seule page web.

- Tout le code de l'app est dans `www/index.html` (HTML + CSS + JS, sans bundler).
- Aucun emoji dans l'UI : icônes SVG inline (objet `ICONS`, helper `ic()`), codes Morse dessinés avec `glyph()`.
- Vibration : plugin natif local `MorseVibe` (`android/app/src/main/java/com/morselab/app/MorseVibePlugin.java`, enregistré dans `MainActivity`) — amplitude max + usage ALARM pour ne pas être coupé sur Android 13+, et `cancel()` pour la clé. Repli : Haptics puis `navigator.vibrate`.
- Parcours façon Duolingo (onglet Apprendre) : 21 unités de 2 caractères Koch × 3 leçons (`makeLesson`, `vLesson`, `vPath`), état `prog.path[u]` = leçons finies. Mascotte originale « Bip », un morse avec un casque radio (`mascot(mood)`, SVG inline). Exercices : intro, hear, see, build, word.
- Décodeur du manipulateur : `decHold()` suspend les chronos à chaque appui ; la clé droite apprend la vitesse réelle (`decClassify`).
- En ligne (Supabase) : schéma + RLS + fonctions dans `supabase/schema.sql` (écritures uniquement via RPC). Clés dans `www/config.js` (vide = fonctions en ligne désactivées). Client `www/vendor/supabase.js` (copie du build UMD de `@supabase/supabase-js`, à recopier si on met à jour le paquet). Connexion anonyme (`signInAnonymously`) : à activer dans Supabase > Authentication.
- Récupération de compte sans e-mail : code de 12 caractères (`new_recovery_code`, empreinte SHA-256 dans la table `recovery`), affiché dans l'onglet Amis et gardé localement (`recov-<uid>`). Sur un nouvel appareil : connexion anonyme puis `claim_account(code)` rattache profil, amis, bouteilles et sauvegarde (clés étrangères ON UPDATE CASCADE). Progression complète dans la table privée `saves` (`save_progress`) ; à la récupération, la sauvegarde qui a le plus de points l'emporte (`cloudRestore`).
- Social : onglet Amis (`vFriends`), défi du jour identique pour tous (`dailyItems`, graine = date), bouteilles à la mer (`vComp` écrire, `vChal` décoder, scène animée `bottleArrive` / `bottleThrow`).
- Bouton retour Android géré via `@capacitor/app` (quitte l'exercice → onglet Apprendre → ferme l'app).
- Icône / splash : `android/app/src/main/res/drawable/ic_launcher_mark.xml` (point + trait ambre sur #0E0D0B).
- Sorties : son (WebAudio), vibration (`@capacitor/haptics`, repli `navigator.vibrate`), flash d'écran, lampe torche (`@capawesome/capacitor-torch`). Voir la section « SORTIES » du script.
- Onglets : Accueil (Bip, défi du jour, bouteilles, parcours), Pratique (Koch libre, réception, codes, traducteur, référence), Amis, Manip, Réglages.
- Après toute modification de `www/`, lancer `npx cap sync android`.
- Compiler l'APK : `npm run apk` (JDK 21 + Android SDK requis) → `android/app/build/outputs/apk/debug/app-debug.apk`. Ou pousser sur GitHub : le workflow `.github/workflows/android.yml` produit l'APK.
- iOS : projet `ios/` (Swift Package Manager, pas de CocoaPods). Ne se compile que sur Mac : le workflow `.github/workflows/ios.yml` produit un `.ipa` non signé (à signer via Sideloadly/AltStore). `MorseVibe` est Android uniquement ; sur iOS la vibration passe par Haptics.
- Aperçu rapide dans un navigateur : ouvrir `www/index.html` (la lampe torche ne marche que sur Android).
