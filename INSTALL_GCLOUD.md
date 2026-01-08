# Installing Google Cloud SDK (gcloud)

## Option 1: Install via Homebrew (Recommended for macOS)

```bash
# Install Homebrew if you don't have it
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Google Cloud SDK
brew install --cask google-cloud-sdk

# Initialize gcloud
gcloud init
```

## Option 2: Download and Install Manually

1. **Download the installer:**
   ```bash
   curl https://sdk.cloud.google.com | bash
   ```

2. **Restart your shell or source the path:**
   ```bash
   exec -l $SHELL
   # OR
   source ~/.zshrc  # if using zsh
   # OR
   source ~/.bash_profile  # if using bash
   ```

3. **Initialize gcloud:**
   ```bash
   gcloud init
   ```

## After Installation

1. **Verify installation:**
   ```bash
   gcloud --version
   ```

2. **Authenticate:**
   ```bash
   gcloud auth login
   ```

3. **Set your project:**
   ```bash
   gcloud config set project sub67-d4648
   ```

4. **Verify project:**
   ```bash
   gcloud config get-value project
   ```

## If gcloud is installed but not in PATH

If you installed gcloud but it's not found, add it to your PATH:

**For zsh (default on macOS):**
```bash
echo 'export PATH="$HOME/google-cloud-sdk/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**For bash:**
```bash
echo 'export PATH="$HOME/google-cloud-sdk/bin:$PATH"' >> ~/.bash_profile
source ~/.bash_profile
```

## Quick Test

After installation, test it:
```bash
gcloud config get-value project
```

This should show your project ID or prompt you to set one.

## Next Steps

Once gcloud is installed and configured:
1. Run `./setup-secrets.sh`
2. Run `./deploy-all.sh`

