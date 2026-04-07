# txt2task

Turn iMessages from a specific contact into Linear issues and Todoist tasks automatically. Any message starting with `request:` (case-insensitive) gets routed to both services.

## How it works

A bash script reads new messages from the macOS Messages SQLite database (`~/Library/Messages/chat.db`), filters for those starting with `request:`, strips the prefix, and sends them to the Linear and Todoist APIs. State is tracked via the message ROWID so messages are never processed twice — even if your machine sleeps or restarts.

A `launchd` agent runs the script every 60 seconds and at login.

## Requirements

- macOS (uses Messages and `launchd`)
- Python 3 (preinstalled on macOS)
- A Linear API key + team ID
- A Todoist API key
- Full Disk Access granted to `/bin/bash` (instructions below)

## Setup

### 1. Clone the repo

```bash
git clone git@github.com:alexchung1233/txt2task.git
cd txt2task
```

### 2. Install the script

Copy the script somewhere outside `~/Downloads` (macOS quarantines files in Downloads, which breaks `launchd` execution):

```bash
mkdir -p ~/.local/bin
cp imessage_to_linear.sh ~/.local/bin/
chmod +x ~/.local/bin/imessage_to_linear.sh
```

### 3. Create the `.env` file

```bash
cp .env.example ~/.local/bin/.env
chmod 600 ~/.local/bin/.env
```

Then edit `~/.local/bin/.env` and fill in:

- `LINEAR_API_KEY` — get from https://linear.app/settings/api
- `LINEAR_TEAM_ID` — find via the Linear API or URL of your team
- `TODOIST_API_KEY` — get from https://todoist.com/app/settings/integrations/developer
- `PHONE` — phone number of the contact to monitor (digits only, e.g. `5551234567`)

### 4. Grant Full Disk Access

`launchd` needs permission to read the Messages database:

1. Open **System Settings → Privacy & Security → Full Disk Access**
2. Click **+**, press **Cmd+Shift+G**, type `/bin/bash`, hit Enter
3. Toggle it **on**

### 5. Install the launchd agent

Edit `com.alexchung.imessage-to-linear.plist` and update the script path and log paths to match your username, then:

```bash
cp com.alexchung.imessage-to-linear.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.alexchung.imessage-to-linear.plist
```

The agent will now run every 60 seconds and at login.

### 6. Test it

Send yourself (or your monitored contact) a text message starting with `request:`, e.g.:

```
request: pick up groceries
```

Within a minute it should appear as an issue in Linear and a task in Todoist (with the `request:` prefix stripped and the first letter capitalized).

You can also run the script manually:

```bash
bash ~/.local/bin/imessage_to_linear.sh
```

## Managing the agent

```bash
# Stop the agent
launchctl unload ~/Library/LaunchAgents/com.alexchung.imessage-to-linear.plist

# Start the agent
launchctl load ~/Library/LaunchAgents/com.alexchung.imessage-to-linear.plist

# Check if it's running
launchctl list | grep imessage

# View logs
tail -f ~/.imessage_to_linear.log
```

## Files

- `imessage_to_linear.sh` — main script
- `.env.example` — template for required env vars
- `com.alexchung.imessage-to-linear.plist` — launchd agent definition

## State

- `~/.imessage_to_linear_last_rowid` — tracks the last processed message ROWID so messages aren't duplicated across runs
- `~/.imessage_to_linear.log` — output log
