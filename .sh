#!/bin/bash

# Variables
GITHUB_USER="allyelvis"
REPO_NAME="tv_broadcasting_cms"
PYTHON_VERSION="3.10"  # Update if needed
NODE_VERSION="16"      # Update if needed
BRANCH_NAME="main"

# Install GitHub CLI if not already installed
if ! command -v gh &> /dev/null
then
    echo "GitHub CLI not found. Installing..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        type -p curl >/dev/null || sudo apt install curl -y
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update
        sudo apt install gh -y
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install gh
    elif [[ "$OSTYPE" == "msys" ]]; then
        winget install --id GitHub.cli
    else
        echo "Unsupported OS. Please install GitHub CLI manually."
        exit 1
    fi
fi

# Authenticate with GitHub CLI
gh auth login

# Create project directory
mkdir $REPO_NAME
cd $REPO_NAME

# Initialize Python environment
echo "Setting up Python environment..."
python3 -m venv venv
source venv/bin/activate  # On Windows use `venv\Scripts\activate`
pip install --upgrade pip

# Install Python dependencies
echo "Installing Python dependencies..."
pip install django  # Replace with your CMS framework
pip install psycopg2-binary  # PostgreSQL support; replace as needed

# Initialize Django project (replace if using a different CMS)
echo "Creating Django project..."
django-admin startproject cms .

# Install Node.js and npm if not already installed
if ! command -v node &> /dev/null || ! command -v npm &> /dev/null
then
    echo "Node.js and npm not found. Installing..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl -fsSL https://deb.nodesource.com/setup_$NODE_VERSION.x | sudo -E bash -
        sudo apt install -y nodejs
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install node
    elif [[ "$OSTYPE" == "msys" ]]; then
        winget install OpenJS.NodeJS
    else
        echo "Unsupported OS. Please install Node.js and npm manually."
        exit 1
    fi
fi

# Initialize Node.js project (if applicable)
if [ -d "frontend" ]; then
    echo "Installing Node.js dependencies..."
    cd frontend
    npm install
    cd ..
fi

# Set up GitHub Actions workflow
echo "Setting up GitHub Actions workflow..."
mkdir -p .github/workflows
cat <<EOL > .github/workflows/deploy.yml
name: Deploy TV Broadcasting CMS

on:
  push:
    branches: ["$BRANCH_NAME"]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: "pages"
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout repository
      uses: actions/checkout@v4

    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '$PYTHON_VERSION'

    - name: Install Python dependencies
      run: |
        python -m pip install --upgrade pip
        pip install -r requirements.txt

    - name: Set up Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '$NODE_VERSION'

    - name: Install Node.js dependencies
      run: |
        cd frontend
        npm install

    - name: Build the site
      run: |
        python manage.py collectstatic --noinput
        python manage.py migrate

    - name: Upload artifact
      uses: actions/upload-pages-artifact@v3
      with:
        name: site
        path: ./staticfiles

  deploy:
    environment:
      name: github-pages
      url: \${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build
    steps:
    - name: Deploy to GitHub Pages
      id: deployment
      uses: actions/deploy-pages@v4
      with:
        github_token: \${{ secrets.GITHUB_TOKEN }}
EOL

# Initialize Git repository
echo "Initializing Git repository..."
git init
git add .
git commit -m "Initial commit with CMS setup and GitHub Actions workflow"

# Create GitHub repository using GitHub CLI
echo "Creating GitHub repository..."
gh repo create $GITHUB_USER/$REPO_NAME --public --source=. --remote=origin --push

# Push the changes to GitHub
echo "Pushing changes to GitHub..."
git branch -M $BRANCH_NAME
git push -u origin $BRANCH_NAME

# Enable GitHub Pages
echo "Enabling GitHub Pages..."
gh api -X PUT "repos/$GITHUB_USER/$REPO_NAME/pages" -F "source.branch=$BRANCH_NAME" -F "source.path=/"

echo "Setup complete. Your TV Broadcasting CMS is now ready and deployed to GitHub Pages."
