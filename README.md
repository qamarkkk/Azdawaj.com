# AZDAWAJ.COM — Android app

Android-first Expo and React Native starter for a Pakistan-focused, adults-only matchmaking app.

## Current prototype
- Welcome screen and AZDAWAJ branding
- Basic profile form with client-side 18+ age check
- Discovery screen with fictional sample profiles
- Local demo like/pass interactions

This is not a production dating service. It does not yet include real accounts, secure age verification, cloud profiles, photo uploads, real matching, private messaging, blocking/reporting, moderation, or account deletion. The age check is only a prototype and is not secure age assurance.

## Planned production work
1. Configure Supabase Auth and PostgreSQL.
2. Implement row-level security and server-side authorization.
3. Add private profile-photo storage.
4. Build real discovery, likes, mutual matches and private chat.
5. Add reporting, blocking, moderation and account deletion.
6. Test on Android devices before release.

## Run and build
Install dependencies using npm install, then run npx expo start. For an Android preview APK, configure Expo and use npx eas build --platform android --profile preview. Build quotas depend on the current Expo plan. Google Play distribution requires a developer account and policy compliance.

Never put Supabase service-role secrets in the mobile app. Do not launch publicly until age assurance, privacy, moderation, abuse prevention, secure authorization and legal compliance are implemented.