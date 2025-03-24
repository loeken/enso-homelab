#!/bin/bash
copy_if_not_exists() {
    local source_file=$1
    local target_file=$2

    if [[ ! -f "$target_file" ]]; then
        if [[ -f "$source_file" ]]; then
            cp "$source_file" "$target_file"
            echo "Copied $source_file to $target_file"
        else
            echo "Source file $source_file does not exist, skipping."
        fi
    else
        echo "$target_file already exists, skipping."
    fi
}

# Check and copy for .env and .env.test
copy_if_not_exists ".env.example" ".env"
copy_if_not_exists ".env.test.example" ".env.test"

# Ensure the script is executed inside a Git repository
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Error: This script must be run inside a Git repository."
    exit 1
fi

# Get the repository folder name
REPO_PATH=$(git rev-parse --show-toplevel)
REPO_NAME=$(basename "$REPO_PATH")

# Define files to update
DEVCONTAINER_FILE="$REPO_PATH/.devcontainer/devcontainer.json"
DOCKER_COMPOSE_FILE="$REPO_PATH/docker-compose.yml"
DOCKER_COMPOSE_FILE_TEST="$REPO_PATH/docker-compose-test.yml"
RENOVATE_GITHUB_ACTION_FILE="$REPO_PATH/.github/workflows/renovate.yml"
# Function to replace "myapp" with the repository name
replace_in_file() {
    local file=$1
    if [[ -f "$file" ]]; then
        sed -i "s/myapp/$REPO_NAME/g" "$file"
        echo "Updated: $file"
    else
        echo "Warning: $file not found."
    fi
}
replace_in_file2() {
    local file=$1
    if [[ -f "$file" ]]; then
        sed -i "s/repo_template_go/$REPO_NAME/g" "$file"
        echo "Updated: $file"
    else
        echo "Warning: $file not found."
    fi
}

# Perform replacements
replace_in_file "$DEVCONTAINER_FILE"
replace_in_file "$DOCKER_COMPOSE_FILE"
replace_in_file "$DOCKER_COMPOSE_FILE_TEST"
replace_in_file2 "$RENOVATE_GITHUB_ACTION_FILE"

# echo "Replacement complete."
git rm rewrite.sh -f
git add .devcontainer/devcontainer.json
git add docker-compose-test.yml
git add docker-compose.yml
git add .github/workflows/renovate.yml
git commit -m "removed rewrite.sh bootstrap script"
git push
# echo "deleting rewrite.sh"