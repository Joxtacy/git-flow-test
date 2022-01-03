#!/bin/bash

### Setting up the environment ###
set -Eeuo pipefail
IFS=$'\n\t'

RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Set default values
COMMITISH="master"
RELEASE_BRANCH_NAME=""
DIRS_WITH_CHANGES=""
##################################

logSuccess() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

logError() {
    echo -e "${RED}[FAILED]${NC} $1"
}

pause() {
    if [[ $# == 0 ]]; then
        sleep 1;
    else
        sleep $1;
    fi
}

# Sets COMMITISH to the first argument passed, if one exists
parseArgs() {
    if [[ $# -ge 1 ]]; then
        COMMITISH=$1
    fi
}

# Ask the user if they want to continue
check() {
    while : ; do
        read -p "$1 [y/N] " -n 1 CONFIRM
        echo ""
        [[ ! $CONFIRM =~ ^[YyNn]$ ]] || break
    done

    if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
        echo -e "\nAborting. Bye bye o7"
        printBongoCat;
        exit 0;
    fi
}

# Check git status, exit if workspace is dirty
checkStatus() {
    if [[ $(git status --porcelain --untracked-files=no) ]]; then
        echo -e "${RED}[ERROR]${NC} You've got uncommited changes, please investigate and try again";
        exit 1;
    fi
}

gitPull() {
    git pull --no-rebase
}

# Checkout master and pull latest changes
checkoutMaster() {
    echo -e "${YELLOW}Checking out master${NC}\n"

    pause;

    git checkout $COMMITISH
    gitPull;
}

# Checkout develop and pull latest changes
checkoutDevelop() {
    echo -e "${YELLOW}Checking out develop${NC}\n"

    pause;

    git checkout develop
    gitPull;
}

printFoldersWithDiff() {
    echo -e "Folders with changes:"

    pause;

    local git_diff=$(git diff --dirstat=files,0,cumulative $COMMITISH)
    local dirs=$(echo "$git_diff" | awk '{print $2}')
    local plain_dirs=$(echo "$dirs" | awk -F '/' '{print $1}')
    DIRS_WITH_CHANGES=$(echo "$plain_dirs" | uniq)

    if [[ -z $DIRS_WITH_CHANGES ]]; then
        echo -e "  ${RED}No changes!$NC Release is not necessary"
        exit 0
    else
        for i in $DIRS_WITH_CHANGES; do
            echo -e "  $ORANGE$i$NC"
        done
    fi
}

# Prints out the commits that differ from the given commit-ish
getCommitDiff() {
    echo -e "Getting commit diff to $GREEN$COMMITISH$NC"

    pause;

    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    local commit_diff=$(git log $COMMITISH..$current_branch --oneline)
    for commit in $commit_diff; do
        echo -e "  $ORANGE$commit$NC"
    done
}

createReleaseBranch() {
    local today=$(date -u +%Y-%m-%d)
    RELEASE_BRANCH_NAME="release/$today"
    echo -e "Creating release branch: ${GREEN}$RELEASE_BRANCH_NAME${NC}"

    check "Do you want to continue?";

    if $(git checkout -b $RELEASE_BRANCH_NAME develop 2> /dev/null); then
        logSuccess "Created release branch: ${GREEN}$RELEASE_BRANCH_NAME${NC}"

        echo -e "Pushing the newly created ${GREEN}${RELEASE_BRANCH_NAME}${NC} branch"

        pause 1;

        git push -u origin $RELEASE_BRANCH_NAME
    else
        logError "Failed to create branch ${RED}$RELEASE_BRANCH_NAME${NC}. Branch already exists."
        exit 1;
    fi
}

# This requires user input to give a message to each tag
createTags() {
    echo -e "Creating tags for the released integrations.."

    pause 2;

    for integration in $DIRS_WITH_CHANGES; do
        if [[ -e $integration/package.json ]]; then
            local version=$(cat ${integration}/package.json | grep '\"version\": \"\d*\.\d*.\d*\"' --only-matching | awk '{print $2}' |  awk '{gsub(/"/,"")}1')
            git tag -a ${integration}/v${version}
            logSuccess "Tag: ${GREEN}$(git describe --abbrev=0 --tags)${NC} successfully created"
            pause 1;
        fi
    done

    echo -e "Pushing the created tags"

    pause 1;

    git push origin --tags
}

mergeReleaseToMaster() {
    if [[ -z ${RELEASE_BRANCH_NAME} ]]; then
        logError "Didn't create a release branch. Can't continue."
        exit 1;
    else
        echo -e "Merging ${GREEN}${RELEASE_BRANCH_NAME}${NC} into ${GREEN}${COMMITISH}${NC}"
        git checkout $COMMITISH
        git merge --no-ff $RELEASE_BRANCH_NAME
        git push
    fi
}

mergeReleaseToDevelop() {
    if [[ -z ${RELEASE_BRANCH_NAME} ]]; then
        logError "Didn't create a release branch. Can't continue."
        exit 1;
    else
        echo -e "Merging ${GREEN}${RELEASE_BRANCH_NAME}${NC} into ${GREEN}develop${NC}"
        git checkout develop
        git merge --no-ff $RELEASE_BRANCH_NAME
        git push
    fi
}

pushReleaseBranchForCompleteness() {
    if [[ -z ${RELEASE_BRANCH_NAME} ]]; then
        logError "Didn't create a release branch. Can't continue."
        exit 1;
    else
        echo -e "Pushing ${GREEN}${RELEASE_BRANCH_NAME}${NC} to remote"
        git push origin $RELEASE_BRANCH_NAME
    fi
}

printBongoCat() {
    echo -e "${ORANGE}
    ⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⣷⣦⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
    ⠀⠀⠀⠀⠀⠀⠀⣀⣶⣿⣿⣿⣿⣿⣿⣷⣶⣶⣶⣦⣀⡀⠀⢀⣴⣇⠀⠀⠀⠀
    ⠀⠀⠀⠀⠀⢠⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀
    ⠀⠀⠀⠀⣰⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀
    ⠀⠀⠀⣴⣿⣿⣿⣿⠛⣿⣿⣿⣿⣿⣿⣿⣿⡿⣿⣿⣿⣿⣿⣿⣿⣿⣄⠀⠀⠀
    ⠀⠀⣾⣿⣿⣿⣿⣿⣶⣿⣯⣭⣬⣉⣽⣿⣿⣄⣼⣿⣿⣿⣿⣿⣿⣿⣿⣷⡀⠀
    ⠀⣸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡄
    ⢸⣿⣿⣿⣿⠟⠋⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠁⣿⣿⣿⣿⡿⠛⠉⠉⠉⠉⠁
    ⠘⠛⠛⠛⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠛⠛⠛⠃⠀⠀⠀⠀⠀⠀⠀
    ${NC}
    "
}

printPikachu() {
    echo -e "${YELLOW}
    ⠸⣷⣦⠤⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣠⣤⠀⠀⠀
    ⠀⠙⣿⡄⠈⠑⢄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⠔⠊⠉⣿⡿⠁⠀⠀⠀
    ⠀⠀⠈⠣⡀⠀⠀⠑⢄⠀⠀⠀⠀⠀⠀⠀⠀⠀⡠⠊⠁⠀⠀⣰⠟⠀⠀⠀⣀⣀
    ⠀⠀⠀⠀⠈⠢⣄⠀⡈⠒⠊⠉⠁⠀⠈⠉⠑⠚⠀⠀⣀⠔⢊⣠⠤⠒⠊⠉⠀⡜
    ⠀⠀⠀⠀⠀⠀⠀⡽⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠩⡔⠊⠁⠀⠀⠀⠀⠀⠀⠇
    ⠀⠀⠀⠀⠀⠀⠀⡇⢠⡤⢄⠀⠀⠀⠀⠀⡠⢤⣄⠀⡇⠀⠀⠀⠀⠀⠀⠀⢰⠀
    ⠀⠀⠀⠀⠀⠀⢀⠇⠹⠿⠟⠀⠀⠤⠀⠀⠻⠿⠟⠀⣇⠀⠀⡀⠠⠄⠒⠊⠁⠀
    ⠀⠀⠀⠀⠀⠀⢸⣿⣿⡆⠀⠰⠤⠖⠦⠴⠀⢀⣶⣿⣿⠀⠙⢄⠀⠀⠀⠀⠀⠀
    ⠀⠀⠀⠀⠀⠀⠀⢻⣿⠃⠀⠀⠀⠀⠀⠀⠀⠈⠿⡿⠛⢄⠀⠀⠱⣄⠀⠀⠀⠀
    ⠀⠀⠀⠀⠀⠀⠀⢸⠈⠓⠦⠀⣀⣀⣀⠀⡠⠴⠊⠹⡞⣁⠤⠒⠉⠀⠀⠀⠀⠀
    ⠀⠀⠀⠀⠀⠀⣠⠃⠀⠀⠀⠀⡌⠉⠉⡤⠀⠀⠀⠀⢻⠿⠆⠀⠀⠀⠀⠀⠀⠀
    ⠀⠀⠀⠀⠀⠰⠁⡀⠀⠀⠀⠀⢸⠀⢰⠃⠀⠀⠀⢠⠀⢣⠀⠀⠀⠀⠀⠀⠀⠀
    ⠀⠀⠀⢶⣗⠧⡀⢳⠀⠀⠀⠀⢸⣀⣸⠀⠀⠀⢀⡜⠀⣸⢤⣶⠀⠀⠀⠀⠀⠀
    ⠀⠀⠀⠈⠻⣿⣦⣈⣧⡀⠀⠀⢸⣿⣿⠀⠀⢀⣼⡀⣨⣿⡿⠁⠀⠀⠀⠀⠀⠀
    ⠀⠀⠀⠀⠀⠈⠻⠿⠿⠓⠄⠤⠘⠉⠙⠤⢀⠾⠿⣿⠟⠋
    ${NC}
    "
}

### Start script execution #####################

parseArgs "$@";
checkStatus;
checkoutMaster;
checkoutDevelop;
printFoldersWithDiff;
getCommitDiff;
createReleaseBranch;
echo -e "Go to Jenkins to make sure that the release branch passes its build."
pause 5;
check "Did the relase branch pass its build?"

echo -e "\nProceed with testing the integrations that are going to be released. Come back here when you're done."
pause 5;
check "Did you finish testing? \"No\" will cancel the release process."

echo -e "It is now time to run \`npm version\` on the packages that are going to be released."
echo -e "The packages that need updating are:"
printFoldersWithDiff;
echo -e "\nUpdate the versions and check back here after to continue the release process."
pause 5;
check "Did you update the versions? \"No\" will cancel the release process.";

mergeReleaseToMaster;
echo -e "\nGo to Jenkins to make sure that the builds passed for all of the integrations being released."
pause 5;
check "Did the master branch build pass and did the integrations get released?"

createTags;

mergeReleaseToDevelop;
echo -e "\nMake sure that the builds on Jenkins passed."
pause 5;
check "Did the develop branch build pass?"

logSuccess "\nYou're now done! Awesome work! 🥳"
printPikachu;
