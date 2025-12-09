#!/usr/bin/env bash
set -Eeuo pipefail

RELEASER_VERSION="2.1.0"
RELEASER_FILE="ops/releaser-${RELEASER_VERSION}"

##

CANDIDATE_ZIP_BUCKET=joi-news-gcp-interviews
GENERIC_ZIP_BUCKET=joi-news-gcp-generic

OMIT_FROM_ALL_ZIPS='-x "*.zip" -x "ops/*" -x ".git/*" -x "**/.git*" -x ".git*" \
  -x .service-account-creds.json -x .gdrive-creds.json -x ".circleci/*" \
  -x ".DS_Store" -x ".interviewer-account.txt" \
  -x "*/.terraform/*" -x "*.tfstate*" -x "*.tfplan" -x "*/classes/*" -x "*.class"'
OMIT_FROM_GENERIC_ZIPS="-x *creds.json -x '*id_rsa*' -x gcr-url.txt -x *id.txt"

#TODO: could be restricted to disallow breaking supporting infrastructure
INTERVIEW_ROLE=roles/editor

function source_releaser {
  mkdir -p ops
  if [[ ! -f $RELEASER_FILE ]];then
    wget --quiet -O $RELEASER_FILE https://github.com/kudulab/releaser/releases/download/${RELEASER_VERSION}/releaser
  fi
  source $RELEASER_FILE
}

function install_prerequisites {
  set +e
  if [[ $(uname) != "Darwin" ]]; then
    >&2 echo "not OSX, you'll have to ensure all tools installed yourself"
    return
  fi

  if ! brew --version; then
    echo "brew not found, you'll have to ensure all tools installed yourself" >&2
    return
  fi
  which dojo || brew install kudulab/homebrew-dojo-osx/dojo
  which jq || brew install jq
  which gcloud || (curl https://sdk.cloud.google.com | bash)
}

# Publishes zip which recruiters distribute to the candidates when scheduling the interview.
# This is immutable and should not be deleted.
# We are sending a link to this GS url to the candidates in emails.
function publish_generic_candidate_zip {
  >&2 echo "Preparing generic zip package for candidate"
  version=$(releaser::get_last_version_from_whole_changelog "${changelog_file}")
  file="joi-news-gcp-candidate-${version}.zip"
  file_latest="joi-news-gcp-candidate-latest.zip"
  cd joi-news-gcp
  rm -f ../$file
  zipcmd="zip -r ../$file . -x $file $OMIT_FROM_ALL_ZIPS $OMIT_FROM_GENERIC_ZIPS"
  eval $zipcmd
  cd ..
  gsutil cp $file gs://$GENERIC_ZIP_BUCKET/
  gsutil cp gs://$GENERIC_ZIP_BUCKET/$file gs://$GENERIC_ZIP_BUCKET/$file_latest
}

# Publishes zip which interviewers use when they don't have access to github recops
function publish_generic_interviewer_zip(){
  >&2 echo "Preparing zip package for interviewer"
  version=$(releaser::get_last_version_from_whole_changelog "${changelog_file}")
  file="joi-news-gcp-interviewer-${version}-full.zip"
  file_latest="joi-news-gcp-interviewer-latest-full.zip"
  rm -f $file
  eval "zip -r $file . $OMIT_FROM_ALL_ZIPS $OMIT_FROM_GENERIC_ZIPS"
  # TODO bake these into the dojo image eventually if desired
  pip3 install --upgrade google-api-python-client google-auth-httplib2 google-auth-oauthlib
  ./gdrive_upload.py $file
}

# In case you want to share your local changes with the candidate
function publish_candidate_zip {
  INTERVIEW_CODE=$(cat .projectid.txt)
  file=joi-news-$INTERVIEW_CODE.zip
  BUCKET_URL=$CANDIDATE_ZIP_BUCKET/$file
  if ! gsutil -i interviewer@joi-news.iam.gserviceaccount.com ls gs://$BUCKET_URL; then
    >&2 echo "Preparing zip package for candidate"
    cd joi-news-gcp
    >&2 eval "zip -rq ../$file ./ -x "./$file" $OMIT_FROM_ALL_ZIPS"
    cd ..
    >&2 echo "Publishing artifact to GS bucket..."
    if ! gsutil -i interviewer@joi-news.iam.gserviceaccount.com cp $file gs://$CANDIDATE_ZIP_BUCKET/; then
      >&2 echo "Artifact preparation for candidate interview failed."
      exit 5
    fi
  fi
  >&2 echo "Artifact is prepared and available at: https://storage.googleapis.com/$BUCKET_URL"
  gsutil -i interviewer@joi-news.iam.gserviceaccount.com signurl -r us -u -d 12h gs://$BUCKET_URL || exit 1
}

if [ "$#" -eq 0 ]; then
  echo "Error: need to specify a command to run." >&2
  exit 1
fi

command="$1"
case "${command}" in
  install_prerequisites)
      install_prerequisites
      ;;
  candidate_prep)
      dojo "./recops.sh _candidate_prep"
      ;;
  _candidate_prep)
      echo "Here is all you need to share with the candidate:"
      echo ""
      echo "Hi there! Please explore README.md for instructions."
      echo ""
      echo "Please email above to the candidate."
      ;;
  _prepare_candidate_zip)
      publish_candidate_zip
      ;;
  prepare_candidate_zip)
      BUCKET_URL=$(dojo -c Dojofile "./recops.sh _prepare_candidate_zip")
      echo "-----------------------------------------------------------------------------"
      echo ""
      echo "Please share this signed link to unique zip containing codebase with the candidate:"
      echo "$BUCKET_URL"
      echo ""
      ;;
  _create_tmp_user)
      INTERVIEW_CODE=$(cat interview_id.txt)
      gcloud iam service-accounts create "interview-$INTERVIEW_CODE" --display-name "Service Account for $INTERVIEW_CODE"
      gcloud projects add-iam-policy-binding "joi-news-$TW_REGION" --member "serviceAccount:interview-$INTERVIEW_CODE@joi-news-$TW_REGION.iam.gserviceaccount.com" --role "$INTERVIEW_ROLE"
      ;;
  _create_user_creds)
      INTERVIEW_CODE=$(cat interview_id.txt)
      gcloud iam service-accounts keys create ./infra/.interviewee-creds.json --iam-account "interview-$INTERVIEW_CODE@joi-news-$TW_REGION.iam.gserviceaccount.com"
      ;;
  setup_user)
      ./recops.sh _create_tmp_user
      ./recops.sh _create_user_creds
      ;;
  verify_version)
      source_releaser
      releaser::verify_release_ready
      ;;
  # Releases this git repo
  release)
      ./recops.sh verify_version
      source_releaser
      version=$(releaser::get_last_version_from_whole_changelog "${changelog_file}")
      git tag "${version}"
      ;;
  # Publish the zip to GCS to distribute among candidates
  publish)
      dojo -c Dojofile "./recops.sh _publish"
      ;;
  _publish)
      source_releaser
      publish_generic_candidate_zip
      publish_generic_interviewer_zip
      ;;
  *)
      echo "Invalid command: '${command}'" >&2
      exit 1
      ;;
esac
