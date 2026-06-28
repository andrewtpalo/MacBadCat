# Previewing Bad Cat on Windows (no Mac)

You can't run an iOS app directly on Windows — the iOS Simulator only exists on macOS. But you can build it on a free cloud Mac and then play it in your browser. Two routes:

## Route A — GitHub Actions builds it, Appetize streams it (free, no Mac)
1. Create a free GitHub account and a new **public** repository (public repos get free macOS Actions minutes).
2. Upload this whole `MacBadCat` folder to the repo (drag-and-drop in the GitHub web UI, or use GitHub Desktop on Windows).
3. Go to the repo's **Actions** tab → run **"Build iOS Simulator app (for Appetize preview)"** (it also runs on each push to `main`).
4. When it finishes (~3–5 min), open the run and download the **BadCat-Simulator** artifact (a `.zip`).
5. Go to **https://appetize.io**, sign up (free), and upload that `.zip`. It gives you a virtual iPhone in your browser — tap and play it on Windows.
   - Free tier is ~30–100 minutes/month; plenty for checking progress. To skip the manual upload, add an `APPETIZE_TOKEN` repo secret and uncomment the "Upload to Appetize" step in `.github/workflows/ios-preview.yml` — the build will print a public URL automatically.

## Route B — Rent a cloud Mac and use Xcode directly
Services like **MacinCloud**, **AWS EC2 Mac**, or **Scaleway Mac mini** give you a real macOS desktop you remote into from Windows. Open the project in Xcode there and press ▶ to run Apple's own Simulator — you're previewing on the remote screen. Costs money (hourly/monthly) but is the closest to a normal dev setup and needs no CI.

## Reality check
- Either route, the app is compiled by a Mac in the cloud — there is no way around that for any iOS app.
- The Simulator can't do hardware features (camera, Face ID, etc.). Bad Cat doesn't use any, so the preview is fully representative.
- If you expect to iterate a lot, Route B (a cheap cloud Mac) is less fiddly than re-running CI + re-uploading for every change.
