#!/usr/bin/env bash
set -eux
SUBJECT="${1}"
TEXT="${2}"
SLACK_WEBHOOK_URL=$3
IMAGE_URL=$4

json=$(cat <<EOF
{
"text": "${SUBJECT}",
"attachments": [
  {
    "blocks": [
      {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": "${TEXT}"
        },
        "accessory": {
          "type": "image",
          "image_url": "${IMAGE_URL}",
          "alt_text": "From tekton with love"
        }
      }
    ]
  }
]
}
EOF
)
curl -X POST -H 'Content-type: application/json' --data "${json}" $SLACK_WEBHOOK_URL
