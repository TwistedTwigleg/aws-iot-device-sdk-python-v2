#!/usr/bin/env bash

RELEASE_TYPE=$1
RELEASE_TITLE=$2
IS_PRE_RELEASE="false"

# Increments the version up by one
# Credit: https://stackoverflow.com/a/64390598
increment_version() {
  local delimiter=.
  local array=($(echo "$1" | tr $delimiter '\n'))
  array[$2]=$((array[$2]+1))
  if [ $2 -lt 2 ]; then array[2]=0; fi
  if [ $2 -lt 1 ]; then array[1]=0; fi
  echo $(local IFS=$delimiter ; echo "${array[*]}")
}

pushd $(dirname $0) > /dev/null

# Get the current version
git checkout main
current_version=$(git describe --tags --abbrev=0)
current_version_without_v=$(echo ${current_version} | cut -f2 -dv)

echo "Current release version is ${current_version_without_v}"

# Validate that RELEASE_TYPE is what we expect and bump the version:
new_version=${current_version_without_v}
if [ $RELEASE_TYPE == "PATCH" ]; then
    new_version=$(increment_version ${current_version_without_v} 2 )
elif [ $RELEASE_TYPE == "MINOR" ]; then
    new_version=$(increment_version ${current_version_without_v} 1 )
elif [ $RELEASE_TYPE == "MAJOR" ]; then
    new_version=$(increment_version ${current_version_without_v} 0 )
else
    echo "ERROR: Unknown release type! Exitting..."
    exit -1
fi
echo "New version is ${new_version}"

# Validate that the title is set
if [ $RELEASE_TITLE == "" ]; then
    echo "ERROR: No title set! Cannot make release. Exitting..."
    exit -1
fi
# (We do not need to validate the pre-release input, it either will be 'true' or not)

# Setup Github credentials
git config --local user.email "ncbeard@amazon.com"
git config --local user.name "TwistedTwigleg"

# --==--
# # NOTE - if you need to make changes BEFORE making a release, do it here and commit the file!
# new_version_branch=AutoTag-v${new_version}
# git checkout -b ${new_version_branch}

# # NOTE: Make changes to files HERE if needed!
# echo "Wow, a test!" > TEST_OUTPUT
# git add TEST_OUTPUT
# git commit -m "[v$new_version] $RELEASE_TITLE"

# # push the commit and create a PR
# git push -u "https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/TwistedTwigleg/aws-iot-device-sdk-python-v2.git" ${new_version_branch}
# gh pr create --title "AutoTag PR for v${new_version}" --body "AutoTag PR for v${new_version}" --head ${new_version_branch}

# # Merge the PR
# gh pr merge --admin --squash
# --==--

# Update local state with the merged pr (if one was made) and just generally make sure we're up to date
git fetch
git checkout main
git pull "https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/TwistedTwigleg/aws-iot-device-sdk-python-v2.git" main

# Create new tag on latest commit with the release title
git tag -f v${new_version} -m "${RELEASE_TITLE}"
# Push new tag to github
git push "https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/TwistedTwigleg/aws-iot-device-sdk-python-v2.git" --tags

# now recreate the release on the updated tag
# (If a pre-release, then -p needs to be added)

# Create the release with auto-generated notes as the description
# - NOTE: This will only add stuff if there is at least one PR. If there is no PRs,
# - then this will be blank and need manual input/changing after running.
if [ $IS_PRE_RELEASE == "true" ]; then
    gh release create "v${new_version}" -p --generate-notes --notes-start-tag "$current_version" --target main -t "${RELEASE_TITLE}"
else
    gh release create "v${new_version}" --generate-notes --notes-start-tag "$current_version" --target main -t "${RELEASE_TITLE}"
fi

# ===========================================

popd > /dev/null
