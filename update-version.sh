#!/usr/bin/env bash

# Redirect output to stderr.
exec 1>&2

RELEASE_TYPE=$1
RELEASE_TITLE=$2
IS_PRE_RELEASE=$3

pushd $(dirname $0) > /dev/null

# TODO - add validation of inputs

git checkout main

version=$(git describe --tags --abbrev=0)
version_without_v=$(echo ${version} | cut -f2 -dv)

# Credit: https://stackoverflow.com/a/64390598
increment_version() {
  local delimiter=.
  local array=($(echo "$1" | tr $delimiter '\n'))
  array[$2]=$((array[$2]+1))
  if [ $2 -lt 2 ]; then array[2]=0; fi
  if [ $2 -lt 1 ]; then array[1]=0; fi
  echo $(local IFS=$delimiter ; echo "${array[*]}")
}

echo "Current release version is ${version_without_v}"

new_version=${version_without_v}
if [ $RELEASE_TYPE == "PATCH" ]; then
    new_version=$(increment_version ${version_without_v} 2 )
elif [ $RELEASE_TYPE == "MINOR" ]; then
    new_version=$(increment_version ${version_without_v} 1 )
elif [ $RELEASE_TYPE == "MAJOR" ]; then
    new_version=$(increment_version ${version_without_v} 0 )
else
    echo "ERROR! Unknown release type! Exitting..."
    exit -1
fi

echo "New version is ${new_version}"

# ===========================================
echo "!!! ABOUT TO MAKE NEW VERSION !!!"
git config --local user.email "ncbeard@amazon.com"
git config --local user.name "TwistedTwigleg"

# --==--
# NOTE - if you need to make changes BEFORE making a release, do it here and commit the file!
new_version_branch=AutoTag-v${new_version}
git checkout -b ${new_version_branch}

# TODO: make changes to files HERE if needed!
# NOTE: Do NOT include VERSION file in the commit.
# Example:
# git add setup.py
# git commit -m "Updated version to ${new_version}"

# push the commit and create a PR
# git push -u "https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/TwistedTwigleg/aws-iot-device-sdk-python-v2.git" ${new_version_branch}
# gh pr create --title "AutoTag PR for v${new_version}" --body "AutoTag PR for v${new_version}" --head ${new_version_branch}

# Merge the PR
# gh pr merge --admin --squash
# --==--

# update local state with the merged pr
git fetch
git checkout main
git pull "https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/TwistedTwigleg/aws-iot-device-sdk-python-v2.git" main

# create new tag on latest commit with old message
git tag -f v${new_version} -m "Version v${new_version} tag"

# push new tag to github
git push "https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/TwistedTwigleg/aws-iot-device-sdk-python-v2.git" --tags

# now recreate the release on the updated tag
# (If a pre-release, then -p needs to be added)
if [ $IS_PRE_RELEASE == "true" ]; then
    gh release create v${new_version} -p --generate-notes --notes-start-tag "$version"
else
    gh release create v${new_version} --generate-notes --notes-start-tag "$version"
fi

# Change the title to the title we put
gh release edit v${new_version} --title $RELEASE_TITLE

# ===========================================

# Make the version file so we can upload it in the next step in manual-release.yml
echo "${new_version}" > VERSION

popd > /dev/null
