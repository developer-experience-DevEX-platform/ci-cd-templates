#!/usr/bin/env bash
#
# Exercises scripts/gitops-write-desired-state.sh against a throwaway GitOps
# remote. gh and yq are stubbed, so this needs no network and nothing installed
# beyond git and ruby. Run it from anywhere:
#
#   tests/gitops-write-desired-state.test.sh
#
set -euo pipefail

tests_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readonly SCRIPT="$tests_dir/../scripts/gitops-write-desired-state.sh"
readonly SHA_A="1111111111111111111111111111111111111111"
readonly SHA_B="2222222222222222222222222222222222222222"

WORK=$(mktemp -d)
readonly WORK
trap 'rm -rf "$WORK"' EXIT

readonly GITOPS="$WORK/gitops"
readonly REMOTE="$WORK/remote.git"
readonly BIN="$WORK/bin"
failures=0

# gh reports whichever trunk SHA the case under test asks for.
mkdir -p "$BIN"
cat > "$BIN/gh" <<'STUB'
#!/usr/bin/env bash
echo "${FAKE_TRUNK_SHA:?}"
STUB

# yq stands in for the two invocations the script makes. Ruby's YAML is
# stdlib, so this needs no gem install on a runner.
cat > "$BIN/yq" <<'STUB'
#!/usr/bin/env ruby
require "yaml"
if ARGV[0] == "--inplace"
  document = YAML.load_file(ARGV[2])
  document["image"] ||= {}
  document["image"]["tag"] = ENV.fetch("IMAGE_TAG")
  File.write(ARGV[2], document.to_yaml)
else
  puts YAML.load_file(ARGV[2]).dig("image", "tag").to_s
end
STUB

chmod +x "$BIN/gh" "$BIN/yq"
export PATH="$BIN:$PATH"

git init --quiet --bare --initial-branch=main "$REMOTE"
git clone --quiet "$REMOTE" "$GITOPS"
cd "$GITOPS"
git config user.email test@example.com
git config user.name test
mkdir -p environments/staging/svc environments/production/svc
printf 'image:\n  repository: ecr/svc\n  tag: ""\n' > environments/staging/svc/values.yaml
printf 'image:\n  repository: ecr/svc\n  tag: ""\n' > environments/production/svc/values.yaml
git add --all
git commit --quiet --message "seed"
git push --quiet origin HEAD:main

export GITOPS_BRANCH=main
export SERVICE_NAME=svc
export SOURCE_REPOSITORY=org/svc
export GITHUB_REPOSITORY=org/svc
export GITHUB_STEP_SUMMARY="$WORK/summary.md"

fail() {
  echo "FAIL $1"
  echo "     $2"
  failures=$((failures + 1))
}

# run_case <label> <expected exit> <expected output substring> [VAR=value ...]
run_case() {
  local label="$1" expected_exit="$2" expected_text="$3"
  local status=0
  shift 3

  (cd "$GITOPS" && env "$@" bash "$SCRIPT") > "$WORK/out.txt" 2>&1 || status=$?

  if [[ "$status" -ne "$expected_exit" ]]; then
    fail "$label" "expected exit $expected_exit, got $status: $(tr '\n' ' ' < "$WORK/out.txt")"
  elif ! grep --quiet -- "$expected_text" "$WORK/out.txt"; then
    fail "$label" "output did not contain: $expected_text"
  else
    echo "ok   $label"
  fi
}

# assert_remote <label> <path> <expected substring>
assert_remote() {
  local label="$1" path="$2" expected="$3" content

  if ! content=$(git -C "$REMOTE" show "main:$path" 2>&1); then
    fail "$label" "$path is not on the remote: $content"
  elif [[ "$content" != *"$expected"* ]]; then
    fail "$label" "$path does not contain $expected"
  else
    echo "ok   $label"
  fi
}

run_case "staging deploys the current trunk SHA" 0 "Desired state updated for staging" \
  ENVIRONMENT=staging IMAGE_TAG="$SHA_A" FAKE_TRUNK_SHA="$SHA_A"

run_case "staging re-run makes no empty commit" 0 "No change required" \
  ENVIRONMENT=staging IMAGE_TAG="$SHA_A" FAKE_TRUNK_SHA="$SHA_A"

run_case "staging skips a superseded SHA and succeeds" 0 "A newer release supersedes it" \
  ENVIRONMENT=staging IMAGE_TAG="$SHA_B" FAKE_TRUNK_SHA="$SHA_A"

run_case "production promotes what staging runs" 0 "Desired state updated for production" \
  ENVIRONMENT=production IMAGE_TAG="$SHA_A"

run_case "production rejects a SHA staging is not running" 1 "Promote only what staging is running" \
  ENVIRONMENT=production IMAGE_TAG="$SHA_B"

run_case "an unknown environment is rejected" 1 "Expected staging or production" \
  ENVIRONMENT=dev IMAGE_TAG="$SHA_A"

run_case "a missing values file is not papered over" 1 "Platform provisioning is incomplete" \
  ENVIRONMENT=staging IMAGE_TAG="$SHA_A" FAKE_TRUNK_SHA="$SHA_A" SERVICE_NAME=absent-svc

run_case "a missing required variable stops the run" 1 "IMAGE_TAG" \
  ENVIRONMENT=staging IMAGE_TAG=""

assert_remote "staging values carry the deployed tag" environments/staging/svc/values.yaml "$SHA_A"
assert_remote "production values carry the promoted tag" environments/production/svc/values.yaml "$SHA_A"
assert_remote "first promotion creates the marker" environments/production/svc/promotion.yaml "enabled: true"

if ! grep --quiet "First promotion" "$GITHUB_STEP_SUMMARY"; then
  fail "first promotion is named in the run summary" "summary was: $(tr '\n' ' ' < "$GITHUB_STEP_SUMMARY")"
else
  echo "ok   first promotion is named in the run summary"
fi

echo
if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed."
  exit 1
fi
echo "All checks passed."
