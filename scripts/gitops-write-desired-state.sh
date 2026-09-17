#!/usr/bin/env bash
#
# Writes a service's image tag into platform-gitops desired state.
#
# Shared by kubernetes-gitops-cd.yml (staging, automatic on push to main) and
# kubernetes-gitops-production-promotion.yml (production, manual). Run from
# inside a checkout of the GitOps repository.
#
# Each environment has one gate of its own:
#   staging     skips when a newer commit already reached the service's trunk
#   production  refuses anything staging is not currently running
#
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:?staging or production}"
SERVICE_NAME="${SERVICE_NAME:?service name}"
IMAGE_TAG="${IMAGE_TAG:?40-character Git commit SHA}"
GITOPS_BRANCH="${GITOPS_BRANCH:?GitOps trunk branch}"
SOURCE_REPOSITORY="${SOURCE_REPOSITORY:?repository the image was built from}"

readonly MAX_ATTEMPTS=3

values_file="environments/$ENVIRONMENT/$SERVICE_NAME/values.yaml"
staging_values_file="environments/staging/$SERVICE_NAME/values.yaml"
marker_file="environments/production/$SERVICE_NAME/promotion.yaml"
first_promotion=false

fail() {
  echo "::error::$1"
  exit 1
}

write_summary() {
  if [[ -z "${GITHUB_STEP_SUMMARY:-}" ]]; then
    return 0
  fi

  {
    echo "# Production Promotion"
    echo
    echo "**Service:**"
    echo "$SERVICE_NAME"
    echo
    echo "**Image Tag:**"
    echo "$IMAGE_TAG"
    echo
    echo "**Outcome:**"
    echo "- $1"
  } >> "$GITHUB_STEP_SUMMARY"
}

# A newer commit on the service's trunk means a newer release is already on
# its way to staging. Writing this older SHA would roll staging back, so the
# run succeeds without deploying.
skip_if_superseded() {
  local current_trunk_sha
  current_trunk_sha=$(gh api "repos/$GITHUB_REPOSITORY/branches/main" --jq '.commit.sha')

  if [[ "$IMAGE_TAG" != "$current_trunk_sha" ]]; then
    echo "Staging deployment skipped: $IMAGE_TAG is no longer the current main SHA ($current_trunk_sha). A newer release supersedes it."
    exit 0
  fi
}

# Production runs the same image bytes staging tested, nothing else.
require_staging_running_image() {
  local staging_image_tag

  if [[ ! -f "$staging_values_file" ]]; then
    fail "Staging values file not found: $staging_values_file"
  fi

  staging_image_tag=$(yq --unwrapScalar '.image.tag' "$staging_values_file")
  if [[ "$staging_image_tag" != "$IMAGE_TAG" ]]; then
    fail "Production promotion rejected: staging references $staging_image_tag, not $IMAGE_TAG. Promote only what staging is running."
  fi
}

if [[ "$ENVIRONMENT" != staging ]] && [[ "$ENVIRONMENT" != production ]]; then
  fail "Unknown environment: $ENVIRONMENT. Expected staging or production."
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

# Several services share this GitOps repository, so a push can lose a race.
# Re-read trunk and retry rather than failing the deploy.
for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  echo "GitOps push attempt $attempt of $MAX_ATTEMPTS."

  git fetch origin "$GITOPS_BRANCH"
  git reset --hard "origin/$GITOPS_BRANCH"

  if [[ "$ENVIRONMENT" == staging ]]; then
    skip_if_superseded
  else
    require_staging_running_image
  fi

  if [[ ! -f "$values_file" ]]; then
    fail "Values file not found: $values_file. Platform provisioning is incomplete."
  fi

  export IMAGE_TAG
  yq --inplace '.image.tag = env(IMAGE_TAG)' "$values_file"
  git add "$values_file"

  if [[ "$ENVIRONMENT" == production ]]; then
    if [[ ! -f "$marker_file" ]]; then
      printf 'enabled: true\n' > "$marker_file"
      first_promotion=true
    fi
    git add "$marker_file"
  fi

  if git diff --staged --quiet; then
    echo "No change required: $ENVIRONMENT already references image $IMAGE_TAG."
    if [[ "$ENVIRONMENT" == production ]]; then
      write_summary "No change: production already references this image."
    fi
    exit 0
  fi

  git commit \
    --message "deploy($ENVIRONMENT): $SERVICE_NAME to $IMAGE_TAG" \
    --message "Source: $SOURCE_REPOSITORY@$IMAGE_TAG"

  if git push origin "HEAD:$GITOPS_BRANCH"; then
    echo "Desired state updated for $ENVIRONMENT: $SERVICE_NAME is now $IMAGE_TAG."
    if [[ "$ENVIRONMENT" == production ]]; then
      if [[ "$first_promotion" == true ]]; then
        write_summary "First promotion. Argo CD now discovers this service in production."
      else
        write_summary "Production desired state updated."
      fi
    fi
    exit 0
  fi

  if (( attempt < MAX_ATTEMPTS )); then
    sleep $((attempt * 2))
  fi
done

fail "Unable to push $ENVIRONMENT desired state after $MAX_ATTEMPTS attempts."
