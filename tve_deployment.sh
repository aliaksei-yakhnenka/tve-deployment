#!/bin/bash
# Requirements: cloned repositories into acquia, nbcutve and publisher7 respectively

################### initialize ###################
clear
echo "Initializing deployment process."
echo ""
UPDATE=0

# update tags from acquia repository
cd acquia
echo "Updating local Acquia repository..."
git fetch --tags
echo "Done."
echo ""

# get the latest acquia build tag
LATEST_BUILD_TAG=$(git describe --tags `git rev-list --tags --max-count=1`)
LATEST_BUILD_TAG_PARSED=(${LATEST_BUILD_TAG//-/ })
echo "Latest build tag: $LATEST_BUILD_TAG"
echo ""
echo "Build info: "
echo "${LATEST_BUILD_TAG//-/$'\n'}"
echo ""
cd ..
<<COMMENT1
LATEST_BUILD_TAG_PARSED=(${LATEST_BUILD_TAG//-/ })

# parse build version
LAST_BUILD_VERSION=${LATEST_BUILD_TAG_PARSED[0]}
LAST_BUILD_VERSION=(${LAST_BUILD_VERSION//build/ })
LAST_BUILD_VERSION=${LAST_BUILD_VERSION[0]}

# parse publisher7 version
P7_VERSION_LATEST=${LATEST_BUILD_TAG_PARSED[1]}
P7_VERSION_LATEST=(${P7_VERSION_LATEST//p/ })
P7_VERSION_LATEST=${P7_VERSION_LATEST[0]}

# parse tve version
TVE_VER_LATEST=${LATEST_BUILD_TAG_PARSED[2]}
TVE_VER_LATEST=(${TVE_VER_LATEST//nbcutve/ })
TVE_VER_LATEST=${TVE_VER_LATEST[0]}

# parse git branch
BRANCH_LATEST=${LATEST_BUILD_TAG_PARSED[3]}

# check if all version tags extracted successfully
if [ $LAST_BUILD_VERSION ] || [ $P7_VERSION_LATEST ] || [ $TVE_VER_LATEST ] || [ $BRANCH_LATEST ] ; then
  echo "Build:      $LAST_BUILD_VERSION"
  echo "Publisher7: $P7_VERSION_LATEST"
  echo "NBCU TVE:   $TVE_VER_LATEST"
  echo "Branch:     $BRANCH_LATEST"
  echo ""
else 
  echo "Error: Could not parse latest build tag."
  exit
fi
COMMENT1


read -n 1 -p "Start new build deployment? (y/n): " CONFIRM
[ "$CONFIRM" = "y" ] || exit
echo ""

# get last build version
LAST_BUILD_VERSION=${LATEST_BUILD_TAG_PARSED[0]}
LAST_BUILD_VERSION=(${LAST_BUILD_VERSION//build/ })
LAST_BUILD_VERSION=${LAST_BUILD_VERSION[0]}

# setup new build version
NEXT_BUILD_VERSION=$(($LAST_BUILD_VERSION+1))

echo "Next build version will be: $NEXT_BUILD_VERSION"
read -n 1 -p "Change build version? (y/n): " CONFIRM
echo ""
if [ "$CONFIRM" = "y" ] ; then
  echo "Enter new build version:"
  read NEXT_BUILD_VERSION
fi

BUILD_VERSION=$NEXT_BUILD_VERSION

echo "Build version is set to $BUILD_VERSION"
echo ""



################### setup publisher7 ###################

# parse publisher7 version
P7_VERSION_LATEST=${LATEST_BUILD_TAG_PARSED[1]}
P7_VERSION_LATEST=(${P7_VERSION_LATEST//p/ })
P7_VERSION_LATEST=${P7_VERSION_LATEST[0]}

echo "Publisher7 (forked) version is: $P7_VERSION_LATEST"
read -n 1 -p "Change Publisher7 version? (y/n): " CONFIRM
echo ""

if [ "$CONFIRM" = "y" ] ; then
  cd publisher7
  echo "Pulling code from forked Publisher7 git repository..."
  git fetch origin
  git checkout tve || (echo "Could not checkout master" && exit 1)
  git pull --ff-only origin tve || (echo "Could not pull. Merge was likely not a fast forward" && exit 1)
  read -n 1 -p "List all forked Publisher7 tags? (y/n): " CONFIRM 
  echo ""
  if [ "$CONFIRM" = "y" ] ; then
    git tag
  fi

  read -n 1 -p "Proceed with Publisher7 update? (y/n): " CONFIRM 
  echo ""
  
  if [ "$CONFIRM" = "y" ] ; then
    read -p "Publisher7 tag to checkout: " P7_VER 
    echo "Checkout..."
    git checkout $P7_VER
    echo "Concatenate gitignore files..."
    cat .gitignore_releases >> .gitignore
    echo "Synchronizing Publisher7 code to acquia/ directory..."
    rsync -aq 	--exclude ".git/" --exclude "docroot/sites/nbcutve" --exclude "docroot/sites/mvpdadmin" --exclude "docroot/sites/default/files" --exclude "docroot/sites/default/files-private" --delete --force . ../acquia
    # remove prefix ("t") from Publisher7 forked tag
    P7_VER=(${P7_VER//t/ })
    P7_VER=${P7_VER[0]}
    UPDATE=1
  else
    P7_VER=$P7_VERSION_LATEST
    echo ""
  fi
  
  cd ..
else
  P7_VER=$P7_VERSION_LATEST
  echo ""
fi



################### setup tve ###################

read -n 1 -p "Deploy TVE? (y/n): " CONFIRM 
echo ""

if [ "$CONFIRM" = "y" ] ; then
  cd nbcutve
  # setup branch
  #LOCAL_BRANCH=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p')
  LOCAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  echo "Current branch: $LOCAL_BRANCH"
  BRANCH_LATEST=$LOCAL_BRANCH
  read -n 1 -p "Switch to other branch? (y/n): " CONFIRM 
  echo ""
  if [ "$CONFIRM" = "y" ] ; then
    echo "Updating local TVE repository..."
	git fetch origin
	echo "Done."
	echo ""
	echo "Available branches:"
	git branch --list -a
	echo ""
	echo "Enter branch name: "
	read LOCAL_BRANCH
	echo ""
	echo "Switching to branch: $LOCAL_BRANCH"
	git checkout "$LOCAL_BRANCH"
	BRANCH_LATEST=$LOCAL_BRANCH
  fi
  
  echo "Updating branch $BRANCH_LATEST..."
  git pull origin "$BRANCH_LATEST"
  echo "Done."

  # detect tag prefix  
  TAG_PREFIX="dev"
  if [[ "$BRANCH_LATEST" == "master" ]] ; then
    TAG_PREFIX="r"
  fi
  
  if [[ "$BRANCH_LATEST" == "dev" ]] ; then
    TAG_PREFIX="dev"
  fi
  
  if [[ "$BRANCH_LATEST" == "release_candidate"* ]] ; then
    TAG_PREFIX="rc"
  fi
  
  echo "TVE tag prefix: $TAG_PREFIX"
  echo "Previous tags with this prefix: "
  
  BRANCH_TAGS=$(git tag -l "$TAG_PREFIX"*)
  echo "$BRANCH_TAGS"
  echo ""
  
  read -p "Enter new TVE tag number (without prefix): " TVE_VER
  echo "TVE version is set to $TVE_VER"
 
  TVE_TAG="$TAG_PREFIX$TVE_VER"
 
  read -n 1 -p "Proceed with files sync for TVE? (y/n): " CONFIRM 
  echo ""
  
  if [ "$CONFIRM" = "y" ] ; then
	read -n 1 -p "Push tag $TVE_TAG? (y/n): " CONFIRM 
	echo ""
	if [ "$CONFIRM" = "y" ] ; then
	  # tag current code and push it back to TVE repo
	  git tag "$TVE_TAG"
      git push -u origin "$TVE_TAG"
	fi
	
	# export changelog to a file
	git log "v$TVE_VER_LATEST".."v$TVE_VER" --merges --format="Date: %ci%nAuthor: %an (%ae)%nCommit: %s%nDescription: %b%n-------------------------------%n" > ../changelogs/changelog."$BRANCH_LATEST"."v$TVE_VER_LATEST"__"v$TVE_VER".txt
	
	# rsync files
    echo "Synchronizing TVE code to acquia/ directory..."
    rsync -aq --exclude ".git/" --exclude ".gitignore" --exclude "default" --exclude "mvpdadmin" --exclude "all/drush" --exclude "all/libraries/ckeditor" --exclude "all/libraries/facebook-php-sdk" --exclude "all/libraries/plupload" --exclude "all/libraries/postscribe" --exclude "all/libraries/smartirc" --exclude "all/libraries/tinymce" --exclude "all/libraries/writecapture" --exclude "all/libraries/zend_crypt" --delete --force . ../acquia/docroot/sites
    cd ..
    UPDATE=1
  fi
else
  TVE_VER=$TVE_VER_LATEST
  echo ""
fi


################### deploy the build ###################

if [ "$UPDATE" = 1 ] ; then
  cd acquia
  #BUILD_TAG="build${BUILD_VERSION}-p${P7_VER}-nbcutve${TVE_VER}-${BRANCH_LATEST}"
  BUILD_TAG="build_${BUILD_VERSION}-tve_${TVE_VER}-pub_${P7_VER}"
  git add -A
  git status
  read -n 1 -p "Press 'y' to commit these changes under $BUILD_TAG: " CONFIRM 
  echo ""
  if [ "$CONFIRM" = "y" ] ; then
    git commit -m "$BUILD_TAG"
    git tag $BUILD_TAG
    git push -u origin $BUILD_TAG
  else
    echo ""
    echo "Exit..."
  fi
  cd ..
else 
  echo "Nothing to deploy. Exit..."
fi