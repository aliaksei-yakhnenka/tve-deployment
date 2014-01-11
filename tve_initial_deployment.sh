#!/bin/bash
# Preparations before deployment - creating dirs and cloning repositories into them.
# Requirements: clean directory .
read -n 1 -p "Are You sure to start preparations for deployment (y/[a]): " AMSURE 
[ "$AMSURE" = "y" ] || exit
echo "" 1>&2
read -n 1 -p "Doy You have access to Acquia hosting, NBCUOTS/Publisher7, NBCUOTS/Publisher7_nbcutve and NBCUOTS/Publisher7_mvpd_admin repositories (SSH keys are configured)?(y/[a]): " AMSURE 
[ "$AMSURE" = "y" ] || exit
echo "" 1>&2
mkdir publisher7
cd publisher7
echo "Start cloning Publisher7 core (forked: git@github.com:aliaksei-yakhnenka/Publisher7.git)"
git clone git@github.com:aliaksei-yakhnenka/Publisher7.git .
echo "Publisher7 core (forked) cloned."
read -n 1 -p "List all Publisher7 tags? (y/[a]): " AMSURE 
echo "" 1>&2
if [ "$AMSURE" = "y" ] ; then
  git tag
fi
read -n 1 -p "Checkout to specific Publisher7 tag? (y/[a]): " AMSURE 
echo "" 1>&2
if [ "$AMSURE" = "y" ] ; then
  read -p "Publisher7 tag to checkout: " P7_VER 
  echo "Checkout..."
  git checkout $P7_VER
fi
cat .gitignore_releases >> .gitignore
cd ..
mkdir nbcutve
cd nbcutve
echo "Start cloning Publisher7_nbcutve"
git clone git@github.com:NBCUOTS/Publisher7_nbcutve.git .
git checkout dev
echo "Publisher7_nbcutve cloned."
cd ..
mkdir mvpdadmin
cd mvpdadmin
echo "Start cloning Publisher7_mvpd_admin"
git clone git@github.com:NBCUOTS/Publisher7_mvpd_admin.git .
git checkout dev
echo "Publisher7_mvpd_admin cloned."
cd ..
mkdir acquia
cd acquia
echo "Start cloning Acquia repository"
git clone nbcutve@svn-3224.prod.hosting.acquia.com:nbcutve.git .
echo "Acquia repository cloned."
echo "Please set latest version (see tags) and preparations for deployment will be completed."
cd ..
mkdir changelogs
