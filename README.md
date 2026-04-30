# YTGestures
Using as the baseline https://github.com/VasirakCalgux/VolumeBoostYT change it from boosting volume to changing system volume with the same gesture. 

## Tested Environments
- **Sideloaded Targets:** Can be injected via tools like LiveContainer into decrypted YouTube IPAs.

## Installation (Self-Build via GitHub Actions)
To ensure you always have the latest version compiled from source, you can build the tweak yourself directly on GitHub without installing any local tools:

1. Click the **Fork** button at the top right of this repository to create your own copy.
2. Go to the **Actions** tab in your forked repository.
3. Click on the **"Build Tweak"** workflow on the left sidebar.
4. You may need to click a button that says *"I understand my workflows, go ahead and enable them"*.
5. Click **Run workflow** -> **Run workflow** (green button).
6. Wait 1-2 minutes for the virtual Mac to compile the code.
7. Go to the **Releases** tab on the right side of your forked repository.
8. Download the raw `.dylib` or `.deb` files directly from the latest generated release.

- Use the `.dylib` file to inject into YouTube IPAs via sideloading (LiveContainer, TrollStore, etc.)
- Use the `.deb` file to install on jailbroken rootless devices (Sileo, Zebra, etc.)

