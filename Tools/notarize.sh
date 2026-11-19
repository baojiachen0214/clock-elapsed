#!/bin/zsh
set -euo pipefail
archive="$1"
receipt_prefix="$2"
if [[ -n "${CLOCKELAPSED_NOTARY_PROFILE:-}" ]]; then
  notary_auth=(--keychain-profile "$CLOCKELAPSED_NOTARY_PROFILE")
else
  : "${CLOCKELAPSED_NOTARY_KEY:?Set a notarytool profile or API key path}"
  : "${CLOCKELAPSED_NOTARY_KEY_ID:?Set the API key ID}"
  notary_auth=(--key "$CLOCKELAPSED_NOTARY_KEY" --key-id "$CLOCKELAPSED_NOTARY_KEY_ID")
  if [[ -n "${CLOCKELAPSED_NOTARY_ISSUER:-}" ]]; then
    notary_auth+=(--issuer "$CLOCKELAPSED_NOTARY_ISSUER")
  fi
fi
# Save Apple's actual verdict; a successful upload alone is not acceptance.
submit_status=0
xcrun notarytool submit "$archive" $notary_auth --wait --output-format json > "$receipt_prefix.json" || submit_status=$?
submission_id=$(/usr/bin/plutil -extract id raw "$receipt_prefix.json")
verdict=$(/usr/bin/plutil -extract status raw "$receipt_prefix.json")
xcrun notarytool log "$submission_id" $notary_auth "$receipt_prefix-log.json"
echo "Notarization $submission_id: $verdict"
if [[ "$verdict" != Accepted || "$submit_status" != 0 ]]; then
  echo "Notarization did not pass. See $receipt_prefix-log.json" >&2
  exit 1
fi
