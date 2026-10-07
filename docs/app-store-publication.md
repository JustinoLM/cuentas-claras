# App Store publication checklist

Status: postponed. Requires the Apple Developer Program (99 USD/year).
Not part of any code phase. v1.0.0 is tagged when the code is complete, not when published.

Figures, sizes and rules below were written from memory on 2026-10-07.
Verify each against developer.apple.com and App Store Connect before acting.

## 1. Prerequisites
- [ ] Enroll in the Apple Developer Program as an individual (identity verification can take days; start early).
- [ ] Decide seller name: individual means the legal name is shown publicly. An organization account avoids that but needs a registered company.
- [ ] Define the final bundle ID before the first upload (it cannot change afterwards). It must match the iOS platform registered in Entra (msauth.{bundle-id}://auth).
- [ ] Dedicated contact email (it will be public in the Privacy Policy).

## 2. Build and test
- [ ] Archive and upload a build to App Store Connect.
- [ ] TestFlight: test on a real device, including camera scan, Face ID lock, MSAL login and Layer 3 sync.
- [ ] Confirm NSCameraUsageDescription and NSFaceIDUsageDescription exist, with clear Spanish text.
- [ ] Confirm PrivacyInfo.xcprivacy is in the target (Privacy Report from the Organizer).

## 3. Store assets
- [ ] App icon 1024x1024, no transparency, no rounded corners.
- [ ] iPhone screenshots at the largest size App Store Connect currently requires.

## 4. Store text (Spanish)
- [ ] Name, subtitle, description, keywords, "what's new".
- [ ] Category (likely Finance) and copyright.
- [ ] Support URL.
- [ ] Privacy Policy URL (mandatory). Hosting is open: the repo is private, so GitHub Pages needs a paid plan. Options: separate public repo only for the policy, or a static page elsewhere.

## 5. Privacy
- [ ] Final review of docs/privacy-policy-draft.md: fill [date] (use the date of submission) and [contact email].
- [ ] Review the Nutrition Label against the app as it is at submission time.
- [ ] Check that the Privacy Policy and the Nutrition Label cover recurring payments and savings/investments (they travel to OneDrive if the user connects Layer 3).
- [ ] Questionnaires: age rating, encryption export compliance (standard HTTPS usually exempt; verify).

## 6. Notes for the reviewer
- [ ] Provide a valid CUFE or QR from a real Panamanian invoice; scanning only works with DGI data.
- [ ] State that the app is fully functional without any account, and that OneDrive (Layer 3) is optional.
- [ ] If Layer 3 must be tested, provide a test personal Microsoft account.
- [ ] Mention the DGI endpoint is public and requires no credentials.

## 7. Donations
- [ ] Re-read App Review Guidelines section 3.1 before adding any donation link inside the app. Safest option: keep the link out of the app (support page or README only). Decide consciously before submitting.

## 8. Known risks at submission
- DGI endpoint is not a documented API and may change (spec 5.1).
- Files.ReadWrite.AppFolder is marked preview by Microsoft (spec 13.2).
- Credit notes fall into .unsupported (spec 7).
- Reviewers may question the DGI scraping or the Microsoft data in the Nutrition Label.

## 9. Submit
- [ ] Submit for review. Expect one or a few days, and possibly a round of questions or a minor rejection.
- [ ] After approval, choose the marketing version (it does not need to match the git tag).