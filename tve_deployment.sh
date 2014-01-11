#!/bin/bash
# Requirements: cloned repositories into acquia, nbcutve and publisher7 respectively

clear

UPDATE=0
cd acquia

echo "Fetching latest built tags..."
git fetch --tags
echo "Done"

# get the latest acquia build tag
LATEST_BUILD_TAG=$(git describe --tags `git rev-list --tags --max-count=1` 2>&1)
echo "Current build tag is $LATEST_BUILD_TAG"
cd ..
arrIN=(${LATEST_BUILD_TAG//-/ })

# parse build version
BUILD_VER_LATEST=${arrIN[0]}
BUILD_VER_LATEST=(${BUILD_VER_LATEST//build/ })
BUILD_VER_LATEST=${BUILD_VER_LATEST[0]}

# parse publisher7 version
P7_VER_LATEST=${arrIN[1]}
P7_VER_LATEST=(${P7_VER_LATEST//p/ })
P7_VER_LATEST=${P7_VER_LATEST[0]}

# parse tve version
TVE_VER_LATEST=${arrIN[2]}
TVE_VER_LATEST=(${TVE_VER_LATEST//nbcutve/ })
TVE_VER_LATEST=${TVE_VER_LATEST[0]}

# parse git branch
BRANCH_LATEST=${arrIN[3]}

# check if all version tags extracted successfully
if [ $BUILD_VER_LATEST ] || [ $P7_VER_LATEST ] || [ $TVE_VER_LATEST ] ; then
  echo "Build:      $BUILD_VER_LATEST"
  echo "Publisher7: $P7_VER_LATEST"
  echo "NBCU TVE:   $TVE_VER_LATEST"
  echo "Branch:     $BRANCH_LATEST"
else 
  echo "Problem to extract some important data (version tag). Exit..."
  exit
fi

read -n 1 -p "Are You sure to start new build deployment (y/[a]): " AMSURE 
[ "$AMSURE" = "y" ] || exit
echo "" 1>&2
read -p "Set build version (current $BUILD_VER_LATEST): " BUILD_VER
echo "Build version is set to $BUILD_VER"
read -n 1 -p "Change Publisher7 forked(!) version (current $P7_VER_LATEST)? (y/[a]): " AMSURE 
echo "" 1>&2

if [ "$AMSURE" = "y" ] ; then
  cd publisher7
  echo "Pulling code from forked Publisher7 git repository..."
  git fetch origin
  git checkout tve || (echo "Could not checkout master" && exit 1)
  git pull --ff-only origin tve || (echo "Could not pull. Merge was likely not a fast forward" && exit 1)
  read -n 1 -p "List all forked Publisher7 tags? (y/[a]): " AMSURE 
  echo "" 1>&2
  if [ "$AMSURE" = "y" ] ; then
    git tag
  fi
  
  read -n 1 -p "Proceed with Publisher7 update? (y/[a]): " AMSURE 
  echo "" 1>&2
  if [ "$AMSURE" = "y" ] ; then
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
    P7_VER=$P7_VER_LATEST
    echo "" 1>&2
  fi
  
  cd ..
else
  P7_VER=$P7_VER_LATEST
  echo "" 1>&2
fi

read -n 1 -p "Deploy TVE? (y/[a]): " AMSURE 
echo "" 1>&2

if [ "$AMSURE" = "y" ] ; then
  cd nbcutve
  
  # setup branch
  LOCAL_BRANCH=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p')
  echo "Local git branch is: $LOCAL_BRANCH"
  BRANCH_LATEST=$LOCAL_BRANCH
  read -n 1 -p "Checkout other branch? (y/[a]): " AMSURE 
  echo "" 1>&2
  if [ "$AMSURE" = "y" ] ; then
	read -p "Branch name: " LOCAL_BRANCH
	echo "Checkout to $LOCAL_BRANCH branch..."
	git checkout "$LOCAL_BRANCH"
  fi

  read -p "Set TVE version (current $TVE_VER_LATEST): " TVE_VER
  echo "TVE version is set to $TVE_VER"
  echo "Pulling code from TVE git repository..."
  git pull origin "$LOCAL_BRANCH"
  read -n 1 -p "Proceed with files sync for TVE? (y/[a]): " AMSURE 
  echo "" 1>&2
  
  if [ "$AMSURE" = "y" ] ; then
	read -n 1 -p "Push tag v$TVE_VER? (y/[a]): " AMSURE 
	echo "" 1>&2
	if [ "$AMSURE" = "y" ] ; then
	  # Tag current code and push it back to TVE repo
	  git tag "v$TVE_VER"
      git push -u origin "v$TVE_VER"
	fi
	
	# Export changelog to a file
	git log "v$TVE_VER_LATEST".."v$TVE_VER" --merges --format="Date: %ci%nAuthor: %an (%ae)%nCommit: %s%nDescription: %b%n-------------------------%n" > ../changelogs/changelog.tve."v$TVE_VER_LATEST"__"v$TVE_VER".txt
	
    echo "Synchronizing TVE code to acquia/ directory..."
    rsync -aq --exclude ".git/" --exclude ".gitignore" --exclude "default" --exclude "mvpdadmin" --exclude "all/drush" --exclude "all/libraries/ckeditor" --exclude "all/libraries/facebook-php-sdk" --exclude "all/libraries/plupload" --exclude "all/libraries/postscribe" --exclude "all/libraries/smartirc" --exclude "all/libraries/tinymce" --exclude "all/libraries/writecapture" --exclude "all/libraries/zend_crypt" --delete --force . ../acquia/docroot/sites
    cd ..
    UPDATE=1
  fi
else
  TVE_VER=$TVE_VER_LATEST
  echo "" 1>&2
fi

if [ "$UPDATE" = 1 ] ; then
  # Deploy code to Acqia hosting
  cd acquia
  BUILD_TAG="build${BUILD_VER}-p${P7_VER}-nbcutve${TVE_VER}-${BRANCH_LATEST}"
  git add -A
  git status
  read -n 1 -p "Commit these changes under $BUILD_TAG tag? (y/[a]): " AMSURE 
  echo "" 1>&2
  if [ "$AMSURE" = "y" ] ; then
    git commit -m "$BUILD_TAG"
    git tag $BUILD_TAG
    git push -u origin $BUILD_TAG
  else
    echo "" 1>&2
    echo "Exit..."
  fi
  cd ..
else 
  echo "Nothing to deploy. Exit..."
fi