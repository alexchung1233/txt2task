#!/bin/bash

# Load environment variables from .env file (located next to this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/.env}"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
else
  echo "Error: .env file not found at $ENV_FILE" >&2
  exit 1
fi

# Required env vars: LINEAR_API_KEY, LINEAR_TEAM_ID, TODOIST_API_KEY, PHONE
: "${LINEAR_API_KEY:?LINEAR_API_KEY not set}"
: "${LINEAR_TEAM_ID:?LINEAR_TEAM_ID not set}"
: "${TODOIST_API_KEY:?TODOIST_API_KEY not set}"
: "${PHONE:?PHONE not set}"

STATE_FILE="${STATE_FILE:-$HOME/.imessage_to_linear_last_rowid}"

# Pull new messages since last run, filtered to "request:" prefix
while IFS= read -r msg; do
  if [ -z "$msg" ]; then continue; fi

  # Strip "request: " prefix and escape double quotes for JSON
  cleaned=$(echo "$msg" | sed -E 's/^[Rr][Ee][Qq][Uu][Ee][Ss][Tt]:\s*//')
  cleaned="$(echo "${cleaned:0:1}" | tr '[:lower:]' '[:upper:]')${cleaned:1}"
  escaped=$(echo "$cleaned" | sed 's/"/\\"/g')

  # Create Linear issue
  curl -s -X POST https://api.linear.app/graphql \
    -H "Authorization: $LINEAR_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"query\": \"mutation { issueCreate(input: { teamId: \\\"$LINEAR_TEAM_ID\\\", title: \\\"$escaped\\\", description: \\\"From iMessage\\\" }) { success issue { id title } } }\"
    }"

  # Create Todoist task
  curl -s -X POST https://api.todoist.com/api/v1/tasks \
    -H "Authorization: Bearer $TODOIST_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"$escaped\", \"description\": \"From iMessage\"}"

  echo "$(date '+%Y-%m-%d %H:%M:%S') Created issue + task: $msg"
done < <(python3 -c "
import sqlite3, re, os

state_file = os.path.expanduser('${STATE_FILE}')
last_rowid = 0
if os.path.exists(state_file):
    with open(state_file) as f:
        try:
            last_rowid = int(f.read().strip())
        except:
            last_rowid = 0

db = sqlite3.connect(os.path.expanduser('~/Library/Messages/chat.db'))
rows = db.execute('''
  SELECT m.ROWID, m.text, m.attributedBody FROM message m
  JOIN chat_message_join cmj ON m.ROWID = cmj.message_id
  JOIN chat c ON cmj.chat_id = c.ROWID
  WHERE c.chat_identifier LIKE '%${PHONE}%'
    AND m.ROWID > ?
  ORDER BY m.ROWID ASC
''', (last_rowid,)).fetchall()

max_rowid = last_rowid
for rowid, text, body in rows:
    if rowid > max_rowid:
        max_rowid = rowid
    if not text and body:
        try:
            cleaned = re.sub(rb'[^\x20-\x7E]', b' ', body)
            m = re.search(rb'NSString\s+..(.*?)\s+iI', cleaned)
            if m:
                text = m.group(1).decode('utf-8', errors='ignore').strip()
        except:
            pass
    if text and text.lower().startswith('request:'):
        print(text)

with open(state_file, 'w') as f:
    f.write(str(max_rowid))

db.close()
")
