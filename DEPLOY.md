# Deploying to Vercel

Since Vercel doesn't natively build Flutter apps out of the box (it needs a custom build environment), we recommend two approaches:

## Option 1: Manual Deployment (Easiest)

1.  **Build Locally**:
    Run the following command in your terminal:
    ```bash
    flutter build web --release
    ```
    This creates a `build/web` directory with your compiled app.

2.  **Deploy with Vercel CLI**:
    If you have the Vercel CLI installed:
    ```bash
    cd build/web
    vercel deploy --prod
    ```
    
    *Or manually upload the `build/web` folder contents to Vercel dashboard if supported.*

## Option 2: Git Integration with Custom Build (Recommended for CD)

1.  **Connect GitHub**:
    -   Push your code to GitHub.
    -   Go to Vercel Dashboard -> Add New Project -> Import your repository.

2.  **Configure Build Settings**:
    -   **Framework Preset**: Other
    -   **Build Command**: `flutter build web`
    -   **Output Directory**: `build/web`
    -   **Install Command**: You need to override the install command to install Flutter.
    
    *However, installing Flutter on every build is slow.*

    **Better Approach for Git**:
    Use a **GitHub Action** to build the app and push the `build/web` artifacts to a `gh-pages` branch, then connect Vercel to that branch, OR use a custom build script in Vercel.

    **Simplest Vercel-Native Approach**:
    1.  Add a `build.sh` script to your root:
        ```bash
        #!/bin/bash
        git clone https://github.com/flutter/flutter.git -b stable --depth 1
        export PATH="$PATH:`pwd`/flutter/bin"
        flutter config --no-analytics
        flutter build web --release
        ```
    2.  In Vercel Settings:
        -   **Build Command**: `bash build.sh`
        -   **Output Directory**: `build/web`
        -   **Install Command**: (Leave empty or `echo "No install needed"`)

## Important Configuration

-   **`vercel.json`**: We have added this file to handle routing. It ensures that when you refresh a page (like `/dashboard`), Vercel serves `index.html` instead of a 404.
-   **Environment Variables**:
    -   Go to **Settings -> Environment Variables** in Vercel.
    -   Add `API_URL` with your Railway URL.
    -   *Note*: Since Flutter web is client-side, environment variables must be available during **build time** (if using `flutter_dotenv` with compile-time defines) or served via a generated config file. 
    -   **Current setup**: We use `flutter_dotenv` which reads from `.env` in assets.
    -   **Action**: You must ensure `.env` is present in the `build/web/assets` folder. 
        -   If building locally: The `.env` file is bundled automatically.
        -   If building on Vercel: You must generate the `.env` file during the build script using Vercel's environment variables.
        
        **Updated `build.sh` to handle .env**:
        ```bash
        #!/bin/bash
        # Create .env from Vercel Environment Variables
        # make sure to add API_URL in Vercel Project Settings
        echo "API_URL=$API_URL" > .env
        
        git clone https://github.com/flutter/flutter.git -b stable --depth 1
        export PATH="$PATH:`pwd`/flutter/bin"
        flutter build web --release
        ```
    -   *Tip*: Use `.env.example` as a reference for what variables need to be set.
